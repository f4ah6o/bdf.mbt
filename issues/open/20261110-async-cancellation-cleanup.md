# browser: async キャンセル時の後片付けを defer/errdefer に移す

Status: open
Model: unknown
Created: 2026-11-10
Updated: 2026-11-10
Branch: fix/20261110-pages-warnings

## 概要

`moon check` が browser パッケージで報告していた `fragile_catch_all` 警告 3 件を、`defer` / `errdefer` に置き換える。キャンセル時にも後片付けが走るようにし、通常エラー時の挙動は変えない。

## 背景

MoonBit 0.1.20261104 の `moon check -p browser --target js` は次の 3 箇所を `fragile_catch_all` として報告していた。

- `browser/browser.mbt:529` `paint_child`: `paint_commands(...) catch { error => { restore(ctx); raise error } }` の後に `restore(ctx)`。
- `browser/prepare.mbt:246` `mount_single`: `ignore(wait_lazy_pages(host).wait()) catch { error => { if current_page_record(host, record) { clear_host(host) }; raise error } }`。
- `browser/split.mbt:404` `mount_split`: 同じ形。

コンパイラの警告本文は「`try ... catch` は将来 async キャンセルを捕捉しなくなるため、`catch` での後片付けは危険」と説明し、`errdefer <cleanup>` への書き換えを提案する。

`moonbitlang/async@0.22.5` の README はより明確で、キャンセル信号は `defer` / `errdefer` を発火するが `catch` は捕捉できない、と明記している。つまり現状の `catch` による `clear_host` はキャンセル時に走らない。

## 問題

- キャンセルされた lazy page 待ちのあと、`clear_host(host)` が走らずホストが残る可能性がある。
- 同期処理の `paint_child` は例外時の状態復元を明示的に保証する必要がある。キャンセルが同期関数の途中で発生するとは確認していない。
- 警告が 3 件残ると、新しい警告が埋もれる。

## 目標

- 3 箇所を `defer` / `errdefer` に置き換え、`fragile_catch_all` を 0 件にする。
- 通常のエラー時と成功時の後片付け順序を変えない。
- 既存の restore 回帰テストを維持する。

## 対象外

- 他の警告クラスの削減（`20261110-compiler-warning-classes.md`）。
- ページ表示以外のキャンセル経路の全面的な変更。
- ホスト型 Pages デプロイ。

## 提案する方針

1. `browser/browser.mbt` の `paint_child` は、`save(ctx)` の直後に `defer restore(ctx)` を置き、`catch` と末尾の `restore(ctx)` を削除する。隣の `paint_object` と同じ形になる。
2. `browser/prepare.mbt` と `browser/split.mbt` は、`catch` を `errdefer { if current_page_record(host, record) { clear_host(host) } }` に置き換え、`ignore(wait_lazy_pages(host).wait())` をそのまま呼ぶ。
3. `errdefer` はブロックスコープを抜けるときに走る。`wait_lazy_pages` の後に別の処理を足す場合はスコープに注意する。

## 受け入れ条件

- [ ] `moon check -p browser --target js` が `fragile_catch_all` 0 件、エラー 0 件。
- [ ] `moon test -p browser --target js` が 22/22 通る。
- [ ] 既存の `child_restored` テストが失敗時の `restore` を引き続き検証する。
- [ ] lazy page のキャンセルで `clear_host` が走ることをホストフィクスチャで検証する（未実装）。
- [ ] 変更をコミットして統合する（未コミット）。

## テスト計画

- `moon check -p browser --target js`
  - 変更前: 1552 warnings, 0 errors, `fragile_catch_all` 3 件。
  - 変更後: 1549 warnings, 0 errors, `fragile_catch_all` 0 件。
- `moon test -p browser --target js` → 22 passed, 0 failed。
- `moon test -p browser --target wasm-gc` は browser が js 専用のため対象外（exit 255、`Selected package(s) do not support target backend 'wasm-gc'`）。
- 追加の回帰: `browser/child_wbtest.mbt` の `child_restored` が `paint_child` 失敗時に `[["save"],["restore"]]` を要求する。

## リスク

- `defer` は成功時にも `restore` するが、元のコードも成功時に `restore` していたため等価。
- `errdefer` はエラー時だけ走る。成功時に `clear_host` しない点も元のコードと同じ。
- `wait_lazy_pages` の後に処理を足すと `errdefer` のスコープが変わる。将来の変更時に注意する。
- lazy page のキャンセル経路はホストフィクスチャがなく、実機のキャンセル挙動は未検証。

## 変更履歴

`CHANGES.md` impact: no

## 注記

- 対象を絞った検査では変更前に 3 件、変更後に 0 件の警告を確認した。キャンセルを発生させる回帰テストは未実施。
- 変更ファイル: `browser/browser.mbt`, `browser/prepare.mbt`, `browser/split.mbt`。
- 修正候補は別ブランチにあり、キャンセル経路の再現テストを含めて統合前に検証する。
