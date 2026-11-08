# light-server: ブラウザで変換する

[`examples/light-server`](https://github.com/shibukawa/bdf/tree/main/examples/light-server) — サーバーは文書を BDF に変換しません。文書をそのまま配り、それぞれのサムネイル画像を添えるだけで、変換と描画はブラウザ側の仕事です。

```sh
cd examples/light-server
node web/build.mjs     # web/main.js、web/lib/（Worker と wasm の変換器）、web/fonts/ をビルド
go run .
open http://127.0.0.1:8081/
```

## サーバーがすること

`main.go` は文書のディレクトリ（`-dir`。既定は `../sample-files`）を走査し、サムネイルがまだない文書ごとに、サムネイルに要る 1 ページ目だけ（`Pages: converter.PageList(1)`）を `converter.ConvertFile` でメモリ上に変換し、`thumbnail.Make` で 320px のサムネイルを描いてから、**変換した BDF を捨てます**。残るのは `-thumbs` の下の PNG だけで、BDF そのものはサーバーのどこにも残りません。同じファイルをもう一度変換したら同じ結果になるかどうかさえ、サーバーは関知しないのです。公開するのは:

- `GET /` — サムネイルがある文書の一覧 HTML。それぞれ `/view/?file=NAME` にリンク
- `GET /files/NAME` — 元のファイル（ただの `http.FileServer`）
- `GET /thumbs/NAME.png` — キャッシュ済みのサムネイル
- `GET /view/` — ビルド済みのフロントエンド

## ブラウザがすること

`web/main.ts` は `?file=` を読み、`/files/` からバイト列を取得して、デモサイトと同じ wasm の変換モジュール（`examples/common/convert.ts` の `ConverterClient`。`web/lib/bdf-*.wasm` から読み込む）で変換し、結果を [`MiniViewer`](https://github.com/shibukawa/bdf/tree/main/examples/miniviewer) で開きます。流れそのものは [`examples/viewer/main.ts`](https://github.com/shibukawa/bdf/blob/main/examples/viewer/main.ts) の `sniff → convert → open` と変わりません。ページめくり、セル選択、PDF のストリーミング変換をすべて外し、1 ファイルに切り詰めてあるだけです。

`web/build.mjs` は [`examples/common/build.mjs`](https://github.com/shibukawa/bdf/blob/main/examples/common/build.mjs)（[デモサイト](../architecture/browser.ja.md)のビルドにも使うのと同じ補助）を呼んで、レンダラ Worker、変換 Worker、wasm モジュール（このサーバーには要らないプレビュー専用モジュールを除く全部）、Office 系変換器がテキストをレイアウトするフォントをビルドします。

## この形にした理由

[なぜ BDF か](../why.ja.md)を参照してください。変換器を WebAssembly でビルドできるのは、まさにサーバーをこれだけ薄くできるようにするためです。その分の負担はブラウザに移ります。wasm モジュールの取得（形式によって 7〜27 MB。gzip されていて、同じ種類の文書を一度開けばキャッシュされます）と、開くたびの（最初の 1 回だけでなく毎回の）手元での変換です。向いているのは、大量に作られるのに、開かれることはまれな文書です。典型は監査のために残す記録で、取引ごとの帳票や報告書、署名済みの書類は作られるたびに保管されますが、実際に開かれるのは監査で求められたごく一部だけです。すべてを事前に変換すると、サーバーの処理時間と置き場所のほとんどを、だれも開かない文書のために使うことになります。この構成なら、サーバーは文書が届いたときにサムネイルを描くだけで、変換は開かれたときに、開いた人のブラウザで行います。サーバーに変換の余力がまったくない場合にも向いています。逆のトレードオフは [preview-server](preview-server.ja.md) を参照してください。
