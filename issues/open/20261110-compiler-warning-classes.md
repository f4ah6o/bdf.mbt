# build: 残るコンパイラ警告クラスを整理する

Status: open
Model: unknown
Created: 2026-11-10
Updated: 2026-11-10
Branch: fix/20261110-pages-warnings

## 概要

Pages ビルドで出るコンパイラ警告（JS 1709 件、wasm-gc 1552 件、duplicate import/alias 36 件）をクラス別に整理し、新規警告を検出できる状態に近づける。まず維持対象の duplicate import/alias を整理する。

## 背景

Pages デプロイ run 42746639394 のビルドログ（利用者報告）では、JS 1709 件、wasm-gc 1552 件の警告と、duplicate import/alias が 36 件出ていた。

この worktree で `moon check -p browser --target js` を実行したときの内訳は次のとおり（変更前、合計 1552 件、0 errors）。

| クラス | 件数 |
| --- | ---: |
| `deprecated` | 352 |
| `reserved_keyword` | 291 |
| `implicit_impl_as_method` | 217 |
| `deprecated_syntax` | 180 |
| `unused_value` | 174 |
| `unused_field` | 98 |
| `redundant_modifier` | 73 |
| `unused_package` | 68 |
| `ambiguous_braces` | 34 |
| `missing_priv` | 21 |
| `unused_error_type` | 18 |
| `ambiguous_precedence` | 9 |
| `unused_constructor` | 6 |
| `unused_try` | 3 |
| `unreachable_code` | 3 |
| `fragile_catch_all` | 3 |
| `missing_pattern_payload` | 1 |
| `ambiguous_block` | 1 |

`fragile_catch_all` の 3 件は `20261110-async-cancellation-cleanup.md` で追跡する。別ブランチの修正候補では 1549 件になったが、まだ統合していない。

duplicate import/alias は、この worktree の browser チェックで duplicate import 2 件、duplicate alias 16 件を確認した。リテラルな重複は `convert/gerber/moon.pkg` と `convert/sxf/moon.pkg` の `moonbitlang/core/encoding/utf8` 二重 import。duplicate alias は `compat/*/moon.pkg` の `test-import` が現在のパッケージと同じ既定 alias を使っている箇所。

## 問題

- 警告が 1500 件を超えると、新しい警告が埋もれてレビューで見落とされる。
- `deprecated_syntax` と `implicit_impl_as_method` は将来のコンパイラで破壊的変更になる。
- `reserved_keyword` 291 件は将来の予約語追加で壊れる可能性がある。
- duplicate import/alias は設定の重複で、意図が読み取りにくい。
- 警告件数のベースラインがないため、増減を検出できない。

## 目標

- 維持対象の duplicate import/alias を整理する。
- クラス別の件数を docs に記録し、再測定できるようにする。
- 新規警告を検出する仕組み（ベースライン比較など）を検討する。
- `deprecated_syntax` / `implicit_impl_as_method` の削減方針を決める。

## 対象外

- 1500 件を一度に 0 にすること。
- `fragile_catch_all`（`20261110-async-cancellation-cleanup.md` で追跡）。
- 対象外の基板、楽譜、EPUB のパッケージ。
- ホスト型 Pages デプロイ。
- 依存パッケージ（`.mooncakes/`）側の警告。リポジトリのソースだけを対象にする。

## 提案する方針

1. duplicate import/alias から着手する。維持対象の `convert/sxf/moon.pkg` の重複行を確認し、`compat/*/moon.pkg` の `test-import` alias を現在のパッケージと衝突しない名前にする。
2. `deprecated_syntax` は `derive(...)` を `#derive(...)` に置き換える。`implicit_impl_as_method` は `pub extend ... with Trait::{...}` を明示する。
3. `unused_*` は利用状況を確認して整理し、警告を消すためだけに公開 API を増やさない。`reserved_keyword` は識別子 rename が必要で影響が大きいため、別 issue に分割する。
4. クラス別件数を `docs/` に記録し、`moon check` の出力を集計するスクリプトを検討する。
5. 警告ベースラインを local verify に組み込む場合は、既存のゲートを弱めない形にする。

## 受け入れ条件

- [ ] 維持対象の duplicate import/alias を整理し、未対応を記録した。
- [ ] クラス別件数を docs に記録した。
- [ ] JS と wasm-gc の件数を同じ手順で再測定できる。
- [ ] 新規警告を検出する仕組み、またはその設計を決めた。
- [ ] `deprecated_syntax` / `implicit_impl_as_method` の削減方針を決めた。

## テスト計画

- `moon check -p browser --target js` でクラス別件数を集計する。
- `moon check --target js` と `moon check --target wasm-gc` で全体の件数を測る（時間がかかるため任意）。
- duplicate import/alias の修正後、`moon check` の該当警告が 0 件であることを確認する。
- `node .github/local/verify.test.mjs` でローカル検証の自己テストが通ることを確認する。

## リスク

- `reserved_keyword` の rename は公開 API や BDF の JSON キーに影響する可能性がある。
- `derive` の書き換えは大量で、機械的な置換は誤りやすい。
- 警告ベースラインを必須ゲートにすると、依存更新で件数が増えたときに正当な変更まで止まる。
- 警告の削減は挙動を変えないはずだが、`unused_*` の削除は意図しない副作用を持ち込む可能性がある。

## 変更履歴

`CHANGES.md` impact: no

## 注記

- browser の変更前後の集計は別ブランチで実行した。
- 全体ビルドの 1709 / 1552 は利用者報告の値で、この worktree では全体ビルドを再実行していない。
- `convert/gerber` は対象外のため、警告数に現れても修正対象へ戻さない。
