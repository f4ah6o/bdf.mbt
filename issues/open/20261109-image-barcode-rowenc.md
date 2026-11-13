# image/barcode と image/rowenc の移植

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-image-barcode-rowenc

## 概要

上流 `image/barcode`（1,356 行）と `image/rowenc`（930 行）を移植する。

## 背景

`form/pdfme` は既に Code 39、Code 93、Code 128、GS1-128、EAN-13、EAN-8、UPC-A、UPC-E、ITF、NW-7、MSI を実装している。upstream の `image/barcode` はモジュールから BDF の vector Path / Object を作り、`image/rowenc` は画像の行から PNG / TIFF を書き出す別の機能である。

## 問題

修正前は独立した barcode の BDF Path / Object 生成経路が無かった。`form/pdfme` のバーコード実装を共通化できるかは未検証。

## 目標

`image/barcode` が対応形式の BDF Path / Object を生成し、`image/rowenc` が PNG / TIFF を行単位で書き出す。

## 対象外

QR（`moon-qrcode` で既に実装済み）。

## 提案する方針

`form/pdfme` のバーコード実装を `image/barcode` に抽出し、`form/pdfme` から参照する。`image/rowenc` は行エンコーダとして独立に移植する。

## 受け入れ条件

- [ ] `image/barcode` が各形式の BDF Path / Object を返す
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

`CHANGES.md` impact: yes

## 注記

上流の行数は `image/barcode` 1,356 と `image/rowenc` 930 の合計 2,286。

## 2026-11-13 Code 39 スライス

- `image/barcode` に Code 39 のモジュール、矩形、BDF Path / Object を追加する。quiet zone、開始・停止文字、無効入力、8192 bytes 上限を upstream 固定版に合わせる。
- EAN・Code 128・ITF など他の形式、barcode MARK、rowenc、`form/pdfme` の共通化は未実装のまま。この issue は open を維持する。PDFMe の既存描画と入力規則は変更しない。
- 上流 `shibukawa/bdf` 固定 `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22` は MIT（`licenses/Shibukawa-bdf.txt`）。Code 39 とオブジェクト出力について適用し、全体の barcode API 移植完了は主張しない。
- 安全な描画境界として、上流が倍率に使う負の幅・高さは拒否し、正の幅でも float32 のモジュール幅が 0 にアンダーフローする場合はエラーとする。幅・高さが 0 の縮退オブジェクトは許可する。
