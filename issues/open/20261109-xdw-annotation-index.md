# xdw: 注釈テキストを索引と注釈レイヤーに載せる

Status: done
Model: unknown
Created: 2026-11-09
Updated: 2026-11-10
Branch: feat/20261109-xdw-annotation-index

## 概要

DocuWorks の注釈(テキスト、付箋)の文字列を BDF のテキスト索引に載せ、注釈を本文と区別できるレイヤーとして出す。

## 背景

以下は実装前（2026-11-09）の状態。

`convert/xdw/document.mbt` は注釈の文字を読んでいる。

- `XdwObject.text : String?`(`document.mbt:185`)に、テキスト注釈(`K_TEXT`)と付箋(`K_FUSEN`)の子テキストの文字列が入る。`%Text(w` は UTF-16、`%Text` は Shift_JIS として復号している(`document.mbt:486` 付近)。
- しかし `text` はどこからも読まれない(`grep -rn "\.text" convert/xdw` に読み出しが無い)。
- 注釈は EMF の描画としては出るため、画面上は見える。文字としては取り出せない。
- `convert/xdw` は `"idx"` パートを作らない。`convert/cgm`、`convert/html`、`convert/sxf`、`convert/epub`、`convert/reader` は作っている。

## 問題

- 注釈の文字を検索できない、コピーできない。
- 注釈と本文が同じ `"body"` レイヤーに混ざるため、注釈だけを表示・非表示にできない。
- `XdwObject.text` を読む経路が無く、パースした文字列が捨てられている。

## 目標

- 注釈の文字列が BDF のテキスト索引に入り、検索できる。
- 注釈が本文と別のレイヤー(`role`)になり、表示を切り替えられる。
- 付箋の子テキストも注釈の文字として扱う。

## 対象外

- 覆われた本文文字の除外(`20261109-xdw-hidden-text.md`)。本文側の索引化はそこで扱う。
- 注釈の編集・書き戻し。bdf.mbt は BDF を編集するもので、XDW の書き戻しは対象外。
- 上流 43 文書の網羅比較(`20261109-xdw-corpus-parity.md`)。

## 提案する方針

1. `xdw_convert` でページごとに `index_runs : Array[@core.IndexRun]` を組み立て、`writer.add_part("idx", @core.encode_text_index(runs))` で保存する。`convert/cgm/cgm.mbt:84` の組み立てを参考にする。
2. `XdwObject.text` を持つオブジェクトについて、配置矩形(`x`,`y`,`w`,`h`)と文字列から `IndexRun` を作る。回転している場合は `rotation` を反映する。
3. 注釈の描画を `"body"` ではなく `"annotation"` ロールのレイヤーに分ける。`xdw_convert` の `layers` 配列に 2 つ目を足す。
4. 本文の文字も同じ索引に入れるが、レイヤーで区別できるようにする。

## 受け入れ条件

- [x] テキスト注釈と付箋の文字列が `"idx"` パートに入り、`@core.index_plain_text` で読める。
- [x] 注釈が `"body"` と別のロールのレイヤーになる。
- [x] 注釈を持つサンプル(`demo.xdw` など)で、注釈の文字列が索引から取れる。
- [x] 既存の `convert/xdw` のテストが全て通る。

## 結果

main `b05cd93` に統合済み。`8e968da` が注釈テキストを `"idx"` パートに載せ、`959c032` が索引をレンダラ自身の run から組み立てるようにした。`bb16d5b` が注釈を本文と別の `"annotation"` レイヤーに分け、`convert/xdw/annotation.mbt` と `render.mbt` で注釈の描画・索引を扱う。付箋の子テキストも注釈の文字として扱う。

テストは `convert/xdw/annotation_wbtest.mbt`（16 テスト）と `convert/xdw/text_index_wbtest.mbt` にある。43 文書のコーパス比較は未実施で、`20261109-xdw-corpus-parity` で追跡する。ここに書いたのは固定 head の実装事実で、最新のテスト実行を主張するものではない。

## テスト計画

- `moon test -p f4ah6o/bdf/convert/xdw`
- テキスト注釈と付箋を含む合成ドキュメントの white-box テストで、索引の文字列とレイヤーのロールを確認する。
- `moon test --target js`、`moon test --target wasm-gc`、`moon test --target native` を通す。

## リスク

- レイヤーを分けると BDF のページ構成が変わる。既存の golden 文字列を持つテストに影響する。
- 付箋の子テキスト探索は深さ優先で最初の `K_TEXT` を取るため、複数の子を持つ付箋で取り違える可能性がある。
- 回転した注釈の索引矩形が実際の描画とずれる可能性がある。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- xdw: 注釈の文字列を検索できるようにし、注釈を本文と別レイヤーで表示する。

## 注記

`XdwObject.text` は既にパース済みなので、索引化は主に配線の作業になる。レイヤー分離のほうが影響範囲は大きい。
