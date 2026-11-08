# preview-server: サーバーで変換する

[`examples/preview-server`](https://github.com/shibukawa/bdf/tree/main/examples/preview-server) — サーバーがすべての文書を 1 度 BDF に変換してキャッシュします。ブラウザは変換済みの BDF を取得して描くだけで、wasm の変換器は一切使いません。

```sh
cd examples/preview-server
node web/build.mjs     # web/main.js と web/lib/worker.js をビルド（変換器なし）
go run .
open http://127.0.0.1:8082/
```

## サーバーがすること

`main.go` は文書のディレクトリ（`-dir`。既定は `../sample-files`）を走査し、キャッシュ済みの BDF がまだない文書ごとに `converter.ConvertFile` で変換し、結果を `(*bdf.Document).WriteSingle` で `-cache` の下に書き出し、[light-server](light-server.ja.md) と同じ方法でサムネイルも描きます。今回はどちらも保存します。公開するのは:

- `GET /` — 文書の一覧 HTML。サムネイルと変換器が言った内容（`res.Summary`）つきで、それぞれ `/view/?src=/cache/NAME.bdf` にリンク
- `GET /cache/NAME.bdf` — 変換済みの文書（ただの `http.FileServer`）
- `GET /view/` — ビルド済みのフロントエンド

`http.FileServer` は自分で Range リクエストに応えるので（`net/http` の `ServeContent`）、ビューアは表示中のページに要る BDF の部分だけを取得します。[サーバーでの変換経路](../architecture/index.ja.md#①-サーバーで変換)で CDN からバンドルを取得するのと、そこは変わりません。

## ブラウザがすること

`web/main.ts` は `?src=` を [`MiniViewer`](https://github.com/shibukawa/bdf/tree/main/examples/miniviewer) でそのまま開きます。変換するものが何も残っていないので、変換器も `sniff()` もありません。`web/build.mjs` はレンダラ Worker だけをビルドします（`buildWorkers(lib, { convert: false })`）。このフロントエンドは数百 KB で、数十 MB にはなりません。

ビューアが取得して描くのは表示範囲の近くのページだけなので、ブラウザ自身の検索では文書の残りが見つかりません。このページは `MiniViewer` に `find: "page"` を渡しています。Cmd+F / Ctrl+F でビューアの検索バーが開き、View 全体のテキスト索引を探します。ページを取得するのは、これまでどおりそのページが表示されるときと、そのページの一致へ移るときだけです。

## この形にした理由

[light-server](light-server.ja.md) とは逆のトレードオフです。変換はサーバーで 1 度だけ、他の BDF ツールと同じ変換パッケージで行われます（ここでも cgo も外部プロセスも不要です。[なぜ BDF か](../why.ja.md)を参照）。ブラウザごと・表示のたびではありません。文書は BDF を Range 取得できる速さのまま、どの端末でも、変換器をダウンロードせずに開きます。ただし、その分だけサーバー自身の変換の余力と、キャッシュを置く場所が要ります。文書が頻繁に編集され、多くの読み手が見るシステムなら、たいていこちらが有利です。同じ変換済みテキストを全文検索に使う話は [search](search.ja.md) を参照してください。
