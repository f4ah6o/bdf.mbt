# PPTX 図形からスライド内リンクを保持する

Status: open
Model: unknown
Created: 2026-11-12
Updated: 2026-11-12
Branch: feat/20261112-pptx-internal-shape-links

## 概要

PPTX 図形や画像のクリック操作から、同じプレゼンテーション内のスライドへ移動するリンクを保持する。

## 背景

upstream `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22` の `converter/internal/ooxml/drawingml/shape.go` の `shapeLink` と `linkTarget` は、内部 relationship と `ppaction://hlinkshowjump` をホストへ委譲する。外部リンクは別途 `convert/pptx/shape_link.mbt` で対応している。

## 問題

現在の PPTX 変換は内部スライドへの図形リンクと showjump アクションを出力しない。ページ選択時の表示ページ番号への対応付けも必要となる。

## 目標

upstream の内部クリックリンクを選択後の出力ページに対応する BDF リンクへ変換する。

## 対象外

外部 URL の取得、PPTX 以外の形式、テキストラン単位のハイパーリンク。

## 提案する方針

upstream の PPTX ホスト実装と既存のページ選択・レイヤキャッシュを調べ、スライド relationship と showjump の各動作を解決する。選択から除外された対象と共有マスター・レイアウトのリンクを明示的に扱う。

## 受け入れ条件

- [ ] upstream が扱う内部 relationship と showjump の動作を出力ページへ正しく対応付ける。
- [ ] ページ選択、除外された対象、非表示スライド、共有レイヤでリンク先とキャッシュを検証する。
- [ ] 未解決の参照で誤ったページへのリンクを出力しない。

## テスト計画

- 合成した複数スライド PPTX で各リンクとページ選択を検証する。
- PPTX パッケージを js、wasm-gc、native でテストする。

## リスク

ページ選択と共有レイヤのキャッシュがリンク先に依存するため、文脈を共有すると別のスライドのリンク先を誤る可能性がある。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- PPTX 図形のスライド内リンクを保持する。

## 注記

外部リンクの URL 検証は upstream の Go `net/url` と完全には同一ではないため、互換性の拡張は独立に検討する。
