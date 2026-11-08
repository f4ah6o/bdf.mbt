# ブラウザ側

2 つの Worker が仕事をします。メインスレッドはビットマップと透明なテキスト層を置くだけです。

## レンダラ Worker（`@bdfkit/render`）

`packages/render/src/worker.ts` は文書を読み込み、Part をデコードして、ページ・シートのタイル・連続レイアウトの帯を `OffscreenCanvas` 上で `ImageBitmap` に描きます。`BdfWorkerClient`（`packages/render/src/client.ts`）はそのメインスレッド側のハンドルで、メソッドごとに 1 回の `postMessage` 呼び出しです。

```ts
import { BdfWorkerClient } from "@bdfkit/render";

const client = new BdfWorkerClient(new Worker("./worker.js", { type: "module" }));
const manifest = await client.open({ kind: "single", url, range: true }); // または {kind: "split", base} / {kind: "buffer", buffer}
const bitmap = await client.page(manifest.views[0].id, 0, scale);         // scale: 1 単位あたりのデバイス画素数
const content = await client.content(manifest.views[0].id, 0);           // buildTextLayer に渡す構造化テキスト
```

`open` は 1 ファイル（HTTP の Range リクエストで読むことも）、分割形式のディレクトリ、またはメモリ上のバッファ（ブラウザ内でいま変換した文書）を受け取ります。暗号化された文書は `BdfWorkerError`（コード `"password-required"`）で拒否され、`unlock(password)` が成功するまで Worker が施錠したまま保持します。`page`・`continuous`・`sheet` はビットマップを、`text`・`continuousText`・`content`・`sheetContent` はテキスト run を返し、`@bdfkit/render` の `buildTextLayer` がそれを選択可能で読み上げ可能な DOM 層に組みます。`search`・`locate` は Worker 内で全文検索を行い、ヒットの矩形を返します。一方 `play` は View の音楽を Standard MIDI File と cue にして返し、`MusicPlayer` が使います。`audio` は音声ファイルのカードの録音を `Blob` と cue にして返し、`AudioPlayer` が `<audio>` 要素で鳴らします。SVG の画像は Worker ではデコードできないため、Worker がメインスレッドに描画を頼みます（`RasterizeRequest`・`RasterizeResponse`）。これは `BdfWorkerClient` が `domSvgRasterizer` 経由で自動的に処理します。

これより上、ビューア自身の仕事は、ページがスクロールで視界に入るたびにビットマップとテキスト層を置き、ズームと検索の UI を動かすことです。ページめくり、セル選択、楽譜の演奏をしたいなら、それらのやり取りも自分で組み立てます。[`examples/miniviewer`](https://github.com/shibukawa/bdf/tree/main/examples/miniviewer) は最初の部分だけをする最小限のビューア（約 800 行）です。[`examples/viewer`](https://github.com/shibukawa/bdf/tree/main/examples/viewer)（デモサイトのフル機能ビューア）は残りも足したものです。

検索の UI には、ブラウザ自身の検索ショートカットも含まれます。ブラウザが探せるのはページにあるテキストだけで、ビューアがテキスト層を置くのは表示範囲の近くのページだけです。そのため Cmd+F / Ctrl+F では離れたページの文字が見つかりません。そこでビューアは、フォーカスが自分の中にある間このショートカットを受け、Worker の検索で View 全体を探します。部品は `@bdfkit/render` にあります。`findKey` がキーを判定し、`FindHits` が検索のヒットを持ってその矩形をページが表示されるときに 1 ページずつ求め、`FindBar` は自前の検索欄を持たないビューアがページの上に出す小さな検索バーです。検索欄の中でもう一度ショートカットを押すと、ブラウザ自身の検索に渡ります。

## 変換 Worker（`cmd/bdfwasm`）

ブラウザ内変換のために、`cmd/bdfwasm` は同じ Go の変換パッケージを WebAssembly でビルドします。Go の `wasm_exec.js` を読み込む必要があるため、クラシック（非モジュール）な Worker です。

```
bdfConverter.convert(data: Uint8Array, options?: {format?, password?, fonts?, name?})
  → Promise<{bdf, format, summary, warnings, protected}>
bdfConverter.open(data, options?) → Promise<{bdf, format, pages, warnings, stream?}>
  // pages > 0: bdf はアウトライン（全ページの大きさだけでレイヤーはまだ空）、stream が残りを変換する
```

`-tags pdfonly|officeonly|webonly|imageonly` でより小さなモジュールをビルドできます — PDF と Illustrator用、Office 系・CAD・KiCad・音楽・フォント用、HTML・Markdown・EPUB 用、ブラウザ自身がデコードできる画像と音声ファイル（カバー、タグ、そのまま格納する音声）用 — ページは必要なものだけを取得します。`-tags previewonly` は変換器を持たないモジュールで、`thumbnail()`・`text()`・`pdf()` を公開します。`-tags formonly` は帳票のテンプレート（タグを書いた Office の文書、入力欄のある PDF、pdfme のテンプレート）を穴埋めし、PDF（指定すればタグ付きや PDF/A）に書き出すモジュールで、`fields()`・`fill()`・`pdf()` を公開します（[フォームのページ](https://shibukawa.github.io/bdf/form/)）。サーバーが使うのと同じ Go のコード（`thumbnail`、`Document.SearchText`）で、[サムネイル](https://shibukawa.github.io/bdf/thumbnail/)と[検索テキスト](https://shibukawa.github.io/bdf/text/)のページに使われます。`examples/common/convert-worker.ts` はクライアント側のつなぎで、必要になったときにこれらのモジュールを読み込み、`convert`・`open`・`page`・`finish`・`thumbnail`・`text` を `postMessage` 越しに公開します。どのモジュールが要るかは、`examples/common/convert.ts` の `sniff()` がドロップされたファイルの中身と拡張子から判定します。

PDF はページ単位で変換します。`open()` はまずページの大きさだけ入った空の文書を返し、`page(i)` が変換の進みに合わせて各ページを埋めていきます（表示中のページを優先）。`finish()` は完成した文書を返し、ストリーミング中のものと差し替えます。この形にした理由は[design.md §2](../design.md#2-go-と-wasm-について)を、呼び出しの全体像は [API 一覧](../api.md#ブラウザ内変換cmdbdfwasm)を参照してください。

## ブラウザでのフォント

Office 系・CAD・HTML・Markdown・EPUB の変換器は、ページを変換する前にテキストを計測してレイアウトする必要があります。ブラウザで動くときは、フォントディレクトリの `index.json`（名前、サイズ、テーブルディレクトリ・`name`・`OS/2`・`post`・`cmap` のバイト範囲）を読みます。これは [`examples/common/build.mjs`](https://github.com/shibukawa/bdf/blob/main/examples/common/build.mjs) が作ります。その範囲を先読みし、フォールバック先を探すときは `cmap` で文字の有無を調べます。必要な文字を持つフォントだけ、ファイル全体を取得します。

## サイトのビルド

[`site/build.mjs`](https://github.com/shibukawa/bdf/blob/main/site/build.mjs) が GitHub Pages で公開しているすべて（トップページ、フル機能のビューア、サムネイル・検索テキストのページ、描画済みのドキュメント、各ページが取得する共有の `lib/`・`fonts/`・`samples/`）をビルドします。`npm run site` で手元に `site/dist` としてビルドし、`npm run site:serve` は配信もします。コマンドの全体像は[ビルドとテスト](development.ja.md)を参照してください。Go のビルドが要らないスタンドアロンのビューア（`npm run demo`）もあります。
