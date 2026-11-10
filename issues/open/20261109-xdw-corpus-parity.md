# xdw: 上流 43 文書のコーパスで変換結果を比較する

Status: open
Model: unknown
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-xdw-corpus-parity

## 概要

上流 `ezpzfile/ezpzfile-xdw` の `corpus/manifest.tsv` が挙げる 43 文書すべてについて、上流 CLI の `render`/`text` 出力と bdf.mbt の変換結果を比較するハーネスを作る。

## 背景

- 上流のコーパスは 43 ファイル。`corpus/manifest.tsv` に一覧がある。
- bdf.mbt の `convert/xdw/fixtures_wbtest.mbt` は 6 件(`test_xdw_ver8`、`test_xdw_ver9`、`test_xdw_ver10`、`okinawa-pref_61`、`test_xbd_ver8`、`koto-ku_r604kinyumihon`)を base64 で埋め込み、コンテナ・エントリ・LZH 展開後のプロパティ・ページモデルを上流 CLI の `pages` 出力と突き合わせている。
- 他の形式は `compat/<format>/verify.mjs` を持つが、`compat/xdw` は存在しない。
- `compat/parity`(PDF/DOCX/XLSX/PPTX/Markdown)の対象に xdw は入っていない。

## 問題

- 6 件でしか確認していない。残り 37 件の描画・テキストが未検証。
- 変換結果の差分が、どの文書のどのレコードに由来するか追えない。
- 回帰(例: パスレコード、回転、注釈ウィンドウ)を 6 件の外で検出できない。

## 目標

- 43 文書すべてで、上流 CLI と bdf.mbt の出力を比較できる。
- 差分を文書単位・レコード種別単位で一覧できる。
- ローカル actrun で回せる時間に収まる(全件は重いので、既定はサブセット + 手動で全件)。

## 対象外

- 上流の `hidden.rs` 相当の文字除外(`20261109-xdw-hidden-text.md`)。
- 注釈の索引化(`20261109-xdw-annotation-index.md`)。
- XDW の書き戻し。
- 上流コーパスの再配布。ライセンスの確認が必要なため、fixture は取得手順だけを記録する。

## 提案する方針

1. `compat/xdw/` を作り、`verify.mjs` を置く。`compat/parity/verify.mjs` の構造(ローカル HTTP サーバ + Playwright + canonical 比較)を流用する。
2. 上流 CLI(`ezpzxdw`)の `pages`、`render`、`text` 出力を golden として保存する。`corpus/manifest.tsv` の 43 件を対象にする。
3. bdf.mbt 側は `native_converter_worker` で変換し、BDF を canonical 化して比較する。`compat/parity/canonical.mjs` を再利用する。
4. 差分は `_scratch/xdw/report.json` に書き、文書 ID と最初の差分パスを記録する。
5. 既定の実行は 6 件(現在の埋め込み fixture)にし、`--all` で 43 件にする。

## 受け入れ条件

- [ ] `node compat/xdw/verify.mjs` が 6 件で動き、レポートを書く。
- [ ] `node compat/xdw/verify.mjs --all` が 43 件で動く。
- [ ] レポートに文書ごとの pass/diff と最初の差分パスが入る。
- [ ] 現在の 6 件は pass する。
- [ ] ローカル検証に 6 件のジョブを足す(43 件は手動)。

## テスト計画

- `moon build --target js`
- `node compat/xdw/verify.mjs`
- `node compat/xdw/verify.mjs --all`
- 既存の `moon test -p f4ah6o/bdf/convert/xdw` が通り続けること。

## リスク

- 上流コーパスのライセンスが再配布を許さない場合、fixture をリポジトリに置けない。取得スクリプトとハッシュだけを持つ形にする。
- 43 件の描画比較は重く、ローカル検証の所要時間が長くなる可能性がある。
- 上流 CLI の出力形式が変わると golden が壊れる。上流のコミットを固定する。

## 変更履歴

`CHANGES.md` impact: no

## 注記

PR #5 の「既知のギャップ」2 番がこれにあたる。`compat/parity` の canonical 比較を再利用できるため、新規に比較器を書く必要はない。


## 2026-11-10 公開サンプルでの追加検証

- 検証対象は候補 `9389852fe5f921a67be8bf341e5d823e6123f2e4`。
  [Fess のテストデータ](https://github.com/codelibs/fess-testdata/tree/master/files/docuworks)
  の XDW 3 件と XBD 3 件を取得し、6 件とも変換成功、各ページの非白描画と
  検索索引を確認した。XDW は各 1 ページ、XBD は各 2 ページで、
  警告は 0 件。画像は含まれず、画像復号の検証にはならない。
- [公開サンプル一覧](https://github.com/ezpzfile/ezpzfile-xdw/blob/main/corpus/manifest.tsv)
  の福岡県公開 XDW 1 件と対応 PDF 1 件を別途取得した。XDW の SHA-256 は
  `ac92c1d3cd586a83d5d4b73e44805dca2d902d114f6456118b7a67eb088acb44`、
  PDF は `f6b39b51192d11fbafb65eaa7346315ddd8b6566a54c7f8808c6b00486d69090`。
  いずれも 3 ページ。XDW は警告 0 件、各ページに JPEG 画像描画 51 件があり、
  ブラウザで全画像が復号された。文字情報を含まないため文字抽出は評価できない。
- PDF を独立した `pdftoppm` で同じ大きさに描画した比較では対応するレイアウトを
  確認できたが、位置・余白・解像度や色の違いが残る。ピクセル単位の一致や
  一般的な描画精度は証明していない。JPEG 断片を扱うサンプルであり、今回修正した
  kind 7 複数 LZH バンドや BI_RLE8 の実文書回帰は未確認。
- 一覧のライセンスが掲載先の各文書にも適用されるとは限らない。Fess のサンプルの
  再配布条件は未確認であり、福岡県はサイト掲載物について県または第三者の著作権を
  明記している。新たに原本・派生画像をコミットしない。利用者提供の別の非公開
  文書もリポジトリに残していない。未取得の一覧掲載ファイルは未検証。
