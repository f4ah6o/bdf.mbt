# XLSX フォント指定時のメトリクスがレイアウト計算に使われていない

Status: open
Model: unknown
Created: 2026-11-12
Updated: 2026-11-13
Branch: feat/20261112-xlsx-font-metrics

## 概要

明示フォントの実測値をXLSXレイアウトへ接続する。PR #9はMDW・列幅・インデントを統合済み。既定行高、自動行高、縮小表示、General書式の当てはめは残件であり、本Issueをopenに維持する。

## 背景

upstream `shibukawa/bdf` はフォント実測でレイアウトし、フォントがない
場合のみ推定メトリクス（空白 0.25em / CJK 1em / その他 0.55em、行高
Asc 0.9 + Desc 0.25、MDW 7）に落ちる
（`converter/xlsx/xlsx.go:367` の警告文参照）。port のメイン経路
（`convert_plain_no_fonts`）はその推定経路そのものであり、
`compat/xlsx` のフィクスチャはすべて upstream を NoSystemFonts で走らせた
期待値（`compat/xlsx/generate_render_test.go:533,548,561,574`）なので、
推定経路のパリティは fixture 検証済みである。

フォント実測に依存する部分は次のとおり:

- 列幅: MDW（最大数字幅）は文書既定フォントから測る
  （`converter/xlsx/geom.go:96-107`。フォント未指定時のみ 7 に固定。
  Calibri/Carlito は非丸め ppem。M PLUS 1p では MDW 9、
  `grid_test.go:74` が検査）
- 既定行高: `(Asc+Desc)・size`（`render.go:503-504`, `geom.go:133-142`）
- 自動行高・縮小表示・General の `#` 当てはめ: 実フォントの
  per-rune アドバンスで計る（`render.go:538-561`, `text.go:412-462`）
- インデント 1 単位: `(mdw+3)*0.75`（`text.go:86,231`）
- グリッド列の自動フィット（CSV 経路）: 実測幅でフィット、
  上限 `(50*mdw+5)*pxPt`（`grid.go:63-64,205-268`）

## 問題

port はフォントを渡す経路（`convert_plain_with_font`,
`convert/xlsx/plain.mbt:2092-2110`）が「セルのアドバンスと行
メトリクスに使う」を謳っているのに、次がフォント無視で固定値のまま:

- MDW が常に `7.0`（`plain.mbt:2976-2977` と `:3813-3820`）— アルゴリ
  ズム自体は mdw 引数化されており、`font_mdw`
  （`convert/sheet/font_geometry.mbt:35-51`）が実装済みだが呼ばれて
  いない（唯一の呼び出し元は `compat/font/fixture.mbt:53`）
- 既定行高が常に `(0.9+0.25)*size`（`plain.mbt:3009`）。一方で描画側は
  実フォントの `face.metrics.ascent/descent` を読む
  （`convert/sheet/draw_existing.mbt:490-498`）
- 自動行高・縮小・General の `#` 当てはめ（`plain.mbt:4594-4862`,
  `:5044-5067`）が `sized_fallback_advance`（推定）のまま → 行高の
  事前見積と描画時の折り返し行数が食い違い、クリップや余白が生じ得る
- インデントが常に `7.5`（= (7+3)*0.75）（`plain.mbt:4772-4787`）
- CSV/グリッド経路にフォントありの配管がなく、
  `grid_geometry_with_font` がどこからも使えない
  （`convert/sheet/font_geometry.mbt:5-51`）

既定フォントが Calibri 11 の間は MDW=7 で一致するため、これは
フォント明示指定でのみ顕在化する。

## 目的

`convert_plain_with_font`（およびグリッド経路）で、
既定フォント実測の MDW とフェイスメトリクスをレイアウト決定に使うこと。
既定の Calibri 11 ワークブックではMDW が 7 のまま変わらないため、
既存フィクスチャはすべて緑のまま変わらないはずである。

## 対象

- `font_mdw` の `plain.mbt:2976-2977,3813-3820` 接続と
  `xlsx_plain_indent` の `(mdw+3)*0.75` 化
- 既定行高・自動行高・縮小・General`#` への実メトリクス横断
- （切り出し可能）CSV/グリッドへのフォントあり配管

## 対象外

- 複数フェイスの解決・フォールバック・逐次埋め込み
  （`convert/all/all.mbt:93-118` の 1 フェイス設計は API 上の意図的な
  逸脱として文書化済み）
- views=print（`issues/open/20261109-parity-xlsx-print-view.md` で管理）
- パターン塗り・複雑罫線・番号書式run

## 受け入れ条件

1. 回帰: 既存の `compat/xlsx/verify-layout.mjs` / `verify-render.mjs` が
   全件緑のまま（Calibri 11 では実測 MDW も 7）。
2. 新規フィクスチャ: MDW≠7 のフィクスチャフォント（例: M PLUS 1p 相当、
   MDW 9）を使うワークブックで、列幅・既定列幅
   （`ceil((8*mdw+5)/8)*8*0.75`）・自動行高が同じフォントを渡した
   upstream `Convert(..., FontDirs: ...) ` の出力と一致すること
   （期待値は既存の `generate_layout_test.go` パターンで新規生成し、
   生成方法をファイルに記録する）。
3. 整合性テスト: `convert_plain_with_font` で折り返しセル
   （"The quick brown fox jumps over the lazy dog" を width=10 列に）
   の行ラン高が、描画側の折り返し行数と一致すること
   （`(ceil(lines*(asc+desc)*size/0.75-0.05)+2)*0.75` を実メトリクスで）。

## 関連

- `docs/upstream-porting-plan.md` スライス 6
- `issues/open/20261109-parity-remaining.md`（XLSX 残差は主に print
  view・チャート）
- `issues/open/20261112-xlsx-fixture-size.md`（フィクスチャ在庫管理。

## 出典

- upstream: `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22`
- port: `61f195b38293415a46a6aca4cff99187ba68ea5e`

## 進捗

- 2026-11-13: 既定行高と通常テキストの自動行高に supplied face の ascent / descent を接続し、通常の折返し幅に glyph advance を使用。欠字は既存の推定値へ戻す。明示行高と sheetFormatPr の既定行高は優先し、フォントなしの出力を維持する。
- 同じ変更で sheet renderer の下降量の符号を正し、実測行高と複数行の基線間隔が一致するようにした。合成フォントの通常行・1行折返し・複数行折返し・明示行高と基線、欠字 fallback を検証する。
- 可変サイズ rich text の折返しは renderer と同じ推定値を維持する。縮小表示と General 書式の当てはめ、rich text 全般の実測化、upstream との同一フォントでの比較は引き続き未完了。この issue は open のままとする。
