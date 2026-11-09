# thumbnail と segment の移植

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-thumbnail-segment

## 概要

上流 `thumbnail`（357 行）と `segment`（180 行）を移植する。

## 背景

サイトの `/thumbnail/` は既に bdf.mbt でサムネイルを描いているが、上流 `thumbnail` パッケージ相当の API は無い。`segment` は ECDH で封印したページセグメントを HTTP で配るハンドラで、`core` の ECDH と `core.select_pages` を使う。

## 問題

サムネイル生成とセグメント配信の API が無い。

## 目標

両パッケージ相当の API が存在する。

## 対象外

HTTP サーバ本体（`print/server` とは別）。

## 提案する方針

`thumbnail` は `render` のページ描画と `convert/raster` のスケーリングを使う。`segment` は `core` の ECDH と `select_pages` を使い、HTTP ハンドラはトランスポート抽象にする。

## 受け入れ条件

- [ ] `thumbnail` が 4 サイズのサムネイルを返す
- [ ] `segment` がリクエストの鍵で封印したセグメントを返す
- [ ] `moon test --target js`、`--target wasm-gc`、`--target native` が green

## テスト計画

- `moon test --target js`
- `moon test --target wasm-gc`
- `moon test --target native`
- 上流 fixture でサムネイルとセグメントを生成する

## リスク

`segment` の HTTP 層は native でソケットが要る。トランスポート抽象で切り離す。

## 変更履歴

`CHANGES.md` impact: no

## 注記

上流の行数は `thumbnail` 357 と `segment` 180 の合計 537。
