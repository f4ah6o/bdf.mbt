# DOCX 文字幅単位インデント（leftChars 等）がレイアウトに反映されない

Status: done
Model: unknown
Created: 2026-11-12
Updated: 2026-11-12
Branch: feat/20261112-docx-character-indents

## 概要

`w:ind` の `leftChars`/`rightChars`/`firstLineChars`/`hangingChars`
（1/100 文字単位）はパーサで保持されているが、レイアウトが常に
ポイント属性（`left`/`right`/`firstLine`/`hanging`）だけを使うため、
日本語文書などで文字単位インデントが無視される。これを upstream
`wordproc/inline.go:48-62` の `indents()` と同じ規則で適用する。

## 背景

- upstream `a5e4d7a6` の `converter/internal/wordproc/inline.go:48-62`:

```go
func (p *para) indents() (l, r, first float64) {
    pp := p.pp
    l, r, first = pp.indL, pp.indR, pp.indFirst
    ch := p.mark.size // a character of the paragraph's font
    if pp.indLCh != 0 { l = pp.indLCh / 100 * ch }
    if pp.indRCh != 0 { r = pp.indRCh / 100 * ch }
    if pp.indFirstCh != 0 { first = pp.indFirstCh / 100 * ch }
    return
}
```

- パース側 `converter/internal/wordproc/props.go:316-327` は
  `startChars`/`endChars` も左/右に対応付け、`hangingChars` を負の
  first-line として格納する。明示的な 0 属性は 0 として格納され、
  `!= 0` ガードによりポイント属性へのフォールバックになる。
- ポートのパーサ（`convert/docx/paragraph_props.mbt:219-235`）は
  この規則を既に正しく実装している。
- 段落記号の書式（`w:pPr/w:rPr` とスタイル連鎖）は slice 2
  （`20261112-docx-mark-rpr`）で `DocxTextParagraph.mark` に解決済みで、
  `docx_layout_paragraph` は空段落の高さに `mark_size` を使っている
  （`convert/docx/layout.mbt:179`）。Upstream で文字単位のスケール
  基準はこの mark size である（`inline.go:51`）。

## 問題

`convert/docx/layout.mbt` の `docx_layout_paragraph` と
`docx_flow_emit_paragraph` は `props.left`、`props.right`、
`props.first`（ポイント換算済み）だけを参照し、
`props.left_chars`、`props.right_chars`、`props.first_chars`
を一切読まない。そのため `w:ind w:leftChars="200"` のような指定が
ある段落の座標・折り返し位置がポイント属性（多くの場合 0）のままになる。

## 目標

- 文字単位属性が非 0 のとき、その値 × 段落記号のフォントサイズ ÷ 100
  が対応するインデントとして使われること。
- 文字単位属性が 0 または不在のとき、従来どおりポイント属性が使われる
  こと（フォールバック・優先順位は upstream `indents()` と同じ）。
- マークサイズはスタイル連鎖・直接 `w:pPr/w:rPr` を含む解決結果に
  従うこと。

## 対象外

- `w:ind` のパース規則の変更（既に upstream 一致）。
- 番号付けレベルの rPr マージや `w:tabs` 幅の文字単位化
  （upstream にもない/別件）。
- 表・ヘッダー等の個別の追加レイアウト条件。

## 提案する方針

- `docx_para_indents(props, mark_size) -> (left, right, first)` を
  `convert/docx/layout.mbt` に追加し、upstream `indents()` を写す。
- `docx_layout_paragraph` の冒頭で呼び、`props.left` 等の代わりに
  有効値（タブの基準、折り返し右端、行左端すべて）を使う。
- `docx_flow_emit_paragraph` でも同一の有効値を
  `right_limit`（flow 幅の右限）と保留行の再基準化
  （`docx_line_rebase`）に使う。

## 受け入れ条件

- [x] 直接 `w:pPr/w:rPr` のサイズ（例 20pt）で `leftChars="200"` +
      `firstLineChars="100"` のとき、先頭行のアイテム x が
      2×20 + 1×20 = 60pt になること。
- [x] `rightChars` が折り返しの右端を狭めること（折り返し座標が
      上記規則の右インデントどおりであること）。
- [x] 段落スタイルの `rPr` から継承されたマークサイズがスケールに
      使われること、かつ直接 `w:pPr/w:rPr` が継承より優先すること。
- [x] `hangingChars` が負の first-line として、`left` と組み合わせて
      先頭行を後退させること。
- [x] `*_Chars="0"` はポイント属性にフォールバックすること、
      属性なし文書のレイアウトが従前どおりであること。

## テスト計画

- `convert/docx/document_text_wbtest.mbt` に合成文書テストを追加し、
  `docx_mark_walker` + `docx_layout_paragraph` で正確な座標を検証。
- `moon test --target js -p f4ah6o/bdf/convert/docx`（full package、
  既存テストの非回帰確認）。
- `moon test --target wasm-gc -p f4ah6o/bdf/convert/docx` と
  `--target native`（利用可能な場合）。
- ローカル actrun ゲートが利用可能なら該当スクリプトを実行する。

## リスク

- 文字単位インデントを持つ実文書の座標が変化する（意図された反映）。
  属性を持たない文書は数値上変化しない。
- マークサイズ 0 の異常文書では既存の 10pt フォールバックに従う
  （既存コードと同じ分岐を使うため新規経路はない）。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- DOCX: `leftChars`/`rightChars`/`firstLineChars`/`hangingChars`
  文字幅単位インデントをレイアウトに反映（段落記号サイズ基準）。

## 注記

- `docs/upstream-porting-plan.md` スライス 5。スライス 2 の
  `20261112-docx-mark-rpr` から分離され、重複の包括 issue は作らない。
- Upstream 側の検証は `a5e4d7a6` を read-only で確認済み。
- 2026-11-12: 文字単位インデントと keepNext の段落記号サイズを実装。3 targets 各840テストとPhase12成功。独立再レビュー承認。

## 検証結果

- 2026-11-12: Vibe が文字単位インデントと回帰テストを実装。
- DOCX パッケージ: JS / wasm-gc / native 各 840 件成功（keepNext 修正後）。
- Phase 12 DOCX integration 成功（依存導入と JS build 後）。
- local actrun ci/test と ci/demo は再実行で成功。初回 ci/test は wasm-gc/native が結果要約前に終了し、原因は未確定。
- parity / visual / site 全体ゲートは未実行。独立レビューの指摘 1 件（keepNext の固定 mark size）を修正し、再レビューで承認。

- keepNext 回帰テストは旧固定値で失敗し、実際の段落記号サイズを使う修正後に成功。
- 修正後の Phase 12 DOCX integration も成功。local ci/test と ci/demo の成功は keepNext 修正前の結果。
