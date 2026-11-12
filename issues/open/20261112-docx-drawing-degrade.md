# DOCX で図形・グループ・チャート Drawing があると変換が致命的失敗する

Status: open
Model: unknown
Created: 2026-11-12
Updated: 2026-11-12
Branch: fix/20261112-docx-drawing-degrade

## 背景

upstream は `w:drawing` の内容をすべて描く:
`converter/internal/wordproc/draw.go:47-140`（inline/anchor、折り返し、
z-order、距離）、`converter/internal/ooxml/drawingml/graphic.go:42-122`
（`pic`, `wsp`, `wgp`, `wpc`, chart, SmartArt の描き分けと pic への
フォールバック）、`draw.go:266-306`（`w:txbxContent` を本物のレイアウト
エンジンに通す DrawTextBox）、`drawingml/shape.go:278-283`（FIGURE マー
ク）。`testdata/basic.docx` は anchored な `wps:wsp` roundRect とセンタ
リング済みテキストボックスを含み、`docx_test.go:150-154` は警告ゼロを
要求する。

## 問題

MoonBit 実装の `convert/docx/document_text.mbt:588-649`
（`docx_text_drawing`）は 2 段構えで、それ以外で致命的失敗する:

1. `blip` があれば画像として処理（crop 等は実装済み）。
2. なければ `txbxContent` 内の全 `w:t` を空白結合した 1 つのインライン
   テキストに潰す（段落・位置・揃え・図形輪郭は失われる）。
3. どちらでもない（素の図形、グループ、チャート、SmartArt、空テキ
   ストボックス、legacy `w:pict`）は
   `docx_text_unsupported("drawing without an embedded image")`
   （`document_text.mbt:253-255`）で `InvalidDocx` となり、
   `convert.mbt:247,264` 経由で変換全体が `DocxInvalid` になる。

upstream が警告なしで通す `basic.docx` 相当の文書が port では読めない。

## 目的

第一段階（本 issue）: 画像でもテキストボックスでもない drawing で変換が
失敗しないこと。スキップ + 警告 1 件とし、`docPr/@descr` があればアク
セシビリティ用の FIGURE 代替テキストとして拾う（upstream
`drawingml/shape.go:278-283` 相当の縮退）。`txbxContent` テキスト抽出は
現状維持。

最終段階（パリティ表で追跡）: `wps`/VML 図形を実際に描く。これは
`docs/parity.md` の DOCX 行（表/図形マーク、tight/through 折り返し…）
で管理する大きな別作業であり、本 issue には含めない。

## 対象

- `convert/docx/document_text.mbt:649` の致命パス → スキップ + 警告
- `docPr/@descr` の FIGURE/代替テキスト扱い（既存マーク機構に接続）
- 上記挙動の単体テストと、テキストボックス・画像レグレッションの確認

## 対象外

- 図形ジオメトリ・塗り・線の描画本体
- Excel/PPTX 側の drawing（`convert/pptx` は sp を描ける。cxnSp は
  `20261112-pptx-cxnsp.md` で対処）

## 受け入れ条件

1. anchored `wps:wsp`（prstGeom rect、txbx も blip もなし）を含む
   最小 DOCX → 変換成功、テキスト項目ゼロ、警告 1 件
   （現状は `DocxInvalid`）。
2. `w:txbxContent` を持つ `wps:wsp`（upstream `basic.docx` の縮小版:
   "A text box with centered text"）→ 変換成功し、テキスト索引にその
   文字列が現れること（現状の抽出機能を壊さない）。
3. 画像 drawing の既存テスト（`layout_wbtest.mbt:507,542,803,1068,1668`）
   が緑のまま。

## 関連

- `docs/upstream-porting-plan.md` スライス 4
- `issues/open/20261112-docx-alternate-content.md`（Choice/Fallback の
  選択が先に決まることで本 issueの入力が変わる）
- `issues/open/20261109-parity-remaining.md`

## 出典

- upstream: `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22`
- port: `61f195b38293415a46a6aca4cff99187ba68ea5e`
