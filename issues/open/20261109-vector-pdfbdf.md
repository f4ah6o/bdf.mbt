# vector/pdfbdf との差分: export/pdf の出力を上流に合わせる

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-vector-pdfbdf

## 概要

上流 `vector/pdfbdf`（4,801 行）は BDF を PDF に書く。MoonBit の `export/pdf`（1,717 行）が同じ役割を担うが、グラデーション、タイルパターン、SMask、JPEG パススルー、SVG、影が未対応。差分を埋める。

## 背景

`vector/pdfbdf` の API は `Write(w io.Writer, doc *bdf.Document, opts *Options)` で、BDF を PDF に書く。`export/pdf` の `write_document` / `write_bytes` が同じ方向。`convert/pdf` は逆方向（PDF を読む）で別パッケージ。`vector/internal/export`（532 行）は数値整形とペンを共有する。

## 問題

`export/pdf` はグラデーションを単色で近似し、パターンを単色で描き、影・フィルタ・画像を落とす。上流は axial/radial shading、conic をメッシュで、タイルパターン、SMask、JPEG パススルー、SVG 画像、影のラスタライズに対応する。

## 目標

`export/pdf` が上流 `vector/pdfbdf` の出力に一致する。

## 対象外

`convert/pdf`（PDF を読む方向）。`vector/psbdf`（別 Issue）。

## 提案する方針

上流の `content.go`、`paint.go`、`image.go`、`shadow.go`、`text.go`、`tags.go`、`pdfa.go` を順に移植する。`vector/internal/export` の数値整形とペンを共有する。まず axial/radial shading とタイルパターンから着手し、SMask、JPEG、SVG、影を続ける。

## 受け入れ条件

- [ ] `export/pdf` が axial と radial の shading を出力する
- [ ] conic グラデーションがメッシュとして出力される
- [ ] タイルパターンが出力される
- [ ] SMask が出力される
- [ ] JPEG が再エンコードされずに格納される
- [ ] SVG 画像が画像として出力される
- [ ] 影がラスタライズされて出力される
- [ ] `moon test --target js`、`--target wasm-gc`、`--target native` が green

## テスト計画

- `moon test --target js`
- `moon test --target wasm-gc`
- `moon test --target native`
- 上流 fixture の BDF を PDF に書き、上流の出力と比較する

## リスク

上流の `vector/internal/export` は `vector/psbdf` と共有される。先に共有部分を切り出すか、`export/pdf` 内に閉じるかを決める。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- `export/pdf` がグラデーション、タイルパターン、SMask、JPEG、SVG、影を出力できるようになりました。

## 注記

上流の行数は `vector/pdfbdf` 4,801 と `vector/internal` 750。`export/pdf` は現在 1,717 行。
