# docx: 下流の「ページ要素 4 対 3」を数え方ごと切り分ける

Status: open
Model: unknown
Created: 2026-11-10
Updated: 2026-11-10
Branch: research/20261110-consumer-feedback

## 概要

下流の利用者から「Word の参照側でページ要素が 4 つ、現行で 3 つ検出された」と報告された。この worktree の DOCX フィクスチャ 8 件では、上流と bdf.mbt のページ数が一致し、再現しない。数え方が BDF のページ数なのか DOM の要素数なのかを切り分け、再現する条件を特定する。

## 背景

報告は `bdf.mbt` `6f2918f` に対する匿名の下流観測で、入力サンプルと実行環境は提供されていない。数値から原因を推測しない。

`6f2918f` の worktree で実行した結果（historical な固定 head の測定。main `b05cd93` では再実行していない）:

```sh
node compat/parity/verify.mjs --format=docx
# Parity: 0 pass, 12 diff, 0 one-sided error, 0 both-error
```

12 ケースすべてが差分だが、`$.views[0].pages.length` の差分は 1 件だけだった。

| ケース | 上流ページ数 | bdf.mbt ページ数 |
| --- | ---: | ---: |
| `docx/basic#scroll` | 2 | 1 |
| それ以外の 11 ケース | 一致 | 一致 |

`pages` ビューのページ数は `compat/docx/README.md` の記載（basic 3、styles 1、grid 4、vertical 2、math 1）と一致し、`form-pages` / `form-rows` / `form-fixed` も上流と一致した。`docx/basic#scroll` の 2 対 1 は README が既に「近似メトリクスにより basic は上流 2 ストリップ、この移植は 1 ストリップ」と記録している既知の差。

## 問題

- 報告された 4 対 3 を、リポジトリ内のフィクスチャで再現できない。
- 「ページ要素」が BDF のページ数なのか、DOM の要素数なのかが特定されていない。
- DOM の要素数を数える場合、テキストレイヤーの内部リンクが同じ属性を持つため、ページ数より多く数えられる。

`browser/textlayer.mbt:280` は内部リンクのアンカーに `data-bdf-page` を付ける。ページ枠は `div[data-bdf-page]`、アンカーは `a[data-bdf-page]` なので、`[data-bdf-page]` を数えると 3 ページ + 内部リンク 1 本 = 4 になる。`site/test.mjs:128` の
「top page counts page frames, not text-layer links」は、まさにこの数え方の違いを固定している。

もう 1 つの候補は近似メトリクスによるページ数の差。`compat/docx/README.md` は
「exact font metrics and OpenType shaping」を未対応として挙げ、`basic#scroll` の
ストリップ数が上流と違うことを記録している。ページ数が変わる可能性はあるが、
この worktree の `pages` ビューでは観測していない。

## 目標

- 下流の数え方（BDF ページ数 / `div[data-bdf-page]` / `[data-bdf-page]`）を確定する。
- 数え方の違いなら、下流のハーネス側の修正として記録し、bdf.mbt は変えない。
- BDF のページ数が違うなら、その DOCX の機能（セクション、段組み、表の分割、近似メトリクス）を特定して再現フィクスチャを作る。

## 対象外

- 利用者サンプルの入手・再配布。
- 報告のパーセントから原因を推測すること。
- 近似メトリクスを正確なフォントメトリクスに置き換える作業（別の課題）。
- 基板、楽譜、EPUB の再導入。
- ピクセル比較のしきい値変更。

## 提案する方針

1. 下流のハーネスが使ったセレクタを確認する。`div[data-bdf-page]` と `[data-bdf-page]` の両方で数を出し、差があればアンカーの本数と一致するかを見る。
2. 内部リンクを 1 本持つ 3 ページの合成 DOCX を作り、`div[data-bdf-page]` が 3、`[data-bdf-page]` が 4 になることを実測する。`site/test.mjs` と同じ形の確認を `compat/docx` 側にも置く。
3. 数え方の違いで説明できない場合、`pages` ビューでページ数が変わる DOCX を探す。候補は段組み、`w:cols` の連続セクション、表の行分割、`keep-with-next`、近似メトリクスでの行送り。
4. 再現したら、その DOCX を `compat/parity/fixtures/docx/` に追加し、`verify.mjs` のケース一覧に入れる。上流のページ数を期待値として固定する。

## 受け入れ条件

- [ ] 下流の数え方が特定され、記録されている。
- [ ] 数え方の違いなら、`div[data-bdf-page]` と `[data-bdf-page]` の差を実測した結果が残っている。
- [ ] BDF のページ数が違うなら、再現する DOCX と上流のページ数が `compat/parity` に入っている。
- [ ] `node compat/parity/verify.mjs --format=docx` の `pages.length` 差分が、既知の `basic#scroll` 以外に増えていない。
- [ ] ピクセル比較のしきい値を変えていない。

## テスト計画

- `node compat/parity/verify.mjs --format=docx`
- 合成 DOCX で `div[data-bdf-page]` と `[data-bdf-page]` の数を比較する。
- `node site/test.mjs` で「top page counts page frames, not text-layer links」が通り続けることを確認する。
- 追加フィクスチャで `node compat/parity/verify.mjs --case=docx/<name>#default` を実行する。

## リスク

- 数え方の違いを bdf.mbt の不具合として扱うと、存在しないページ数の差を追うことになる。
- 内部リンクのアンカーから `data-bdf-page` を外すと、閲覧側のページ移動が壊れる。属性は残し、数え方を直す。
- 近似メトリクスの差は、フォントを変えるとページ数が動く。フィクスチャの期待値を固定しすぎると、フォント更新で壊れる。
- `compat/parity` の DOCX ケースは既に 12 件すべて差分がある。新しいケースを足すとき、既存の差分と混ざらないよう `--case` で絞る。

## 変更履歴

`CHANGES.md` impact: no（数え方の確認だけなら）

## 注記

- 実測コマンド: `node compat/parity/verify.mjs --format=docx`。
- レポートは `_scratch/parity/report.json` に出力される。`$.views[0].pages.length` の差分は `docx/basic#scroll` の 2 対 1 のみ。
- 報告の「4 対 3」は再現していない。ページ数の差ではなく、DOM の数え方の差である可能性を排除できていない。
- `browser/textlayer.mbt:280` のアンカーは内部リンクのみ `data-bdf-page` を持つ。外部リンクには付かない。
