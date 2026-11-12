# PPTX コネクタ（p:cxnSp）がサイレンにスキップされる

Status: open
Model: unknown
Created: 2026-11-12
Updated: 2026-11-12
Branch: fix/20261112-pptx-connectors

## 背景

upstream `shibukawa/bdf` は `p:cxnSp` を他の図形と同じ DrawingML 描画経路で処理する
（`converter/internal/ooxml/drawingml/shape.go:294` の drawElem が
`"sp", "cxnSp", "pic", "graphicFrame", "grpSp", "wsp", "wgp"` を受け付け、
`:322` で `cxnSp` は `sp` と同じ drawSp に渡る）。テンプレート側も
`converter/pptx/template.go:361,833` が図形として列挙する。
`stCxn`/`endCxn` による図形への接続は upstream にも実装がなく、
コネクタは自身の `a:xfrm` 矩形で描かれる。

## 問題

MoonBit 実装の `convert/pptx/convert.mbt:742-767`
（`pptx_collect_shapes`）は `sp`/`pic`/`graphicFrame`/`grpSp` のみを一致させ、
`cxnSp` は `_ => ()` に落ちてすべてのレイヤ（本文・レイアウト・マスタ）と
テキスト索引からサイレントに脱落する。警告も出ない。

さらに `convert/pptx/render_page.mbt:102-104` が
`draw_width <= 0.0 || draw_height <= 0.0` の図形を飛ばすため、
平坦なコネクタ（`a:ext cy="0"`。upstream テストデータ `features.pptx` slide 5 の
3 本のコネクタがまさにこの形）は仮に収集しても描画されない。
upstream は `shape.go:158` の xfrm 処理でサイズ未指定時のみ諦め、
ゼロ寸法は描画する。

下流の機能はすべて既にある: コネクタのプリセット
（`straightConnector1`、`bent/curvedConnector2-5`、`flowChartConnector`、
`line` — `convert/pptx/presets_generated.mbt:217-247,462-486,1499`）、
`a:headEnd`/`a:tailEnd` の解析と `pptx_draw_arrow`
（`convert/pptx/paint.mbt:394-407,648-757`）、`p:style lnRef` の代替
（`paint.mbt:227-279`）。`cxnSp` が到達できていないだけである。

## 目的

upstream の `basic.pptx`（slide 3: 赤 2pt の `line` コネクタ、
`tailEnd type="triangle"`）と `features.pptx`（slide 5: 平坦 3 本、
dash と先端/終端装飾の組み合わせ）が、upstream と同じ描画結果になること。

## 対象

- `convert/pptx/convert.mbt` の `pptx_collect_shapes` への `"cxnSp"` 追加
- `convert/pptx/render_page.mbt:102-104` のゼロ寸法スキップの緩和
  （どちらか一方がゼロでも描く。塗りつぶし図形は従来どおりスキップ可）
- 白箱テストと埋め込み fixture（`basic.pptx`/`features.pptx` は
  `convert/pptx/presentation_generated_wbtest.mbt` に既に収録）による回帰

## 対象外

- `stCxn`/`endCxn` による接続先追従（upstream 未実装のためパリティ対象外）
- SmartArt・ink・3Dなど `docs/port-status.md` 記載の PPTX 公知ギャップ

## 受け入れ条件

1. 最小デッキ（`p:cxnSp`、`prstGeom prst="line"`、off (100,100)、ext (200,0)、
   `a:ln w="25400"` solid `C00000`、`tailEnd type="triangle"`）の変換で、
   本文レイヤに 1 本の水平 StrokePath（色 C00000）と終端の塗り三角 1 個が
   含まれ、warnings が空であること。
2. `basic.pptx` slide 3 で本文レイヤに赤 2pt のストロークと塗り三角が 1 組
   増え、警告が増えないこと（upstream の `TestConvertBasic` はこのデッキで
   警告ゼロを要求する）。
3. `features.pptx` slide 5 の 3 本が確定的に描画されること。
4. `npm run test:phase15-pptx` と parity の既存合格ケース
   `pptx/basic#slide-1` が変わらず緑であること。

## 関連

- `docs/upstream-porting-plan.md` スライス 1
- `issues/open/20261109-parity-remaining.md`（PPTX の残差と並行）
- 予約済み worktree `bdf-pptx-connectors-20261112`（2026-11-12 時点で
  コミットなし。この Issue の作業 lagging duplication に注意）

## 出典

- upstream: `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22`
- port: `61f195b38293415a46a6aca4cff99187ba68ea5e`
