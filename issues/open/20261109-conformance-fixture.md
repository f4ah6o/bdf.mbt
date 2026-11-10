# conformance と fixture の移植

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-conformance-fixture

## 概要

上流 `conformance`（657 行）と `fixture`（416 行）を移植する。

## 背景

`conformance` は BDF v1 の機械可読な適合性スイートを書き出す。`fixture` はテストとデモ用のサンプル文書を組み立てる。

## 問題

適合性スイートの出力とサンプル文書のビルダーが無い。

## 目標

`conformance` が `suite.json` と `inputs/` を書き出し、`fixture` がサンプル文書を組み立てる。

## 対象外

他実装の適合性実行。

## 提案する方針

`conformance` は `core` の読み取り API を使ってケースを生成する。`fixture` は `core` と `convert/parquet` を使ってサンプルを組み立てる。

## 受け入れ条件

- [ ] `conformance` が `suite.json` を書き出す
- [ ] `fixture` がサンプル文書を返す
- [ ] `moon test --target js`、`--target wasm-gc`、`--target native` が green

## テスト計画

- `moon test --target js`
- `moon test --target wasm-gc`
- `moon test --target native`
- `suite.json` の構造を検証する

## リスク

`fixture` はフォントを embed する。MoonBit の embed 相当の扱いを決める必要がある。

## 変更履歴

`CHANGES.md` impact: no

## 注記

上流の行数は `conformance` 657 と `fixture` 416 の合計 1,073。
