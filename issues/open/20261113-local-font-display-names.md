# Local Font Access の選択後表示を人間向け書体名に統一する

Status: open
Model: unknown
Created: 2026-11-13
Updated: 2026-11-13
Branch: fix/20261113-local-font-display-names

## 概要

選択一覧と選択後サマリーに同じ人間向け表示名を使い、変換用識別子から分離する。

## 背景

共通 UI は `site/assets/local-fonts.js`、契約は `docs/local-fonts-ui.md`。責務は bdf.mbt の Web UI とブラウザーアダプターで、下流プラグインは共通機能を利用する。
参考: https://developer.chrome.com/docs/capabilities/web-apis/local-fonts 、https://wicg.github.io/local-font-access/

## 問題

site/assets/local-fonts.js の一覧は fullName → family + style → postscriptName の順で表示するが、選択後サマリーは item.name を表示し、サニタイズされた内部ファイル名になる。

## 目標

選択一覧と選択後サマリーに同じ人間向け表示名を使い、変換用識別子から分離する。

## 対象外

フォント name table の多言語解析、OS ネイティブ列挙、変換器のフォントメトリクス修正。

## 提案する方針

displayName を UI メタデータとして保持し、選択後にも表示する。変換用 name と postscriptName は既存契約を保つ。ファイル選択時は元ファイル名を表示用 fallback とし、API の fullName を必ず日本語名とみなさない。

## 受け入れ条件

- [x] 選択一覧と選択後のサマリーに同じ表示名が出る。
- [x] name の安全化・重複回避と postscriptName による TTC フェイス選択が変わらない。
- [x] 同じ表示名の別フェイスを取り違えず、欠けた fullName の fallback と HTML 特殊文字を安全に扱う。
- [ ] 実 OS で権限を許可した際の表示、および統合版が配信された Pages での表示を確認する。

## テスト計画

`node site/local-fonts-test.mjs` と `node site/test.mjs` を実行する。合成 FontData で fullName、family/style、PostScript-only、同名別フェイス、特殊文字を検証する。選択→変換→解除→再選択の表示を検証する。

## リスク

表示名は一意識別子ではない。既存のサイズ上限、TTC セレクター、ユーザー操作時のみの許可要求、メモリのみでの保持を維持する。OS フォントをテスト用 fixture としてコミットしない。

## 変更履歴

`CHANGES.md` への影響: yes

項目案：
- 選択一覧と選択後サマリーに同じ人間向け表示名を使い、変換用識別子から分離する。

## 注記

確認基点: main 相当の `ea2d633a`。同基点の issues に本件の重複なし。GitHub の最新 PR 状態は着手時に再確認する。二件は独立レビュー可能だが共通 UI を触るため、表示名分離を先に実装し、その後に検索・導線改善を行う。

- 2026-11-13: [PR #33](https://github.com/f4ah6o/bdf.mbt/pull/33) の実装を main に統合。選択一覧とサマリーは表示名を共有し、Worker に渡す内部名と PostScript 名は別に保持する。
- 固定 head `265b8b17b44fa13c803078b2a830bf91a886ed54` のローカル actrun site gate は PASS、終了コード 0。合成メタデータによる一覧・サマリーと、テストフォントを実 Worker に渡す選択・変換・解除・再選択を確認した。独立レビューの指摘は修正済み。
- 実 OS のフォント権限・表示と、統合版の Pages 配信は未確認。後続の実機・配信確認を追跡するため、この issue は open のままにする。site 以外の actrun gate はこの変更について未実行。
