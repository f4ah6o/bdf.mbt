// The release recipe and the packer must stay in lockstep: library-pack.mjs
// stages exactly the bundles its BUNDLES list names — it refuses to stage a
// missing one — while the npm release workflow builds them from a fixed
// command of its own. A bundle added to the packer but not to the workflow
// would pass every local check and then fail a clean release with "missing
// bundle". This test reads both sources as text and asserts every bundle
// the packer stages is built by the workflow's step and named by the
// packer's own BUILD_COMMAND; nothing is built or packed here.

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { test } from "node:test";

const root = resolve(import.meta.dirname, "../..");

///|
// The MoonBit package every staged bundle is built from: the packer's BUNDLES
// entries are `_build/js/release/build/<package>/*.js`.
function stagedPackages(text) {
  const packages = new Set();
  for (const match of text.matchAll(/_build\/js\/release\/build\/([a-z0-9_/]+)\//g)) {
    packages.add(match[1]);
  }
  return [...packages].sort();
}

test("the packer stages bundles from exactly its declared build list", () => {
  const packer = readFileSync(resolve(root, "plugin/tools/library-pack.mjs"), "utf8");
  const packages = stagedPackages(packer);
  // the exact six the library package ships today; a new bundle must join
  // this list, the workflow step and the BUILD_COMMAND together
  assert.deepEqual(packages, [
    "browser",
    "export/pdf_js",
    "form_page",
    "native_converter_worker",
    "plugin/moonbit/docuworks_js",
    "render_worker",
  ]);
  // the BUILD_COMMAND the packer tells its caller to run names them all
  const command = /BUILD_COMMAND = "([^;]+)"/.exec(packer)?.[1] ?? "";
  for (const name of packages) {
    assert.ok(command.includes(name), `BUILD_COMMAND does not build ${name}`);
  }
  assert.ok(/moon build/.test(command), "BUILD_COMMAND must be a moon build");
  assert.ok(/--target js --release/.test(command), "BUILD_COMMAND must build the js release");
});

test("the npm release workflow builds every bundle the packer stages", () => {
  const packer = readFileSync(resolve(root, "plugin/tools/library-pack.mjs"), "utf8");
  const workflow = readFileSync(resolve(root, ".github/workflows/npm-release.yaml"), "utf8");
  const packages = stagedPackages(packer);
  assert.ok(packages.length > 0, "no staged bundles found in the packer");
  const step = /- name: Build public JS bundles\n\s+run: >-\n([\s\S]*?)(?=\n {6}- name:|$)/.exec(workflow)?.[1] ?? "";
  assert.ok(/moon build/.test(step), "the workflow step must be a moon build");
  assert.ok(/--target js --release/.test(step), "the workflow step must build the js release");
  for (const name of packages) {
    assert.ok(step.includes(name), `the release workflow does not build ${name}`);
  }
  // and nothing it builds is unknown to the packer
  for (const word of step.replace(/moon build|--target js --release/g, "").split(/\s+/)) {
    if (word.length === 0) continue;
    assert.ok(packages.includes(word), `the release workflow builds an unstaged package: ${word}`);
  }
});
