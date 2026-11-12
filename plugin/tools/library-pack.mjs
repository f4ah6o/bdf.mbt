// Build and pack the staged main library package (`bdf.mbt`, the decided
// unscoped npm name): the prebuilt browser/viewer bundle, the render, native
// converter and plugin converter Workers, the form page API, the raw
// DocuWorks export, and the format plugin API with its DocuWorks adapter.
//
//   node plugin/tools/library-pack.mjs [--dry-run] [--staging-name NAME]
//                                       [--staging-version V] [--out DIR]
//
// Default staging keeps `"private": true`. Explicit --release-version
// YYYY.M.PATCH --source-sha FULL_SHA creates a publishable artifact only;
// this tool never invokes npm publish. The bundles are built
// beforehand by the repository's standard moon build (see the README); the
// tool refuses to stage if a bundle is missing instead of shipping holes.
//
// After packing, the tar member list must equal the allowlist exactly; source
// maps, tests, fixtures, corpora and local paths are refused.

import { releaseMetadata } from "./release-metadata.mjs";

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

import { assertWritableOutput, refuseSymlinkedSource, resolveInsideRoot, validateStagingName, validateStagingVersion } from "./staging-path.mjs";

const root = resolve(import.meta.dirname, "../..");
const plugin = resolve(root, "plugin");
const scratch = resolve(root, "_scratch/library-pack");

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const flag = (name, fallback) => {
  const at = args.indexOf(name);
  return at !== -1 && args[at + 1] ? args[at + 1] : fallback;
};
validateStagingName((flag("--staging-name", "bdf.mbt")));
const stagingName = flag("--staging-name", "bdf.mbt");
const release = releaseMetadata(args, stagingName);
const stagingVersion = release?.version ?? validateStagingVersion(flag("--staging-version", "0.0.0-staging"));
const outDir = resolveInsideRoot(flag("--out", "_scratch/library-pack"), root, "--out");
const tarballName = `${stagingName}-${stagingVersion}.tgz`;
// Validate fixed staging as well as a custom output before touching either.
resolveInsideRoot(scratch, root, "staging scratch");

// The MoonBit bundles, already built by moon build --target js --release.
const BUNDLES = [
  ["_build/js/release/build/browser/browser.js", "dist/browser.js"],
  ["_build/js/release/build/render_worker/render_worker.js", "dist/workers/render_worker.js"],
  ["_build/js/release/build/native_converter_worker/native_converter_worker.js",
    "dist/workers/native_converter_worker.js"],
  ["_build/js/release/build/form_page/form_page.js", "dist/form/form_page.js"],
  ["_build/js/release/build/export/pdf_js/pdf_js.js", "dist/pdf/pdf_js.js"],
  ["_build/js/release/build/plugin/moonbit/docuworks_js/docuworks_js.js",
    "dist/xdw/docuworks_js.js"],
];
const BUILD_COMMAND = "MOON_CORE_OVERRIDE=$PWD/_scratch/moon-core moon build browser render_worker "
  + "native_converter_worker form_page export/pdf_js plugin/moonbit/docuworks_js --target js --release";

// The compiled bundles contain two kinds of third-party material, and both
// must ship inside the artifact:
// 1. ports with their own notice obligations — CCITT from golang.org/x/image,
//    shaping/decoding from golang.org/x/text and the WHATWG Encoding
//    Standard, Adobe's predefined CMaps (embedded in the PDF text layer),
//    Cephes maths;
// 2. compiled MoonBit dependencies (verified against the bundle link
//    response files, not guessed): gaato/deflate, gaato/brotli (with the
//    RFC 7932 static dictionary), gaato/codec, gaato/codec_bytes,
//    gaato/zstd (Apache NOTICE included), Milky2018/xml,
//    LL728/moon_encoding, moonbit-community/{normalization,ucd,yaml},
//    oilleelssq-wq/moonmarkdown, allenli178/moon-qrcode (form bundle),
//    moonbitlang/async, moonbitlang/x and the MoonBit core standard
//    library — Apache-2.0, one text plus the per-package NOTICE mapping.
const THIRD_PARTY_LICENSES = [
  "Shibukawa-bdf.txt",
  "EZPZFile-xdw.txt",
  "Go-x-image.txt",
  "Go-x-text.txt",
  "WHATWG-Encoding.txt",
  "Adobe-CMap.txt",
  "Cephes.txt",
  "Apache-2.0.txt",
  "Mooncake-gaato-zstd-NOTICE.txt",
  "Brotli-dictionary-MIT.txt",
  "Mooncake-yaml-MIT.txt",
  "Mooncake-moonmarkdown-MIT.txt",
  "Mooncake-moonmarkdown-THIRD-PARTY-NOTICES.txt",
  "Mooncake-moon-encoding-WHATWG.txt",
  "MoonBit-core-NOTICE.txt",
];

const ALLOWED_TAR_ENTRIES = new Set(["package.json", "README.md", "LICENSE", "NOTICE.md",
  "docs/format-plugin-api.md", "docs/diagram-plugins.md",
  "types/index.d.ts", "types/worker.d.ts", "types/diagram-bdf.d.ts", "types/pdf.d.ts",
  "types/docuworks.d.ts", "types/excalidraw.d.ts", "types/mermaid.d.ts"]);
for (const license of THIRD_PARTY_LICENSES) {
  ALLOWED_TAR_ENTRIES.add(`licenses/${license}`);
}
for (const [, staged] of BUNDLES) {
  ALLOWED_TAR_ENTRIES.add(staged);
  ALLOWED_TAR_ENTRIES.add(staged.replace(/\.js$/, ".d.ts"));
  ALLOWED_TAR_ENTRIES.add(staged.replace(/[^/]+$/, "moonbit.d.ts"));
}
// the prebuilt plugin converter Worker
ALLOWED_TAR_ENTRIES.add("dist/workers/plugin-converter.mjs");
// the typed public PDF export wrapper, staged next to its compiled bridge
ALLOWED_TAR_ENTRIES.add("dist/pdf/index.js");
// the downstream-worker emitter (browser-resolvable worker output)
ALLOWED_TAR_ENTRIES.add("dist/tools/emit-downstream-worker.mjs");
// the plugin API sources ship inside the library package
for (const entry of readdirSync(resolve(plugin, "src"), { withFileTypes: true })) {
  if (entry.isFile() && entry.name.endsWith(".js")) {
    ALLOWED_TAR_ENTRIES.add(`dist/plugin/${entry.name}`);
  } else if (entry.isDirectory()) {
    for (const nested of readdirSync(resolve(plugin, "src", entry.name), { withFileTypes: true })) {
      if (nested.isFile() && nested.name.endsWith(".js")) {
        ALLOWED_TAR_ENTRIES.add(`dist/plugin/${entry.name}/${nested.name}`);
      }
    }
  }
}

function stage() {
  // A fresh throwaway directory inside the tool-owned scratch root: the
  // staging name never names a filesystem location anymore, so no input can
  // steer a deletion anywhere. The exit hook is registered at allocation
  // time, so even a staging failure cleans the directory up.
  mkdirSync(scratch, { recursive: true });
  const stageDir = mkdtempSync(join(scratch, "stage-"));
  process.on("exit", () => rmSync(stageDir, { recursive: true, force: true }));
  // staged sources must be real files: a symlink must refuse the pack, not
  // produce a silently different artifact
  for (const source of BUNDLES.map(([from]) => resolve(root, from))) {
    refuseSymlinkedSource(source, "a MoonBit bundle");
    refuseSymlinkedSource(source.replace(/\.js$/, ".d.ts"), "a bundle declaration");
    refuseSymlinkedSource(resolve(source, "..", "moonbit.d.ts"), "the moonbit declaration");
  }
  for (const source of [
    resolve(plugin, "library/plugin-converter.mjs"),
    resolve(plugin, "library/pdf.mjs"),
    resolve(plugin, "tools/emit-downstream-worker.mjs"),
    resolve(plugin, "src"),
    resolve(plugin, "types"),
    resolve(plugin, "library/README.md"),
    resolve(plugin, "library/NOTICE.md"),
    resolve(root, "docs/format-plugin-api.md"),
    resolve(root, "docs/diagram-plugins.md"),
    resolve(root, "LICENSE"),
  ]) {
    refuseSymlinkedSource(source, "a staging source");
  }
  for (const license of THIRD_PARTY_LICENSES) {
    refuseSymlinkedSource(resolve(root, "licenses", license), "a third-party license text");
  }

  // 1) the MoonBit bundles, with adjacent type declarations
  for (const [from, staged] of BUNDLES) {
    const source = resolve(root, from);
    if (!existsSync(source)) {
      throw new Error(`missing bundle ${from}; build it first:\n  ${BUILD_COMMAND}`);
    }
    const destination = resolve(stageDir, staged);
    mkdirSync(resolve(destination, ".."), { recursive: true });
    copyBundle(source, destination);
    const types = resolve(source.replace(/\.js$/, ".d.ts"));
    if (!existsSync(types)) {
      throw new Error(`missing declaration ${types}`);
    }
    cpSync(types, resolve(stageDir, staged.replace(/\.js$/, ".d.ts")));
    const moonbitTypes = resolve(source, "..", "moonbit.d.ts");
    if (!existsSync(moonbitTypes)) {
      throw new Error(`missing moonbit.d.ts next to ${source}`);
    }
    cpSync(moonbitTypes, resolve(stageDir, staged.replace(/[^/]+$/, "moonbit.d.ts")));
  }

  // 2) the prebuilt plugin converter Worker, the downstream emitter, and
  //    the typed PDF export wrapper next to its compiled bridge
  cpSync(resolve(plugin, "library/plugin-converter.mjs"), resolve(stageDir, "dist/workers/plugin-converter.mjs"));
  mkdirSync(resolve(stageDir, "dist/pdf"), { recursive: true });
  cpSync(resolve(plugin, "library/pdf.mjs"), resolve(stageDir, "dist/pdf/index.js"));
  mkdirSync(resolve(stageDir, "dist/tools"), { recursive: true });
  cpSync(
    resolve(plugin, "tools/emit-downstream-worker.mjs"),
    resolve(stageDir, "dist/tools/emit-downstream-worker.mjs"),
  );

  // 3) the third-party license texts the shipped derivations require
  mkdirSync(resolve(stageDir, "licenses"), { recursive: true });
  for (const license of THIRD_PARTY_LICENSES) {
    const text = resolve(root, "licenses", license);
    if (!existsSync(text)) {
      throw new Error(`missing third-party license text: ${text}`);
    }
    cpSync(text, resolve(stageDir, "licenses", license));
  }

  // 4) the plugin API sources and per-module type declarations
  mkdirSync(resolve(stageDir, "types"), { recursive: true });
  cpSync(resolve(plugin, "src"), resolve(stageDir, "dist/plugin"), {
    recursive: true,
    filter: source => statSync(source).isDirectory() || source.endsWith(".js"),
  });
  for (const dts of ["index.d.ts", "worker.d.ts", "diagram-bdf.d.ts", "pdf.d.ts", "docuworks.d.ts",
    "excalidraw.d.ts", "mermaid.d.ts"]) {
    const source = resolve(plugin, "types", dts);
    if (!existsSync(source)) {
      throw new Error(`missing plugin type module: ${source}`);
    }
    cpSync(source, resolve(stageDir, "types", dts));
  }

  // 5) the manifest, README and licenses
  const manifest = {
    name: stagingName,
    version: stagingVersion,
    private: true,
    description: "bdf.mbt prebuilt bundles: browser/viewer, converter and render Workers, forms, PDF export, DocuWorks and the file format plugin API (staging publication is blocked)",
    type: "module",
    license: "MIT",
    types: "./dist/browser.d.ts",
    exports: {
      ".": { types: "./dist/browser.d.ts", default: "./dist/browser.js" },
      "./forms": { types: "./dist/form/form_page.d.ts", default: "./dist/form/form_page.js" },
      "./pdf": { types: "./types/pdf.d.ts", default: "./dist/pdf/index.js" },
      "./xdw": { types: "./dist/xdw/docuworks_js.d.ts", default: "./dist/xdw/docuworks_js.js" },
      "./plugin": { types: "./types/index.d.ts", default: "./dist/plugin/index.js" },
      "./plugin/worker": { types: "./types/worker.d.ts", default: "./dist/plugin/worker.js" },
      "./plugin/diagram-bdf": {
        types: "./types/diagram-bdf.d.ts",
        default: "./dist/plugin/diagram-bdf.js",
      },
      "./plugin/adapters/docuworks": {
        types: "./types/docuworks.d.ts",
        default: "./dist/plugin/adapters/docuworks.js",
      },
      "./plugin/adapters/excalidraw": {
        types: "./types/excalidraw.d.ts",
        default: "./dist/plugin/adapters/excalidraw.js",
      },
      "./plugin/adapters/mermaid": {
        types: "./types/mermaid.d.ts",
        default: "./dist/plugin/adapters/mermaid.js",
      },
      "./tools/emit-downstream-worker": {
        default: "./dist/tools/emit-downstream-worker.mjs",
      },
      "./workers/plugin": { default: "./dist/workers/plugin-converter.mjs" },
      "./workers/render": { types: "./dist/workers/render_worker.d.ts", default: "./dist/workers/render_worker.js" },
      "./workers/native": {
        types: "./dist/workers/native_converter_worker.d.ts",
        default: "./dist/workers/native_converter_worker.js",
      },
    },
    files: ["dist", "types", "licenses", "docs", "README.md", "LICENSE", "NOTICE.md"],
    engines: { node: ">=20" },
    ...(release ?? {}),
  };
  if (release) manifest.description = manifest.description.replace(" (staging publication is blocked)", "");
  writeFileSync(resolve(stageDir, "package.json"), JSON.stringify(manifest, null, 2) + "\n");
  // the library README's doc links are source-tree relative (../../docs/…):
  // the packed copy ships the docs beside the README, so the link prefix is
  // rewritten for the package layout alone — the source file keeps links
  // that resolve inside the repository
  let packedReadme = readFileSync(resolve(plugin, "library/README.md"), "utf8")
    .replace(/\]\(\.\.\/\.\.\/docs\//g, "](docs/");
  if (release) packedReadme = packedReadme.replace("**Not yet published to npm.**", `**Release artifact ${release.version}.**`);
  writeFileSync(resolve(stageDir, "README.md"), packedReadme);
  cpSync(resolve(plugin, "library/NOTICE.md"), resolve(stageDir, "NOTICE.md"));
  cpSync(resolve(root, "LICENSE"), resolve(stageDir, "LICENSE"));
  // the API reference and the diagram formats doc ship inside the package;
  // the source tree's relative link to the library README
  // (../plugin/library/README.md) is rewritten to the packed layout
  // (../README.md), so the shipped copies' links resolve
  mkdirSync(resolve(stageDir, "docs"), { recursive: true });
  const packedApiDoc = readFileSync(resolve(root, "docs/format-plugin-api.md"), "utf8")
    .replace(/\]\(\.\.\/plugin\/library\/README\.md\)/g, "](../README.md)");
  writeFileSync(resolve(stageDir, "docs/format-plugin-api.md"), packedApiDoc);
  cpSync(resolve(root, "docs/diagram-plugins.md"), resolve(stageDir, "docs/diagram-plugins.md"));

  // 5) refuse anything that would leak local absolute paths into the artifact
  for (const file of walk(stageDir)) {
    if (/\.(js|mjs|json|md|d\.ts)$/.test(file)) {
      const text = readFileSync(file, "utf8");
      const home = process.env.HOME ?? "/home";
      const hit = text.includes(home + "/") ? text.match(new RegExp(home + "/\\S+"))?.[0] : null;
      if (hit) {
        throw new Error(`${file} contains a local absolute path: ${hit}`);
      }
      if (/sourceMappingURL/.test(text)) {
        throw new Error(`${file} contains a sourceMappingURL comment`);
      }
    }
  }
  return { stageDir };
}

// The emitted bundles are final: strip nothing silently. The tool only rewrites
// the rare trailing source map comment, never code.
function copyBundle(source, destination) {
  const text = readFileSync(source, "utf8");
  const stripped = text.replace(/\n?\/\/#\s*sourceMappingURL=\S*\s*$/g, "");
  if (stripped.length !== text.length) {
    console.log(`stripped a source map comment from ${source}`);
  }
  writeFileSync(destination, stripped);
}

function* walk(dir) {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = resolve(dir, entry.name);
    if (entry.isDirectory()) {
      yield* walk(path);
    } else {
      yield path;
    }
  }
}

const { stageDir } = stage();
// (the stage directory's exit hook was registered at allocation time, above)
// npm's default cache lives in a read-only home here; use a writable one
const npmCache = process.env.BDF_PLUGIN_NPM_CACHE || resolve(root, "_scratch/npm-cache");
const pack = (npmArgs) =>
  spawnSync("npm", ["pack", ...npmArgs, "--json", "--cache", npmCache], { cwd: stageDir, encoding: "utf8" });

function parseJsonDocuments(stdout, label) {
  const documents = [];
  let at = 0;
  while (at < stdout.length) {
    const start = stdout.indexOf("[", at);
    if (start === -1) {
      break;
    }
    let depth = 0;
    let end = -1;
    let inString = false;
    for (let index = start; index < stdout.length; index += 1) {
      const character = stdout[index];
      if (inString) {
        if (character === "\\") {
          index += 1;
        } else if (character === '"') {
          inString = false;
        }
        continue;
      }
      if (character === '"') {
        inString = true;
      } else if (character === "[") {
        depth += 1;
      } else if (character === "]") {
        depth -= 1;
        if (depth === 0) {
          end = index + 1;
          break;
        }
      }
    }
    if (end === -1) {
      throw new Error(`${label} printed an unbalanced JSON array:\n${stdout.slice(start)}`);
    }
    documents.push(JSON.parse(stdout.slice(start, end)));
    at = end;
  }
  if (documents.length === 0) {
    throw new Error(`${label} did not print JSON:\n${stdout}`);
  }
  return documents;
}

///|
// `npm pack --json` prints its files either as a bare array of {path} entries
// — the listing first, metadata second in some modes — or as a metadata
// document whose element carries the same entries nested under `files`.
// Both describe the exact same staged content, so either shape is accepted.
function packListing(stdout, label) {
  const documents = parseJsonDocuments(stdout, label);
  const bare = documents.find(value => Array.isArray(value) && value[0]?.path);
  if (bare) {
    return bare.map(entry => entry.path).sort();
  }
  const nested = documents.find(value => Array.isArray(value)
    && Array.isArray(value[0]?.files) && typeof value[0].files[0]?.path === "string");
  if (!nested) {
    throw new Error(`${label} result has no files list:\n${stdout}`);
  }
  return nested[0].files.map(entry => entry.path).sort();
}

if (dryRun) {
  const run = pack(["--dry-run"]);
  if (run.status !== 0) {
    throw new Error(`npm pack --dry-run failed:\n${run.stdout}\n${run.stderr}`);
  }
  const listing = packListing(run.stdout, "npm pack --dry-run");
  listingChecks(listing);
  report("dry-run", null, listing);
} else {
  const run = pack([]);
  if (run.status !== 0) {
    throw new Error(`npm pack failed:\n${run.stdout}\n${run.stderr}`);
  }
  const listing = packListing(run.stdout, "npm pack");
  listingChecks(listing);
  const tarballs = readdirSync(stageDir).filter(name => name.endsWith(".tgz"));
  if (tarballs.length !== 1) {
    throw new Error(`expected exactly one tarball in the stage dir, found ${tarballs}`);
  }
  if (tarballs[0] !== tarballName) {
    throw new Error(`npm packed ${tarballs[0]}, but the configured identity names ${tarballName}`);
  }
  mkdirSync(outDir, { recursive: true });
  // both output destinations are validated before either is written, so no
  // pointer failure can leave a half-updated output directory behind
  const destination = assertWritableOutput(resolve(outDir, tarballName), "the packed tarball output");
  const pointer = assertWritableOutput(resolve(outDir, "latest.json"), "the latest.json pointer output");
  cpSync(resolve(stageDir, tarballName), destination);
  writeFileSync(
    pointer,
    JSON.stringify({ tarball: tarballName, stagingName, stagingVersion }, null, 2) + "\n",
  );
  report(tarballName, destination, listing);
}

function listingChecks(present) {
  const expected = [...ALLOWED_TAR_ENTRIES].sort();
  const missing = expected.filter(name => !present.includes(name));
  const extra = present.filter(name => !expected.includes(name));
  if (missing.length || extra.length) {
    throw new Error(`tarball allowlist mismatch: missing [${missing}], extra [${extra}]`);
  }
  for (const forbidden of [/\.map$/, /(^|\/)test/, /fixtures?/, /corpus/, /node_modules/, /_scratch/, /\.npmrc/, /\.d\.ts\.map$/]) {
    const hit = present.find(name => forbidden.test(name));
    if (hit) {
      throw new Error(`tarball contains a forbidden entry: ${hit}`);
    }
  }
}

function report(name, destination, listing) {
  console.log(`staged library package: ${stagingName}@${stagingVersion} (${release ? "release artifact; not published" : "private: publication blocked"})`);
  if (listing) {
    console.log(`files (${listing.length}):`);
    for (const entry of listing) {
      console.log(`  ${entry}`);
    }
  }
  if (destination) {
    const bytes = readFileSync(destination);
    console.log(`tarball: ${destination}`);
    console.log(`sha256: ${createHash("sha256").update(bytes).digest("hex")}`);
    console.log(`size: ${bytes.length}`);
  }
}
