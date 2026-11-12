// Deterministic tests for the local verification runner.
//
// These cover the parts that decide whether a run may be reported as a pass:
// status aggregation, empty or skipped steps, missing prerequisites, the
// retained-scope marker and the site server checks. They do not run actrun,
// MoonBit or a browser.
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

import { plan } from "./moon-test.mjs";
import { workflowFiles } from "./lint-workflows.mjs";
import {
  DEPLOY_WORKFLOW,
  GATES,
  HOSTED_ONLY,
  WORKFLOW_DIR,
  gateCommand,
  missingPrerequisites,
  overallResult,
  parseArgs,
  readJson,
  renderSummary,
  validateCiTest,
  validateHostedOnlySteps,
  validateRequiredSteps,
  validateRetainedScope,
  validateSiteServer,
} from "./verify.mjs";

const REPO_ROOT = path.resolve(import.meta.dirname, "..", "..");
const TARGETS = ["js", "wasm-gc", "native"];

function tempRunDir(t) {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "bdf-verify-test-"));
  fs.mkdirSync(path.join(dir, "tasks"), { recursive: true });
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));
  return dir;
}

function writeTaskLog(runDir, taskId, stream, text) {
  fs.writeFileSync(path.join(runDir, "tasks", `${taskId.replace("/", "__")}.${stream}.log`), text);
}

/** A run record shaped like the one actrun writes for the ci/test matrix. */
function matrixRun({ totals = {}, failed = {}, conclusions = {} } = {}) {
  const jobs = [];
  const steps = [];
  TARGETS.forEach((target, index) => {
    const jobId = `test__matrix_${index + 1}`;
    const names = [
      `moon check (${target})`,
      `moon test (${target})`,
      `assert the test run was not empty (${target})`,
      `moon build (${target})`,
    ];
    const taskIds = names.map((_, stepIndex) => `${jobId}/step_${stepIndex + 1}`);
    const total = totals[target] ?? 2817;
    const failedCount = failed[target] ?? 0;
    const messages = ["", "", `total=${total} failed=${failedCount}\n`, ""];
    jobs.push({
      id: jobId,
      steps: names.map((name, stepIndex) => ({
        name,
        conclusion: conclusions[`${target}:${name}`] ?? "success",
      })),
      task_ids: taskIds,
    });
    taskIds.forEach((taskId, stepIndex) => {
      steps.push({ id: taskId, message: messages[stepIndex] });
    });
  });
  return { run_id: "run-1", jobs, steps };
}

function writeScopeMarkers(runDir, scope) {
  TARGETS.forEach((target, index) => {
    writeTaskLog(
      runDir,
      `test__matrix_${index + 1}/step_2`,
      "stdout",
      `retained-scope: ${scope} (test fixture)\nTotal tests: 2817, passed: 2817, failed: 0.\n`,
    );
  });
}

function summaryManifest(overrides = {}) {
  return {
    result: "pass",
    repo: {
      head: "0123456789abcdef",
      branch: "main",
      dirty: false,
      statusCount: 0,
      diffHeadSha256: "",
      untracked: [],
    },
    evidenceDir: "/tmp/evidence",
    startedAt: "2026-11-10T00:00:00.000Z",
    finishedAt: "2026-11-10T00:01:00.000Z",
    exitCode: 0,
    retainedScope: { status: "pending", detail: "compat/retained-test.mjs is not present yet" },
    subset: false,
    selectedGateIds: [],
    gates: [],
    prerequisites: [],
    hostedOnly: [],
    limitations: [],
    ...overrides,
  };
}

test("overallResult never reports a partial run as a pass", () => {
  assert.deepEqual(overallResult([{ status: "pass" }, { status: "pass" }]), {
    result: "pass",
    exitCode: 0,
  });
  assert.deepEqual(overallResult([{ status: "pass" }, { status: "not-selected" }]), {
    result: "partial-pass",
    exitCode: 0,
  });
  assert.deepEqual(overallResult([{ status: "pass" }, { status: "skipped" }]), {
    result: "incomplete",
    exitCode: 2,
  });
  assert.deepEqual(overallResult([{ status: "blocked" }]), { result: "incomplete", exitCode: 2 });
  assert.deepEqual(overallResult([{ status: "not-run" }]), { result: "incomplete", exitCode: 2 });
  assert.deepEqual(overallResult([{ status: "incomplete" }]), {
    result: "incomplete",
    exitCode: 2,
  });
  assert.deepEqual(overallResult([{ status: "fail" }, { status: "skipped" }]), {
    result: "fail",
    exitCode: 1,
  });
  assert.deepEqual(overallResult([]), { result: "incomplete", exitCode: 2 });
  // A deliberately selected subset succeeds, but is not a full verification.
  assert.deepEqual(overallResult([{ status: "pass" }, { status: "not-selected" }]), {
    result: "partial-pass",
    exitCode: 0,
  });
});

test("validateRequiredSteps separates missing, skipped, failed and successful steps", () => {
  const run = {
    jobs: [
      {
        id: "build",
        steps: [
          { name: "ok", conclusion: "success" },
          { name: "skipped", conclusion: "skipped" },
          { name: "failed", conclusion: "failure" },
        ],
        task_ids: ["build/step_1", "build/step_2", "build/step_3"],
      },
    ],
    steps: [],
  };
  const statuses = new Map(
    validateRequiredSteps(run, ["ok", "skipped", "failed", "absent"]).map((check) => [
      check.id,
      check.status,
    ]),
  );
  assert.equal(statuses.get("step:ok"), "pass");
  assert.equal(statuses.get("step:skipped"), "fail");
  assert.equal(statuses.get("step:failed"), "fail");
  assert.equal(statuses.get("step:absent"), "incomplete");
});

test("validateCiTest passes when every target clears the floor", (t) => {
  const runDir = tempRunDir(t);
  writeScopeMarkers(runDir, "pending");
  const result = validateCiTest(matrixRun(), 2700, {
    runDir,
    scope: { status: "pending", detail: "pending" },
  });
  assert.equal(result.status, "pass");
  assert.deepEqual(
    result.targets.map((target) => target.total),
    [2817, 2817, 2817],
  );
  assert.deepEqual(
    result.targets.map((target) => target.scope),
    ["pending", "pending", "pending"],
  );
});

test("validateCiTest reports an empty run as incomplete, not as a pass", () => {
  const result = validateCiTest({ jobs: [] }, 2700, {});
  assert.equal(result.status, "incomplete");
  for (const target of TARGETS) {
    assert.ok(
      result.checks.some((check) => check.id === `target:${target}` && check.status === "incomplete"),
      target,
    );
  }
});

test("validateCiTest fails when a required step was skipped", (t) => {
  const runDir = tempRunDir(t);
  writeScopeMarkers(runDir, "pending");
  const result = validateCiTest(
    matrixRun({ conclusions: { "js:moon test (js)": "skipped" } }),
    2700,
    { runDir, scope: { status: "pending", detail: "pending" } },
  );
  assert.equal(result.status, "fail");
  assert.ok(
    result.checks.some((check) => check.id === "target:js:test" && check.status === "fail"),
  );
});

test("validateCiTest fails when a target is below the floor", (t) => {
  const runDir = tempRunDir(t);
  writeScopeMarkers(runDir, "pending");
  const result = validateCiTest(matrixRun({ totals: { js: 100 } }), 2700, {
    runDir,
    scope: { status: "pending", detail: "pending" },
  });
  assert.equal(result.status, "fail");
  assert.ok(
    result.checks.some(
      (check) => check.id === "target:js:count" && /expected at least 2700/.test(check.detail),
    ),
  );
});

test("validateCiTest fails when tests failed", (t) => {
  const runDir = tempRunDir(t);
  writeScopeMarkers(runDir, "pending");
  const result = validateCiTest(matrixRun({ failed: { "wasm-gc": 3 } }), 2700, {
    runDir,
    scope: { status: "pending", detail: "pending" },
  });
  assert.equal(result.status, "fail");
  assert.ok(
    result.checks.some(
      (check) => check.id === "target:wasm-gc:count" && /3 tests failed/.test(check.detail),
    ),
  );
});

test("validateCiTest fails when the run reports a different retained scope", (t) => {
  const runDir = tempRunDir(t);
  writeScopeMarkers(runDir, "pending");
  writeTaskLog(runDir, "test__matrix_1/step_2", "stdout", "retained-scope: retained (fixture)\n");
  const result = validateCiTest(matrixRun(), 2700, {
    runDir,
    scope: { status: "pending", detail: "pending" },
  });
  assert.equal(result.status, "fail");
  assert.ok(
    result.checks.some((check) => check.id === "target:js:scope" && check.status === "fail"),
  );
});

test("validateCiTest reports a missing retained-scope marker as incomplete", (t) => {
  const runDir = tempRunDir(t);
  const result = validateCiTest(matrixRun(), 2700, {
    runDir,
    scope: { status: "pending", detail: "pending" },
  });
  assert.equal(result.status, "incomplete");
  assert.ok(
    result.checks.some((check) => check.id === "target:js:scope" && check.status === "incomplete"),
  );
});

test("validateRetainedScope accepts the expected scope and rejects a mismatch", (t) => {
  const runDir = tempRunDir(t);
  const step = { taskId: "test__matrix_1/step_2" };
  writeTaskLog(runDir, step.taskId, "stdout", "retained-scope: retained (fixture)\n");
  assert.equal(
    validateRetainedScope(runDir, step, { status: "retained", detail: "retained" }).status,
    "pass",
  );
  assert.equal(
    validateRetainedScope(runDir, step, { status: "pending", detail: "pending" }).status,
    "fail",
  );
  assert.equal(
    validateRetainedScope(runDir, { taskId: "missing/step_1" }, { status: "pending" }).status,
    "incomplete",
  );
});

test("validateHostedOnlySteps accepts skipped steps and rejects forbidden ones", () => {
  const run = {
    jobs: [
      {
        id: "build",
        steps: [
          { name: "checkout", conclusion: "skipped" },
          { name: "npm ci", conclusion: "success" },
          { name: "setup Node.js", conclusion: "success" },
        ],
        task_ids: ["build/step_1", "build/step_2", "build/step_3"],
      },
    ],
    steps: [],
  };
  const statuses = new Map(
    validateHostedOnlySteps(run, {
      hostedOnlySteps: ["checkout", "npm ci", "setup Node.js", "absent"],
    }).map((check) => [check.id, check.status]),
  );
  assert.equal(statuses.get("hosted:checkout"), "pass");
  assert.equal(statuses.get("hosted:npm ci"), "fail");
  assert.equal(statuses.get("hosted:setup Node.js"), "warn");
  assert.equal(statuses.get("hosted:absent"), "note");
});

test("missingPrerequisites lists only prerequisites that are not ok", () => {
  const prereqs = new Map([
    ["node", { id: "node", status: "ok", detail: "v1" }],
    ["moon", { id: "moon", status: "missing", detail: "not installed" }],
  ]);
  assert.deepEqual(missingPrerequisites({ requires: ["node"] }, prereqs), []);
  assert.deepEqual(missingPrerequisites({ requires: ["node", "moon", "actrun"] }, prereqs), [
    "moon: not installed",
    "unknown prerequisite",
  ]);
});

test("validateSiteServer requires the step to report its own ephemeral port", (t) => {
  const runDir = tempRunDir(t);
  const run = {
    jobs: [
      {
        id: "build",
        steps: [{ name: "Validate the site with vlmkit", conclusion: "success" }],
        task_ids: ["build/ui_gates"],
      },
    ],
    steps: [],
  };
  writeTaskLog(runDir, "build/ui_gates", "stderr", "+ port=41234\n+ url=http://127.0.0.1:41234\n");
  const checks = validateSiteServer(runDir, run);
  assert.equal(checks[0].status, "pass");
  assert.match(checks[0].detail, /41234/);
});

test("validateSiteServer fails when the step checked a different port", (t) => {
  const runDir = tempRunDir(t);
  const run = {
    jobs: [
      {
        id: "build",
        steps: [{ name: "Validate the site with vlmkit", conclusion: "success" }],
        task_ids: ["build/ui_gates"],
      },
    ],
    steps: [],
  };
  writeTaskLog(runDir, "build/ui_gates", "stderr", "+ port=41234\n+ url=http://127.0.0.1:8771\n");
  assert.equal(validateSiteServer(runDir, run)[0].status, "fail");
});

test("validateSiteServer fails when the server did not come up or died", (t) => {
  const runDir = tempRunDir(t);
  const run = {
    jobs: [
      {
        id: "build",
        steps: [{ name: "Validate the site with vlmkit", conclusion: "failure" }],
        task_ids: ["build/ui_gates"],
      },
    ],
    steps: [],
  };
  writeTaskLog(
    runDir,
    "build/ui_gates",
    "stderr",
    "+ port=41234\n+ url=http://127.0.0.1:41234\nthe local site server exited before the checks finished\n",
  );
  assert.equal(validateSiteServer(runDir, run)[0].status, "fail");
});

test("validateSiteServer fails when the port was already in use", (t) => {
  const runDir = tempRunDir(t);
  const run = {
    jobs: [
      {
        id: "build",
        steps: [{ name: "Validate the site with vlmkit", conclusion: "failure" }],
        task_ids: ["build/ui_gates"],
      },
    ],
    steps: [],
  };
  writeTaskLog(runDir, "build/ui_gates", "stderr", "OSError: [Errno 98] Address already in use\n");
  assert.equal(validateSiteServer(runDir, run)[0].status, "fail");
});

test("validateSiteServer reports a missing step as incomplete", () => {
  const checks = validateSiteServer("/tmp/does-not-exist", { jobs: [], steps: [] });
  assert.equal(checks[0].status, "incomplete");
});

test("renderSummary marks a dry run as not a verification result", () => {
  const text = renderSummary(summaryManifest({ result: "dry-run", exitCode: 0 }));
  assert.match(text, /DRY RUN — NOT A VERIFICATION RESULT/);
  assert.doesNotMatch(text, /# Local verification — PASS/);
});

test("renderSummary shows an incomplete run and its exit code", () => {
  const text = renderSummary(summaryManifest({ result: "incomplete", exitCode: 2 }));
  assert.match(text, /# Local verification — INCOMPLETE/);
  assert.match(text, /- Exit code: 2/);
});

test("renderSummary records a pending retained scope", () => {
  const text = renderSummary(summaryManifest());
  assert.match(text, /- Retained scope: pending \(integration pending\)/);
});

test("readJson tolerates the raw control characters actrun writes", (t) => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "bdf-verify-json-"));
  t.after(() => fs.rmSync(dir, { recursive: true, force: true }));

  const clean = path.join(dir, "clean.json");
  fs.writeFileSync(clean, JSON.stringify({ ok: true }));
  assert.deepEqual(readJson(clean), { ok: true });

  const ansi = path.join(dir, "ansi.json");
  fs.writeFileSync(ansi, '{"message":"\u001b[31mDEFECTS\u001b[0m"}');
  assert.deepEqual(readJson(ansi), { message: "DEFECTS" });

  const broken = path.join(dir, "broken.json");
  fs.writeFileSync(broken, "{not json");
  assert.throws(() => readJson(broken), /cannot parse/);
});

test("parseArgs splits gate lists and rejects unknown options", () => {
  const options = parseArgs(["--only", "ci/test,parity", "--skip", "visual", "--keep-going"]);
  assert.deepEqual(options.only, ["ci/test", "parity"]);
  assert.deepEqual(options.skip, ["visual"]);
  assert.equal(options.keepGoing, true);
  assert.throws(() => parseArgs(["--nope"]), /unknown option/);
  assert.throws(() => parseArgs(["--only"]), /missing value/);
});

test("gateCommand runs the local workflow definitions through actrun", () => {
  const gate = GATES.find((item) => item.id === "ci/test");
  const { command, args } = gateCommand(gate, {
    runRoot: "/tmp/runs",
    artifactRoot: "/tmp/artifacts",
  });
  assert.match(command, /actrun$/);
  assert.equal(args[0], "workflow");
  assert.equal(args[1], "run");
  assert.equal(args[2], `${WORKFLOW_DIR}/ci.yml`);
  assert.ok(args.includes("--local"));
  assert.ok(args.includes("--no-nix"));
  assert.ok(!args.includes("--ref"));
  assert.ok(args.includes("actions/checkout@v4"));
});

test("every actrun gate points at a workflow file that exists", () => {
  for (const gate of GATES.filter((item) => item.kind === "actrun")) {
    assert.ok(fs.existsSync(path.join(REPO_ROOT, gate.workflow)), gate.workflow);
  }
});

function onBlockOf(file) {
  const text = fs.readFileSync(file, "utf8");
  return /^on:\n((?:[ \t].*\n|\n)*)/m.exec(text)?.[1] ?? "";
}

test("only deployment and release workflows are dispatchable", () => {
  const dispatchable = workflowFiles().filter((file) => /workflow_dispatch/.test(onBlockOf(file)));
  assert.deepEqual(
    dispatchable.map((file) => path.basename(file)),
    ["npm-release.yaml", "pages-deploy.yml"],
  );
});

test("verification workflows are inert on GitHub", () => {
  const verification = workflowFiles().filter(
    (file) => !["pages-deploy.yml", "npm-release.yaml"].includes(path.basename(file)),
  );
  assert.equal(verification.length, 4);
  for (const file of verification) {
    const onBlock = onBlockOf(file);
    assert.doesNotMatch(onBlock, /workflow_dispatch|pull_request|schedule/, path.basename(file));
    assert.match(onBlock, /push:/, path.basename(file));
    assert.match(onBlock, /branches-ignore: \['\*\*'\]/, path.basename(file));
    assert.doesNotMatch(onBlock, /branches:/, path.basename(file));
  }
});

test("the deployment workflow only builds, uploads and deploys", () => {
  const file = path.join(REPO_ROOT, DEPLOY_WORKFLOW);
  const text = fs.readFileSync(file, "utf8");
  const onBlock = onBlockOf(file);
  assert.match(onBlock, /workflow_dispatch/);
  assert.doesNotMatch(onBlock, /push|pull_request|schedule/);
  assert.doesNotMatch(
    text,
    /npm run test|moon test|vlmkit|bench:site|test:site|test:previews|probe-overflow/,
  );
  assert.match(text, /pages: write/);
  assert.match(text, /id-token: write/);
  assert.match(text, /cancel-in-progress: false/);
  assert.match(text, /actions\/upload-pages-artifact@v3/);
  assert.match(text, /actions\/deploy-pages@v4/);
});

test("no local gate targets the deployment workflow", () => {
  for (const gate of GATES) {
    assert.notEqual(gate.workflow, DEPLOY_WORKFLOW, gate.id);
    if (gate.kind !== "actrun") continue;
    const { args } = gateCommand(gate, { runRoot: "/tmp/runs", artifactRoot: "/tmp/artifacts" });
    assert.ok(!args.some((arg) => arg.includes("pages-deploy")), gate.id);
  }
});

test("HOSTED_ONLY records the deployment as unsupported", () => {
  const deploy = HOSTED_ONLY.find((item) => item.id === "pages/deploy");
  assert.ok(deploy);
  assert.equal(deploy.workflow, DEPLOY_WORKFLOW);
  assert.equal(deploy.status, "unsupported");
});

test("moon-test plan delegates to the retained helper when it exists", () => {
  const retained = plan("js", { retainedHelper: true });
  assert.equal(retained.scope, "retained");
  assert.match(retained.marker, /^retained-scope: retained/);
  assert.equal(retained.args.at(-1), "js");

  const pending = plan("wasm-gc", { retainedHelper: false });
  assert.equal(pending.scope, "pending");
  assert.match(pending.marker, /^retained-scope: pending/);
  assert.deepEqual(pending.args, ["test", "--target", "wasm-gc"]);

  assert.throws(() => plan(undefined, { retainedHelper: false }), /usage/);
});

test("workflowFiles lists the local workflow definitions", () => {
  assert.deepEqual(
    workflowFiles().map((file) => path.basename(file)),
    ["ci.yml", "npm-release.yaml", "pages-deploy.yml", "pages.yml", "parity.yml", "visual.yml"],
  );
});

test("verification workflows never run a bare moon check, build or test", () => {
  for (const file of workflowFiles()) {
    if (path.basename(file) === "npm-release.yaml") continue; // release-only explicit build packages
    const text = fs.readFileSync(file, "utf8");
    for (const line of text.split("\n")) {
      const command = line.trim().replace(/^run:\s*/, "");
      if (!/^moon (check|build|test)\b/.test(command)) continue;
      assert.fail(`${path.basename(file)} runs a bare moon command: ${line.trim()}`);
    }
  }
});

test("package scripts route check, build and test through the retained selector", () => {
  const scripts = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "package.json"), "utf8")).scripts;
  assert.match(scripts["test:visual"], /node compat\/retained-test\.mjs --mode build js/);
  assert.match(scripts["build:site"], /^node compat\/retained-test\.mjs --mode build --release js &&/);
  assert.match(scripts["test:prepush:quick"], /--mode check js/);
  assert.match(scripts["test:prepush:quick"], /--mode check wasm-gc/);
  assert.match(scripts["test:prepush:quick"], /retained-test\.mjs js/);
  assert.match(scripts["test:prepush:quick"], /retained-test\.mjs wasm-gc/);
  for (const name of ["test:visual", "build:site", "test:prepush:quick"]) {
    assert.doesNotMatch(scripts[name], /(^|&& )moon (check|build|test) --target/, name);
  }
  assert.match(scripts["test:local-verify"], /compat\/retained-test\.test\.mjs/);
});

test("the self-test gate runs the runner and retained-selection tests", () => {
  const gate = GATES.find((item) => item.id === "self-test");
  assert.ok(gate.command.some((arg) => arg.endsWith("verify.test.mjs")));
  assert.ok(gate.command.some((arg) => arg.endsWith("retained-test.test.mjs")));
});
