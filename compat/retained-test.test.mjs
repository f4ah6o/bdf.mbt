// Deterministic tests for the retained-package selector.
//
// These cover the parts that decide what verification runs: which packages are
// selected for each mode and target, that dormant packages are never selected
// and retained ones never dropped, that flags reach `moon`, that a failing
// package fails the run, and that generated or symlinked trees add no packages.
// They do not run MoonBit.
import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import {
  DORMANT,
  MODES,
  TARGETS,
  dormantDependents,
  moonArgs,
  packages,
  parseArgs,
  retainedPackages,
  retainedPaths,
  verify,
} from "./retained-test.mjs";

const CLI = path.join(import.meta.dirname, "retained-test.mjs");

function tempDir(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "bdf-retained-test-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}

test("dormant packages are never selected for any target", () => {
  for (const target of TARGETS) {
    const selected = retainedPaths(target);
    for (const dormant of DORMANT) {
      assert.ok(!selected.includes(dormant), `${dormant} selected for ${target}`);
    }
  }
});

test("every retained package is selected for at least one target", () => {
  const counts = verify();
  assert.equal(counts.total, counts.retained + counts.dormant);
  const covered = new Set(TARGETS.flatMap((target) => retainedPaths(target)));
  for (const dormant of DORMANT) assert.ok(!covered.has(dormant));
  assert.equal(covered.size, counts.retained);
});

test("every dormant entry still exists in the tree", () => {
  const all = packages();
  for (const dormant of DORMANT) assert.ok(all.includes(dormant), `${dormant} is missing`);
});

test("test mode selects packages by name, check and build by path", () => {
  for (const target of TARGETS) {
    const testArgs = moonArgs({ mode: "test", target });
    assert.deepEqual(testArgs.slice(0, 3), ["test", "--target", target]);
    assert.equal(testArgs.filter((arg) => arg === "-p").length, retainedPackages(target).length);
    assert.ok(testArgs.includes("f4ah6o/bdf/convert/pdf"));
    assert.ok(!testArgs.includes("convert/pdf"));

    for (const mode of ["check", "build"]) {
      const args = moonArgs({ mode, target });
      assert.deepEqual(args.slice(0, 3), [mode, "--target", target]);
      assert.ok(args.includes("convert/pdf"));
      assert.ok(!args.includes("-p"));
      assert.ok(!args.includes("f4ah6o/bdf/convert/pdf"));
      assert.deepEqual(args.slice(3), retainedPaths(target));
    }
  }
});

test("release is forwarded to every mode and only when asked", () => {
  for (const mode of MODES) {
    const plain = moonArgs({ mode, target: "js" });
    assert.ok(!plain.includes("--release"));
    const release = moonArgs({ mode, target: "js", release: true });
    assert.deepEqual(release.slice(0, 4), [mode, "--target", "js", "--release"]);
    assert.deepEqual(release.slice(4), plain.slice(3));
  }
});

test("unknown modes and targets are rejected", () => {
  assert.throws(() => moonArgs({ mode: "run", target: "js" }), /unknown mode/);
  assert.throws(() => moonArgs({ mode: "test", target: "wasm" }), /unknown target/);
});

test("the CLI keeps the bare-target test form and rejects unknown flags", () => {
  assert.deepEqual(parseArgs([]), { mode: "test", release: false, list: false, targets: [] });
  assert.deepEqual(parseArgs(["js"]), { mode: "test", release: false, list: false, targets: ["js"] });
  assert.equal(parseArgs(["--mode", "check", "--release", "js"]).mode, "check");
  assert.equal(parseArgs(["--mode", "check", "--release", "js"]).release, true);
  assert.throws(() => parseArgs(["--nope"]), /unknown option/);
  assert.throws(() => parseArgs(["--mode", "run"]), /--mode must be one of/);
  assert.throws(() => parseArgs(["wasm"]), /unknown target/);
});

test("--list prints the selection and nothing dormant", () => {
  const result = spawnSync(process.execPath, [CLI, "--list", "js"], { encoding: "utf8" });
  assert.equal(result.status, 0, result.stderr);
  const lines = result.stdout.trim().split("\n");
  assert.equal(lines.length, retainedPaths("js").length);
  for (const line of lines) {
    assert.match(line, /^js f4ah6o\/bdf\/\S+$/);
    assert.ok(!DORMANT.some((dormant) => line.endsWith(" " + dormant)), line);
  }
});

test("a failing package fails the run with its exit code", (t) => {
  const bin = tempDir(t);
  const fake = path.join(bin, "moon");
  fs.writeFileSync(fake, "#!/bin/sh\nexit 3\n");
  fs.chmodSync(fake, 0o755);
  const result = spawnSync(process.execPath, [CLI, "--mode", "check", "js"], {
    encoding: "utf8",
    env: { ...process.env, PATH: bin + path.delimiter + process.env.PATH },
  });
  assert.equal(result.status, 3, result.stderr);
  assert.match(result.stdout, /moon check --target js over \d+ retained packages/);
});

test("generated, ignored and symlinked trees add no packages", (t) => {
  const dir = tempDir(t);
  const pkg = (relative) => {
    fs.mkdirSync(path.join(dir, relative), { recursive: true });
    fs.writeFileSync(path.join(dir, relative, "moon.pkg"), "");
  };
  pkg("kept");
  pkg("kept/nested");
  for (const ignored of ["_build", ".git", ".moon-home", "node_modules", "_scratch"]) {
    pkg(path.join(ignored, "hidden"));
  }
  const outside = tempDir(t);
  fs.writeFileSync(path.join(outside, "moon.pkg"), "");
  fs.symlinkSync(outside, path.join(dir, "linked"));
  assert.deepEqual(packages(dir).sort(), ["kept", "kept/nested"]);
});

test("retained packages that import dormant ones are reported, not hidden", () => {
  const dependents = dormantDependents();
  for (const entry of dependents) {
    assert.ok(!DORMANT.includes(entry.package), entry.package);
    assert.ok(entry.imports.length > 0);
    for (const imported of entry.imports) assert.ok(DORMANT.includes(imported), imported);
  }
});
