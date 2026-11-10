# text/markdownbdf の移植: Markdown から BDF へ

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-text-markdownbdf

## 概要

上流 `text/markdownbdf`（1,542 行）を移植し、Markdown を BDF に変換できるようにする。

## 背景

`convert/markdown` は既に CommonMark と GFM を BDF のスクロールビューに変換している。`text/markdownbdf` は上流の別経路で、`docflow` の入力として使われる。

## 問題

`text/markdownbdf` 相当の API が無い。

## 目標

Markdown 文字列から BDF 文書を返す API が存在する。

## 対象外

`docflow` 本体（対象外）。

## 提案する方針

`convert/markdown` のパーサを再利用し、`text/markdownbdf` の出力形式に合わせる。差分があれば `convert/markdown` 側に寄せる。

## 受け入れ条件

- [ ] `text/markdownbdf` パッケージが存在する
- [ ] 上流 fixture で BDF が生成される
- [ ] `moon test --target js`、`--target wasm-gc`、`--target native` が green

## テスト計画

- `moon test --target js`
- `moon test --target wasm-gc`
- `moon test --target native`
- 上流 fixture の Markdown を変換する

## リスク

`convert/markdown` と出力が重複する可能性がある。どちらを正とするかを Issue 内で決める。

## 変更履歴

`CHANGES.md` impact: no

## 注記

上流の行数は 1,542。
