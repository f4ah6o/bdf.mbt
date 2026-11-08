// ページの骨組み（head・ナビゲーション・サイドバー）と、
// 上流の日本語 Markdown を HTML にする処理。
import { marked } from "marked";
import { PAGES, SECTIONS, REPO, SITE, UPSTREAM_PAGES, relative } from "./nav.mjs";

export { PAGES, SECTIONS };

export function esc(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

/** GitHub と同じ見出しの id（小文字にし、記号を落とし、空白を - に）。 */
export function slugify(text) {
  return text
    .trim()
    .toLowerCase()
    .replace(/<[^>]*>/g, "")
    .replace(/[^\p{L}\p{N}\p{M}\s_-]/gu, "")
    .replace(/\s+/g, "-");
}

const NAV = [
  { href: "viewer/", label: "ビューア", key: "viewer" },
  { href: "thumbnail/", label: "サムネイル", key: "thumbnail" },
  { href: "text/", label: "検索テキスト", key: "text" },
  { href: "docs/index.html", label: "ドキュメント", key: "docs" },
  { href: REPO, label: "GitHub", key: "repo" },
];

/** head。base はページからサイトのルートまでの接頭辞（"" か "../"）。 */
export function head({ base = "", title, description, body = "", styles = [] } = {}) {
  return `<!doctype html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light dark">
<link rel="stylesheet" href="${base}site.css">
${styles.map((href) => `<link rel="stylesheet" href="${base}${href}">`).join("\n")}
<meta name="description" content="${esc(description)}">
<title>${esc(title)}</title>
${body}</head>`;
}

export function header({ base = "", current = "" } = {}) {
  const items = NAV.map(
    (item) =>
      `<li><a href="${item.href.startsWith("http") ? item.href : base + item.href}"${item.key === current ? ' aria-current="page"' : ""}>${esc(item.label)}</a></li>`,
  ).join("\n");
  return `<a class="skip" href="#content">本文へ移動</a>
<header class="bar">
<nav aria-label="サイト">
<a class="home" href="${base}index.html">BDF.mbt</a>
<ul>
${items}
</ul>
</nav>
</header>`;
}

export function footer({ base = "" } = {}) {
  return `<footer class="wrap foot">bdf.mbt（MoonBit 実装）· <a href="${base}docs/licenses.html">フォントとライセンス</a> · <a href="${REPO}">GitHub</a> · 上流 <a href="${"https://shibukawa.github.io/bdf/"}" lang="ja">BDF</a> の日本語ページを元にしています</footer>`;
}

/** Markdown 中のリンクを、このサイトのページに合わせて書き換える。
 *  サイトの中のリンクは "/" で始まる形（サイトのルートから）で返す。 */
function rewriteLink(href, fromId) {
  if (!href) return href;
  // 上流サイトへの絶対リンクは、このサイトの同じページへ
  const upstreamSite = /^https:\/\/shibukawa\.github\.io\/bdf\/?(.*)$/.exec(href);
  if (upstreamSite) {
    const rest = upstreamSite[1];
    if (rest === "" || rest.startsWith("index.")) return "/index.html";
    if (rest.startsWith("viewer/")) return "/viewer/" + rest.slice("viewer/".length);
    if (rest.startsWith("thumbnail/")) return "/thumbnail/";
    if (rest.startsWith("text/")) return "/text/";
    if (rest.startsWith("samples/")) return "/samples/" + rest.slice("samples/".length);
    if (rest.startsWith("docs/")) {
      const id = rest.slice("docs/".length).replace(/\.ja\.html$/, "").replace(/\.html$/, "");
      if (PAGES.some((p) => p.id === id)) return "/docs/" + id + ".html";
      const moved = UPSTREAM_PAGES[id];
      if (moved) return "https://shibukawa.github.io/bdf/" + moved;
      return href;
    }
    return href;
  }
  if (/^(?:[a-z]+:|#|\/)/i.test(href)) return href;
  const [path, hash = ""] = href.split("#");
  const suffix = hash ? "#" + hash : "";
  // docs 内の相対リンク
  const dir = fromId.includes("/") ? fromId.slice(0, fromId.lastIndexOf("/") + 1) : "";
  const resolved = normalizePath(dir + path);
  const id = resolved.replace(/^docs\//, "").replace(/\.ja?\.md$/, "").replace(/\.md$/, "");
  const page = PAGES.find((p) => p.id === id);
  if (page) return "/docs/" + page.id + ".html" + suffix;
  const upstream = UPSTREAM_PAGES[id];
  if (upstream) return "https://shibukawa.github.io/bdf/" + upstream + suffix;
  // リポジトリの中のファイルやフォルダは、上流の GitHub を指す
  if (!resolved.startsWith("docs/")) {
    const kind = /\.(?:go|json|md|txt|yml|yaml)$/.test(resolved) ? "blob" : "tree";
    return "https://github.com/shibukawa/bdf/" + kind + "/main/" + resolved + suffix;
  }
  return href;
}

function normalizePath(path) {
  const parts = [];
  for (const part of path.split("/")) {
    if (part === "." || part === "") continue;
    if (part === "..") parts.pop();
    else parts.push(part);
  }
  return parts.join("/");
}

/** Markdown を HTML にし、見出しの id と目次を集める。 */
export function renderMarkdown(markdown, { fromId = "index" } = {}) {
  const toc = [];
  const renderer = {
    heading({ tokens, depth, text }) {
      const raw = this.parser.parseInline(tokens);
      const id = slugify(text);
      if (depth === 2 || depth === 3) toc.push({ depth, id, text: raw });
      return `<h${depth} id="${id}">${raw}</h${depth}>\n`;
    },
    link({ href, title, tokens }) {
      const base = "../".repeat(fromId.split("/").length);
      const rewritten = rewriteLink(href, fromId);
      const target = rewritten.startsWith("/") ? base + rewritten.slice(1) : rewritten;
      const external = /^(?:[a-z]+:)?\/\//i.test(target) && !target.startsWith("https://f4ah6o.github.io");
      const text = this.parser.parseInline(tokens);
      return `<a href="${esc(target)}"${external ? ' rel="noopener"' : ""}${title ? ` title="${esc(title)}"` : ""}>${text}</a>`;
    },
    table(token) {
      const header = token.header.map((cell) => `<th>${this.parser.parseInline(cell.tokens)}</th>`).join("");
      const body = token.rows
        .map((row) => `<tr>${row.map((cell) => `<td>${this.parser.parseInline(cell.tokens)}</td>`).join("")}</tr>`)
        .join("");
      return `<div class="table-wrap"><table><thead><tr>${header}</tr></thead><tbody>${body}</tbody></table></div>\n`;
    },
  };
  marked.use({ renderer, gfm: true });
  const html = marked.parse(markdown, { async: false });
  const title = /<h1[^>]*>([\s\S]*?)<\/h1>/.exec(html)?.[1]?.replace(/<[^>]*>/g, "") ?? "";
  return { html, toc, title };
}

/** ドキュメントのページ（サイドバー・本文・目次）。 */
export function docPage({ id, label, html, toc, source = "upstream" }) {
  const base = relative(id);
  const nav = SECTIONS.map(
    (section) => `<li><span>${esc(section.title)}</span><ul>${section.pages
      .map(
        (p) =>
          `<li><a href="${base}${"docs/" + p.id}.html"${p.id === id ? ' aria-current="page"' : ""}>${esc(p.label)}</a></li>`,
      )
      .join("")}</ul></li>`,
  ).join("");
  const outline = toc.length
    ? `<nav class="toc" aria-label="このページの内容"><h2>このページの内容</h2><ul>${toc
        .map((item) => `<li class="l${item.depth}"><a href="#${item.id}">${item.text}</a></li>`)
        .join("")}</ul></nav>`
    : "";
  return `${head({ base, title: label + " – BDF.mbt", description: label + "（bdf.mbt のドキュメント）" })}
<body class="doc">
${header({ base, current: "docs" })}
<div class="layout${toc.length ? "" : " no-toc"}">
<nav class="sidebar" aria-label="ドキュメント"><details open><summary>ドキュメント</summary><ul>${nav}</ul></details></nav>
<main id="content" tabindex="-1">
${html}
<p class="source">${source === "upstream"
    ? `出典: <a href="https://github.com/shibukawa/bdf/blob/main/docs/${id}.ja.md" rel="noopener">shibukawa/bdf docs/${id}.ja.md</a>（MIT）。この文書は上流 BDF（Go 実装）のもので、bdf.mbt ではコマンド名やパッケージ構成が異なります。違いは<a href="${base}docs/api.html">bdf.mbt の API</a>にまとめています。`
    : "このページは bdf.mbt のために書いたものです。"}</p>
</main>
${outline}
</div>
${footer({ base })}
</body>
</html>`;
}
