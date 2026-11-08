// _build/pages の中のリンクと画像が、すべて実在するかを調べる。
//
//   node site/check-links.mjs
//
// サイトは /bdf.mbt/ の下で配るので、"/" で始まるリンクがサイトの外を指していないかも見る。
import { readdir, readFile, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { PAGES } from "./nav.mjs";

const root = resolve(import.meta.dirname, "../_build/pages");
const problems = [];

async function* walk(dir) {
  for (const entry of await readdir(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) yield* walk(full);
    else if (entry.name.endsWith(".html")) yield full;
  }
}

const files = [];
for await (const file of walk(root)) files.push(file);

for (const file of files) {
  const html = await readFile(file, "utf8");
  const page = relative(root, file);
  for (const match of html.matchAll(/\b(?:href|src)="([^"]*)"/g)) {
    const href = match[1];
    if (href === "" || href.startsWith("#") || /^(?:[a-z]+:)?\/\//i.test(href) || href.startsWith("data:")) continue;
    if (href.startsWith("mailto:")) continue;
    let path = href.split("#")[0].split("?")[0];
    if (path === "") continue;
    if (path.startsWith("/")) {
      // サイトの外（GitHub Pages のルート）を指している
      problems.push(page + ": サイトの外を指すリンク " + href);
      continue;
    }
    const target = resolve(dirname(file), decodeURIComponent(path));
    if (!target.startsWith(root)) {
      problems.push(page + ": サイトの外に出るリンク " + href);
      continue;
    }
    if (!existsSync(target)) {
      problems.push(page + ": 見つからない " + href);
      continue;
    }
    const info = await stat(target);
    if (info.isDirectory() && !existsSync(join(target, "index.html"))) {
      problems.push(page + ": index.html が無い " + href);
    }
  }
}

// 各ドキュメントのページが実際にできているか
for (const page of PAGES) {
  if (!existsSync(join(root, "docs", page.id + ".html"))) problems.push("docs/" + page.id + ".html が無い");
}

const unique = [...new Set(problems)];
if (unique.length) {
  for (const problem of unique) console.log("NG " + problem);
  console.log(unique.length + " problems in " + files.length + " pages");
  process.exit(1);
}
console.log("links ok: " + files.length + " pages");
