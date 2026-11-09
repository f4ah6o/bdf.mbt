# image/svg と image/formula の移植

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-image-svg-formula

## 概要

上流 `image/svg`（937 行）と `image/formula`（503 行）を移植する。

## 背景

`convert/image/svg.mbt` は SVG のサイズとメタデータを読む。`image/svg` は SVG をラスタライズする層。`image/formula` は数式を描く層で、`convert/markdown` の数式は現在テキストに線形化している。

## 問題

SVG を画像として描く経路が無い。数式を組版する経路が無い。

## 目標

SVG と数式が BDF の画像パーツとして描かれる。

## 対象外

完全な SVG 仕様。完全な数式組版（上流もサブセット）。

## 提案する方針

`image/svg` はパス、図形、テキストのサブセットを実装する。`image/formula` は上流のレイアウトを移植する。

## 受け入れ条件

- [ ] `image/svg` が SVG を画像パーツに変換する
- [ ] `image/formula` が数式を画像パーツに変換する
- [ ] `moon test --target js`、`--target wasm-gc`、`--target native` が green

## テスト計画

- `moon test --target js`
- `moon test --target wasm-gc`
- `moon test --target native`
- 上流 fixture の SVG と数式を変換する

## リスク

SVG のラスタライズは `convert/image` の既存デコーダと責務が重なる。境界を Issue 内で決める。

## 変更履歴

`CHANGES.md` impact: no

## 注記

上流の行数は `image/svg` 937 と `image/formula` 503 の合計 1,440。
