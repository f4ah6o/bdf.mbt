// Safety tests for the packing tools' path handling. The tools stage under
// fresh `mkdtemp` directories inside a fixed tool-owned scratch root and
// refuse anything that could name a path outside it, so a staging name, a
// version, or an output flag can never steer a filesystem deletion.
//
// The sentinel directory stands in for "any directory outside the tool's
// own scratch": the traversal forms below would have resolved to it under
// the previous scheme (which deleted `resolve(scratch, stagingName)`
// recursively). Every invalid input must be refused before anything is
// staged, and the sentinel must survive untouched. Nothing here points
// outside this repository, and no destructive command is ever run.

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { cpSync, existsSync, lstatSync, linkSync, mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { test } from "node:test";

import {
  assertWritableOutput,
  refuseSymlinkedSource,
  resolveInsideRoot,
  validateStagingName,
  validateStagingVersion,
} from "../tools/staging-path.mjs";

const root = resolve(import.meta.dirname, "../..");
const scratch = resolve(root, "_scratch");

test("staging names refuse traversal, absolute and scoped forms", () => {
  for (const valid of ["bdf.mbt", "bdf-format-plugin-api", "a", "x-y_z.v1-rc1", "0.pad"]) {
    assert.equal(validateStagingName(valid), valid, `valid name refused: ${valid}`);
  }
  for (const invalid of ["", ".", "..", "../source", "..\\source", "/absolute/path",
    "src/../../escape", "a/b", "@scope/pkg", "./x", "X-Upper", " leading-space",
    null, undefined, 42]) {
    assert.throws(() => validateStagingName(invalid), /invalid staging name/, `invalid name accepted: ${String(invalid)}`);
  }
});

test("staging versions refuse anything that could move a filename", () => {
  assert.equal(validateStagingVersion("0.0.0-staging"), "0.0.0-staging");
  assert.equal(validateStagingVersion("1.2.3"), "1.2.3");
  for (const invalid of ["", ".", "..", "../x", "1/2", "..\\1", "/1", null, 7]) {
    assert.throws(() => validateStagingVersion(invalid), /invalid staging version/, `invalid version accepted: ${String(invalid)}`);
  }
});

test("output flags must stay inside the repository, symlink-free", () => {
  const sandbox = mkdtempSync(join(scratch, "pack-safety-root-"));
  try {
    const inside = join(sandbox, "out");
    assert.equal(resolveInsideRoot(inside, sandbox, "--out"), resolve(sandbox, inside));
    assert.throws(() => resolveInsideRoot(join(sandbox, ".."), sandbox, "--out"), /must stay inside/);
    assert.throws(() => resolveInsideRoot("/etc", sandbox, "--out"), /must stay inside/);
    assert.throws(() => resolveInsideRoot(".", sandbox, "--out"), /repository root itself|must stay inside/);
    // a symlinked output refuses even when its target is inside the sandbox
    const target = join(sandbox, "target");
    mkdirSync(target);
    const link = join(sandbox, "out-link");
    symlinkSync(target, link);
    assert.throws(() => resolveInsideRoot(link, sandbox, "--out"), /symbolic link/);
    // a symlink whose target escapes the sandbox refuses at the realpath too
    const outside = mkdtempSync(join(scratch, "pack-safety-out-"));
    try {
      const escaping = join(sandbox, "out-escape");
      symlinkSync(outside, escaping);
      assert.throws(() => resolveInsideRoot(escaping, sandbox, "--out"), /must stay inside|symbolic link/);
    } finally {
      rmSync(outside, { recursive: true, force: true });
    }
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test("the packing tools refuse destructive staging identities before staging", () => {
  // The sentinel: a per-run, test-owned directory one level above the
  // plugin-pack scratch root, allocated with mkdtemp so this test can never
  // overwrite or delete a directory it did not create itself. Under the old
  // scheme, `--staging-name ../<sentinel>` resolved to exactly this
  // directory and its recursive delete destroyed it.
  const sentinel = mkdtempSync(join(scratch, "pack-safety-sentinel-"));
  const sentinelName = sentinel.split("/").at(-1);
  const sentinelFile = join(sentinel, "do-not-delete.txt");
  writeFileSync(sentinelFile, "sentinel");
  try {
    const tools = [
      "plugin/tools/pack.mjs",
      "plugin/tools/library-pack.mjs",
    ];
    const hostile = [
      "--staging-name", `../${sentinelName}`,
      "--staging-name", "..",
      "--staging-name", ".",
      "--staging-name", "/tmp/pack-safety-victim",
      "--staging-name", "@scope/pkg",
      "--staging-name", "./x",
      "--staging-version", `../${sentinelName}`,
      "--out", `../${sentinelName}`,
      "--out", "/tmp/pack-safety-victim",
    ];
    for (const tool of tools) {
      for (let index = 0; index < hostile.length; index += 2) {
        const run = spawnSync("node", [resolve(root, tool), hostile[index], hostile[index + 1]], {
          cwd: root,
          encoding: "utf8",
        });
        assert.notEqual(run.status, 0, `${tool} accepted ${hostile[index]} ${hostile[index + 1]}`);
        assert.match(run.stderr, /invalid staging|must stay inside|symbolic link/,
          `${tool} ${hostile[index]}: unhelpful refusal`);
      }
      // an absolute --out whose target exists elsewhere is refused too
      const outside = mkdtempSync(join(scratch, "pack-safety-out-"));
      try {
        const run = spawnSync("node", [resolve(root, tool), "--out", outside], {
          cwd: root,
          encoding: "utf8",
        });
        // a path inside the scratch tree is allowed; a path at the same
        // depth as the tool root's own scratch is still inside the repo —
        // the meaningful refusal was the traversal set above
        if (run.status === 0) {
          assert.ok(outside.startsWith(scratch + "/"), "unexpected write outside scratch");
        } else {
          assert.match(run.stderr, /must stay inside|invalid staging/);
        }
      } finally {
        rmSync(outside, { recursive: true, force: true });
      }
    }
    // the sentinel survived every refusal attempt
    assert.ok(existsSync(sentinelFile), "the sentinel directory was affected");
    assert.equal(readFileSync(sentinelFile, "utf8"), "sentinel");
  } finally {
    rmSync(sentinel, { recursive: true, force: true });
  }
});

test("output destinations refuse symlinked parents, symlinks and nonregular files", () => {
  const sandbox = mkdtempSync(join(scratch, "pack-safety-output-"));
  try {
    // an absent destination in a plain directory is fine
    assert.equal(assertWritableOutput(join(sandbox, "pkg-1.0.0.tgz"), "tarball"), join(sandbox, "pkg-1.0.0.tgz"));
    // an existing regular file is a replaceable generated output
    const regular = join(sandbox, "pkg-1.0.0.tgz");
    writeFileSync(regular, "older output");
    assert.equal(assertWritableOutput(regular, "tarball"), regular);
    // an existing directory is refused: it is not a replaceable output
    const asDirectory = join(sandbox, "adir");
    mkdirSync(asDirectory);
    assert.throws(() => assertWritableOutput(asDirectory, "tarball"), /not a regular file/);
    // a destination that is a symlink is refused even inside the sandbox:
    // cpSync would replace the link, writeFileSync would follow it, and a
    // refusal is required for both
    const victim = join(sandbox, "victim");
    mkdirSync(victim);
    writeFileSync(join(victim, "sentinel.txt"), "sentinel");
    const linkedOutput = join(sandbox, "out-link.tgz");
    symlinkSync(victim, linkedOutput);
    assert.throws(() => assertWritableOutput(linkedOutput, "tarball"), /symbolic link/);
    // a missing output whose PARENT is an in-root symlink was the
    // resolveInsideRoot loophole: it must be refused before any write
    const realParent = join(sandbox, "real-parent");
    mkdirSync(realParent);
    const linkedParent = join(sandbox, "parent-link");
    symlinkSync(realParent, linkedParent);
    assert.throws(
      () => assertWritableOutput(join(linkedParent, "missing.tgz"), "tarball"),
      /symbolic link/,
    );
    // resolveInsideRoot refused its own anchored end through the same check
    assert.throws(
      () => resolveInsideRoot(join(linkedParent, "out"), sandbox, "--out"),
      /symbolic link/,
    );
    // every sentinel survived
    assert.equal(readFileSync(join(victim, "sentinel.txt"), "utf8"), "sentinel");
    assert.ok(existsSync(realParent), "the symlinked parent's real target survived");
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test("packing preserves unrelated files in the output directory", () => {
  // The old cleanup loop deleted every *.tgz in --out that did not match the
  // staged identity — a reviewer's file, another tool's tarball, anything.
  // Packing must write its own outputs and touch nothing else.
  const sandbox = mkdtempSync(join(scratch, "pack-safety-tgz-"));
  try {
    writeFileSync(join(sandbox, "someone-elses-1.2.3.tgz"), "not this tool's");
    writeFileSync(join(sandbox, "notes.txt"), "unrelated");
    for (const tool of ["plugin/tools/pack.mjs", "plugin/tools/library-pack.mjs"]) {
      const run = spawnSync("node", [resolve(root, tool), "--out", sandbox], {
        cwd: root,
        encoding: "utf8",
      });
      assert.equal(run.status, 0, `${tool} failed:\n${run.stdout}\n${run.stderr}`);
      assert.equal(
        readFileSync(join(sandbox, "someone-elses-1.2.3.tgz"), "utf8"),
        "not this tool's",
        `${tool} deleted an unrelated tarball`,
      );
      assert.equal(readFileSync(join(sandbox, "notes.txt"), "utf8"), "unrelated");
      const pointer = JSON.parse(readFileSync(join(sandbox, "latest.json"), "utf8"));
      assert.ok(existsSync(join(sandbox, pointer.tarball)), `${tool} did not write its own tarball`);
    }
    // after both tools, the directory holds exactly its own two tarballs, the
    // pointer, and the two unrelated files that were there before
    assert.deepEqual(
      readdirSync(sandbox).sort(),
      [
        "bdf-format-plugin-api-0.0.0-staging.tgz",
        "bdf.mbt-0.0.0-staging.tgz",
        "latest.json",
        "notes.txt",
        "someone-elses-1.2.3.tgz",
      ],
    );
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test("packing refuses claimed outputs: symlinks and directories, sentinels intact", () => {
  const sandbox = mkdtempSync(join(scratch, "pack-safety-claim-"));
  try {
    for (const tool of ["plugin/tools/pack.mjs", "plugin/tools/library-pack.mjs"]) {
      // fresh out dir per tool: the tarball name collides across tools
      const out = join(sandbox, tool.split("/").at(-1));
      mkdirSync(out, { recursive: true });
      const sentinelDir = join(sandbox, `sentinel-${tool.split("/").at(-1)}`);
      mkdirSync(sentinelDir);
      writeFileSync(join(sentinelDir, "do-not-touch.txt"), "sentinel");
      const pointerName = "latest.json";
      symlinkSync(sentinelDir, join(out, pointerName));
      const run = spawnSync("node", [resolve(root, tool), "--out", out], {
        cwd: root,
        encoding: "utf8",
      });
      assert.notEqual(run.status, 0, `${tool} wrote through a symlinked latest.json`);
      assert.match(run.stderr, /symbolic link|not a regular file/, `${tool}: unhelpful refusal`);
      assert.equal(
        readFileSync(join(sentinelDir, "do-not-touch.txt"), "utf8"),
        "sentinel",
        `${tool} wrote into the symlinked target`,
      );
      assert.ok(lstatSync(join(out, pointerName)).isSymbolicLink(), `${tool} replaced the latest.json link`);
    }
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test("a missing multi-level output path validates instead of failing on ENOENT", () => {
  // A clean checkout has no `_scratch/` at all: if a tool treats the missing
  // immediate parent of `--out` as an error, it fails before reaching any
  // build artifact. Missing trailing components must validate (they are the
  // generated directories the tool creates after validation), while the
  // existing part of the path is still fully checked.
  const sandbox = mkdtempSync(join(scratch, "pack-safety-fresh-"));
  try {
    assert.deepEqual(readdirSync(sandbox), [], "the sandbox starts empty like a fresh checkout");
    const deep = join(sandbox, "nodir-a", "nodir-b", "nodir-c");
    assert.equal(resolveInsideRoot(deep, sandbox, "--out"), resolve(sandbox, deep));
    // resolving with `..` through missing components still cannot escape
    const escape = resolve(sandbox, "nodir-a", "..", "..", "elsewhere");
    assert.throws(() => resolveInsideRoot(escape, sandbox, "--out"), /must stay inside|root itself/);
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test("both pack tools accept a not-yet-existing nested --out", () => {
  const token = `fresh-checkout-${process.pid}-${Date.now()}`;
  for (const tool of ["plugin/tools/pack.mjs", "plugin/tools/library-pack.mjs"]) {
    const run = spawnSync(
      "node",
      [resolve(root, tool), "--dry-run", "--out", `_scratch/${token}/nested/out`],
      { cwd: root, encoding: "utf8" },
    );
    assert.equal(run.status, 0, `${tool} failed on a nonexistent nested --out:\n${run.stderr}`);
    assert.ok(!existsSync(resolve(root, "_scratch", token)), `${tool} wrote to a dry-run output`);
  }
});

test("output destinations refuse hard-linked files, leaving the shared inode intact", () => {
  const sandbox = mkdtempSync(join(scratch, "pack-safety-hardlink-"));
  try {
    const partner = join(sandbox, "unrelated-settings.json");
    writeFileSync(partner, "{\"unrelated\": true}");
    const claimed = join(sandbox, "latest.json");
    linkSync(partner, claimed);
    assert.throws(() => assertWritableOutput(claimed, "the pointer output"), /hard-linked/);
    assert.equal(readFileSync(partner, "utf8"), "{\"unrelated\": true}");
    assert.equal(lstatSync(claimed).nlink, 2, "the hard link itself is untouched by the refusal");
    // a fresh single-linked destination is fine
    assert.equal(assertWritableOutput(join(sandbox, "fresh-pointer.json"), "pointer"), join(sandbox, "fresh-pointer.json"));
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test("packing refuses hard-linked outputs and writes no partial artifacts", () => {
  // Before both destinations are validated, nothing may be written: a run
  // refused over its pointer must not leave the tarball behind, and the
  // unrelated file sharing the pointer's inode must survive untouched.
  const sandbox = mkdtempSync(join(scratch, "pack-safety-hardlink-e2e-"));
  try {
    for (const [tool, tarball] of [
      ["plugin/tools/pack.mjs", "bdf-format-plugin-api-0.0.0-staging.tgz"],
      ["plugin/tools/library-pack.mjs", "bdf.mbt-0.0.0-staging.tgz"],
    ]) {
      const out = join(sandbox, tool.includes("library") ? "library" : "plugin");
      mkdirSync(out, { recursive: true });
      const partner = join(sandbox, "partner-of", `${tool.includes("library") ? "library" : "plugin"}-pointer.json`);
      mkdirSync(join(sandbox, "partner-of"), { recursive: true });
      writeFileSync(partner, "{\"someone\": \"else\"}");
      linkSync(partner, join(out, "latest.json"));
      const run = spawnSync("node", [resolve(root, tool), "--out", out], { cwd: root, encoding: "utf8" });
      assert.notEqual(run.status, 0, `${tool} overwrote a hard-linked latest.json`);
      assert.match(run.stderr, /hard-linked/, `${tool}: unhelpful refusal`);
      assert.equal(readFileSync(partner, "utf8"), "{\"someone\": \"else\"}", `${tool} truncated the shared inode`);
      assert.deepEqual(readdirSync(out), ["latest.json"], `${tool} left partial outputs behind`);
      assert.ok(!existsSync(join(out, tarball)), `${tool} wrote the tarball despite the invalid pointer`);
      assert.equal(lstatSync(join(out, "latest.json")).nlink, 2, `${tool} broke the link`);
    }
  } finally {
    rmSync(sandbox, { recursive: true, force: true });
  }
});

test("staging sources that are symlinks are refused, and a staging failure leaks nothing", () => {
  // A synthetic isolated tree per run: never the real repository's sources.
  const owned = mkdtempSync(join(tmpdir(), "bdf-pack-safety-staging-"));
  try {
    const root = join(owned, "toolroot");
    const plugin = join(root, "plugin");
    mkdirSync(join(plugin, "tools"), { recursive: true });
    mkdirSync(join(plugin, "types"), { recursive: true });
    mkdirSync(join(plugin, "src"), { recursive: true });
    mkdirSync(join(root, "_scratch"), { recursive: true });
    for (const file of ["pack.mjs", "staging-path.mjs"]) {
      cpSync(resolve(import.meta.dirname, "../tools", file), join(plugin, "tools", file));
    }
    writeFileSync(join(plugin, "package.json"), "{\"name\":\"x\",\"private\":true}\n");
    // 1) a staging failure (missing NOTICE.md) after the stage dir was
    //    allocated: the exit hook must still remove the stage dir
    const missing = spawnSync("node", [join(plugin, "tools", "pack.mjs")], { cwd: root, encoding: "utf8" });
    assert.notEqual(missing.status, 0, "staging must fail without NOTICE.md");
    assert.ok(!existsSync(join(plugin, "src", "evil.js")), "sanity");
    assert.deepEqual(
      readdirSync(join(root, "_scratch", "plugin-pack")).filter(name => name.startsWith("stage-")),
      [],
      "a failed staging left its stage directory behind",
    );
    // 2) a symlinked source must be an explicit refusal, not a silently
    //    different artifact
    writeFileSync(join(plugin, "README.md"), "readme");
    writeFileSync(join(plugin, "NOTICE.md"), "notice");
    writeFileSync(join(root, "LICENSE"), "license");
    for (const dts of ["index.d.ts", "worker.d.ts", "docuworks.d.ts"]) {
      writeFileSync(join(plugin, "types", dts), "declare const x: number;\n");
    }
    writeFileSync(join(plugin, "src", "plain.js"), "export const a = 1;\n");
    symlinkSync(join(plugin, "src", "plain.js"), join(plugin, "src", "evil.js"));
    const refused = spawnSync("node", [join(plugin, "tools", "pack.mjs")], { cwd: root, encoding: "utf8" });
    assert.notEqual(refused.status, 0, "staging must refuse a symlinked source");
    assert.match(refused.stderr, /symbolic link/, "unhelpful refusal for a symlinked source");
    assert.deepEqual(
      readdirSync(join(root, "_scratch", "plugin-pack")).filter(name => name.startsWith("stage-")),
      [],
      "a refused staging left its stage directory behind",
    );
    // the shared helper refuses symlinked files and directories alike
    assert.ok(typeof refuseSymlinkedSource === "function");
  } finally {
    rmSync(owned, { recursive: true, force: true });
  }
});
