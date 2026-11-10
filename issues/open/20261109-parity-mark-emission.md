# パリティ: MARK の出力

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-10
Branch: fix/20261109-parity-mark-emission

## 概要

DOCX、PPTX、PDF の MARK 出力を上流に合わせる。

## 背景

`docs/parity.md` は DOCX の header bbox、per-word run、table/cell/figure MARK、PDF の MARK 挿入を差分として挙げている。PPTX の BOX と title MARK は出力済みで、残るのはその他の MARK。

## 問題

MARK の欠落と順序の違いが複数形式の差分になっている。

## 目標

3 形式の MARK が上流と一致する。

## 対象外

フォントメトリクス（別 Issue）。

## 提案する方針

上流の `emit.go` 相当を形式ごとに移植する。MARK の種類と順序をテストで固定する。

## 受け入れ条件

- [ ] DOCX の header、footer、table、figure MARK が一致する
- [ ] PPTX の残りの MARK が一致する（BOX と title は出力済み）
- [ ] PDF の MARK が一致する
- [ ] パリティの該当ケースが pass する

## テスト計画

- `node compat/parity/verify.mjs --strict`
- `moon test --target js`
- `moon test --target wasm-gc`
- `moon test --target native`

## リスク

MARK は出力の広い範囲に影響する。ケース単位で退行を確認する。

## 変更履歴

`CHANGES.md` impact: no

## 注記

`docs/parity.md` の Next gates 2 番目に対応する。
