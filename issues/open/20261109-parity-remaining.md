# パリティ: 残りの形式別差分を 52/52 にする

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: fix/20261109-parity-remaining

## 概要

共有修正の後も残る DOCX、PPTX、PDF、XLSX、Markdown の差分を潰し、パリティを 52/52 にする。

## 背景

前段の 6 Issue で共有原因を解消した後の残差を扱う。

## 問題

共有修正だけでは 52/52 に届かない可能性がある。

## 目標

`node compat/parity/verify.mjs --strict` が 52 pass と 0 diff を返す。

## 対象外

新しい fixture の追加。

## 提案する方針

`_scratch/parity/report.json` の `diffCategories` を形式ごとに分類し、残差を個別に潰す。比較を緩めない。

## 受け入れ条件

- [ ] `node compat/parity/verify.mjs --strict` が exit 0
- [ ] 52 ケースすべて pass
- [ ] 比較の許容差を広げていない

## テスト計画

- `node compat/parity/verify.mjs --strict`
- `moon test --target js`
- `moon test --target wasm-gc`

## リスク

残差が上流の未文書化挙動に依存する場合、上流のコードを読んで仕様を確定する必要がある。

## 変更履歴

`CHANGES.md` impact: no

## 注記

この Issue はパリティの最終ゲート。前段の 6 Issue に依存する。
