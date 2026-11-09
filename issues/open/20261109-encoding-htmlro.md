# encoding/htmlro の移植: HTML リーダーモード

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-encoding-htmlro

## 概要

上流 `encoding/htmlro`（5,278 行）を移植し、HTML からリーダーモードのブロックモデルを抽出する。

## 背景

`convert/html` は既にリーダーモードのブロックモデルを持つが、上流の `encoding/htmlro` は Readability 相当の抽出を含む。`convert/reader` がブロックモデルを提供する。

## 問題

HTML から本文を抽出する経路が `convert/html` の簡易版に限られる。

## 目標

`encoding/htmlro` 相当の API が HTML から本文ブロックを返す。

## 対象外

CSS レイアウト。完全な Readability 互換。

## 提案する方針

`convert/reader` のブロックモデルを出力先にする。抽出規則を上流から移植する。5,278 行あるため、抽出、スコアリング、ブロック変換の 3 段に分けて進める。

## 受け入れ条件

- [ ] `encoding/htmlro` パッケージが存在する
- [ ] 上流 fixture（`html/math.html` を含む）で本文が抽出される
- [ ] `convert/html` が新しい抽出器を使う
- [ ] `moon test --target js`、`--target wasm-gc`、`--target native` が green

## テスト計画

- `moon test --target js`
- `moon test --target wasm-gc`
- `moon test --target native`
- 上流 fixture の HTML を変換する

## リスク

最大の単一ギャップ。1 Issue に収まらない場合は分割する。

## 変更履歴

`CHANGES.md` impact: no

## 注記

上流の行数は 5,278。`convert/reader` の既存ブロックモデルを再利用できるか最初に確認する。
