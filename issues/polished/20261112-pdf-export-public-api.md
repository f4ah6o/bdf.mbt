# PDF 書き出しの公開 npm API

Status: polished
Model: unknown
Created: 2026-11-12
Updated: 2026-11-12
Branch: feat/20261112-pdf-export-public-api

## 概要

既存の BDF→PDF writer を `bdf.mbt` npm パッケージから利用できる、型付きの公開 JavaScript API として提供する。アプリごとの PDF 出力処理が、デモサイトの内部コードや未公開ビルド成果物を参照せず共通 API を利用できるようにする。

## 背景

確認対象は main `61f195b38293415a46a6aca4cff99187ba68ea5e`。

- `export/pdf/pdf.mbt` は `write_bytes` / `write_document`、`PdfOptions`（views、tagged、compress、fallback_font）、`PdfResult`（bytes、pages、fonts、warnings）を持つ。
- `bridge/wasm` は `bdf_wasm_export_pdf` / `bdf_wasm_export_pdf_font` を持つが、これは公開 npm API の契約ではない。
- `plugin/tools/library-pack.mjs` の export map には browser、forms、xdw、plugin 等があるが、PDF 書き出し用の公開エントリはない。
- `export/pdf/content.mbt` は画像・切り抜き画像、影、フィルターの省略とグラデーション近似を警告する。`pdf.mbt` はタグ付き構造の未実装、ページを持たないビュー、フォントの不足も警告する。
- `issues/open/20261109-native-convert-export.md` は native 対応、`20261109-parity-pdf-structure.md` は PDF 読み込み側の構造互換性であり、本件の npm 書き出し API とは別範囲。

## 問題

利用者が npm パッケージだけで BDF bytes を PDF bytes に変換する安定した入口、型定義、警告・例外契約を利用できない。プレビューできることと、PDF に画像や日本語を欠落なく書き出せることが混同されるおそれがある。

## 目標

ブラウザーと Node.js で、インストール済みパッケージの公開パスから BDF bytes と必要なフォントを渡して PDF bytes、ページ数、埋め込みフォント数、警告を取得できる。ダウンロードやファイル保存は呼び出し側に任せる。

## 対象外

- PDF writer の全形式互換性、画像描画・タグ付き PDF・PDF/A・電子署名の新規実装。
- XLSX sheet ビューから印刷ページを生成するレイアウトエンジン、Office 形式への書き戻し。
- アプリ固有のデータ取得、帳票テンプレート、権限、保存先 UI。
- フォントの自動外部取得・OS フォント列挙・ライセンス判断の代行。
- 本 Issue 作成時点での実装、npm 公開、リリース実行。

## 提案する方針

1. 公開サブパス `bdf.mbt/pdf` に `exportPdf(input: Uint8Array, options?): Promise<PdfExportResult>` を追加する。結果は `bytes: Uint8Array`、`pages: number`、`fonts: number`、`warnings: string[]`。公開名と型をドキュメント・型テストで固定する。
2. options は既存 writer の `views`、`tagged`、`compress`、`fallbackFont: Uint8Array` に対応させる。既定値は既存 writer と一致させる。入力バッファを変更・detach しない。型不正や壊れた BDF は Promise の reject とし、空の PDF を成功として返さない。
3. `export/pdf` を再利用する JS bridge を用意し、可能な範囲で既存 writer の処理を共有する。Wasm を選ぶ場合も必要な資産をパッケージに含め、デモサイトや開発 checkout からの取得を不要にする。初期化方法とサポート環境を明示する。
4. 現在の writer が返す警告を欠落なく結果へ伝える。画像省略等の警告がある結果を「完全再現」と表現しない。ページを持つ対象ビューがなく PDF ページ数が 0 の場合は明示的に reject する。無効な view 指定の扱いもテストする。
5. フォントは呼び出し側が提供する bytes を使用し、既存のサブセット埋め込みを維持する。フォント未指定、日本語の欠落、壊れたフォント、未収録グリフ時の実際の結果・警告を明文化する。単一 fallback で regular/bold の忠実な再現を保証しない。
6. `plugin/tools/library-pack.mjs` とパッケージ検証に export map、JS、型宣言、必要資産を追加する。既存 exports と import 時の挙動は壊さない。
7. `plugin/library/README.md` にブラウザーの Blob 保存例と Node.js のファイル保存例、forms が返す BDF からの接続例、対応範囲表、警告の表示例を追加する。例のフォントは利用者が適切な権利で用意し、無断の外部通信をしない。

## 受け入れ条件

- [ ] npm pack 相当の tarball を空の consumer にインストールし、公開パスだけで import と TypeScript 型チェックが成功する。
- [ ] ブラウザーと Node.js の双方で、単一・複数ページの BDF から読み取り可能な PDF と正しいページ数を取得できる。
- [ ] ページサイズ、罫線、既存 writer が扱える文字・図形、view 選択を維持し、入力 bytes を変更しない。
- [ ] 日本語フォントを明示供給すると期待する文字を抽出でき、フォントが埋め込まれる。未指定・欠落グリフ・不正フォントは、欠落を隠さず仕様どおり警告または reject する。
- [ ] 画像・切り抜き画像・影・フィルター・グラデーション・tagged の制限を返却警告で識別でき、ドキュメントと一致する。
- [ ] 壊れた BDF、型不正、ページなしビュー、無効な view 指定の結果をテストし、0 ページの出力を成功として返さない。
- [ ] パッケージ内の資産だけで実行でき、自動フォント取得や非公開ファイルへの依存がない。
- [ ] 公開 API、型宣言、実行例、制限とエラー契約が一致し、既存 npm exports の回帰テストが通る。

## テスト計画

- 既存 writer: `moon test export/pdf --target js`。bridge を追加した場合はその単体テストを追加し実行する。
- package: 既存 `plugin/tools/library-pack.mjs` と library の smoke/型検証手順を使って tarball を作り、新規 consumer の Node.js ESM と TypeScript から `bdf.mbt/pdf` を確認する。新規 PDF smoke を同じ検証に追加する。
- ブラウザー統合: ローカル HTTP 配信した consumer で export し、ネットワーク記録で予期しない外部取得がないことを確認する。
- Golden/構造: 固定 BDF とライセンス確認済みテストフォントで、PDF のページ数、サイズ、テキスト抽出、埋め込みフォントを確認する。レンダリング画像で罫線・文字・改ページを比較する。PDF bytes の完全一致だけに依存しない。
- 異常系: 不正入力、0 ページ、無効 view、フォント欠落、未対応画像を含む文書で reject/警告を検証する。
- forms 結合: forms の出力 BDF を本 API に渡し、日本語を含む PDF を生成する。sheet ビューだけの入力は未対応として明示されることを確認する。
- 本 Issue 作成時は仕様と配置の検証のみ。実装テストはまだ実行しない。実装時は実行コマンド、環境、結果と未実施範囲を記録する。

## リスク

警告付き成功を利用者が見落とすと帳票の内容が欠落する。画像の忠実な書き出しは本件で解決せず、制限表と警告を必ず示す。フォントサイズ・権利・日本語 shaping、Node/ブラウザー差、バンドル容量の増大、内部 bridge への過度な依存に注意する。既存公開パスを変更せず追加で導入する。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- BDF bytes を PDF に書き出す公開 npm API `bdf.mbt/pdf` を追加し、明示フォント指定、返却警告と利用例を提供する。

## 注記

本件は公開 API の追加であり、PDF の完全再現を保証する作業ではない。上記の公開入口・失敗条件・制限を実装契約とし、内部 bridge のファイル名等は既存構成に合わせて選択する。
- 2026-11-12: 現行 writer と npm export map を確認し、API 契約・範囲・受け入れ条件・テスト計画を具体化。
