# vector/psbdf の移植: PostScript から BDF へ

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-vector-psbdf

## 概要

上流 `vector/psbdf`（2,083 行）を移植し、PostScript を BDF に変換できるようにする。

## 背景

上流は `vector/internal` の平坦化を共有する。`vector/pdfbdf` の Issue が前提。

## 問題

PostScript を入力として BDF を生成する経路が無い。

## 目標

PostScript バイト列から BDF 文書を返す。

## 対象外

PDF（別 Issue）。完全な PostScript インタプリタ。

## 提案する方針

`vector/pdfbdf` の Issue で整えた `vector/internal` を共有する。PostScript の演算子サブセットを実装する。

## 受け入れ条件

- [ ] `vector/psbdf` パッケージが存在し、PostScript から BDF を返す
- [ ] 上流の fixture で BDF が生成される
- [ ] `moon test --target js`、`--target wasm-gc`、`--target native` が green

## テスト計画

- `moon test --target js`
- `moon test --target wasm-gc`
- `moon test --target native`
- 上流 fixture の PostScript を変換する

## リスク

PostScript はチューリング完全であり、上流もサブセット。対応演算子の範囲を Issue 内で明示する必要がある。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- PostScript を BDF に変換する `vector/psbdf` を追加しました。

## 注記

`vector/pdfbdf` の Issue に依存する。
