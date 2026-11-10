# パリティ: 共有チャートレンダラ

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: fix/20261109-parity-chart-renderer

## 概要

PPTX と XLSX のチャート描画を共有レンダラに抽出し、上流と一致させる。

## 背景

`docs/parity.md` は PPTX の chart labels と XLSX の chart SVG pictures を差分として挙げている。現在は形式ごとに別実装。

## 問題

チャートの描画が形式ごとに違い、ラベルが BDF に載らない。

## 目標

共有チャートレンダラが BDF の描画コマンドを生成する。

## 対象外

SmartArt（PPTX の `dgm`）。

## 提案する方針

`convert/drawingml` にチャートレンダラを置き、PPTX と XLSX から参照する。ラベルを BDF のテキストとして出力する。

## 受け入れ条件

- [ ] 共有チャートレンダラが存在する
- [ ] PPTX のチャートラベルが BDF に載る
- [ ] XLSX のチャートが SVG 画像ではなく BDF で描かれる
- [ ] パリティの該当ケースが pass する

## テスト計画

- `node compat/parity/verify.mjs --strict`
- `moon test --target js`
- `moon test --target wasm-gc`

## リスク

チャートの種類が多い。対応範囲を Issue 内で明示する。

## 変更履歴

`CHANGES.md` impact: no

## 注記

`docs/parity.md` の Next gates 5 番目に対応する。
