# Wasm ランタイムをビルドする

ブラウザでファイルを BDF に変換するランタイムは、必要な Go の変換器だけを含む Wasm と、そのコンパイラに対応する JavaScript ランタイム・Worker で構成します。ビルドはこのリポジトリのルートで行います。Go 1.27 以上と Node.js が必要で、TinyGo 版には TinyGo も必要です。表示側の接続方法は[フロントエンドに組み込む](integrating-to-frontend.ja.md)を参照してください。

## TinyGo: 好きな形式を選ぶ

npm の `@bdfkit/convert` は TinyGo のランタイムを含む Worker を使用します。リポジトリ内のビルドスクリプトで、空 import を持つ一時的な Go エントリを作り、指定形式の Wasm を生成できます。

```sh
npm ci
node tools/build-npm-converters.mjs --formats pdf,epub,docx,csv --out ./public/my-converter.wasm
```

`--formats` はカンマ区切りで、名前は `converter/` のサブディレクトリ名です。`tsv` は `csv` の別名で、`converter/csv` 一つで CSV と TSV を扱います。例えば PowerPoint と Parquet を足すなら `--formats pdf,epub,docx,csv,pptx,parquet` とします。`html` や `markdown` を含める場合、スクリプトはブラウザ向けの goldmark 修正も一時的に適用します。

音楽変換が不要なら MML、MIDI、MusicXML を選ばずにビルドします。全形式を出発点にする場合は `--formats all --without-music` でこの 3 形式を除外できます。レンダラーは変換 Wasm には含まれず、表示が必要なときだけ `@bdfkit/viewer` を追加します。ピアノロールと再生の JS も `@bdfkit/viewer/music` の追加 import です。

```sh
node tools/build-npm-converters.mjs --formats all --without-music --out ./public/my-converter.wasm
```

2026 年 9 月 30 日、TinyGo 0.42.0 で計測した Wasm 単体のサイズは、All が無圧縮 20.09 MiB / gzip 8.81 MiB、音楽なし All が無圧縮 19.51 MiB / gzip 8.58 MiB でした。削減量は無圧縮 0.58 MiB / gzip 0.23 MiB です。カスタム Wasm は `npm run size:npm -- --custom-wasm ./public/my-converter.wasm` で同じ方法（gzip レベル 9）で計測できます。

生成した Wasm を Web アプリの公開ディレクトリに置き、`@bdfkit/convert` から読み込みます。パッケージ内の Worker も配信される必要があります。リポジトリの workspace から試すときは `npm run build && npm run build:wasm` を先に実行して Worker を生成します（`build:wasm` は標準プリセット 3 種もビルドします）。

```ts
import { createConverter } from "@bdfkit/convert";

const converter = createConverter(new URL("/my-converter.wasm", location.href));
console.log((await converter.ready).map((format) => format.name));
// viewer.openFile(converter, await file.arrayBuffer(), { name: file.name, fonts: "/fonts/" });
// 不要になったら converter.terminate()
```

標準プリセットの Wasm をまとめて生成するなら `npm run build:wasm`、一つだけなら `node tools/build-npm-converters.mjs --preset pdf-epub`（`office`、`all` も可）を使います。プリセットとビューアを含む配信サイズは [npm パッケージ](npm.ja.md#配信サイズ) にあります。

## Go: 通常の Go コンパイラで作る

Go 版は Go 自身の `wasm_exec.js` を使います。`@bdfkit/convert` の Worker は TinyGo の実行コードを含むため、Go 版にはリポジトリの `examples/common/convert-worker.ts` と同じ構成を使います。次の例は PDF、EPUB、Word、CSV/TSV を選びます。`formats.go` の空 import を増減すれば、組み合わせを変更できます。

音楽変換が必要な場合だけ `converter/mml`、`converter/midi`、`converter/musicxml` を追加します。描画 Worker はこの変換 Wasm とは別の配布物です。

```sh
mkdir -p cmd/my-bdfwasm public/lib
cp cmd/bdfwasm/main.go cmd/bdfwasm/fontfs.go cmd/my-bdfwasm/
cat > cmd/my-bdfwasm/formats.go <<'EOF'
//go:build js && wasm

package main

import (
    _ "github.com/shibukawa/bdf/converter/pdf"
    _ "github.com/shibukawa/bdf/converter/epub"
    _ "github.com/shibukawa/bdf/converter/docx"
    _ "github.com/shibukawa/bdf/converter/csv"
)
EOF
GOOS=js GOARCH=wasm go build -tags bdf_noconv -trimpath -ldflags='-s -w' \
  -o public/lib/converter.wasm ./cmd/my-bdfwasm
cp "$(go env GOROOT)/lib/wasm/wasm_exec.js" public/lib/wasm_exec.js
node --input-type=module -e 'import { bundle } from "./examples/common/build.mjs"; await bundle("./public/lib", [["examples/common/convert-worker.ts", "convert-worker"]], { format: "iife" })'
```

配信する 3 ファイルは `public/lib/converter.wasm`、`wasm_exec.js`、`convert-worker.js` です。Go のビルドと `wasm_exec.js` は同じ Go インストールから取得してください。Worker は `importScripts("./wasm_exec.js")` を使うため、2 つの JS ファイルを同じディレクトリで配信します。`examples/common/convert.ts` の `ConverterClient` でこの Worker を開き、`convert("/lib/converter.wasm", data, { name: file.name })` の返す `bdf` を `Viewer.open({ kind: "buffer", buffer: ... })` に渡せます。Go 版の実例は[ブラウザで変換するサンプル](examples/light-server.ja.md)です。

HTML または Markdown を Go 版へ入れる場合は、上の Go ビルドを次の手順でやり直してください。`patchGoldmark()` が作る `go.mod` を使い、Safari の Worker 起動時に深い正規表現がスタックを使い切る問題を避けます。サイトのビルドも同じ処理を使います。

```sh
node --input-type=module -e 'import { patchGoldmark } from "./examples/common/build.mjs"; await patchGoldmark("cmd/my-bdfmod")'
GOOS=js GOARCH=wasm go build -tags bdf_noconv -trimpath -ldflags='-s -w' \
  -modfile=cmd/my-bdfmod/go.mod -o public/lib/converter.wasm ./cmd/my-bdfwasm
```

## フォントと配信の確認

Office 系、EPUB など文字をレイアウトする形式では、変換時の `fonts` オプションにフォントディレクトリの URL を指定します。そのディレクトリにはフォントと `index.json` が必要で、生成処理は `examples/common/build.mjs` の `copyFonts()` にあります。Wasm は HTTP で配信し、Go 版では `application/wasm` の MIME タイプを設定します。CSP で Worker と WebAssembly を許可してください。ビルドした形式は TinyGo 版なら `converter.ready`、Go 版なら Worker 内の `bdfConverter.formats` で確認できます。
