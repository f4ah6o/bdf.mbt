# vector/pdfbdf の移植: PDF から BDF へ

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-vector-pdfbdf

## 概要

上流 `vector/pdfbdf`（4,801 行）と `vector/internal`（750 行）を MoonBit に移植し、PDF を BDF に変換できるようにする。

## 背景

上流は PDF のページを BDF の view に変換する。`export/pdf` は BDF から PDF への逆方向で既に移植済み。`convert/pdf` は PDF を読むが、BDF を書く経路は無い。

## 問題

PDF を入力として BDF を生成する経路が無い。

## 目標

`vector/pdfbdf` 相当の API が PDF バイト列から BDF 文書を返す。

## 対象外

PostScript（別 Issue）。`convert/pdf` の documented gaps を超える PDF 機能。

## 提案する方針

`vector/internal` の図形平坦化と `vector/pdfbdf` のページ変換を移植する。`convert/pdf` のオブジェクト解析を再利用する。`export/pdf` の座標変換と対称になるようテストを書く。

## 受け入れ条件

- [ ] `vector/pdfbdf` パッケージが存在し、PDF バイト列から BDF を返す
- [ ] 上流の fixture で BDF が生成される
- [ ] 生成した BDF を `render` でデコードできる
- [ ] `moon test --target js`、`--target wasm-gc`、`--target native` が green

## テスト計画

- `moon test --target js`
- `moon test --target wasm-gc`
- `moon test --target native`
- 上流 fixture の PDF を変換し、BDF を `render` でデコードする

## リスク

上流の `vector/internal` は `export/pdf` と共有されている可能性がある。共有部分の重複を避ける設計判断が要る。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- PDF を BDF に変換する `vector/pdfbdf` を追加しました。

## 注記

上流の行数は `vector/pdfbdf` 4,801 と `vector/internal` 750 の合計 5,551。
