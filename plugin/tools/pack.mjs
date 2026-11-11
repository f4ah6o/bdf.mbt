// Build the staged npm package from an allowlisted file list and pack it.
//
//   node plugin/tools/pack.mjs [--dry-run] [--staging-name NAME] [--staging-version V] [--out DIR]
//
// - The staging name and version are configurable because they are not
//   finalized; the staged package keeps `"private": true` so npm refuses to
//   publish it until a maintainer decides otherwise.
// - Staging happens in a fresh `mkdtemp` directory inside the tool-owned
//   `_scratch/plugin-pack` root: nothing user-supplied ever names a delete
//   target, the output directory is validated to stay inside this
//   repository, and the packed tarball plus a `latest.json` pointer land in
//   that fixed output directory.
// - After packing, the tar member list must equal the allowlist exactly;
//   source maps, tests, fixtures and local paths are refused.

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { cpSync, existsSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

import { assertWritableOutput, refuseSymlinkedSource, resolveInsideRoot, validateStagingName, validateStagingVersion } from "./staging-path.mjs";

const root = resolve(import.meta.dirname, "../..");
const plugin = resolve(root, "plugin");
const scratch = resolve(root, "_scratch/plugin-pack");

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const flag = (name, fallback) => {
  const at = args.indexOf(name);
  return at !== -1 && args[at + 1] ? args[at + 1] : fallback;
};
validateStagingName((flag("--staging-name", "bdf-format-plugin-api")));
const stagingVersion = validateStagingVersion(flag("--staging-version", "0.0.0-staging"));
const stagingName = flag("--staging-name", "bdf-format-plugin-api");
const outDir = resolveInsideRoot(flag("--out", "_scratch/plugin-pack"), root, "--out");
const tarballName = `${stagingName}-${stagingVersion}.tgz`;
// Validate fixed staging as well as a custom output before touching either.
resolveInsideRoot(scratch, root, "staging scratch");

const ALLOWED_TAR_ENTRIES = new Set([
  "package.json",
  "README.md",
  "LICENSE",
  "NOTICE.md",
  "types/index.d.ts",
  "types/worker.d.ts",
  "types/diagram-bdf.d.ts",
  "types/docuworks.d.ts",
  "types/excalidraw.d.ts",
  "types/mermaid.d.ts",
]);
// js sources of src/
for (const entry of readdirSync(resolve(plugin, "src"), { withFileTypes: true })) {
  if (entry.isFile() && entry.name.endsWith(".js")) {
    ALLOWED_TAR_ENTRIES.add(`src/${entry.name}`);
  } else if (entry.isDirectory()) {
    for (const nested of readdirSync(resolve(plugin, "src", entry.name), { withFileTypes: true })) {
      if (nested.isFile() && nested.name.endsWith(".js")) {
        ALLOWED_TAR_ENTRIES.add(`src/${entry.name}/${nested.name}`);
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
  mkdirSync(resolve(stageDir, "types"), { recursive: true });
  mkdirSync(resolve(stageDir, "src"), { recursive: true });
  const manifest = JSON.parse(readFileSync(resolve(plugin, "package.json"), "utf8"));
  if (manifest.private !== true) {
    throw new Error('the staging package must keep "private": true: publishing is blocked');
  }
  // staged sources must be real files: a symlink must refuse the pack, not
  // produce a silently different artifact
  for (const source of [resolve(plugin, "README.md"), resolve(plugin, "NOTICE.md"),
    resolve(root, "LICENSE"), resolve(plugin, "types"), resolve(plugin, "src")]) {
    refuseSymlinkedSource(source, "a staging source");
  }
  const stagedManifest = {
    ...manifest,
    name: stagingName,
    version: stagingVersion,
  };
  writeFileSync(resolve(stageDir, "package.json"), JSON.stringify(stagedManifest, null, 2) + "\n");
  cpSync(resolve(plugin, "README.md"), resolve(stageDir, "README.md"));
  cpSync(resolve(plugin, "NOTICE.md"), resolve(stageDir, "NOTICE.md"));
  cpSync(resolve(root, "LICENSE"), resolve(stageDir, "LICENSE"));
  for (const dts of ["index.d.ts", "worker.d.ts", "diagram-bdf.d.ts", "docuworks.d.ts",
    "excalidraw.d.ts", "mermaid.d.ts"]) {
    const source = resolve(plugin, "types", dts);
    if (!existsSync(source)) {
      throw new Error(`missing plugin type module: ${source}`);
    }
    cpSync(source, resolve(stageDir, "types", dts));
  }
  cpSync(resolve(plugin, "src"), resolve(stageDir, "src"), {
    recursive: true,
    filter: source => !statSync(source).isDirectory() && !source.endsWith(".js") ? false : true,
  });
  // refuse anything that would leak local absolute paths into the artifact
  const files = [...walk(stageDir)];
  for (const file of files) {
    if (file.endsWith(".js") || file.endsWith(".json") || file.endsWith(".md") || file.endsWith(".d.ts")) {
      const text = readFileSync(file, "utf8");
      const home = process.env.HOME ?? "/home";
      if (text.includes(home + "/")) {
        throw new Error(`${file} contains a local absolute path: ${text.match(new RegExp(home + "/\\S+"))?.[0]}`);
      }
    }
  }
  return { stageDir, files: [...ALLOWED_TAR_ENTRIES].sort() };
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
        } else if (character === "\"") {
          inString = false;
        }
        continue;
      }
      if (character === "\"") {
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
  report("dry-run", null, packListing(run.stdout, "npm pack --dry-run"));
} else {
  const run = pack([]);
  if (run.status !== 0) {
    throw new Error(`npm pack failed:\n${run.stdout}\n${run.stderr}`);
  }
  const listing = packListing(run.stdout, "npm pack");
  const tarballs = readdirSync(stageDir).filter(name => name.endsWith(".tgz"));
  if (tarballs.length !== 1) {
    throw new Error(`expected exactly one tarball in the stage dir, found ${tarballs}`);
  }
  verify(listing);
  mkdirSync(outDir, { recursive: true });
  if (tarballs[0] !== tarballName) {
    throw new Error(`npm packed ${tarballs[0]}, but the configured identity names ${tarballName}`);
  }
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

function verify(listing) {
  const expected = [...ALLOWED_TAR_ENTRIES].sort();
  const present = listing.filter(name => !name.endsWith("/"));
  const missing = expected.filter(name => !present.includes(name));
  const extra = present.filter(name => !expected.includes(name));
  if (missing.length || extra.length) {
    throw new Error(`tarball allowlist mismatch: missing [${missing}], extra [${extra}]`);
  }
  for (const forbidden of [/\.map$/, /^test\//, /fixtures?/, /node_modules/, /_scratch/, /\.npmrc/]) {
    const hit = present.find(name => forbidden.test(name));
    if (hit) {
      throw new Error(`tarball contains a forbidden entry: ${hit}`);
    }
  }
}

function report(name, destination, listing) {
  console.log(`staged package: ${stagingName}@${stagingVersion} (private: publication blocked)`);
  console.log(`files (${listing.length}):`);
  for (const entry of listing) {
    console.log(`  ${entry}`);
  }
  if (destination) {
    const bytes = readFileSync(destination);
    console.log(`tarball: ${destination}`);
    console.log(`sha256: ${createHash("sha256").update(bytes).digest("hex")}`);
    console.log(`size: ${bytes.length}`);
  }
}
