# convert/xdw の残りのギャップ: テキスト抽出とコーパス一致

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-xdw-remaining-gaps

## 概要

PR #5 と #6 の後も残る `convert/xdw` のギャップを埋める。覆われた文字の除去、注釈テキストのテキスト索引への取り込み、43 ファイルのコーパスでの `render` と `text` の一致、wasm-gc の確認。

## 背景

`convert/xdw` は上流 `shibukawa/bdf` の converter ではなく、`ezpzfile/ezpzfile-xdw` v0.3（MIT）の移植。PR #5 で main に入り、PR #6 が精度改善中。PR #5 の known gaps のうち 4 番目（注釈の fit-window）は PR #6 が閉じる。

## 問題

覆われた文字がテキスト検索に残り、注釈テキストが BDF のテキスト索引に載らない。43 ファイルのコーパス全体での一致は未検証。wasm-gc は未確認。

## 目標

`hidden.rs` 相当の挙動、コーパス一致、wasm-gc green を満たす。

## 対象外

XDW の書き戻し（上流も対象外）。上流 `shibukawa/bdf` の移植範囲。

## 提案する方針

`hidden.rs`（364 行）の覆われた文字の除去を移植する。注釈テキストを `XdwObject.text` から BDF のテキスト索引に載せる。`compat/xdw` の fixture を 43 ファイルに広げる。wasm-gc で check/test/build を回す。

## 受け入れ条件

- [ ] 覆われた文字が既定でテキスト索引から除かれる
- [ ] `include_hidden=1` で覆われた文字が残る
- [ ] 注釈テキストがテキスト索引に載る
- [ ] 43 ファイルのコーパスで `render` と `text` が上流 CLI と一致する
- [ ] `moon check`、`moon test`、`moon build` が wasm-gc で green

## テスト計画

- `moon test --target js`
- `moon test --target wasm-gc`
- `compat/xdw` のコーパス比較
- `include_hidden` の有無でテキスト索引を比較する

## リスク

43 ファイルのコーパスはリポジトリに無い可能性がある。fixture の入手元を Issue 内で明示する。PR #6 が未マージのため、その上に積むか main に rebase するかを決める。

## 変更履歴

`CHANGES.md` impact: no

## 注記

PR #6 に依存する。上流の移植範囲外なので、ロードマップの完了条件には含めない。
