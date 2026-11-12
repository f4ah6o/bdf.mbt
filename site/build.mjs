// このサイトのビルド。site/ のページと、moon が作った bdf.mbt の束を
// _build/pages にまとめる（GitHub Pages のサブパス /bdf.mbt/ で配る）。
import { cp, mkdir, readFile, readdir, rm, writeFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { home } from "./home.mjs";
import { docPage, renderMarkdown } from "./docs.mjs";
import { PAGES } from "./nav.mjs";

const site = resolve(import.meta.dirname);
const root = resolve(site, "..");
const out = join(root, "_build/pages");

const log = (message) => console.log(message);

await rm(out, { recursive: true, force: true });
await mkdir(out, { recursive: true });

/** ディレクトリをまるごと写す（無ければ飛ばす）。 */
async function copyTree(from, to) {
  if (!existsSync(from)) {
    log("skip (missing): " + from);
    return;
  }
  await mkdir(dirname(to), { recursive: true });
  await cp(from, to, { recursive: true });
}

/** ビルド済みの MoonBit の束。 */
const bundles = [
  ["_build/js/release/build/browser/browser.js", "browser.js"],
  ["_build/js/release/build/render_worker/render_worker.js", "render_worker.js"],
  ["_build/js/release/build/native_converter_worker/native_converter_worker.js", "native_converter_worker.js"],
  ["_build/js/release/build/form_page/form_page.js", "form_api.js"],
  ["_build/js/release/build/bridge/wasm/wasm.js", "export.js"],
  ["_build/wasm-gc/release/build/bridge/wasm/wasm.wasm", "wasm-gc.wasm"],
];
for (const [from, to] of bundles) {
  const source = join(root, from);
  if (!existsSync(source)) {
    log("missing bundle: " + from);
    continue;
  }
  await mkdir(dirname(join(out, to)), { recursive: true });
  await cp(source, join(out, to));
}

/** プラグインの変換 Worker（Mermaid・Excalidraw）が読む、公式プラグイン API の実装。 */
await copyTree(join(root, "plugin/src"), join(out, "plugin"));

/** フォントやサンプル、プレビュー画像。 */
await copyTree(join(site, "assets"), out);
await copyTree(join(site, "samples"), join(out, "samples"));
await copyTree(join(site, "previews"), join(out, "previews"));
await copyTree(join(site, "licenses"), join(out, "licenses"));
await copyTree(join(site, "benchmarks"), join(out, "benchmarks"));
await copyTree(join(root, "node_modules/minisearch/dist/es"), join(out, "minisearch"));
await copyTree(join(site, "docs-src/images"), join(out, "docs/images"));

/** フォームのページのサンプル（テンプレートと、その形のデータ）。 */
await copyTree(join(site, "form/samples"), join(out, "forms"));
await copyTree(join(site, "form/fonts"), join(out, "forms/fonts"));
await cp(join(site, "form/index.json"), join(out, "forms/index.json"));

/** サンプルの別名（トップページは demo.pdf / demo.bdf を開く）。 */
const aliases = [
  ["upstream-demo.bdf", "demo.bdf"],
  ["upstream-demo.pdf", "demo.pdf"],
];
for (const [from, to] of aliases) {
  const source = join(out, "samples", from);
  if (existsSync(source)) await cp(source, join(out, "samples", to));
}

/** ページ。 */
await writeFile(join(out, "index.html"), home());
for (const name of await readdir(join(site, "pages"))) {
  await copyTree(join(site, "pages", name), join(out, name));
}

/** 上流の文書のうち、Go 固有の手順を含むページの冒頭に置く断り書き。 */
const NOTES = {
  "formats/index": "bdf.mbt は MHTML（<code>.mht</code>、<code>.mhtml</code>）に未対応です。基板、楽譜、EPUB の形式は移植対象から除外しています。",
  "formats/document": "bdf.mbt は MHTML（<code>.mht</code>、<code>.mhtml</code>）に未対応です。",
  why: "bdf.mbt は MHTML（<code>.mht</code>、<code>.mhtml</code>）に未対応です。基板、楽譜、EPUB の形式は移植対象から除外しています。",
  "getting-started": "bdf.mbt では、ビルドは <code>moon build</code>、変換はブラウザの変換 Worker か wasm-gc の入口から呼びます。<code>bdf</code> コマンドはありません。",
  "integrating-to-frontend": "bdf.mbt では <code>@bdfkit/*</code> の代わりに、このリポジトリの <code>browser</code> パッケージ（<code>browser.js</code> と <code>render_worker.js</code>）を使います。API の形は上流と同じです。",
  "integrate-to-server": "bdf.mbt に Go のサーバー実装はありません。サーバーで変換するときは上流 BDF の Go 実装を使ってください。このサイトの変換はブラウザと wasm-gc で行います。",
  rendering: "bdf.mbt は描画をブラウザの Canvas に任せます。Go の <code>image.Image</code> や Ebitengine に当たるものはありません。",
  "build-wasm-runtime": "bdf.mbt の wasm-gc は <code>moon build bridge/wasm --target wasm-gc --release</code> で作ります。TinyGo や Go は使いません。",
  "architecture/cli": "bdf.mbt には <code>bdf</code> コマンドがありません。ビルドと実行の入口は「bdf.mbt の API」にまとめています。",
  "architecture/layout": "bdf.mbt のフォルダ構成は MoonBit のパッケージ構成です（<code>core</code>、<code>render</code>、<code>convert/*</code>、<code>browser</code>、<code>export/*</code>、<code>bridge/wasm</code>）。MHTML（<code>.mht</code>、<code>.mhtml</code>）は未対応です。基板、楽譜、EPUB の形式は移植対象から除外しています。",
  "architecture/development": "bdf.mbt のテストは <code>moon test</code> と <code>node site/test.mjs</code> です。",
  "examples/index": "この構成のサンプルは Go のサーバーで作られています。bdf.mbt では、ブラウザ内の変換（<code>viewer/</code>）で置き換えられます。",
  "examples/light-server": "この構成のサンプルは Go のサーバーで作られています。bdf.mbt では、ブラウザ内の変換（<code>viewer/</code>）で置き換えられます。",
  "examples/preview-server": "この構成のサンプルは Go のサーバーで作られています。bdf.mbt では、ブラウザ内の変換（<code>viewer/</code>）で置き換えられます。",
  "examples/search": "この構成のサンプルは Go のサーバーで作られています。テキストの取り出しは bdf.mbt の wasm-gc（<code>bdf_wasm_search_text</code>）でも行えます。",
  "examples/secure-reader": "この構成のサンプルは Go のサーバーで作られています。bdf.mbt でもパスワード付き BDF の復号は <code>browser</code> パッケージで行えます。",
};

/** bdf.mbt のために書いたページ（上流の文書を写したものではない）。 */
const IDS_OWN = new Set(["api", "licenses"]);

/** ドキュメント。site/docs-src/<id>.md を docs/<id>.html にする。 */
let docs = 0;
for (const page of PAGES) {
  const source = join(site, "docs-src", page.id + ".md");
  if (!existsSync(source)) {
    log("missing doc: " + page.id);
    continue;
  }
  const markdown = await readFile(source, "utf8");
  const rendered = renderMarkdown(markdown, { fromId: page.id });
  const note = NOTES[page.id];
  const html = note
    ? rendered.html.replace(/<\/h1>/, "</h1>\n<div class=\"note-box\"><p>" + note + "</p></div>")
    : rendered.html;
  const toc = rendered.toc;
  const target = join(out, "docs", page.id + ".html");
  await mkdir(dirname(target), { recursive: true });
  const own = IDS_OWN.has(page.id);
  await writeFile(target, docPage({ id: page.id, label: page.label, html, toc, source: own ? "own" : "upstream" }));
  docs += 1;
}
log("docs: " + docs + " pages");

/** サイトの地図。 */
const urls = ["index.html", "viewer/index.html", "thumbnail/index.html", "text/index.html", "form/index.html", "wasm-gc.html",
  ...PAGES.map((page) => "docs/" + page.id + ".html")];
await writeFile(join(out, "sitemap.txt"), urls.join("\n") + "\n");

log("built " + out);
