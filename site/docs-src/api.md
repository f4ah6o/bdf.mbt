# bdf.mbt の API

bdf.mbt は MoonBit のパッケージ群で、JavaScript と wasm-gc の両方にビルドできます。上流 BDF の API と形を合わせてあるので、上流の文書のうち API の説明はそのまま読めます（Go の関数名を MoonBit の関数名に読み替えてください）。

## パッケージ

| パッケージ | 役割 |
| --- | --- |
| \`core\` | BDF ファイルの読み書き、テキスト索引、オブジェクトの復号 |
| \`render\` | 描画命令への展開、検索、表計算のシート、再生位置のカーソル |
| \`convert/*\` | 形式ごとの変換器（pdf、docx、xlsx、pptx、csv、markdown、html、font、image、drawio、dxf、jww、sxf、cgm、visio、idml、psd、tiff、emf、parquet、audio、ai、hpgl） |
| \`browser\` | ブラウザ用のビューア、変換 Worker のクライアント、描画 Worker |
| \`export/pdf\` | BDF から PDF を書き出す |
| \`export/markdown\` | BDF から Markdown を書き出す |
| \`export/search\` | BDF から検索用テキストを取り出す |
| \`bridge/wasm\` | wasm-gc の入口（文字列と JSON だけをやりとりする） |

## JavaScript（JS ターゲット）

\`\`\`js
import { bdf_create_viewer, bdf_create_native_converter } from "./browser.js";

const viewer = bdf_create_viewer(host, {
  workerUrl: "./render_worker.js",
  layout: "single",           // "single" | "spread" | "continuous"
});
await viewer.open({ kind: "buffer", buffer: bytes.buffer });
viewer.setView(id);           // ビュー（ページ・シート）の切り替え
viewer.setZoom(1.25);
viewer.scrollToPage(3);
const hit = await viewer.find("canvas");   // { index, total, more }

const converter = bdf_create_native_converter("./native_converter_worker.js");
const { bdf, summary } = await converter.convert(bytes, { name: "basic.docx" });
\`\`\`

そのほか、\`mount_bdf\`・\`mount_bdf_async\`・\`mount_bdf_interactive_async\`（文書をそのまま描く）、\`render_bdf_sheet_region_async\`（シートの一部だけを描く）、\`bdf_selection_text\`（選択中のテキスト）があります。

## wasm-gc（\`bridge/wasm\`）

wasm-gc の入口は、文字列（base64）と JSON だけをやりとりします。canvas を呼べないため、描画は JS 側のレンダラが担当します。

\`\`\`js
const { instance } = await WebAssembly.instantiate(bytes, {
  console: { log() {} },
  spectest: { print_char() {} },
});

JSON.parse(instance.exports.bdf_wasm_pdf(pdfBase64, ""));         // PDF → BDF
JSON.parse(instance.exports.bdf_wasm_export_pdf(bdfBase64, 0));  // BDF → PDF
JSON.parse(instance.exports.bdf_wasm_markdown(bdfBase64, "zip"));// BDF → Markdown
JSON.parse(instance.exports.bdf_wasm_search_text(bdfBase64));    // BDF → 検索用テキスト
\`\`\`

## ビルド

\`\`\`sh
moon build --target js --release
moon build bridge/wasm --target wasm-gc --release
node site/build.mjs
\`\`\`

## 上流との違い

- 上流の \`bdf\` コマンド（Go の CLI）はありません。変換はブラウザの Worker か、wasm-gc の入口から呼びます。
- プリント基板（Gerber・Excellon、KiCad）、楽譜（MML・MIDI・MusicXML）、EPUB の変換器は移植の対象から外しました。ソースとフィクスチャはリポジトリに残していますが、保守対象ではなく、変換 Worker の一覧にも含めていません。音声ファイルの再生と、プリント基板以外の CAD は引き続き対象です。
- サーバー側の Go パッケージ（\`converter/*\`、\`form\`、\`printd\`）は移植していません。帳票とプリントサーバーの文書はこのサイトにはありません（[上流の文書](https://shibukawa.github.io/bdf/docs/forms.ja.html)を参照）。
- wasm-gc は canvas を呼べないため、描画を伴う機能（ビューア・サムネイル）は JS ターゲットだけです。変換は PDF→BDF と、BDF→PDF・Markdown・検索テキストが wasm-gc でも動きます。PDF 以外の入力形式は JavaScript の変換 Worker が担当します（wasm-gc の入口に足すのは、必要な変換器だけを link すれば済みます）。
