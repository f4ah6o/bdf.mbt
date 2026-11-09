# パリティ: Markdown のリーダー規則とリソース解決

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: fix/20261109-parity-markdown-reader

## 概要

Markdown の行ボックス、見出し、表の規則と、`base`、`remote`、`private` のリソース解決を上流に合わせる。

## 背景

`docs/parity.md` は Markdown のページ高さとフォント数の差、wordproc リーダー規則、リソース解決を挙げている。

## 問題

Markdown の 6 ケースが diff のまま。

## 目標

Markdown の 6 ケースが pass する。

## 対象外

数式組版（`image/formula` の Issue）。

## 提案する方針

上流の wordproc リーダー規則を移植する。`base`、`remote`、`private` のリソース解決を共有 fontset に接続する。

## 受け入れ条件

- [ ] 行ボックス、見出し、表の規則が一致する
- [ ] リソース解決が上流と一致する
- [ ] Markdown の 6 ケースが pass する

## テスト計画

- `node compat/parity/verify.mjs --strict`
- `moon test --target js`
- `moon test --target wasm-gc`

## リスク

リソース解決はネットワークに依存する。テストではローカル fixture に限定する。

## 変更履歴

`CHANGES.md` impact: no

## 注記

`docs/parity.md` の Next gates 4 番目に対応する。
