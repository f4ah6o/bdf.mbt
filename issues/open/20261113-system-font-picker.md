# Linux・macOS・Windows でシステムフォントを選びやすくする

Status: open
Model: unknown
Created: 2026-11-13
Updated: 2026-11-13
Branch: feat/20261113-system-font-picker

## 概要

共通 Web UI にフォント検索と明確な許可・非対応時の導線を用意する。

## 背景

共通 UI は `site/assets/local-fonts.js`、契約は `docs/local-fonts-ui.md`。責務は bdf.mbt の Web UI とブラウザーアダプターで、下流プラグインは共通機能を利用する。
参考: https://developer.chrome.com/docs/capabilities/web-apis/local-fonts 、https://wicg.github.io/local-font-access/

## 問題

Local Font Access の利用可否は OS 名だけでは判定できず、ブラウザー・secure context・権限に依存する。既存のファイル選択 fallback を維持しながら、多数の書体からの選択を改善する。

## 目標

共通 Web UI にフォント検索と明確な許可・非対応時の導線を用意する。

## 対象外

ブラウザー制限の回避、自動権限要求、OS のフォントディレクトリ直接読取、ネイティブ CLI アダプター、フォント配布・ライセンス判断。

## 提案する方針

feature detection を使い、利用可能・許可拒否・非対応を区別して説明する。fullName/family/style を検索できる UI と選択数・解除導線を設ける。検索しても既選択状態を失わない。非対応または拒否時は手動ファイル選択へ誘導し、OS ごとの利用手順をドキュメント化する。

## 受け入れ条件

- [x] OS 名だけで対応を断定せず、queryLocalFonts と secure context を検出する。
- [x] API 呼び出しは利用者操作時だけ行い、拒否・非対応・空一覧からファイル選択へ進める。
- [x] 表示名・family・style を検索でき、検索解除後も選択状態とキーボード操作が維持される。
- [x] Linux/macOS/Windows の確認手順とブラウザー制約を文書化し、未実機検証は未検証と明記する。
- [x] 選択したフォント以外の bytes を読まず、一覧や bytes を保存・送信・ログ出力しない。
- [ ] 実 OS・ブラウザーで権限、選択と描画を確認し、統合版が配信された Pages の動作を確認する。

## テスト計画

`node site/local-fonts-test.mjs` と `node site/test.mjs` を実行する。API success/denial/unsupported/insecure/empty を mock で検証する。検索・空結果・選択保持・キーボードを検証し、利用可能な OS/ブラウザーだけ実機結果を記録する。

## リスク

表示名は一意識別子ではない。既存のサイズ上限、TTC セレクター、ユーザー操作時のみの許可要求、メモリのみでの保持を維持する。OS フォントをテスト用 fixture としてコミットしない。

## 変更履歴

`CHANGES.md` への影響: yes

項目案：
- 共通 Web UI にフォント検索と明確な許可・非対応時の導線を用意する。

## 注記

確認基点: main 相当の `ea2d633a`。同基点の issues に本件の重複なし。GitHub の最新 PR 状態は着手時に再確認する。二件は独立レビュー可能だが共通 UI を触るため、表示名分離を先に実装し、その後に検索・導線改善を行う。

- 2026-11-13: [PR #34](https://github.com/f4ah6o/bdf.mbt/pull/34) の実装を main に統合。書体検索、選択保持、ファイル選択、読み込み完了前の初回プレビュー防止を追加した。
- 固定 head `4ad30b3aa1589cdc343eec2a9c7c246f5fb4e36e` のローカル actrun site gate は PASS、終了コード 0。合成データと mock による権限・検索・選択テスト、および配布可能なテストフォントと実 Worker を使う変換テストが成功。独立 worktree で `node site/local-fonts-test.mjs` の 35 ケースも成功し、独立レビューの指摘は修正済み。
- Linux・macOS・Windows 上の実フォント権限と実描画、統合版の Pages 配信は未確認。これらを追跡するため、この issue は open のままにする。site 以外の actrun gate はこの変更について未実行。
- 手動選択した TTC は個別フェイスを指定せず読める全フェイスを読み込む。XLSX の埋め込み制約など既存の形式別制限は [UI 契約](../../docs/local-fonts-ui.md)を参照。
