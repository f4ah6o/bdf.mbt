# image/barcode と image/rowenc の移植

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-image-barcode-rowenc

## 概要

上流 `image/barcode`（1,356 行）と `image/rowenc`（930 行）を移植する。

## 背景

`form/pdfme` は既に Code 39、Code 93、Code 128、GS1-128、EAN-13、EAN-8、UPC-A、UPC-E、ITF、NW-7、MSI を実装している。`image/barcode` はそれを画像として描く層。`image/rowenc` は行単位のエンコーダ。

## 問題

バーコードを BDF の画像パーツとして描く経路が無い。`form/pdfme` のバーコード実装が再利用できるか未検証。

## 目標

`image/barcode` と `image/rowenc` 相当の API が BDF の画像パーツを返す。

## 対象外

QR（`moon-qrcode` で既に実装済み）。

## 提案する方針

`form/pdfme` のバーコード実装を `image/barcode` に抽出し、`form/pdfme` から参照する。`image/rowenc` は行エンコーダとして独立に移植する。

## 受け入れ条件

- [ ] `image/barcode` が各形式の画像パーツを返す
- [ ] `image/rowenc` が行をエンコードする
- [ ] `form/pdfme` が新しい `image/barcode` を使う
- [ ] `moon test --target js`、`--target wasm-gc`、`--target native` が green

## テスト計画

- `moon test --target js`
- `moon test --target wasm-gc`
- `moon test --target native`
- 上流 fixture のバーコードを変換する

## リスク

`form/pdfme` の既存実装を壊す可能性がある。先にテストで固定してから抽出する。

## 変更履歴

`CHANGES.md` impact: no

## 注記

上流の行数は `image/barcode` 1,356 と `image/rowenc` 930 の合計 2,286。
