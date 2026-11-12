// Focused parity test: `npm pack --dry-run` refuses an allowlist mismatch
// exactly like the real pack does, so a dry-run's success report is as
// trustworthy as an actual pack's. The mismatch is induced on a synthetic
// copy of the pack inputs inside a fresh mkdtemp fixture the test owns:
// nothing here touches the repository's real staging outputs, and nothing
// user-supplied names a deletion target.

import assert from "node:assert/strict";
import { test } from "node:test";
import { spawnSync } from "node:child_process";
import { cpSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");

// A synthetic pack root: the pack tool, its staging-path helper and the real
// pack inputs (src, types, manifests, notices, license), all under the test's
// own throwaway directory.
function makeFixture() {
  const owned = mkdtempSync(join(tmpdir(), "bdf-pack-dryrun-"));
  const fixture = join(owned, "repo");
  mkdirSync(join(fixture, "plugin/tools"), { recursive: true });
  mkdirSync(join(fixture, "_scratch"));
  for (const file of ["pack.mjs", "staging-path.mjs"]) {
    cpSync(resolve(root, "plugin/tools", file), join(fixture, "plugin/tools", file));
  }
  for (const part of ["src", "types", "package.json", "README.md", "NOTICE.md"]) {
    cpSync(resolve(root, "plugin", part), join(fixture, "plugin", part), { recursive: true });
  }
  cpSync(resolve(root, "LICENSE"), join(fixture, "LICENSE"));
  return { owned, fixture };
}

function dryRun(fixture) {
  return spawnSync(
    process.execPath,
    [join(fixture, "plugin/tools/pack.mjs"), "--dry-run"],
    {
      cwd: fixture,
      encoding: "utf8",
      env: {
        ...process.env,
        BDF_PLUGIN_NPM_CACHE: join(root, "_scratch/npm-cache"),
      },
    },
  );
}

test("dry-run reports the listing when it matches, and fails on a mismatch like the real pack", () => {
  const { owned, fixture } = makeFixture();
  try {
    // parity baseline: a clean tree reports and exits 0, like the real pack
    const clean = dryRun(fixture);
    assert.equal(clean.status, 0, `clean dry-run failed:\n${clean.stdout}\n${clean.stderr}`);
    assert.match(clean.stdout, /files \(\d+\):/);
    assert.doesNotMatch(clean.stdout, /allowlist mismatch/);

    // an ordinary mismatch: a nested source directory the allowlist scan
    // does not cover (the stage copies it recursively, npm packs it, the
    // allowlist has no second-level entry)
    mkdirSync(join(fixture, "plugin/src/adapters/deep"), { recursive: true });
    writeFileSync(
      join(fixture, "plugin/src/adapters/deep/extra.js"),
      "export const extra = \"a nested source the allowlist does not cover\";\n",
    );
    const mismatch = dryRun(fixture);
    assert.notEqual(mismatch.status, 0, "the dry run must fail on an allowlist mismatch");
    assert.match(mismatch.stderr, /allowlist mismatch/);
    assert.match(mismatch.stderr, /extra \[src\/adapters\/deep\/extra\.js\]/,
      "the mismatch names the extra tar entry");
  } finally {
    // the fixture's own throwaway tree only
    rmSync(owned, { recursive: true, force: true });
  }
});
