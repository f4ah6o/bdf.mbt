# native 対応: crypto / core / encoding / font

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-native-crypto-core-encoding-font

## 概要

`crypto`、`core`、`encoding/*`、`font/*` を native で check/test/build できるようにする。

## 背景

偵察（2026-11-09）で、`moon.mod` と全パッケージを flip すると `moon check`、`moon test`、`moon build` が native で全て通ることが判明した。`moon test --target native` は 2730/2730 pass。この Issue は flip をレビュー可能な単位に切るためのもので、コード変更は不要。

## 問題

これら 4 領域は `+js+wasm-gc` を宣言しており、native ではビルド計画から外れる。

## 目標

4 領域の全パッケージが `moon check`、`moon test`、`moon build` を native で通る。

## 対象外

`convert` 以降。CI matrix。

## 提案する方針

`moon.mod` を `+js+wasm-gc+native` に変える。`crypto`、`core`、`encoding/parquet`、`encoding/zip`、`font/cff`、`font/db`、`font/otlayout`、`font/sfnt`、`font/woff2` の `supported_targets` を flip する。偵察で判明した失敗を修正する。

## 受け入れ条件

- [ ] `moon check --target native` が 4 領域で 0 errors
- [ ] `moon test --target native` が 4 領域で全件 pass
- [ ] `moon build --target native` が 4 領域で成功
- [ ] `moon test --target js` と `moon test --target wasm-gc` が退行していない

## テスト計画

- `moon check --target js && moon test --target js && moon build --target js`
- `moon check --target wasm-gc && moon test --target wasm-gc && moon build --target wasm-gc`
- `moon check --target native && moon test --target native && moon build --target native`

## リスク

`moon.mod` の flip は全パッケージに影響する。他領域が native 非対応のままでも、宣言が無ければスキップされるため壊れない。

## 変更履歴

`CHANGES.md` impact: no

## 注記

`core` の 81 テストは既に native で通る。`crypto` は `core` の依存なので同時に flip する必要がある。
