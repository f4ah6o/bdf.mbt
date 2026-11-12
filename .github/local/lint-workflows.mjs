#!/usr/bin/env node
// `actrun lint` accepts one workflow file, so lint every local verification
// workflow and fail if any of them reports an error.
//
// The manual deployment workflow is excluded: actrun 0.32.0 cannot parse a
// workflow_dispatch-only file, and that workflow is not a local verification
// definition. verify.test.mjs asserts its shape instead.
import { spawnSync } from "node:child_process";
import { readdirSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

const root = resolve(import.meta.dirname, "..", "..");
const WORKFLOW_DIR = join(root, ".github", "workflows");
const ACTRUN = join(root, "node_modules", ".bin", "actrun");
const DEPLOY_WORKFLOW = "pages-deploy.yml";

/** Every workflow file in the directory, sorted. */
export function workflowFiles(directory = WORKFLOW_DIR) {
  return readdirSync(directory)
    .filter((name) => name.endsWith(".yml") || name.endsWith(".yaml"))
    .sort()
    .map((name) => join(directory, name));
}

/** The verification workflows actrun can parse and run. */
export function verificationWorkflows(directory = WORKFLOW_DIR) {
  return workflowFiles(directory).filter((file) => !file.endsWith(DEPLOY_WORKFLOW) && !file.endsWith("npm-release.yaml"));
}

function main() {
  const files = verificationWorkflows();
  if (files.length === 0) {
    console.error(`no verification workflow files in ${WORKFLOW_DIR}`);
    process.exit(1);
  }
  console.log(`# skipping ${DEPLOY_WORKFLOW}: manual deployment, not a local gate`);
  let failed = 0;
  for (const file of files) {
    console.log(`# actrun lint ${file}`);
    const result = spawnSync(ACTRUN, ["lint", file], { cwd: root, stdio: "inherit" });
    if (result.error) throw result.error;
    if (result.status !== 0) failed += 1;
  }
  if (failed > 0) {
    console.error(`${failed} of ${files.length} workflow file(s) failed lint`);
    process.exit(1);
  }
  console.log(`${files.length} workflow file(s) linted`);
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
