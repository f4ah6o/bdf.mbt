# search: 検索エンジンとつなぐ

[`examples/search`](https://github.com/shibukawa/bdf/tree/main/examples/search) — [preview-server](preview-server.ja.md) のサーバー側変換の上に、[Meilisearch](https://www.meilisearch.com/) を使った全文書横断の全文検索を足したものです。

```sh
docker run --rm -p 7700:7700 getmeili/meilisearch:v1.12 \
  meilisearch --master-key=dev-key --no-analytics

cd examples/search
node web/build.mjs
go run . -meili-key dev-key
open http://127.0.0.1:8083/
```

HTTP で使える検索エンジンなら何でも同じ役割を果たせます。Meilisearch の素の REST API はごく小さいので、この例はクライアントライブラリを足さず `net/http` で直接呼んでいます。

## サーバーがすること

[preview-server](preview-server.ja.md)（すべての文書を BDF に変換してキャッシュし、サムネイルも作る）に加えて、キャッシュ済みの BDF をもう一度開き（`bdf.OpenSingleFile`、`(*Reader).ToDocument`）、`(*bdf.Document).SearchText()` を呼びます。サーバーが自分で変換した文書を、変換し直さずに検索可能にするのと同じ呼び出しです。`SearchText` は文書のメタデータと、ページごとのテキストを返します（シートはページ番号なしで 1 件）。各ページが Meilisearch の 1 ドキュメントになり、id、元のファイルと View、ページ番号、文書の題名を持ちます。

```go
type meiliDoc struct {
	ID    string `json:"id"`
	File  string `json:"file"`
	BDF   string `json:"bdf"`
	View  string `json:"view"`
	Page  int    `json:"page,omitempty"`
	Title string `json:"title"`
	Text  string `json:"text"`
}
```

これらは起動時に一括で Meilisearch に送られます（`POST /indexes/{index}/documents`）。サーバーはインデックス作成のタスクが終わるのを待ってからリクエストに応え始めるので、起動直後の最初の検索から、Meilisearch がそこまで処理し終えたものだけでなく、すべてが見つかります（インデックス作成は通常は非同期です）。

`GET /search?q=` はクエリを Meilisearch 自身の `/search` エンドポイントに取り次ぎ、一致箇所を切り出して `<mark>` でハイライトしたスニペットを頼み（`attributesToCrop`、`attributesToHighlight`）、小さな JSON の配列（ファイル、BDF、View、ページ、題名、スニペット）を返します。検索そのものの仕組みについては何も語りません。API キーはサーバー側にとどまり、ブラウザが Meilisearch と直接話すことはありません。

## ブラウザがすること

ホームページの検索ボックス（`web/search.ts`）は `/search` を呼び、返ってきたものを一覧にして、それぞれのヒットを `/view/?src=/cache/NAME.bdf#view=ID&page=N` にリンクします。`web/main.ts`（preview-server のものとほぼ同じ）は、文書を開いた後で URL のフラグメントから `view` と `page` を読み取り、`viewer.show(view, page - 1)` を呼んでそこへ直接移動します。ディープリンクを扱うビューアなら、[`MiniViewer`](https://github.com/shibukawa/bdf/tree/main/examples/miniviewer) の上に作るどんなものでもこの API を使うはずです。

## この形にした理由

検索に要るのは文書のテキストだけで、描画そのものは要りません。だからこそ、すでに使っている変換の構成とうまく組み合わせられます。この例は都合上 preview-server の上に作りましたが、light-server の上でも動きます。SearchText には変換済みの BDF があればよく、それは文書をインデックスする（または再インデックスする）ときに 1 度作ればよいからです。検索の API キーをサーバー側に留め、クエリを取り次ぐことで、ブラウザは検索エンジンの資格情報を一切持たずに済みます。

## サーバーなしで同じレコードを

[サイトのトップページ](https://shibukawa.github.io/bdf/)では、同じ考え方をブラウザの中だけで動かしています。デモ文書のテキストを、WebAssembly にしたプレビューモジュール（`bdf text` に相当）で 1 ページ 1 レコードとして取り出し、JavaScript の検索ライブラリ [MiniSearch](https://github.com/lucaong/minisearch) に入れます。日本語は隣り合う 2 文字の組（バイグラム）で索引づけます。辞書なしで索引づける常道で、ブラウザの `Intl.Segmenter` は辞書にある語しか切り出せず、「ぶらうざ」を 4 文字に刻んでしまいます。語の正規化は `@bdfkit/core` の `normalizeQuery` で、ビューア自身の検索と同じです。ヒットを選ぶとビューアがそのページを開きます。文書が数件のような小さなアプリケーションなら検索エンジンなしで済ませられますし、レコードは検索エンジンに渡すものと同じです。
