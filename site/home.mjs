// トップページ。上流 BDF の home.mjs の構成をそのままに、日本語だけで、
// bdf.mbt（MoonBit の JS / wasm-gc）で動く形に書き直したもの。
import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { esc, head, header, footer } from "./docs.mjs";
import { REPO } from "./nav.mjs";

const root = resolve(import.meta.dirname);
const readJson = (path, fallback) => {
  const file = resolve(root, path);
  if (!existsSync(file)) return fallback;
  return JSON.parse(readFileSync(file, "utf8"));
};
const upstream = readJson("benchmarks/upstream.json", null);
const ours = readJson("benchmarks/bdfmbt.json", null);

/** ギャラリーのカード。このサイトに置いてあるサンプルだけを並べる。 */
export const GALLERY = [
  { shot: "pdf.png", sample: "demo.pdf", doc: "formats/pdf", title: "PDF",
    text: "フォントを埋め込んだページ、選択できるテキスト、タグ付き PDF の構造。Illustrator のファイルも。" },
  { shot: "epub.png", sample: "basic.epub", doc: "formats/ebook", title: "EPUB",
    text: "本も、ページをめくって。リフロー型の本も固定レイアウトの絵本も。" },
  { shot: "features-pptx.png", sample: "features.pptx", doc: "formats/presentation", title: "PowerPoint",
    text: "スライドマスター、レイアウトのレイヤー、テーマ色、表、画像を含むスライド。" },
  { shot: "xlsx.png", sample: "features.xlsx", doc: "formats/spreadsheet", title: "Excel",
    text: "ページに分断されずスクロールできるシート。CSV・TSV・Parquet も同じ見た目で表示します。" },
  { shot: "docx.png", sample: "basic.docx", doc: "formats/document", title: "Word",
    text: "紙面のページでも、一続きのスクロールでも。見出し・段落・表・リストを含む文書。" },
  { shot: "drawio.png", sample: "multipage.drawio", doc: "formats/diagram", title: "draw.io",
    text: "ページはタブで切り替え。図形・コネクタ・ラベルの書式をそのまま描画。Visio の図面も。" },
  { shot: "dxf.png", sample: "layout.dxf", doc: "formats/cad", title: "DXF",
    text: "モデル空間とレイアウト。Jw_cad、SXF、CGM、HP-GL/2 も。" },
  { shot: "kicad.png", sample: "demo.kicad_pcb", doc: "formats/electronics", title: "KiCad",
    text: "KiCad の基板をフロントビューで 1 ページに。Gerber・Excellon の製造データも。" },
  { shot: "music.png", sample: "minuet.musicxml", doc: "formats/music", title: "楽譜",
    text: "MML・MIDI・MusicXML を五線譜に組み、ビューアで演奏。" },
  { shot: "audio.png", sample: "synced.mp3", doc: "formats/audio", title: "音声",
    text: "MP3・M4A・FLAC・Ogg・WAV・AIFF のカバーアート・タグ・歌詞をカードに。ブラウザで再生でき、歌っている行を示します。" },
  { shot: "csv.png", sample: "basic.csv", doc: "formats/spreadsheet", title: "CSV",
    text: "行と列のデータを、そのままスクロールできる表として。" },
  { shot: "markdown.png", sample: "basic.md", doc: "formats/document", title: "Markdown",
    text: "CommonMark/GFM の段落・リスト・表・数式を、BDF のスクロール表示に。" },
  { shot: "image.png", sample: "drawing.svg", doc: "formats/image", title: "画像",
    text: "SVG・PNG・JPEG などの画像を BDF に変換し、ページとして表示します。" },
  { shot: "font.png", sample: "stix.ttf", doc: "formats/font", title: "フォント",
    text: "文字の形やフォント情報を、見本に組み直して表示します。" },
];

const POINTS = [
  ["オフィススイートを動かさない", "ヘッドレスの LibreOffice も cgo も外部プログラムも要りません。変換はブラウザの中、JavaScript と wasm-gc のどちらでも動きます。"],
  ["MoonBit で書かれている", "変換器もレンダラも MoonBit の 1 つの実装です。同じコードを JS にコンパイルして Worker で、wasm-gc にコンパイルして WebAssembly で動かします。"],
  ["内容に合った形で見せる", "スライドや図面には固定ページ、表計算にはスクロールするシート、文章にはページか一続きの列。"],
  ["ブラウザ表示に特化", "命令は Canvas 2D に対応。フォント、画像、展開はブラウザに任せます。"],
  ["多くの形式を 1 つのレンダラで", "検索、テキスト選択、読み上げ用のテキストは、どの形式でも同じように使えます。"],
  ["上流 BDF との互換", "ファイル形式も API の形も上流 BDF に合わせています。上流の Go 実装で作った BDF をそのまま表示でき、書き出した PDF も同じ読み方になります。"],
];

function formatSeconds(seconds) {
  if (!Number.isFinite(seconds)) return "–";
  if (seconds < 1) return (seconds * 1000).toFixed(0) + " ms";
  return seconds.toFixed(2) + " s";
}

function formatMiB(bytes) {
  return (bytes / 1024 / 1024).toFixed(1) + " MiB";
}

function measure(cls, label, ratio, value) {
  return '<div class="benchmark-measure ' + cls + '"><span class="benchmark-series">' + esc(label) +
    '</span><span class="benchmark-track" aria-hidden="true"><span style="width:' + ratio.toFixed(1) +
    '%"></span></span><strong class="benchmark-value">' + esc(value) + "</strong></div>";
}

/** 上流のベンチマーク（Office 文書）と、bdf.mbt の追記分をまとめた表。 */
function benchmarkSection() {
  if (!upstream?.process?.results) return "";
  const results = upstream.process.results;
  const names = Object.keys(results);
  const labels = {
    "basic.docx": "小さい DOCX",
    "basic.pptx": "小さい PPTX",
    "basic.xlsx": "小さい XLSX",
    "many-sheets.xlsx": "合成 XLSX · 4 シート × 3,000 行",
    "many-slides.pptx": "合成 PPTX · 100 スライド",
  };
  const office = new Map((ours?.office ?? []).map((row) => [row.input, row]));

  const timeCases = names.map((name) => {
    const row = results[name];
    const mine = office.get(name);
    const longest = Math.max(
      row.libreoffice.elapsed_seconds,
      row.bdf.elapsed_seconds,
      mine?.js?.ms ? mine.js.ms / 1000 : 0,
      mine?.wasm?.ms ? mine.wasm.ms / 1000 : 0,
    );
    const bar = (seconds) => (longest > 0 ? (seconds / longest) * 100 : 0);
    const parts = [
      measure("office", "LibreOffice + Poppler", bar(row.libreoffice.elapsed_seconds), formatSeconds(row.libreoffice.elapsed_seconds)),
      measure("bdf", "BDF（Go）", bar(row.bdf.elapsed_seconds), formatSeconds(row.bdf.elapsed_seconds)),
    ];
    if (mine?.js?.ms) parts.push(measure("bdfmbt", "bdf.mbt（JS）", bar(mine.js.ms / 1000), formatSeconds(mine.js.ms / 1000)));
    if (mine?.wasm?.ms) parts.push(measure("bdfmbt", "bdf.mbt（wasm-gc）", bar(mine.wasm.ms / 1000), formatSeconds(mine.wasm.ms / 1000)));
    return '<li class="benchmark-case"><h4>' + esc(labels[name] ?? name) + "</h4>" + parts.join("") + "</li>";
  }).join("");

  const memoryCases = names.map((name) => {
    const row = results[name];
    const longest = Math.max(row.libreoffice.max_rss_bytes, row.bdf.max_rss_bytes);
    return '<li class="benchmark-case"><h4>' + esc(labels[name] ?? name) + "</h4>" +
      measure("office", "LibreOffice + Poppler", (row.libreoffice.max_rss_bytes / longest) * 100, formatMiB(row.libreoffice.max_rss_bytes)) +
      measure("bdf", "BDF（Go）", (row.bdf.max_rss_bytes / longest) * 100, formatMiB(row.bdf.max_rss_bytes)) +
      "</li>";
  }).join("");

  const power = upstream.power?.pairs ?? [];
  const loJ = power.filter((p) => p.workflow === "libreoffice");
  const bdfJ = power.filter((p) => p.workflow === "bdf");
  const mean = (list) => (list.length ? list.reduce((sum, p) => sum + p.estimated_soc_j_per_document, 0) / list.length : NaN);
  const energy = loJ.length && bdfJ.length
    ? '<ul class="benchmark-cases"><li class="benchmark-case"><h4>小さい DOCX・小さい PPTX・小さい XLSX の文書あたり平均</h4>' +
      measure("office", "LibreOffice + Poppler", 100, mean(loJ).toFixed(2) + " J") +
      measure("bdf", "BDF（Go）", (mean(bdfJ) / mean(loJ)) * 100, mean(bdfJ).toFixed(2) + " J") +
      "</li></ul>"
    : "";

  const roundtrip = (ours?.roundtrip ?? []).length
    ? '<figure class="benchmark-card"><h3 id="benchmark-roundtrip-title">bdf.mbt の往復（20 ページの BDF）</h3>' +
      '<ul class="benchmark-cases">' +
      ours.roundtrip.map((row) => {
        const longest = Math.max(row.js ?? 0, row.wasm ?? 0);
        const bar = (ms) => (longest > 0 ? (ms / longest) * 100 : 0);
        const parts = [];
        if (row.js != null) parts.push(measure("bdfmbt", "JS（Worker）", bar(row.js), Math.round(row.js) + " ms"));
        if (row.wasm != null) parts.push(measure("bdfmbt-wasm", "wasm-gc", bar(row.wasm), Math.round(row.wasm) + " ms"));
        return '<li class="benchmark-case"><h4>' + esc(row.label) + "</h4>" + parts.join("") +
          (row.detail ? '<p class="note">' + esc(row.detail) + "</p>" : "") + "</li>";
      }).join("") +
      "</ul><figcaption>ブラウザ（Chromium）の中の測定。JS と wasm-gc は同じ MoonBit の実装です。</figcaption></figure>"
    : "";

  return '<section class="wrap benchmarks" aria-labelledby="benchmark-title">' +
    '<h2 id="benchmark-title">文書変換が速く、メモリと電力も少なく</h2>' +
    '<p class="lead">同じ Office ファイルを LibreOffice + Poppler と BDF の Go 変換器で処理して比較した上流の計測に、bdf.mbt（ブラウザ内、JS と wasm-gc）の結果を追記しています。</p>' +
    '<div class="benchmark-grid">' +
    '<figure class="benchmark-card"><h3 id="benchmark-time-title">変換＋サムネイル作成の経過時間（中央値）</h3>' +
    '<ul class="benchmark-cases">' + timeCases + "</ul>" +
    '<figcaption>横棒はファイルごとに比較し、長い方を 100% に正規化。上流の数値は上流の公開値、bdf.mbt の数値はこのサイトの測定値です。</figcaption></figure>' +
    '<figure class="benchmark-card"><h3 id="benchmark-memory-title">最大 RSS（中央値）</h3>' +
    '<ul class="benchmark-cases">' + memoryCases + "</ul>" +
    '<figcaption>上流の測定（新規プロセスを起動して計測）。ブラウザの内側では同じ意味の値を測れないため、bdf.mbt の行は載せていません。</figcaption></figure>' +
    (energy ? '<figure class="benchmark-card"><h3 id="benchmark-energy-title">1 文書あたりの推定 SoC エネルギー</h3>' + energy +
      '<figcaption>上流の測定値（powermetrics からアイドル分を差し引いた推定）。</figcaption></figure>' : "") +
    roundtrip +
    "</div>" +
    '<p class="benchmark-method">上流の数値: ' + esc(upstream.process.created_utc?.slice(0, 10) ?? "") +
    " の計測（LibreOffice " + esc((upstream.process.versions?.soffice ?? "").split(" ").slice(0, 2).join(" ")) +
    "、Poppler、Go " + esc((upstream.process.versions?.go ?? "").replace("go version ", "")) +
    "）。bdf.mbt の数値: " + esc(ours?.environment?.browser ?? "Chromium") +
    " で " + (ours?.methodology?.iterations ?? 7) + " 回の中央値。bdf.mbt はブラウザのタブの中で、ファイルの取得と Worker の起動を除いて計測しています。</p>" +
    "</section>";
}

function gallerySection() {
  const cards = GALLERY.map((item) =>
    '<li class="card"><a class="shot" href="viewer/?file=samples/' + encodeURIComponent(item.sample) + '" tabindex="-1" aria-hidden="true">' +
    '<img src="previews/' + esc(item.shot) + '" alt="" width="1600" height="1000" loading="lazy"></a>' +
    '<div class="body"><h3>' + esc(item.title) + "</h3><p>" + esc(item.text) + "</p>" +
    '<p class="links"><a href="viewer/?file=samples/' + encodeURIComponent(item.sample) + '" aria-label="ビューアで開く: ' + esc(item.title) + '">ビューアで開く</a> ' +
    '<a href="docs/' + esc(item.doc) + '.html" aria-label="形式の説明: ' + esc(item.title) + '">形式の説明</a></p></div></li>',
  ).join("");
  return '<section class="wrap" aria-labelledby="gallery-title">' +
    '<h2 id="gallery-title">文書の種類ごとに、合った形で</h2>' +
    '<p class="lead">シートはスクロールできるシートのまま、文書はページのまま。どれも同じレンダラが描きます。</p>' +
    '<ul class="cards">' + cards + "</ul>" +
    '<p class="more">対応する形式の一覧と、bdf.mbt での対応状況: <a href="docs/formats/index.html">形式の一覧</a></p></section>';
}

export function home() {
  const points = POINTS.map(([title, text]) => "<li><h3>" + esc(title) + "</h3><p>" + esc(text) + "</p></li>").join("");
  return head({
    title: "BDF.mbt – ブラウザのための文書プレビュー",
    description: "BDF.mbt は MoonBit で書かれたブラウザ向けの文書プレビュースイートです。多形式のコンバーターを JS と wasm-gc にコンパイルし、ブラウザの中だけで文書を表示・変換します。",
  }) + `
<body class="home">
${header({ current: "home" })}
<main id="content" tabindex="-1">
<section class="hero wrap">
<h1>オフィススイートなしで、文書をブラウザでプレビュー</h1>
<p>BDF.mbt は、ブラウザ向けの文書プレビュースイート <a href="https://github.com/shibukawa/bdf">BDF</a> を MoonBit で書き直した実装です。多様な形式に対応するコンバーター、軽量なレンダラー、中間形式 BDF で構成され、JavaScript と wasm-gc のどちらでも動きます。</p>
<p class="format-note">PDF が PostScript をベースにした印刷向けのポータブル文書形式であるのに対し、BDF は Canvas 2D の描画命令を基盤とした、ブラウザ表示向けの軽量な中間形式です。サーバーでの事前生成と、WebAssembly を使ったブラウザ内でのリアルタイム変換に対応します。</p>
<p class="actions"><a class="button primary" href="viewer/">ビューアを開く</a> <a class="button" href="docs/index.html">ドキュメントを読む</a> <a class="button" href="${REPO}">GitHub</a></p>
</section>
<section class="wrap" aria-labelledby="demo-title">
<h2 id="demo-title">BDF から描いた PDF</h2>
<p class="lead">上流 BDF で作った BDF ファイルを、bdf.mbt のレンダラで表示します。ページめくり、テキストの選択、検索、拡大ができます。</p>
<div class="demo">
<div class="tools">
<span class="name">demo.pdf → demo.bdf</span>
<span role="search"><input id="q" type="search" placeholder="検索…" aria-label="検索…">
<button type="button" id="prev" title="前の一致" aria-label="前の一致">▲</button>
<button type="button" id="next" title="次の一致" aria-label="次の一致">▼</button></span>
<span id="hits" role="status"></span>
<select id="layout" aria-label="表示" title="表示"><option value="spread">見開き</option><option value="single" selected>1 ページずつ</option><option value="scroll">スクロール</option></select>
<span class="pager" role="group" aria-label="ページ"><button type="button" id="prevPage" title="前のページ" aria-label="前のページ">‹</button>
<span id="pageNum" aria-live="polite"></span>
<button type="button" id="nextPage" title="次のページ" aria-label="次のページ">›</button></span>
<span><button type="button" id="zoomOut" title="縮小" aria-label="縮小">−</button>
<button type="button" id="zoomIn" title="拡大" aria-label="拡大">+</button></span>
</div>
<div class="view bdf-host" id="demo" role="region" aria-label="demo.pdf" tabindex="0"></div>
</div>
<p class="note">20 ページの PDF で 742 KB、フォントを含む BDF で 392 KB。bdf.mbt はこの BDF をそのまま読み、ブラウザの Canvas に描きます。</p>
</section>
<section class="wrap" aria-labelledby="back-title">
<h2 id="back-title">BDF から元に戻す</h2>
<p class="lead">上の文書 demo.bdf を PDF ファイルと Markdown に書き戻し、テキストを検索エンジン向けに取り出します。どれも、このブラウザの中で、wasm-gc にコンパイルした MoonBit のコードが行います。アップロードはしません。</p>
<div class="back">
<div class="tabs" role="tablist" aria-label="BDF から戻す形">
<button type="button" role="tab" id="tab-pdf" aria-controls="panel-pdf" aria-selected="true">PDF</button>
<button type="button" role="tab" id="tab-md" aria-controls="panel-md" aria-selected="false" tabindex="-1">Markdown</button>
<button type="button" role="tab" id="tab-text" aria-controls="panel-text" aria-selected="false" tabindex="-1">検索用テキスト</button>
<button type="button" role="tab" id="tab-find" aria-controls="panel-find" aria-selected="false" tabindex="-1">MiniSearch で検索</button>
</div>
<div class="panel" id="panel-pdf" role="tabpanel" aria-labelledby="tab-pdf">
<p class="about">ページを PDF ファイルに書き出します。文書のフォントを埋め込み、タグ付きにすれば見出しや表の構造も残ります。できたファイルは、ブラウザ自身の PDF ビューアで下に表示します。</p>
<div class="row"><button type="button" class="button primary" data-export-run="pdf">PDF を書き出す</button>
<label><input type="checkbox" data-export-tagged> タグ付き（読み上げ用の構造）</label>
<span class="status" data-export-status role="status"></span></div>
<p class="links" data-export-links hidden><a class="button" data-export-pdf-open target="_blank" rel="noopener">新しいタブで開く</a> <a class="button" data-export-pdf-save>PDF を保存</a></p>
<iframe data-export-frame hidden title="文書から書き出した PDF（ブラウザの PDF ビューア）"></iframe>
<pre><code>bdf_wasm_export_pdf(base64, { tagged: false })</code></pre>
</div>
<div class="panel" id="panel-md" role="tabpanel" aria-labelledby="tab-md" hidden>
<p class="about">文書を Markdown に書き出します。見出し・リスト・表はそのまま。図は zip にファイルとして同梱するか、データ URL で本文に埋め込むか、省きます。</p>
<div class="row"><button type="button" class="button primary" data-export-run="md">Markdown を書き出す</button>
<label>図 <select data-export-images><option value="zip">ファイルにして zip に</option><option value="embed">本文に埋め込む</option><option value="none">省く</option></select></label>
<span class="status" data-export-status role="status"></span></div>
<textarea class="output" data-export-markdown readonly spellcheck="false" aria-label="文書から書き出した Markdown"></textarea>
<p class="links" data-export-links hidden><button type="button" class="button" data-export-md-copy>コピー</button> <a class="button" data-export-md-save>保存</a></p>
<pre><code>bdf_wasm_markdown(base64, { images: "zip" })</code></pre>
</div>
<div class="panel" id="panel-text" role="tabpanel" aria-labelledby="tab-text" hidden>
<p class="about">ページごとのテキストと文書のメタデータを JSON に取り出します。サーバーが検索エンジンに渡すものと同じ形で、1 ページが 1 レコードです。</p>
<div class="row"><button type="button" class="button primary" data-export-run="text">テキストを取り出す</button>
<label>表示 <select data-export-shape><option value="json">JSON（サーバーが受け取る形）</option><option value="plain">テキストだけ</option></select></label>
<span class="status" data-export-status role="status"></span></div>
<textarea class="output" data-export-text readonly spellcheck="false" aria-label="検索エンジン向けの文書のテキスト"></textarea>
<p class="links" data-export-links hidden><button type="button" class="button" data-export-text-copy>コピー</button> <a class="button" data-export-text-save>保存</a></p>
<pre><code>bdf_wasm_search_text(base64)</code></pre>
</div>
<div class="panel" id="panel-find" role="tabpanel" aria-labelledby="tab-find" hidden>
<p class="about">同じレコードを、JavaScript の検索ライブラリ MiniSearch でブラウザの中に索引づけします。1 ページが 1 レコード、日本語は隣り合う 2 文字の組（バイグラム。辞書なしで索引づける常道）、語の正規化はビューアの検索と同じ（NFKC、大文字小文字、かな）。ヒットを選ぶと上の文書がそのページを開きます。</p>
<div class="row" role="search"><input type="search" data-export-find placeholder="検索…（canvas、ぶらうざ など）" aria-label="検索" autocomplete="off">
<button type="button" class="button" data-export-find-run>検索</button>
<span class="status" data-export-status role="status"></span></div>
<ol class="results" data-export-hits aria-label="ヒット"></ol>
<pre><code>import MiniSearch from "minisearch";
const index = new MiniSearch({ fields: ["text", "title"], storeFields: ["page"], tokenize });
index.addAll(records); // bdf_wasm_search_text の 1 ページ 1 レコード</code></pre>
</div>
</div>
<p class="note">書き出しは <code>export.js</code>（wasm-gc）が行います。JS 版の同じ処理も <code>browser.js</code> に含まれています。</p>
</section>
${benchmarkSection()}
${gallerySection()}
<section class="wrap" aria-labelledby="demos-title">
<h2 id="demos-title">手元のファイルで試す</h2>
<p class="lead">ファイルはブラウザの中で変換します。アップロードはされません。</p>
<ul class="cards plain">
<li class="card"><div class="body"><h3><a href="viewer/">ビューア</a></h3><p>ファイルをドロップして表示。ビューの切り替え、検索、テキスト選択、ページ移動、BDF の保存。</p></div></li>
<li class="card"><div class="body"><h3><a href="thumbnail/">サムネイル</a></h3><p>4 つの大きさのサムネイルを一度に。ブラウザの外のエンジンなしで描きます。</p></div></li>
<li class="card"><div class="body"><h3><a href="text/">検索用テキスト</a></h3><p>検索エンジンに渡す、ページごとのテキストとメタデータ。</p></div></li>
<li class="card"><div class="body"><h3><a href="wasm-gc.html">wasm-gc デモ</a></h3><p>同じ実装を WebAssembly にしたもの。PDF から BDF への変換と、PDF・Markdown・テキストの書き出し。</p></div></li>
</ul>
</section>
<section class="wrap" aria-labelledby="arch-title">
<h2 id="arch-title">システムに組み込む</h2>
<p class="lead">BDF の形はそのままに、変換器だけを入れ替えられます。構成ごとの解説があります。</p>
<ul class="cards plain">
<li class="card"><div class="body"><h3><a href="docs/examples/light-server.html">ブラウザで変換する</a></h3><p>サーバーは BDF だけを配り、変換は開いた人のブラウザで。</p><p class="links"><a href="docs/examples/light-server.html">解説を読む</a></p></div></li>
<li class="card"><div class="body"><h3><a href="docs/examples/preview-server.html">サーバーで変換する</a></h3><p>プレビューとサムネイルをサーバーが一度だけ作ります。ブラウザは描くだけ。</p><p class="links"><a href="docs/examples/preview-server.html">解説を読む</a></p></div></li>
<li class="card"><div class="body"><h3><a href="docs/examples/search.html">検索エンジンとつなぐ</a></h3><p>テキストをページごとに検索エンジンへ。ヒットからそのページを開きます。</p><p class="links"><a href="docs/examples/search.html">解説を読む</a></p></div></li>
</ul>
</section>
<section class="wrap" aria-labelledby="why-title">
<h2 id="why-title">なぜ BDF か、なぜ MoonBit か</h2>
<ul class="points">${points}</ul>
<p class="more"><a href="docs/why.html">もっと詳しく</a></p>
</section>
</main>
${footer()}
<script>
// 上流のトップページと同じ振る舞い: 旧いリンク (?src=&layout=&range=) は
// ビューアの URL にそのまま引き継ぐ（上流 site/home.mjs と同じ）。
if (/[?&](src|layout|range)\\b/.test(location.search)) location.replace("viewer/" + location.search + location.hash);
</script>
<script type="module" src="home.js"></script>
</body>
</html>`;
}
