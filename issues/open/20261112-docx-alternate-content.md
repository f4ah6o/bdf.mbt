# DOCX mc:AlternateContent が Requires を見ずに最初の Choice を選ぶ

Status: open
Model: unknown
Created: 2026-11-12
Updated: 2026-11-12
Branch: fix/20261112-docx-alternate-content

## 背景

upstream は XML 解析時に `mc:AlternateContent` を解決する
（`internal/xmltree/xmltree.go:446-508` resolveAlternates）。
`ParseChoosing` + `SupportedChoice`（`:417-425`, `:516-524`）では、
`mc:Choice` の `Requires` 属性のすべての接頭辞がサポート集合に含まれる
ものを最初に選び、なければ `mc:Fallback`、それもなければ最初の Choice
を取る。DOCX のサポート集合は
`converter/internal/wordproc/docx.go:43-45`:

```go
var supported = map[string]bool{"wps": true, "wpg": true, "wpc": true, "wp14": true, "w14": true, "w15": true, "a14": true, "pic14": true}
```

テスト `converter/internal/ooxml/ooxml_test.go:97-112,225-250` と、
`testdata/basic.docx` / `form-fixed.docx`（`Requires="wps"` の Choice と
VML `w:pict` の Fallback を持つ）がこの挙動を固定している。

## 問題

MoonBit 実装の `convert/docx/document_text.mbt:1001-1010`
（`docx_alternate_content`）は最初の `mc:Choice` を無条件に返し、
`Requires` を一切読まない。そのため:

- `Requires="wps"` の典型的な文書は結果が一致する（Choice が今回の
  対応範囲にたまたま入る）が、
- upstream が Fallback に落とす `Requires`（未対応接頭辞）でも port は
  Choice に降り、未対応の図形などに当たると
  `InvalidDocx` → 致命的 `DocxInvalid`
  （`document_text.mbt:253-255`, `convert.mbt:247,264`）で変換全体が
  失敗する。upstream は Fallback（多くは VML のシンプルな絵）を描いて
  通る。

## 目的

upstream と同じ選択規則（サポート集合 ≥ Requires の最初の Choice、
なければ Fallback）に揃え、未対応 `Requires` の文書が Fallback 経由で
変換に失敗しないこと。

## 対象

- `convert/docx/document_text.mbt:1001-1010` の選択ロジックと
  サポート接頭辞の集合定数（upstream `wordproc/docx.go:43-45` の写し）
- Fallback 選択時の単体テスト（inline 適用箇所は `:1317-1323`,
  `:1416-1423` のまま変更不要）

## 対象外

- Fallback の VML `w:pict` 自体の描画（別 issue
  `20261112-docx-drawing-degrade.md` 参照）
- DOCX 以外（XLSX/PPTX）の AlternateContent。XLSX 側
  （`convert/xlsx/plain.mbt:1330`）は既に代替走査に `cxnSp` 相当を
  含んでおり、今回の調査では差を見ていない

## 受け入れ条件

1. `Requires="wps"` の Choice（blip 画像）+ Fallback（run テキ
   スト "FALLBACK"）→ Choice が選ばれ画像項目が抽出されること
   （upstream `ooxml_test.go:97-112` の対応）。
2. 同一構成で `Requires="c14"` → Fallback の run テキストがテキスト
   索引に現れ、かつ Choice 内の未対応図形があっても `DocxInvalid` に
   ならないこと（現状は失敗する）。
3. 既存テストが緑のまま（first-Choice 挙動に暗黙に依存するテストは
   `Requires` 付きに更新してよい）。

## 関連

- `docs/upstream-porting-plan.md` スライス 3
- `issues/open/20261112-docx-drawing-degrade.md`（Choice/Fallback 両方の
  図形が描けない場合の後段）
- `issues/open/20261109-parity-remaining.md`

## 出典

- upstream: `a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22`
- port: `61f195b38293415a46a6aca4cff99187ba68ea5e`
