// Pack the staged library package, install it from the tarball, and
// smoke-test the installed copy with Node and Chromium, following the
// documented deployment recipe exactly: the downstream demo Worker is
// EMITTED by the emitter that ships inside the tarball, from the same zine
// plugin module the README shows. No network beyond the local filesystem:
// npm works offline with the tarball as a local file, and vendor scripts are
// never executed.
//
//   node plugin/tools/library-smoke.mjs [--staging-name NAME] [--staging-version V]
//
// The install directory is a fresh `mkdtemp` under the tool-owned
// `_scratch/library-smoke-node`: nothing user-supplied names a deletion
// target, and the run's own directory is removed after the smoke passes.

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const at = args.indexOf(name);
  return at !== -1 && at + 1 < args.length ? args.at(at + 1) : fallback;
};
const stagingName = flag("--staging-name", "bdf.mbt");
const stagingVersion = flag("--staging-version", "0.0.0-staging");
const npmCache = process.env.BDF_PLUGIN_NPM_CACHE || resolve(root, "_scratch/npm-cache");

const packArgs = ["--staging-name", stagingName, "--staging-version", stagingVersion];
const pack = spawnSync("node", [resolve(root, "plugin/tools/library-pack.mjs"), ...packArgs], {
  cwd: root,
  encoding: "utf8",
  stdio: ["ignore", "inherit", "inherit"],
});
if (pack.status !== 0) {
  process.exit(pack.status ?? 1);
}

// the pack tool leaves a deterministic pointer next to the tarball
const packDir = resolve(root, "_scratch/library-pack");
const pointer = JSON.parse(readFileSync(resolve(packDir, "latest.json"), "utf8"));
const tarball = resolve(packDir, pointer.tarball);

const scratchBase = resolve(root, "_scratch/library-smoke-node");
mkdirSync(scratchBase, { recursive: true });
const installDir = mkdtempSync(join(scratchBase, "smoke-"));
try {
  writeFileSync(
    resolve(installDir, "package.json"),
    JSON.stringify({ name: "bdf-library-smoke", private: true }, null, 2) + "\n",
  );
  const install = spawnSync(
    "npm",
    ["install", "--ignore-scripts", "--no-audit", "--no-fund", "--cache", npmCache, tarball],
    { cwd: installDir, encoding: "utf8" },
  );
  if (install.status !== 0) {
    throw new Error(`installing the library tarball failed:\n${install.stdout}\n${install.stderr}`);
  }
  const installed = resolve(installDir, "node_modules", stagingName);
  if (!existsSync(installed)) {
    throw new Error(`the tarball did not install ${stagingName} into ${installDir}`);
  }
  const relative = installed.slice(root.length + 1);
  console.log(`installed ${stagingName}@${pointer.tarball} into ${relative}`);

  // The Node `self` adapter: worker_threads has none, and the MoonBit Worker
  // bundles speak self.postMessage/self.onmessage. This is the one piece of
  // glue a Node consumer writes; it stays outside the package. It notifies
  // the parent when the shipped module finished loading, so a load crash
  // surfaces as a worker error instead of silence.
  const adapter = resolve(installDir, "node-self-adapter.mjs");
  writeFileSync(adapter, [
    "import { parentPort } from \"node:worker_threads\";",
    "globalThis.self = {",
    "  postMessage(message, transfer) { parentPort.postMessage(message, transfer); },",
    "  onmessage: null,",
    "};",
    "await import(process.env.BDF_WORKER_MODULE); // the shipped Worker bundle",
    "parentPort.postMessage({ type: \"bdf-adapter-loaded\" });",
    "parentPort.on(\"message\", data => { globalThis.self.onmessage({ data }); });",
    "",
  ].join("\n"));

  // The documented deployment recipe, executed with shipped files only:
  // the consumer's plugin module, emitted into a Worker with served URLs by
  // the emitter that ships inside the tarball.
  const generated = resolve(root, "_scratch/library-smoke-browser");
  mkdirSync(generated, { recursive: true });
  writeFileSync(
    resolve(generated, "zine-plugin.mjs"),
    [
      "// The consumer's own third-party plugin module (README demo).",
      "export const plugin = {",
      "  apiVersion: 1,",
      "  name: \"zine\",",
      "  description: \"a third-party format added downstream\",",
      "  extensions: [\".zine\"],",
      "  detect: bytes => bytes[0] === 0x5a && bytes[1] === 0x49 && bytes[2] === 0x4e,",
      "  convert: async (bytes, options) => ({",
      "    bdf: bytes.slice(),",
      "    summary: `zine: ${bytes.length} bytes, formatted by downstream code`,",
      "    warnings: [\"this demo plugin is not part of the package\"],",
      "  }),",
      "};",
      "",
    ].join("\n"),
  );
  const downstreamWorker = resolve(generated, "downstream-worker.mjs");
  const emit = spawnSync(
    "node",
    [resolve(installed, "dist/tools/emit-downstream-worker.mjs"),
      "--plugin", resolve(generated, "zine-plugin.mjs"),
      "--out", downstreamWorker,
      "--prefix", `/${relative}/dist`],
    { cwd: installDir, encoding: "utf8" },
  );
  if (emit.status !== 0) {
    throw new Error(`emitting the downstream worker failed:\n${emit.stdout}\n${emit.stderr}`);
  }
  process.stdout.write(emit.stdout);
  // the emitted Worker must import served URLs only, never bare specifiers
  const emitted = readFileSync(downstreamWorker, "utf8");
  for (const line of emitted.split("\n").filter(line => line.startsWith("import"))) {
    if (!/from "(\.|\/)/.test(line)) {
      throw new Error(`the emitted Worker uses a non-URL import the browser cannot fetch: ${line}`);
    }
  }

  const env = {
    ...process.env,
    BDF_LIBRARY_INSTALLED: installed,
    BDF_LIBRARY_STAGING_NAME: stagingName,
    BDF_LIBRARY_ADAPTER: adapter,
    BDF_LIBRARY_EMITTED_WORKER: downstreamWorker,
  };
  const nodeTests = spawnSync("node", ["--test", resolve(root, "plugin/test/library-installed.test.mjs")], {
    cwd: root,
    encoding: "utf8",
    env,
  });
  process.stdout.write(nodeTests.stdout);
  if (nodeTests.status !== 0) {
    process.stderr.write(nodeTests.stderr);
    throw new Error("the installed-library Node smoke failed");
  }

  const browserScript = resolve(root, "plugin/browser/library-smoke.mjs");
  if (existsSync(browserScript)) {
    const browser = spawnSync(
      "node",
      [browserScript, "--installed", installed, "--emitted-worker", downstreamWorker],
      { cwd: root, encoding: "utf8", env },
    );
    process.stdout.write(browser.stdout);
    if (browser.status !== 0) {
      process.stderr.write(browser.stderr);
      throw new Error("the installed-library browser smoke failed");
    }
  }
  console.log(`library tarball smoke complete for ${stagingName}@${pointer.tarball}`);
} finally {
  // this run's own throwaway install directory only
  rmSync(installDir, { recursive: true, force: true });
}
