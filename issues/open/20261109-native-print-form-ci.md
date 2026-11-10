# native 対応: print / form とローカル actrun matrix

Status: done
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-10
Branch: feat/20261109-native-print-form-ci

## 概要

`print/*` と `form/*` を native 化し、ローカル actrun の matrix に native を追加する。

## 背景

前段までで convert と export まで native 化済み。偵察で flip だけで通ることは確認済み。残るのはローカル actrun の matrix と実変換ゲート。

## 問題

`print/ipp_js` は JS fetch transport を使うため js 専用。`form/*` は 12 パッケージある。ローカル actrun の matrix は js と wasm-gc のみを検証していた。

## 目標

`print/ipp_js` を除く全パッケージが native で green。ローカル actrun の matrix が native を検証する。

## 対象外

`browser`、`converter_worker`、`render_worker`、`native_converter_worker`、`compat/*` は native の対象外。`compat/*` のうち 22 パッケージは js 専用、`compat/size/*` の 4 パッケージは wasm-gc 専用。`viewer` は `viewer.mbt` 165 行と `viewer_test.mbt` 88 行で `core` だけを import し、JS extern を持たないため native に参加する。

## 提案する方針

`print`、`print/dnssd`、`print/ipp`、`print/raster`、`print/server` と `form/*` を flip する。`.github/workflows/ci.yml` の matrix に `native` を追加する。このワークフローは GitHub では実行せず、ローカル actrun で回す。native の実変換ゲートとして、fixture を native バイナリで BDF に変換するテストを追加する。

## 受け入れ条件

- [x] `moon check --target native` が `print/ipp_js` を除いて 0 errors
- [x] `moon test --target native` が `print/ipp_js` を除いて全件 pass
- [x] `moon build --target native` が成功
- [x] ローカル actrun の matrix に `native` が入り、green
- [x] native バイナリで fixture が BDF に変換される（3 テスト）
- [x] `moon test --target js` と `moon test --target wasm-gc` が退行していない

## 結果

main `b05cd93` に統合済み。`.github/workflows/ci.yml` の matrix は `[js, wasm-gc, native]` で、GitHub では実行せずローカル actrun で回す。native の実変換ゲートは `convert/all/fixture_file_wbtest.mbt` の 3 テストで、`compat/pdf/fixtures/*.pdf` と `compat/html/fixtures/article.html` を実ファイルから変換する。#8 ブランチの最終測定は native 2733/2733、js 2749/2749、wasm-gc 2733/2733 で、これは historical な固定 head の測定であり、main `b05cd93` やその後の実行を主張するものではない。PR #8 は open のままの可能性があるが、実装は main にある。

## テスト計画

- `moon check --target js && moon test --target js && moon build --target js`
- `moon check --target wasm-gc && moon test --target wasm-gc && moon build --target wasm-gc`
- `moon check --target native && moon test --target native && moon build --target native`
- native バイナリで fixture を変換し、BDF を `render` でデコードする
- ローカル actrun の `ci/test` ジョブが native を含めて green

## リスク

`moonbitlang/async` の native 対応状況に依存する。`print/server` は HTTP を扱うため、native のソケット実装が無い場合はテストをトランスポート抽象で差し替える。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- native ターゲット（`moon build --target native`）に対応しました。

## 注記

`moon check --target native` 単独ではゲートにならない。テスト件数と実変換の両方を確認する。
