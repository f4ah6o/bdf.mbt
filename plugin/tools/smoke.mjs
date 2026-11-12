// Pack the staged package, install it from the tarball, and smoke-test the
// installed copy with Node (and, when the browser build exists, with
// Chromium). No network beyond the local filesystem: npm works offline with
// the tarball itself (a local file), and vendor scripts are never executed.
//
//   node plugin/tools/smoke.mjs [--staging-name NAME] [--staging-version V]
//
// The install directory is a fresh `mkdtemp` under the tool-owned
// `_scratch/plugin-smoke-node`: nothing user-supplied names a deletion
// target, and the run's own directory is removed after the smoke passes.

import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const args = process.argv.slice(2);
const flag = (name, fallback) => {
  const at = args.indexOf(name);
  return at !== -1 && args[at + 1] && at + 1 < args.length ? args.at(at + 1) : fallback;
};
const stagingName = flag("--staging-name", "bdf-format-plugin-api");
const npmCache = process.env.BDF_PLUGIN_NPM_CACHE || resolve(root, "_scratch/npm-cache");

const packArgs = ["--staging-name", stagingName];
if (args.includes("--staging-version") && args.indexOf("--staging-version") + 1 < args.length) {
  packArgs.push("--staging-version", args.at(args.indexOf("--staging-version") + 1));
}

const pack = spawnSync("node", [resolve(root, "plugin/tools/pack.mjs"), ...packArgs], {
  cwd: root,
  encoding: "utf8",
  stdio: ["ignore", "inherit", "inherit"],
});
if (pack.status !== 0) {
  process.exit(pack.status ?? 1);
}

// the pack tool leaves a deterministic pointer next to the tarball
const packDir = resolve(root, "_scratch/plugin-pack");
const pointer = JSON.parse(readFileSync(resolve(packDir, "latest.json"), "utf8"));
const tarball = resolve(packDir, pointer.tarball);

const scratchBase = resolve(root, "_scratch/plugin-smoke-node");
mkdirSync(scratchBase, { recursive: true });
const installDir = mkdtempSync(join(scratchBase, "smoke-"));
try {
  writeFileSync(
    resolve(installDir, "package.json"),
    JSON.stringify({ name: "bdf-plugin-smoke", private: true }, null, 2) + "\n",
  );
  const install = spawnSync(
    "npm",
    ["install", "--ignore-scripts", "--no-audit", "--no-fund", "--cache", npmCache, tarball],
    { cwd: installDir, encoding: "utf8" },
  );
  if (install.status !== 0) {
    throw new Error(`installing the tarball failed:\n${install.stdout}\n${install.stderr}`);
  }
  const installed = resolve(installDir, "node_modules", stagingName);
  if (!existsSync(installed)) {
    throw new Error(`the tarball did not install ${stagingName} into ${installDir}`);
  }
  const relative = installed.slice(root.length + 1);
  console.log(`installed ${stagingName} from ${pointer.tarball} into _scratch/plugin-smoke-node/ (served as /${relative})`);

  const env = {
    ...process.env,
    BDF_PLUGIN_INSTALLED: installed,
    BDF_PLUGIN_STAGING_NAME: stagingName,
  };
  const xdwModule = resolve(root, "_build/js/debug/build/plugin/moonbit/docuworks_js/docuworks_js.js");
  if (existsSync(xdwModule)) {
    env.BDF_XDW_MODULE = xdwModule;
  } else {
    console.log("note: no built docuworks_js module; the binding test reports a skip");
  }

  const nodeTests = spawnSync("node", ["--test", resolve(root, "plugin/test/installed.test.mjs")], {
    cwd: root,
    encoding: "utf8",
    env,
  });
  process.stdout.write(nodeTests.stdout);
  if (nodeTests.status !== 0) {
    process.stderr.write(nodeTests.stderr);
    throw new Error("the installed-tarball Node smoke failed");
  }

  const browserScript = resolve(root, "plugin/browser/plugin-smoke.mjs");
  if (existsSync(browserScript)) {
    const browser = spawnSync("node", [browserScript, "--installed", installed], {
      cwd: root,
      encoding: "utf8",
      env,
    });
    process.stdout.write(browser.stdout);
    if (browser.status !== 0) {
      process.stderr.write(browser.stderr);
      throw new Error("the installed-tarball browser smoke failed");
    }
  } else {
    console.log("note: no browser smoke script present");
  }
  console.log(`tarball smoke complete for ${stagingName}@${pointer.tarball}`);
} finally {
  // this run's own throwaway install directory only
  rmSync(installDir, { recursive: true, force: true });
}
