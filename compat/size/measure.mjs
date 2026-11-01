// Measure the size of the wasm-gc converter probes against the upstream Wasm
// presets. See compat/size/README.md.
//
//   node compat/size/measure.mjs
//   node compat/size/measure.mjs --json _build/wasm-size/sizes.json
//   node compat/size/measure.mjs --fast          # brotli quality 9 instead of 11
//   node compat/size/measure.mjs --js            # also measure the JS build
//
// The probes are linked by `moon build --target wasm-gc --release`; their
// `main` references every converter entry point so the linker keeps it. The
// upstream preset sizes come from the packages installed by `npm ci` and,
// for PDF + EPUB, from the published npm tarball.
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { copyFile, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { gzipSync, brotliCompressSync, constants as zlibConstants } from "node:zlib";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../..");
const upstreamVersion = "0.2.1";
const upstreamCache = join(root, "_build/wasm-size/upstream");

const args = new Set(process.argv.slice(2));
const quality = args.has("--fast") ? 9 : 11;
const withJs = args.has("--js");
const jsonAt = process.argv.indexOf("--json");
const jsonPath = jsonAt >= 0 ? resolve(root, process.argv[jsonAt + 1] ?? "") : "";

const probes = [
  { label: "PDF + EPUB", dir: "pdf_epub", upstream: "pdf-epub" },
  { label: "Office", dir: "office", upstream: "office" },
  { label: "All", dir: "all", upstream: "all" },
];

function run(command, commandArgs, options = {}) {
  const result = spawnSync(command, commandArgs, { cwd: root, encoding: "utf8", ...options });
  if (result.error) throw result.error;
  return result;
}

async function measure(buffer) {
  return {
    raw: buffer.length,
    gzip: gzipSync(buffer, { level: 9 }).length,
    brotli: brotliCompressSync(buffer, {
      params: { [zlibConstants.BROTLI_PARAM_QUALITY]: quality },
    }).length,
  };
}

function customSections(buffer) {
  const sections = [];
  let offset = 8;
  while (offset < buffer.length) {
    const id = buffer[offset++];
    let size = 0;
    let shift = 0;
    let byte;
    do {
      byte = buffer[offset++];
      size |= (byte & 0x7f) << shift;
      shift += 7;
    } while (byte & 0x80);
    const start = offset;
    if (id === 0) {
      const nameLength = buffer[offset];
      const name = buffer.subarray(offset + 1, offset + 1 + nameLength).toString("latin1");
      sections.push({
        name,
        size,
        body: buffer.subarray(start + 1 + nameLength, start + size),
      });
    }
    offset = start + size;
  }
  return sections;
}

function describe(buffer) {
  const sections = customSections(buffer);
  const name = sections.find((section) => section.name === "name");
  const producers = sections.find((section) => section.name === "producers");
  const tinygo =
    producers?.body.toString("latin1").match(/TinyGo.{1,8}?(\d+\.\d+\.\d+)/)?.[1] ?? "";
  return { nameSection: name?.size ?? 0, tinygo };
}

async function readVersion(packageName) {
  const path = join(root, "node_modules", packageName, "package.json");
  if (!existsSync(path)) return "";
  return JSON.parse(await readFile(path, "utf8")).version;
}

async function fetchPdfEpub() {
  const target = join(upstreamCache, "convert-pdf-epub.wasm");
  if (existsSync(target)) return target;
  const tarball = join(upstreamCache, `convert-pdf-epub-${upstreamVersion}.tgz`);
  await mkdir(upstreamCache, { recursive: true });
  if (!existsSync(tarball)) {
    const url = `https://registry.npmjs.org/@bdfkit/convert-pdf-epub/-/convert-pdf-epub-${upstreamVersion}.tgz`;
    process.stderr.write(`fetching ${url}\n`);
    const response = await fetch(url);
    if (!response.ok) throw new Error(`cannot fetch ${url}: ${response.status}`);
    await writeFile(tarball, Buffer.from(await response.arrayBuffer()));
  }
  const extract = join(upstreamCache, `extract-${process.pid}`);
  await rm(extract, { recursive: true, force: true });
  await mkdir(extract, { recursive: true });
  const result = spawnSync("tar", ["-xzf", tarball, "-C", extract, "package/dist/converter.wasm"], {
    encoding: "utf8",
  });
  if (result.status !== 0) throw new Error(`cannot extract ${tarball}: ${result.stderr}`);
  await copyFile(join(extract, "package/dist/converter.wasm"), target);
  await rm(extract, { recursive: true, force: true });
  return target;
}

async function upstreamPath(name) {
  if (name === "all" || name === "office") {
    return join(root, "node_modules", `@bdfkit/convert-${name}`, "dist", "converter.wasm");
  }
  return fetchPdfEpub();
}

function probePath(dir) {
  return join(root, "_build/wasm-gc/release/build/compat/size", dir, `${dir}.wasm`);
}

const size = (bytes) =>
  bytes >= 1024 * 1024
    ? `${(bytes / (1024 * 1024)).toFixed(2)} MiB`
    : `${(bytes / 1024).toFixed(1)} KiB`;
const bytesText = (bytes) => `${bytes.toLocaleString("en-US")} B (${size(bytes)})`;
const ratio = (bdf, upstream) => `${(bdf / upstream).toFixed(2)}x`;

function table(headers, rows) {
  const lines = [`| ${headers.join(" | ")} |`, `| ${headers.map(() => "---").join(" | ")} |`];
  for (const row of rows) lines.push(`| ${row.join(" | ")} |`);
  return lines.join("\n");
}

const moon = run("moon", ["version"]).stdout.trim().split("\n")[0] ?? "";
for (const name of ["convert-all", "convert-office"]) {
  const version = await readVersion(`@bdfkit/${name}`);
  if (version && version !== upstreamVersion) {
    process.stderr.write(`warning: @bdfkit/${name} is ${version}, expected ${upstreamVersion}\n`);
  }
}

process.stderr.write("building wasm-gc probes\n");
const build = run("moon", ["build", "--target", "wasm-gc", "--release"], { stdio: "inherit" });
if (build.status !== 0) throw new Error("moon build --target wasm-gc --release failed");

const rows = [];
for (const probe of probes) {
  const bdfPath = probePath(probe.dir);
  if (!existsSync(bdfPath)) throw new Error(`missing ${bdfPath}`);
  const bdfBytes = await readFile(bdfPath);
  process.stderr.write(`${probe.label}: measuring bdf.mbt\n`);
  const bdf = await measure(bdfBytes);
  const bdfInfo = describe(bdfBytes);
  const upstreamFile = await upstreamPath(probe.upstream);
  if (!existsSync(upstreamFile)) throw new Error(`missing upstream wasm ${upstreamFile}; run npm ci`);
  const upstreamBytes = await readFile(upstreamFile);
  process.stderr.write(`${probe.label}: measuring upstream\n`);
  const upstream = await measure(upstreamBytes);
  const upstreamInfo = describe(upstreamBytes);
  rows.push({
    preset: probe.label,
    bdf,
    upstream,
    bdfFile: bdfPath.slice(root.length + 1),
    upstreamFile: upstreamFile.slice(root.length + 1),
    bdfNameSection: bdfInfo.nameSection,
    upstreamNameSection: upstreamInfo.nameSection,
    upstreamTinygo: upstreamInfo.tinygo,
  });
}

const baselinePath = probePath("baseline");
if (!existsSync(baselinePath)) throw new Error(`missing ${baselinePath}`);
const baseline = await measure(await readFile(baselinePath));

const js = [];
if (withJs) {
  for (const [name, path] of [
    ["native converter worker", "_build/js/release/build/native_converter_worker/native_converter_worker.js"],
    ["browser", "_build/js/release/build/browser/browser.js"],
  ]) {
    const full = join(root, path);
    if (!existsSync(full)) {
      process.stderr.write(`note: ${path} is missing; run moon build --target js --release\n`);
      continue;
    }
    process.stderr.write(`${name}: measuring\n`);
    js.push({ name, path, ...(await measure(await readFile(full))) });
  }
}

const tinygo = rows.find((row) => row.upstreamTinygo)?.upstreamTinygo ?? "";

console.log("# Wasm size comparison\n");
console.log(`Measured with ${moon}${tinygo ? ` and upstream TinyGo ${tinygo}` : ""}.`);
console.log(`Compression: gzip level 9, brotli quality ${quality}.`);
console.log();
console.log(
  table(
    [
      "Preset",
      "bdf.mbt raw",
      "bdf.mbt gzip",
      "bdf.mbt brotli",
      "upstream raw",
      "upstream gzip",
      "upstream brotli",
      "raw ratio",
      "gzip ratio",
    ],
    rows.map((row) => [
      row.preset,
      bytesText(row.bdf.raw),
      bytesText(row.bdf.gzip),
      bytesText(row.bdf.brotli),
      bytesText(row.upstream.raw),
      bytesText(row.upstream.gzip),
      bytesText(row.upstream.brotli),
      ratio(row.bdf.raw, row.upstream.raw),
      ratio(row.bdf.gzip, row.upstream.gzip),
    ]),
  ),
);
console.log();
console.log(
  table(
    ["Preset", "name section (bdf.mbt)", "name section (upstream)"],
    rows.map((row) => [
      row.preset,
      row.bdfNameSection ? `${row.bdfNameSection.toLocaleString("en-US")} B` : "none",
      row.upstreamNameSection
        ? `${row.upstreamNameSection.toLocaleString("en-US")} B`
        : "none",
    ]),
  ),
);
console.log();
console.log(
  `Baseline (empty wasm-gc executable): ${bytesText(baseline.raw)} raw, ` +
    `${bytesText(baseline.gzip)} gzip, ${bytesText(baseline.brotli)} brotli.`,
);
console.log();
if (js.length) {
  console.log("Current JavaScript build (reference; not wasm):");
  console.log();
  console.log(
    table(
      ["File", "raw", "gzip", "brotli"],
      js.map((entry) => [
        `\`${entry.path}\``,
        bytesText(entry.raw),
        bytesText(entry.gzip),
        bytesText(entry.brotli),
      ]),
    ),
  );
  console.log();
}
console.log("Upstream files:");
for (const row of rows) {
  console.log(
    `- ${row.preset}: \`${row.upstreamFile}\` (TinyGo ${row.upstreamTinygo || "?"})`,
  );
}
console.log(`- bdf.mbt probes: \`${rows[0].bdfFile}\` etc.`);

if (jsonPath) {
  await mkdir(dirname(jsonPath), { recursive: true });
  await writeFile(
    jsonPath,
    JSON.stringify(
      { generatedAt: new Date().toISOString(), moon, tinygo, quality, baseline, rows, js },
      null,
      2,
    ),
  );
  process.stderr.write(`wrote ${jsonPath}\n`);
}
