# PPTX 図形の代替テキストを FIGURE マークに出力する

Status: done
Model: unknown
Created: 2026-11-12
Updated: 2026-11-13
Branch: feat/20261112-pptx-figure-markers

## 概要

PPTX の図形や画像の代替テキストを、対応する描画を囲む FIGURE マークに出力する。

## 背景

upstream `a5e4d7a6` の `converter/internal/ooxml/drawingml/shape.go:258-289` は、`cNvPr` の `descr`、次に `title` をトリムして選び、装飾指定の場合はマークを出力しない。同ファイルの `drawElem`、`drawGroup`、`drawSp`、`drawPic`、`drawFrame` が可視性と描画対象に応じて境界を設定する。

## 問題

port の `18f4f4d0` では `convert/pptx` に FIGURE 出力がなく、`pptx_collect_shapes` はグループを平坦化するため、グループの代替テキストも失われる。

## 目標

upstream に対応する FIGURE と END の順序および代替テキストを保持する。

## 対象外

ハイパーリンク、viewer の URL ポリシー、PPTX 以外の MARK、未対応の描画機能。

## 提案する方針

既存の図形収集とレイヤ出力を調べ、グループ境界を保持して対応する描画だけを囲む。upstream の表は独自の構造を使い、通常図形のテキストは図形描画の FIGURE の外に置く。関連: `issues/open/20261109-parity-mark-emission.md`。

## 受け入れ条件

- [x] `sp`、`cxnSp`、`pic`、表以外の `graphicFrame`、`grpSp` の描画で upstream に対応する FIGURE/END を出力する。
- [x] 空白除去後の `descr` を優先し、空なら `title` を使い、両方空または decorative が真なら出力しない。
- [x] 非表示や描画されない対象には不要なマークを出さず、グループと子のマークは正しい順で釣り合う。通常図形のテキストは図形描画の FIGURE の外に置き、表は upstream の表処理に従う。
- [x] 代替テキストがない入力の既存描画とテキスト索引を維持する。

## テスト計画

- 生成した最小 PPTX を使い、説明・タイトル優先順位、装飾、非表示、入れ子グループ、図形テキスト、画像および表を検査する。
- PPTX の対象テストを js、wasm-gc、native で実行し、`npm run test:phase15-pptx` と適切な既存のローカル CI を実行する。

## リスク

グループの平坦化、レイヤキャッシュ、テキスト・表のマーク順序に影響するため、マークなしの出力も回帰確認する。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- PPTX の図形と画像の代替テキストを FIGURE マークで保持する。

## 注記

比較元: upstream `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22`、port `18f4f4d0a96674fccd5332fde7cd03d7c896a03d`。

## 2026-11-13 トリアージ結果

- 照合対象: main `d13b9578c86982cb6ea0d955f678c16e2edc84e9`。
- 判断: この Issue の限定された実装・受入範囲は統合済み。状態と格納先を done に整合。
- 根拠: PR#18 merged b08dd257、figure_mark_wbtest.mbt、nesting/decorative/hidden/table、3target各171/phase15 pass、CHANGES.md。
- 範囲と留保: 限定された受入範囲をdoneに更新した。完全描画/全形式parityではない。段落markのlist-level rPrなど独立残件は保持。
- 検証記録は上記コミット・PR時点のもの。今回の整理で製品テスト全体を新規実行したとは主張しない。本文の過去の問題記述は履歴として保持し、受入チェック欄を照合結果に整合した。
