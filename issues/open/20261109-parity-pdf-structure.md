# パリティ: PDF の構造とフォームフィールド

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: fix/20261109-parity-pdf-structure

## 概要

PDF の子オブジェクトグループ化、タグ付き構造、フォームフィールドを上流に合わせる。

## 背景

`docs/parity.md` は PDF の `pages[].layers[].obj.ops` の MARK、タグ付き構造、子オブジェクトグループ化、JPX 色変換を差分として挙げている。`form/pdf` は AcroForm の読み取りと上書きを持つが、`convert/pdf` はフォームフィールドを BDF に載せていない。

## 問題

PDF の構造情報が BDF に反映されず、8 ケースが diff のまま。

## 目標

PDF の 8 ケースが pass する。

## 対象外

JPX の残差（別 Issue）。

## 提案する方針

`converter/pdf/structure.go` 相当を移植する。MARK とタグ付き構造を出力する。フォームフィールドを `form/pdf` から `convert/pdf` に接続する。

## 受け入れ条件

- [ ] 子オブジェクトのグループ化が一致する
- [ ] タグ付き構造が一致する
- [ ] フォームフィールドが BDF に載る
- [ ] PDF の 8 ケースが pass する

## テスト計画

- `node compat/parity/verify.mjs --strict`
- `moon test --target js`
- `moon test --target wasm-gc`

## リスク

構造の変更は既存の pass ケースに影響し得る。

## 変更履歴

`CHANGES.md` impact: no

## 注記

`docs/parity.md` の Next gates 2 番目に対応する。
