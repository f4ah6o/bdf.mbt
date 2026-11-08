# はじめかた

BDF の動きを一番早く見るには[デモサイト](https://shibukawa.github.io/bdf/viewer/)です。ファイルをページにドロップすると、アップロードせずにブラウザの中で変換して描画します。ここからは、bdf を手元でビルドして動かします。

## CLI

BDF には Go 1.27 以上が必要です。

```sh
git clone https://github.com/shibukawa/bdf
cd bdf
go run ./cmd/bdf generate report.pptx report.bdf
```

`generate` は入力の形式をファイルの中身から判別します（Markdown はバイト列だけでは判別できないので `.md` 拡張子から決めます）。出力先を `/` で終わるディレクトリにすると、1 ファイルの代わりに[分割形式](spec.md#34-分割形式split)を書き出します。ファイルサーバーや CDN がそのまま配信できる形です。

```sh
go run ./cmd/bdf generate report.pptx out/          # 分割形式: manifest.json と Part ごとのファイル
go run ./cmd/bdf generate -pages 1-3 book.pdf out.bdf   # 最初の 3 ページだけ
go run ./cmd/bdf generate -thumbnail thumb.png -text text.json report.docx out.bdf  # サムネイルと検索用テキストも
```

`go run ./cmd/bdf generate -h` で全フラグと、入力形式ごとの `-param` オプションの一覧が出ます。

## 変換結果を見る

```sh
go run ./cmd/bdf ls out.bdf          # Part の一覧: フォント・画像・描画命令とそのサイズ
go run ./cmd/bdf manifest out.bdf    # manifest を JSON で: View、ページ、メタデータ
```

## ブラウザで開く

リポジトリを clone してから:

```sh
npm ci
npm run demo
# http://127.0.0.1:8765/examples/viewer/.out/?src=/out.bdf
```

`examples/viewer` はデモサイトと同じビューアです（検索、テキスト選択、本のようにめくれるページ、演奏できる楽譜）。`?src=` でリポジトリ内の任意の `.bdf` を開けます。`npm run site:serve` は、ブラウザ内変換つきのフルのデモサイトを手元で動かします。[GitHub Pages で公開しているもの](https://shibukawa.github.io/bdf/)と同じ体験を、手元のチェックアウトから再現できます。

## Go のコードから

```go
import (
	"github.com/shibukawa/bdf/converter"
	_ "github.com/shibukawa/bdf/converter/pptx" // すべての形式なら converter/all
)

res, err := converter.ConvertFile("report.pptx", "", &converter.Options{}) // "" で形式を判別
if err != nil {
	// 入力にパスワードが要る・違うなら converter.ErrPasswordRequired / ErrWrongPassword
}
// res.Doc は *bdf.Document。res.Doc.WriteSingle(w) か WriteSplit(dir) で書き出す
```

各変換器のパッケージは import されたときに自分の形式を登録するので、プログラムはリンクした形式だけを扱えます。全体像は [API 一覧](api.md)（Go、CLI、ブラウザの wasm モジュール、2 つの TypeScript パッケージ）を、これを使った小さなサーバーの例は[構成のサンプル](examples/index.ja.md)を参照してください。

## 次に読むもの

- **[なぜ BDF か](why.ja.md)** — 対応形式の一覧と、変換後も使えるもの: ページめくり、検索、選択、読み上げ
- **[対応形式](formats/index.ja.md)** — すべての入力形式とそのレイアウト
- **[アーキテクチャ](architecture/index.ja.md)** — 変換と描画のつながり、ビルドとテストの方法
