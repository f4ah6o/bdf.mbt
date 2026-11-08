# サーバーに組み込む

Go の `converter` は、import された形式の変換器だけを登録します。必要なサブパッケージを空 import すれば、サーバーが受け付ける形式を組み合わせられます。生成した BDF はブラウザの[ビューア](integrating-to-frontend.ja.md)に渡せます。Go 1.27 以上が必要です。

## 必要な形式を選ぶ

例えば PDF、EPUB、Word、CSV/TSV だけを扱うサーバーなら、次の import にします。TSV は `converter/csv` が扱います。

```go
import (
    "github.com/shibukawa/bdf/converter"
    _ "github.com/shibukawa/bdf/converter/pdf"
    _ "github.com/shibukawa/bdf/converter/epub"
    _ "github.com/shibukawa/bdf/converter/docx"
    _ "github.com/shibukawa/bdf/converter/csv"
)
```

PowerPoint は `converter/pptx`、Excel は `converter/xlsx`、Visio は `converter/visio`、Parquet は `converter/parquet` を追加します。全形式を選ぶ場合は個別の空 import の代わりに `converter/all` を使います。名前は[対応形式](formats/index.ja.md)と [`converter/`](../converter/) の各ディレクトリを参照してください。

音楽変換が不要なら `converter/mml`、`converter/midi`、`converter/musicxml` を import しません。BDF への変換だけを行うサーバーには描画用の `imagebdf` や `thumbnail` の import も不要です。

## HTTP で受け取って変換する

次は、リポジトリ内の `cmd/my-bdf-server/main.go` として保存して動かせる最小例です。`POST /convert?name=report.pdf` に元ファイルのバイト列を送ると、単一ファイル形式の BDF を返します。`name` は、内容だけで判定しにくい CSV や Markdown の拡張子にも使われます。

```go
package main

import (
    "bytes"
    "io"
    "log"
    "net/http"
    "path/filepath"

    "github.com/shibukawa/bdf/converter"
    _ "github.com/shibukawa/bdf/converter/csv"
    _ "github.com/shibukawa/bdf/converter/docx"
    _ "github.com/shibukawa/bdf/converter/epub"
    _ "github.com/shibukawa/bdf/converter/pdf"
)

func main() {
    http.HandleFunc("POST /convert", func(w http.ResponseWriter, r *http.Request) {
        input, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 32<<20))
        if err != nil {
            http.Error(w, err.Error(), http.StatusBadRequest)
            return
        }
        name := filepath.Base(r.URL.Query().Get("name"))
        result, err := converter.Convert(bytes.NewReader(input), int64(len(input)), "",
            &converter.Options{FileName: name})
        if err != nil {
            http.Error(w, err.Error(), http.StatusUnprocessableEntity)
            return
        }
        var output bytes.Buffer
        if err := result.Doc.WriteSingle(&output); err != nil {
            http.Error(w, err.Error(), http.StatusInternalServerError)
            return
        }
        w.Header().Set("Content-Type", "application/octet-stream")
        _, _ = w.Write(output.Bytes())
    })
    log.Fatal(http.ListenAndServe(":8080", nil))
}
```

```sh
go run ./cmd/my-bdf-server
curl --data-binary @report.pdf 'http://localhost:8080/convert?name=report.pdf' -o report.bdf
```

ここでは説明を短くするため、入力と出力をメモリに置いています。実際のサービスではサイズ上限、認証、変換の同時実行数、キャッシュ先を用途に合わせて決めてください。

## BDF を保存して配信する

変換結果を再利用するなら、`result.Doc.WriteSingle(file)` で `.bdf` ファイルに保存し、`http.FileServer` などで GET 配信します。単一ファイルは Range リクエストに対応する配信方法を使うと、ビューアが必要な部分から読みます。CDN やオブジェクトストレージに展開するなら `result.Doc.WriteSplit(dir)` で分割形式を生成し、フロントエンドで `{ kind: "split", base: "..." }` を指定します。

サーバー上のファイルを直接変換する場合は `converter.ConvertFile(path, "", &converter.Options{})` が便利です。HTML の画像や KiCad の別シートなど、元ファイルから参照するファイルも読む形式では、`ConvertFile` が入力ディレクトリを `Options.Dir` に設定します。アップロードで複数ファイルを受け取るなら `Options.Files` に渡します。キャッシュと配信を含む実例は [preview-server](examples/preview-server.ja.md) を参照してください。
