# native 対応: print / form と CI matrix

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-native-print-form-ci

## 概要

`print/*` と `form/*` を native 化し、CI の matrix に native を追加する。

## 背景

前段までで convert と export まで native 化済み。

## 問題

`print/ipp_js` は JS fetch transport を使うため js 専用。`form/*` は 11 パッケージある。CI は js と wasm-gc のみを検証している。

## 目標

`print/ipp_js` を除く全パッケージが native で green。CI が native を検証する。

## 対象外

`browser`、`viewer`、`converter_worker`、`render_worker`、`native_converter_worker`、`compat/*`。これらは js 専用のまま。

## 提案する方針

`print`、`print/dnssd`、`print/ipp`、`print/raster`、`print/server` と `form/*` を flip する。`.github/workflows/ci.yml` の matrix に `native` を追加する。native の実変換ゲートとして、fixture を native バイナリで BDF に変換するテストを 1 本追加する。

## 受け入れ条件

- [ ] `moon check --target native` が `print/ipp_js` を除いて 0 errors
- [ ] `moon test --target native` が `print/ipp_js` を除いて全件 pass
- [ ] `moon build --target native` が成功
- [ ] CI matrix に `native` が入り、green
- [ ] native バイナリで fixture が BDF に変換される
- [ ] `moon test --target js` と `moon test --target wasm-gc` が退行していない

## テスト計画

- `moon check --target js && moon test --target js && moon build --target js`
- `moon check --target wasm-gc && moon test --target wasm-gc && moon build --target wasm-gc`
- `moon check --target native && moon test --target native && moon build --target native`
- native バイナリで fixture を変換し、BDF を `render` でデコードする
- GitHub Actions の `moonbit` ワークフローが native を含めて green

## リスク

`moonbitlang/async` の native 対応状況に依存する。`print/server` は HTTP を扱うため、native のソケット実装が無い場合はテストをトランスポート抽象で差し替える。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- native ターゲット（`moon build --target native`）に対応しました。

## 注記

`moon check --target native` 単独ではゲートにならない。テスト件数と実変換の両方を確認する。
