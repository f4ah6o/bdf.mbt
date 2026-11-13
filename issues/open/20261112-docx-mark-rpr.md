# DOCX 段落記号の直接 run 属性（w:pPr/w:rPr）が無視される

Status: open
Model: unknown
Created: 2026-11-12
Updated: 2026-11-13
Branch: fix/20261112-docx-mark-rpr

## 概要

PR #4で直接の段落記号run属性を統合済み。対象に含むlist-level rPr結合は残件のため、本Issueはopenに保持する。

## 背景

upstream は段落毎に段落記号（¶）の書式を
`converter/internal/wordproc/model.go:396-398` で

```go
p.mark = c.runStyle(c.runProps(styleID, "", w.tl, pPr.Child("rPr")), "", w.dark)
```

として解決する。つまり段落スタイル連鎖に加えて `w:pPr/w:rPr` の直接指定を
段落記号に適用する。この mark はレイアウトのあちこちで使われる:

- 空段落の高さ（`inline.go:491-499`、mark の ascent/descent × size）
- 空段落の `lh` 行間（`inline.go:505-512`、`size = p.mark.size`）
- 文字単位インデント（`inline.go:50-57`、`chars/100 * p.mark.size`）
- リスト番号/ビュレットの書式（`model.go:923-940`、level の rPr と結合）
- 数式のみの段落の垂直センター（`math.go:74-77`）

## 問題

MoonBit 実装では段落記号の概念（`DocxTextParagraph.mark`）はあるが、
`convert/docx/document_text.mbt:2196` が

```moonbit
let mark = self.styles.resolve_run(paragraph_style, None)
```

と直接ノードを常に `None` で渡すため、`w:pPr/w:rPr` が読まれない。
`DocxStyles::resolve_run`（`convert/docx/style_resolver.mbt:308-342`）は
`docx_style_apply_rpr(props, direct)`（`:341`）で直接ノードを適用でき、
引数を `docx_style_child(direct, "rPr")` に変えるだけで届く。
また `convert/docx/numbering.mbt:227,258` は level の rPr との結合をして
いない（upstream `makeLabel` は結合する）。

Word 文書では 1 行空けに `sz` だけ指定した空段落が実務で頻出するため、
.port の空段落高さがスタイル既定のままになり、ページ区切りや
ページ数が upstream とずれる。

## 目標

段落記号の書式解決で `w:pPr/w:rPr` を直接属性として適用し、
空段落の高さ・行間が upstream と一致すること。

## 対象

- `convert/docx/document_text.mbt:2196` の直接 rPr 渡し
- （同一スライスでも可、別スライスでも可）`convert/docx/numbering.mbt`
  のリストラベル書式への level rPr 結合

## 対象外

- 文字単位インデント（leftChars 等）の適用 — これは別 issue として
  `docs/upstream-porting-plan.md` スライス 5 に分離した
- テキスト run 自体の rPr（既に実装済み）

## 提案する方針

本文の番号ラベルで段落記号の書式を複製し、番号付けレベルの `rPr` を上書きする。ラベルで非表示となる装飾は取り除き、未対応の combine 指定は警告する。

## 受け入れ条件

1. `DocxTextWalker::blocks` の単体テスト: body が
   `<w:p><w:pPr><w:rPr><w:sz w:val="60"/></w:rPr></w:pPr></w:p>`
   （空段落、文書既定 10pt）のとき `mark.size == 30.0` となること
   （`document_text_wbtest.mbt:131-165` の体裁に合わせる）。
2. `docx_layout_paragraph` を通した空段落の行高が mark サイズ基準
   （≈ 30 × 1.2 pt）になること。
3. 既存の継承テスト（`document_text_wbtest.mbt:163`）が緑のまま
   であること（スタイル連鎖は変わらない）。

## 関連

- `docs/upstream-porting-plan.md` スライス 2
- `issues/open/20261109-parity-remaining.md`（DOCX 残差の土台修正）
- `issues/open/20261110-docx-page-count-sample.md`（ページ数サンプルでも
  空段落高さが効く）

## 出典

- upstream: `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22`
- port: `61f195b38293415a46a6aca4cff99187ba68ea5e`

## 番号ラベル書式の対応範囲

- 本文 blocks（本文の表セルを含む）のラベルに対し、段落記号の書式を複製して番号付けレベルの `rPr` を適用する。レベル上書き、テーマ書体、Symbol / Wingdings、caps / smallCaps を扱い、ラベルに使わない下線・網掛け・ハイライトは外す。
- ラベルの `eastAsianLayout combine` は未実装のため、無視することを変換結果の警告で明示する。
- テーマ書体は文書テーマから解決する。一方、テーマ色は既存の固定パレットに従い、文書固有の色・tint・shade の解決は未実装・未検証である。
- ヘッダー、フッター、脚注のストーリーには既存の番号付け処理が適用されないため、これらのリストラベルは今回の対象外として未対応のまま追跡する。本 issue は open とする。
- 回帰テストは合成 XML・合成 DOCX と生成ケースで、レベルの優先順位、実際の描画サイズ、段落記号・本文 run の独立性を検証する。実文書との描画比較は未実施。

## テスト計画

合成文書・生成ケースでレベルの継承と明示的な上書き、記号フォント、装飾、文字サイズを確認し、JS・wasm-gc・native の DOCX テストを実行する。

## リスク

番号付けの書式適用によってラベルの描画が変化する。本文 run と段落記号は元の書式を維持する。テーマ色とヘッダー等は上記のとおり未対応が残る。

## 変更履歴

`CHANGES.md` に本文リストラベルの書式修正とストーリー別の制限を記載する。

## 注記

実装候補の統合と実文書での表示確認は別途記録する。未対応のストーリーがあるため issue は open とする。
