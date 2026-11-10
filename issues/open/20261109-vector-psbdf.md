# vector/psbdf の移植: BDF から PostScript へ

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-vector-psbdf

## 概要

上流 `vector/psbdf`（2,083 行）を移植し、BDF を PostScript に書けるようにする。

## 背景

上流は `Write(w io.Writer, doc *bdf.Document, opts *Options)` で BDF を PostScript に書く。`vector/internal/export` と `vector/internal/flatten` を `vector/pdfbdf` と共有する。MoonBit に PostScript 出力は無い。

## 問題

BDF を PostScript に書く経路が無い。

## 目標

BDF 文書から PostScript を生成できる。

## 対象外

PDF（別 Issue）。PostScript の読み取り。

## 提案する方針

`vector/pdfbdf` の Issue で整えた `vector/internal` を共有する。`content.go`、`paint.go`、`image.go`、`text.go` を移植する。

## 受け入れ条件

- [ ] `vector/psbdf` パッケージが存在し、BDF から PostScript を返す
- [ ] 上流の fixture で PostScript が生成される
- [ ] Ghostscript で描画できる
- [ ] `moon test --target js`、`--target wasm-gc`、`--target native` が green

## テスト計画

- `moon test --target js`
- `moon test --target wasm-gc`
- `moon test --target native`
- 生成した PostScript を Ghostscript で描画する

## リスク

Ghostscript はテスト環境に無い可能性がある。無い場合は構造の検証に留め、描画確認は手動とする。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- BDF を PostScript に変換する `vector/psbdf` を追加しました。

## 注記

上流の行数は 2,083。`vector/pdfbdf` の Issue に依存する。
