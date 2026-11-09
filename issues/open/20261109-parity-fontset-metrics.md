# パリティ: 共有 fontset のメトリクスと埋め込み

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: fix/20261109-parity-fontset-metrics

## 概要

DOCX、Markdown、XLSX が共有する fontset のメトリクスとフォント埋め込みを上流に合わせる。

## 背景

`docs/parity.md` の Next gates の 1 番目。DOCX は theme font と fallback advance が一致したが、Markdown はページ高さとフォント数が違い、XLSX はフォント埋め込みモードが未対応。

## 問題

3 形式で fontset の扱いが揃っていない。

## 目標

3 形式が同じ fontset メトリクスと埋め込みを使う。

## 対象外

個別形式の MARK。

## 提案する方針

`font/db` に共有メトリクスを集約し、`convert/docx`、`convert/markdown`、`convert/xlsx` から参照する。上流の fallback advance（space 0.25、East Asian 1、control 0、その他 0.55）を単一の関数にする。

## 受け入れ条件

- [ ] 3 形式が同じ fontset API を使う
- [ ] Markdown のページ高さとフォント数が上流と一致する
- [ ] XLSX のフォント埋め込みが上流と一致する
- [ ] パリティの該当ケースが pass する

## テスト計画

- `node compat/parity/verify.mjs --strict`
- `moon test --target js`
- `moon test --target wasm-gc`

## リスク

共有化で DOCX の既存 pass が崩れる可能性がある。ケース単位で確認する。

## 変更履歴

`CHANGES.md` impact: no

## 注記

`docs/parity.md` の Next gates 1 番目に対応する。
