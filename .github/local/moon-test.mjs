#!/usr/bin/env node
// Run `moon test` for one target over the maintained scope.
//
// PCB/KiCad, musical score and EPUB were dropped from the porting scope. The
// compat/retained-test.mjs selects the retained packages; when
// it is present this delegates to it, so the dormant packages are not required
// to pass. Until it lands this runs the full suite and prints
// `retained-scope: pending`, so a partial scope is never reported as retained
// coverage.
//
//   node .github/local/moon-test.mjs js
import { spawnSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const root = resolve(import.meta.dirname, "..", "..");
const RETAINED_HELPER = join(root, "compat", "retained-test.mjs");

/** What to run for `target`, given whether the retained-scope helper exists. */
export function plan(target, { retainedHelper = existsSync(RETAINED_HELPER) } = {}) {
  if (!target) throw new Error("usage: node .github/local/moon-test.mjs <target>");
  if (retainedHelper) {
    return {
      scope: "retained",
      command: process.execPath,
      args: [RETAINED_HELPER, target],
      marker: `retained-scope: retained (compat/retained-test.mjs, target ${target})`,
    };
  }
  return {
    scope: "pending",
    command: "moon",
    args: ["test", "--target", target],
    marker:
      "retained-scope: pending (compat/retained-test.mjs is not present; " +
      "this run includes the dormant PCB, score and EPUB packages)",
  };
}

function main() {
  const selected = plan(process.argv[2]);
  console.log(selected.marker);
  const result = spawnSync(selected.command, selected.args, { cwd: root, stdio: "inherit" });
  if (result.error) throw result.error;
  process.exit(result.status ?? 1);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
