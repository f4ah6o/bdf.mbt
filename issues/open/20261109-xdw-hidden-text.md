# xdw: 覆われた文字を検索対象から外す

Status: done
Model: unknown
Created: 2026-11-09
Updated: 2026-11-10
Branch: feat/20261109-xdw-hidden-text

## 概要

DocuWorks のページで、後から描かれた不透明な塗りに完全に覆われた文字を BDF のテキスト索引から外す。あわせて、現在は無視されている `include_hidden` を実際に効かせる。

## 背景

以下は実装前（2026-11-09）の状態。

上流の `ezpzfile/ezpzfile-xdw` は `hidden.rs`(364 行)で、描画順に塗りを積み上げて文字が覆われたかを判定し、隠れた文字を検索結果から除く。`include_hidden` はその判定を無効化するための切り替え。

bdf.mbt 側の実装前の状態:

- `convert/xdw/document.mbt:214` に `mut include_hidden : Bool` があるが、読み出し箇所が無い(`grep -rn include_hidden convert/xdw` は定義と初期化とテストのみ)。
- `convert/xdw` は `"idx"` パート(`@core.encode_text_index`)を一切作らない。`convert/cgm`、`convert/html`、`convert/sxf`、`convert/epub`、`convert/reader` は作っている。
- `site/docs-src/formats/xdw.md` は `-param include_hidden=` を「のちに描かれた不透明な塗りで完全に覆われた文字もテキストに残す」と説明しているが、実装が無い。

## 問題

- 隠れた文字が検索に出る、という以前の状態にも到達していない。そもそも xdw の文字が索引に入っていない。
- `include_hidden` を指定しても結果が変わらない。利用者から見るとオプションが壊れている。

## 目標

- xdw のページ本文の文字が BDF のテキスト索引に入り、検索できる。
- 後続の不透明な塗りに完全に覆われた文字は、既定で索引から外れる。
- `include_hidden=1` で、覆われた文字も索引に残る。
- 部分的に覆われた文字は残す(上流と同じ判定)。

## 対象外

- 注釈テキストの索引化(`20261109-xdw-annotation-index.md`)。
- 上流 43 文書の網羅比較(`20261109-xdw-corpus-parity.md`)。
- 覆われた文字の描画自体を省くこと。描画は現状のまま。

## 提案する方針

1. `convert/xdw/render.mbt` の `xdw_draw_body` で、`Gdi::text` 相当の描画時に文字と位置を集める。`convert/metafile` は現在テキストを索引に渡していないため、収集用のコールバックか戻り値を足す必要がある。
2. 塗りの蓄積と被覆判定を `convert/xdw` 側に置く。上流 `hidden.rs` の判定(文字の矩形が後続の不透明な塗り矩形に完全に含まれるか)を移植する。
3. `include_hidden` を `xdw_convert` の引数に通し、`convert/all` の `-param` から渡す。
4. 索引は `writer.add_part("idx", @core.encode_text_index(runs))` で作り、ページのレイヤーに紐づける。既存の `convert/cgm` の組み立てを参考にする。

## 受け入れ条件

- [x] xdw のページ本文の文字が `"idx"` パートに入り、`@core.index_plain_text` で読める。
- [x] 完全に覆われた文字が既定で索引から外れる。
- [x] `include_hidden=1` で覆われた文字が索引に残る。
- [x] 部分的に覆われた文字は既定でも残る。
- [x] 既存の `convert/xdw` のテストが全て通る。

## 結果

main `b05cd93` に統合済み。`8e968da` がページ本文の文字を `"idx"` パートに入れ、後続の不透明な塗りに完全に覆われた文字を既定で外すようにした。`959c032` が索引をレンダラ自身の run から組み立て、覆いと判定するのは証明できる塗りだけに絞った。`9f224fc` が browser の converter から `include_hidden` を渡し、`convert/all` も同じオプションを渡す。部分的に覆われた文字は残る。

テストは `convert/xdw/text_index_wbtest.mbt`（21 テスト）と `browser/native_converter_xdw_wbtest.mbt` にある。43 文書のコーパス比較は未実施で、`20261109-xdw-corpus-parity` で追跡する。ここに書いたのは固定 head の実装事実で、最新のテスト実行を主張するものではない。

## テスト計画

- `moon test -p f4ah6o/bdf/convert/xdw`
- 覆いの無い文字、完全に覆われた文字、部分的に覆われた文字を含む合成 EMF の white-box テストを追加する。
- `moon test --target js`、`moon test --target wasm-gc`、`moon test --target native` を通す。

## リスク

- 被覆判定は描画順に依存する。クリップや変換行列の扱いを誤ると、覆われていない文字を落とす。
- 索引を足すと BDF のパート構成が変わるため、既存の golden 文字列を持つテストに影響する可能性がある。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- xdw: ページ本文の文字を検索できるようにし、覆われた文字を既定で除外する(`include_hidden=1` で残す)。

## 注記

上流の `hidden.rs` は `ezpzfile/ezpzfile-xdw` の MIT ライセンス実装。移植時はライセンス表記を `licenses/` に合わせる。
