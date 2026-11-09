# パリティ: XLSX の印刷ビューと数値書式

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: fix/20261109-parity-xlsx-print-view

## 概要

XLSX の `views=print` と数値書式のランの分割を上流に合わせる。

## 背景

`docs/parity.md` は XLSX の `views=print` が無視され view id が `sheet1` になること、数値書式のラン分割が不完全であることを挙げている。

## 問題

印刷ビューが生成されず、数値書式のランが上流と違う。

## 目標

XLSX の 7 ケースが pass する。

## 対象外

チャート（別 Issue）。

## 提案する方針

ページ設定、印刷範囲、印刷タイトル、改ページ、ヘッダとフッタ、用紙を実装する。数値書式のラン分割を上流に合わせる。

## 受け入れ条件

- [ ] `views=print` が `print1` などの view id を返す
- [ ] 数値書式のランが一致する
- [ ] XLSX の 7 ケースが pass する

## テスト計画

- `node compat/parity/verify.mjs --strict`
- `moon test --target js`
- `moon test --target wasm-gc`

## リスク

印刷ビューはページ幾何に依存する。用紙サイズの既定値を上流と合わせる必要がある。

## 変更履歴

`CHANGES.md` impact: no

## 注記

`docs/parity.md` の Next gates 6 番目に対応する。
