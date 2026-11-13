#!/usr/bin/env node
// Local verification for bdf.mbt.
//
// Runs the workflow definitions in .github/workflows through actrun in the
// current worktree, checks the steps that are quality gates, and writes a
// manifest, logs and actrun run records under _scratch/local-verify/. The
// workflows are inert on GitHub (push with branches-ignore ['**'], no manual
// trigger). Hosted-only steps are skipped by the workflows themselves and
// reported here; they are never counted as passes.
//
// Exit codes:
//   0  every selected gate passed (or --dry-run / --list / --help)
//   1  at least one gate failed
//   2  a gate was blocked by a missing prerequisite, a required step was
//      missing/skipped, or --skip excluded a gate from the full run
//
// A dry run is not a verification result. It writes result "dry-run" and says
// so in the summary.

import { spawn, execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..');
const WORKFLOW_DIR = '.github/workflows';
const DEPLOY_WORKFLOW = `${WORKFLOW_DIR}/pages-deploy.yml`;
const ACTRUN = path.join(REPO_ROOT, 'node_modules', '.bin', 'actrun');
const VLMKIT = path.join(REPO_ROOT, 'node_modules', '.bin', 'vlmkit');
const DEFAULT_EVIDENCE_ROOT = path.join(REPO_ROOT, '_scratch', 'local-verify');
const MIN_TEST_COUNT_FALLBACK = 2700;
const RETAINED_HELPER = path.join(REPO_ROOT, 'compat', 'retained-test.mjs');

const GATES = [
  {
    id: 'self-test',
    title: 'Local runner self-tests',
    workflow: null,
    job: null,
    description: 'node --test over the runner status, step, prerequisite, server and retained-selection checks',
    requires: ['node'],
    kind: 'command',
    command: [
      process.execPath,
      '--test',
      path.join(REPO_ROOT, '.github', 'local', 'verify.test.mjs'),
      path.join(REPO_ROOT, 'compat', 'retained-test.test.mjs'),
    ],
    requiredSteps: [],
    hostedOnlySteps: [],
  },
  {
    id: 'workflow-lint',
    title: 'Workflow lint',
    workflow: null,
    job: null,
    description: `actrun lint over ${WORKFLOW_DIR}`,
    requires: ['node', 'actrun'],
    kind: 'command',
    command: [process.execPath, path.join(REPO_ROOT, '.github', 'local', 'lint-workflows.mjs')],
    requiredSteps: [],
    hostedOnlySteps: [],
  },
  {
    id: 'ci/test',
    title: 'MoonBit check, test and build (js, wasm-gc, native)',
    workflow: `${WORKFLOW_DIR}/ci.yml`,
    job: 'test',
    description:
      'moon check/test/build for all three targets, including the min-test-count assertion',
    requires: ['node', 'moon', 'moonc', 'mooncakes', 'bash'],
    kind: 'actrun',
    requiredSteps: [],
    hostedOnlySteps: ['checkout', 'setup MoonBit', 'moon update'],
    targetMatrix: ['js', 'wasm-gc', 'native'],
  },
  {
    id: 'ci/demo',
    title: 'Demo build, browser tests and gallery previews',
    workflow: `${WORKFLOW_DIR}/ci.yml`,
    job: 'demo',
    description:
      'verify-samples, build:demo, test:demo and test:previews',
    requires: [
      'node',
      'npm',
      'moon',
      'moonc',
      'mooncakes',
      'node_modules',
      'playwright',
      'chromium',
      'bash',
      'site_samples',
    ],
    kind: 'actrun',
    requiredSteps: ['verify samples', 'build demo', 'test demo', 'test previews'],
    hostedOnlySteps: [
      'checkout',
      'setup Node.js',
      'setup MoonBit',
      'moon update',
      'npm ci',
      'install Playwright Chromium',
    ],
  },
  {
    id: 'parity',
    title: 'Document parity with upstream',
    workflow: `${WORKFLOW_DIR}/parity.yml`,
    job: 'parity',
    description: 'moon build --target js and compat/parity/verify.mjs --limit=100',
    requires: [
      'node',
      'npm',
      'moon',
      'moonc',
      'mooncakes',
      'node_modules',
      'playwright',
      'chromium',
      'bash',
      'parity_fixtures',
    ],
    kind: 'actrun',
    requiredSteps: ['build JavaScript target', 'compare with upstream'],
    hostedOnlySteps: [
      'checkout',
      'setup Node.js',
      'setup MoonBit',
      'moon update',
      'npm ci',
      'install Playwright Chromium',
    ],
  },
  {
    id: 'visual',
    title: 'Visual compatibility',
    workflow: `${WORKFLOW_DIR}/visual.yml`,
    job: 'compare',
    description:
      'XLSX picture rendering and npm run test:visual',
    requires: [
      'node',
      'npm',
      'moon',
      'moonc',
      'mooncakes',
      'node_modules',
      'playwright',
      'chromium',
      'bash',
      'visual_fixture',
      'xlsx_oracle',
    ],
    kind: 'actrun',
    requiredSteps: ['test XLSX picture rendering', 'test visual compatibility'],
    hostedOnlySteps: [
      'checkout',
      'setup Node.js',
      'setup MoonBit',
      'moon update',
      'npm ci',
      'install Playwright Chromium',
    ],
  },
  {
    id: 'site',
    title: 'Site build, tests, previews, benchmarks and vlmkit',
    workflow: `${WORKFLOW_DIR}/pages.yml`,
    job: 'build',
    description:
      'build:site, test:site, test:previews, bench:site --check and the vlmkit checks',
    requires: [
      'node',
      'npm',
      'moon',
      'moonc',
      'mooncakes',
      'node_modules',
      'playwright',
      'chromium',
      'python3',
      'vlmkit',
      'bash',
      'site_copy',
      'site_samples',
    ],
    kind: 'actrun',
    requiredSteps: [
      'Build the site (bdf.mbt in JavaScript and wasm-gc)',
      'Test the site',
      'Check the gallery previews and the sample checksums',
      'Check the committed benchmarks still hold',
      'Validate the site with vlmkit',
    ],
    hostedOnlySteps: [
      'checkout',
      'setup Node.js',
      'setup MoonBit',
      'moon update',
      'npm ci',
      'install Playwright Chromium',
      'upload Pages artifact',
      'Check whether Pages is configured for Actions',
    ],
  },
];

const HOSTED_ONLY = [
  {
    id: 'pages/deploy',
    title: 'GitHub Pages deployment',
    workflow: DEPLOY_WORKFLOW,
    job: 'deploy',
    status: 'unsupported',
    reason:
      'The separate manual workflow pages-deploy.yml requires the GitHub-hosted Pages service, actions/deploy-pages, the github-pages environment and network access. It is workflow_dispatch only and the local flow never runs or dispatches it.',
  },
  {
    id: 'pages/artifact',
    title: 'Pages artifact upload',
    workflow: DEPLOY_WORKFLOW,
    job: 'deploy',
    status: 'unsupported',
    reason:
      'actions/upload-pages-artifact packages _build/pages inside the manual deployment workflow. The local flow never uploads a Pages artifact.',
  },
  {
    id: 'hosted/setup',
    title: 'Hosted runner setup',
    workflow: 'all',
    job: 'all',
    status: 'unsupported',
    reason:
      'actions/checkout, actions/setup-node, hustcer/setup-moonbit, moon update, npm ci and npx playwright install --with-deps are skipped locally. The flow uses the current worktree, the installed Node and MoonBit toolchains, node_modules, .mooncakes and the installed Playwright Chromium.',
  },
];

const FORBIDDEN_LOCAL_STEPS = new Set([
  'npm ci',
  'moon update',
  'install Playwright Chromium',
  'upload Pages artifact',
  'Deploy to GitHub Pages',
]);

const USAGE = `Usage: node .github/local/verify.mjs [options]

Run the repository's workflow definitions locally through actrun and retain
evidence under _scratch/local-verify/. The workflows never run on GitHub.

Options:
  --only <ids>          Comma-separated gate ids to run (default: all)
  --skip <ids>          Comma-separated gate ids to exclude; the result is
                        "incomplete" because the full suite did not run
  --keep-going          Continue after a failing gate (default: stop)
  --dry-run             Print the plan and write a dry-run manifest; no gate
                        is executed and the result is never "pass"
  --evidence-dir <dir>  Evidence directory (default: _scratch/local-verify/<utc>-<sha>[-dirty])
  --force               Allow an existing non-empty evidence directory
  --timeout <seconds>   Per-gate timeout (default: 0, no runner timeout)
  --list                List gate ids and exit
  --help                Show this help

Exit codes:
  0  every selected gate passed (or --dry-run / --list / --help)
  1  at least one gate failed
  2  a gate was blocked, incomplete, or excluded with --skip

Examples:
  npm run verify:local
  npm run verify:local:plan
  npm run verify:local:ci
  node .github/local/verify.mjs --only ci/test --keep-going
`;

function parseArgs(argv) {
  const options = {
    only: null,
    skip: null,
    keepGoing: false,
    dryRun: false,
    evidenceDir: null,
    force: false,
    timeoutSeconds: 0,
    list: false,
    help: false,
  };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => {
      i += 1;
      if (i >= argv.length) throw new Error(`missing value for ${arg}`);
      return argv[i];
    };
    switch (arg) {
      case '--only':
        options.only = next().split(',').map((s) => s.trim()).filter(Boolean);
        break;
      case '--skip':
        options.skip = next().split(',').map((s) => s.trim()).filter(Boolean);
        break;
      case '--keep-going':
        options.keepGoing = true;
        break;
      case '--dry-run':
        options.dryRun = true;
        break;
      case '--evidence-dir':
        options.evidenceDir = next();
        break;
      case '--force':
        options.force = true;
        break;
      case '--timeout':
        options.timeoutSeconds = Number(next());
        if (!Number.isFinite(options.timeoutSeconds) || options.timeoutSeconds < 0) {
          throw new Error('--timeout must be a non-negative number of seconds');
        }
        break;
      case '--list':
        options.list = true;
        break;
      case '--help':
      case '-h':
        options.help = true;
        break;
      default:
        throw new Error(`unknown option: ${arg}`);
    }
  }
  return options;
}

function shellQuote(arg) {
  if (/^[A-Za-z0-9_./:=@+-]+$/.test(arg)) return arg;
  return `'${String(arg).replace(/'/g, `'\\''`)}'`;
}

function commandLine(command, args) {
  return [command, ...args].map(shellQuote).join(' ');
}

function sha256(text) {
  return createHash('sha256').update(text).digest('hex');
}

function formatDuration(ms) {
  if (ms === null || ms === undefined) return '—';
  if (ms < 1000) return `${ms}ms`;
  const seconds = Math.round(ms / 1000);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  if (minutes < 60) return `${minutes}m${rest.toString().padStart(2, '0')}s`;
  const hours = Math.floor(minutes / 60);
  return `${hours}h${(minutes % 60).toString().padStart(2, '0')}m`;
}

function utcStamp(date = new Date()) {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}

function shortSha(sha) {
  return sha ? sha.slice(0, 12) : 'unknown';
}

function execText(command, args, options = {}) {
  return execFileSync(command, args, {
    cwd: REPO_ROOT,
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe'],
    timeout: 30000,
    maxBuffer: 64 * 1024 * 1024,
    ...options,
  }).trim();
}

function tryExecText(command, args, options = {}) {
  try {
    return { ok: true, text: execText(command, args, options) };
  } catch (error) {
    const stderr = error.stderr ? String(error.stderr).trim() : '';
    const stdout = error.stdout ? String(error.stdout).trim() : '';
    return {
      ok: false,
      text: stdout || stderr || error.message,
      code: error.status ?? null,
    };
  }
}

function readJson(file) {
  const text = fs.readFileSync(file, 'utf8');
  try {
    return JSON.parse(text);
  } catch (error) {
    // actrun copies step output into the run record verbatim, so ANSI escapes
    // from tools like vlmkit end up as raw control characters and the file is
    // not valid JSON. Strip them and retry once.
    const sanitized = text
      .replace(/\u001b\[[0-9;?]*[ -/]*[@-~]/g, '')
      .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, '');
    try {
      return JSON.parse(sanitized);
    } catch {
      throw new Error(`cannot parse ${file}: ${error.message}`);
    }
  }
}

function readPackageVersion(packageName) {
  const file = path.join(REPO_ROOT, 'node_modules', packageName, 'package.json');
  if (!fs.existsSync(file)) return null;
  try {
    return readJson(file).version ?? null;
  } catch {
    return null;
  }
}

function collectGitState() {
  const head = execText('git', ['rev-parse', 'HEAD']);
  const branch = tryExecText('git', ['branch', '--show-current']).text;
  const status = tryExecText('git', ['status', '--porcelain=v1', '--untracked-files=all']).text;
  const diff = tryExecText('git', ['diff', '--binary']).text;
  const diffCached = tryExecText('git', ['diff', '--cached', '--binary']).text;
  const diffHead = tryExecText('git', ['diff', '--binary', 'HEAD']).text;
  const diffStat = tryExecText('git', ['diff', '--stat', 'HEAD']).text;
  const untracked = tryExecText('git', ['ls-files', '--others', '--exclude-standard']).text
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);
  const commit = tryExecText('git', ['log', '-1', '--format=%H%n%an%n%ae%n%ad%n%s']).text;
  const describe = tryExecText('git', ['describe', '--always', '--dirty', '--tags']).text;
  const before = tryExecText('git', ['rev-parse', 'HEAD^']).text;
  const statusLines = status.split('\n').filter(Boolean);
  return {
    root: REPO_ROOT,
    head,
    branch,
    before: before || null,
    describe: describe || null,
    commit,
    dirty: statusLines.length > 0,
    status,
    statusLines,
    statusCount: statusLines.length,
    diff,
    diffCached,
    diffHead,
    diffStat,
    untracked,
    diffSha256: sha256(diff),
    diffCachedSha256: sha256(diffCached),
    diffHeadSha256: sha256(diffHead),
  };
}

function collectEnvironment() {
  const moonVersion = tryExecText('moon', ['version', '--all']);
  const moonLines = moonVersion.text.split('\n').filter(Boolean);
  const findLine = (prefix) => moonLines.find((line) => line.startsWith(prefix)) ?? null;
  const chromium = tryExecText(process.execPath, [
    '--input-type=module',
    '-e',
    "import { chromium } from 'playwright'; import fs from 'node:fs'; const p = chromium.executablePath(); console.log(p); process.exit(fs.existsSync(p) ? 0 : 1);",
  ]);
  return {
    platform: `${os.platform()} ${os.release()} ${os.arch()}`,
    hostname: os.hostname(),
    cpus: os.cpus().length,
    totalMemoryBytes: os.totalmem(),
    node: process.version,
    npm: tryExecText('npm', ['--version']).text,
    git: tryExecText('git', ['--version']).text,
    bash: tryExecText('bash', ['--version']).text.split('\n')[0],
    python3: tryExecText('python3', ['--version']).text,
    moon: findLine('moon '),
    moonc: findLine('moonc '),
    moonrun: findLine('moonrun '),
    moonVersionAll: moonVersion.text,
    actrun: readPackageVersion('@mizchi/actrun'),
    vlmkit: readPackageVersion('@mizchi/vlmkit'),
    playwright: readPackageVersion('playwright'),
    chromiumPath: chromium.ok ? chromium.text.split('\n').pop() : null,
    chromiumInstalled: chromium.ok,
    gh: tryExecText('gh', ['--version']).text.split('\n')[0] || null,
    curl: tryExecText('curl', ['--version']).text.split('\n')[0] || null,
    docker: tryExecText('docker', ['--version']).text || null,
    nix: tryExecText('nix', ['--version']).text || null,
  };
}

async function probeXlsxOracle(build, emulator) {
  const binary = path.join(build, 'xlsx-oracle.test');
  const args = ['-test.list=^$'];
  if (emulator) args.unshift(binary);
  await new Promise((resolve, reject) => {
    const child = spawn(emulator ?? binary, args, {
      cwd: path.join(build, 'runtime/xlsx'), stdio: 'ignore', timeout: 15000,
      env: { ...process.env, GOMAXPROCS: '2', GODEBUG: '', TZ: 'UTC', LC_ALL: 'C' },
    });
    child.once('error', reject);
    child.once('close', (code, signal) => code === 0 ? resolve() : reject(new Error(`oracle execution probe failed (code=${code}, signal=${signal})`)));
  });
}

async function checkXlsxOraclePrerequisite({ env = process.env, platform = process.platform, arch = process.arch, validate, probe = probeXlsxOracle } = {}) {
  const id = 'xlsx_oracle';
  const build = env.BDF_XLSX_ORACLE_BUILD;
  const emulator = env.BDF_XLSX_ORACLE_EMULATOR;
  const guide = 'see compat/xlsx/oracle/README.md';
  const result = (status, detail) => ({ id, status, detail, required: true });
  if (!build) return result('missing', `BDF_XLSX_ORACLE_BUILD is not set; ${guide}`);
  if (!emulator && (platform !== 'linux' || arch !== 'arm64')) {
    return result('missing', `BDF_XLSX_ORACLE_EMULATOR is required outside native Linux ARM64; ${guide}`);
  }
  const buildPath = path.resolve(REPO_ROOT, build);
  const emulatorPath = emulator ? path.resolve(REPO_ROOT, emulator) : null;
  try {
    await fsp.access(emulatorPath ?? path.join(buildPath, 'xlsx-oracle.test'), fs.constants.X_OK);
    const validateBuild = validate ?? (await import('../../compat/xlsx/oracle/generate.mjs')).validateBuild;
    await validateBuild(buildPath, emulatorPath);
    await probe(buildPath, emulatorPath);
  } catch (error) {
    const message = String(error.message ?? error).split('\n')[0];
    return result('missing', `invalid or inaccessible XLSX oracle build/emulator: ${message}; ${guide}`);
  }
  return result('ok', `verified build ${buildPath}; ${emulatorPath ? `verified emulator ${emulatorPath}` : 'native Linux ARM64'}`);
}

async function checkPrerequisites(environment) {
  const checks = [];
  const add = (id, status, detail, required = true) => {
    checks.push({ id, status, detail, required });
  };

  add('git', tryExecText('git', ['--version']).ok ? 'ok' : 'missing', environment.git);
  const nodeMajor = Number(process.versions.node.split('.')[0]);
  add(
    'node',
    nodeMajor >= 24 ? 'ok' : 'missing',
    `${process.version}${nodeMajor >= 24 ? '' : ' (Node 24 or newer is required by the workflows)'}`,
  );
  add('npm', tryExecText('npm', ['--version']).ok ? 'ok' : 'missing', environment.npm);
  add('bash', tryExecText('bash', ['--version']).ok ? 'ok' : 'missing', environment.bash);
  add('python3', tryExecText('python3', ['--version']).ok ? 'ok' : 'missing', environment.python3);

  const moonOk = Boolean(environment.moon && environment.moonc);
  add('moon', moonOk ? 'ok' : 'missing', environment.moon ?? 'moon not found');
  add('moonc', environment.moonc ? 'ok' : 'missing', environment.moonc ?? 'moonc not found');

  const mooncakes = path.join(REPO_ROOT, '.mooncakes');
  const mooncakesOk = fs.existsSync(mooncakes) && fs.readdirSync(mooncakes).length > 0;
  add(
    'mooncakes',
    mooncakesOk ? 'ok' : 'missing',
    mooncakesOk
      ? `${mooncakes} (${fs.readdirSync(mooncakes).length} entries)`
      : `${mooncakes} is missing or empty; run "moon update" once with network access`,
  );

  const nodeModules = path.join(REPO_ROOT, 'node_modules');
  add(
    'node_modules',
    fs.existsSync(nodeModules) ? 'ok' : 'missing',
    fs.existsSync(nodeModules)
      ? nodeModules
      : `${nodeModules} is missing; run "npm ci" once with network access`,
  );

  add(
    'actrun',
    fs.existsSync(ACTRUN) ? 'ok' : 'missing',
    fs.existsSync(ACTRUN)
      ? `${ACTRUN} (${environment.actrun ?? 'unknown version'})`
      : `${ACTRUN} is missing; run "npm ci" once with network access`,
  );
  add(
    'vlmkit',
    fs.existsSync(VLMKIT) ? 'ok' : 'missing',
    fs.existsSync(VLMKIT)
      ? `${VLMKIT} (${environment.vlmkit ?? 'unknown version'})`
      : `${VLMKIT} is missing; run "npm ci" once with network access`,
  );
  add(
    'playwright',
    fs.existsSync(path.join(nodeModules, 'playwright')) ? 'ok' : 'missing',
    path.join(nodeModules, 'playwright'),
  );
  add(
    'chromium',
    environment.chromiumInstalled ? 'ok' : 'missing',
    environment.chromiumInstalled
      ? environment.chromiumPath
      : 'Playwright Chromium is not installed; run "npx playwright install chromium" once with network access',
  );

  const fileChecks = [
    ['site_copy', path.join(REPO_ROOT, 'site', 'copy.txt')],
    ['site_samples', path.join(REPO_ROOT, 'site', 'samples')],
    ['parity_fixtures', path.join(REPO_ROOT, 'compat', 'parity', 'fixtures')],
    ['visual_fixture', path.join(REPO_ROOT, 'compat', 'visual', 'fixture.bdf')],
  ];
  for (const [id, file] of fileChecks) {
    add(id, fs.existsSync(file) ? 'ok' : 'missing', file);
  }
  checks.push(await checkXlsxOraclePrerequisite());

  add('gh', environment.gh ? 'ok' : 'optional', environment.gh ?? 'not installed (hosted-only)', false);
  add('curl', environment.curl ? 'ok' : 'optional', environment.curl ?? 'not installed (hosted-only)', false);
  add('docker', environment.docker ? 'ok' : 'optional', environment.docker ?? 'not installed (not used)', false);
  add('nix', environment.nix ? 'ok' : 'optional', environment.nix ?? 'not installed (--no-nix)', false);

  return checks;
}

function prerequisiteMap(checks) {
  return new Map(checks.map((check) => [check.id, check]));
}

function missingPrerequisites(gate, prereqs) {
  return gate.requires
    .map((id) => prereqs.get(id))
    .filter((check) => !check || check.status !== 'ok')
    .map((check) => (check ? `${check.id}: ${check.detail}` : 'unknown prerequisite'));
}

function readMinTestCount() {
  const file = path.join(REPO_ROOT, WORKFLOW_DIR, 'ci.yml');
  try {
    const text = fs.readFileSync(file, 'utf8');
    const match = /-lt\s+(\d+)/.exec(text);
    if (match) return { value: Number(match[1]), source: file };
  } catch {
    // fall through
  }
  return { value: MIN_TEST_COUNT_FALLBACK, source: 'fallback' };
}

function jobStepMap(run, job) {
  const map = new Map();
  const flatById = new Map((run.steps ?? []).map((step) => [step.id, step]));
  (job.steps ?? []).forEach((step, index) => {
    const taskId = (job.task_ids ?? [])[index];
    const flat = taskId ? flatById.get(taskId) : null;
    map.set(step.name, {
      ...step,
      taskId: taskId ?? null,
      message: flat?.message ?? '',
    });
  });
  return map;
}

function allJobSteps(run) {
  const map = new Map();
  for (const job of run.jobs ?? []) {
    for (const [name, step] of jobStepMap(run, job)) {
      if (!map.has(name)) map.set(name, { ...step, jobId: job.id });
    }
  }
  return map;
}

function validateRequiredSteps(run, requiredSteps) {
  const checks = [];
  const steps = allJobSteps(run);
  for (const name of requiredSteps) {
    const step = steps.get(name);
    if (!step) {
      checks.push({
        id: `step:${name}`,
        status: 'incomplete',
        detail: 'required step is missing from the actrun run record',
      });
    } else if (step.conclusion === 'skipped') {
      checks.push({
        id: `step:${name}`,
        status: 'fail',
        detail: 'required quality-gate step was skipped',
      });
    } else if (step.conclusion !== 'success') {
      checks.push({
        id: `step:${name}`,
        status: 'fail',
        detail: `step concluded ${step.conclusion}`,
      });
    } else {
      checks.push({
        id: `step:${name}`,
        status: 'pass',
        detail: 'step succeeded',
      });
    }
  }
  return checks;
}

function validateCiTest(run, minTestCount, { runDir, scope } = {}) {
  const checks = [];
  const targets = new Map();
  const expected = ['js', 'wasm-gc', 'native'];

  for (const job of run.jobs ?? []) {
    if (!job.id.startsWith('test__matrix_')) continue;
    const steps = jobStepMap(run, job);
    let target = null;
    for (const name of steps.keys()) {
      const match = /^moon check \((.+)\)$/.exec(name);
      if (match) {
        target = match[1];
        break;
      }
    }
    if (!target) {
      checks.push({
        id: `job:${job.id}`,
        status: 'incomplete',
        detail: 'no "moon check (<target>)" step in the run record',
      });
      continue;
    }
    const entry = {
      target,
      job: job.id,
      steps: {},
      total: null,
      failed: null,
    };
    for (const [name, step] of steps) {
      if (name === `moon check (${target})`) entry.steps.check = step;
      if (name === `moon test (${target})`) entry.steps.test = step;
      if (name === `assert the test run was not empty (${target})`) entry.steps.assert = step;
      if (name === `moon build (${target})`) entry.steps.build = step;
    }
    for (const key of ['check', 'test', 'assert', 'build']) {
      const step = entry.steps[key];
      if (!step) {
        checks.push({
          id: `target:${target}:${key}`,
          status: 'incomplete',
          detail: `missing ${key} step`,
        });
      } else if (step.conclusion === 'skipped') {
        checks.push({
          id: `target:${target}:${key}`,
          status: 'fail',
          detail: `${key} step was skipped`,
        });
      } else if (step.conclusion !== 'success') {
        checks.push({
          id: `target:${target}:${key}`,
          status: 'fail',
          detail: `${key} step concluded ${step.conclusion}`,
        });
      } else {
        checks.push({
          id: `target:${target}:${key}`,
          status: 'pass',
          detail: `${key} step succeeded`,
        });
      }
    }
    const assertStep = entry.steps.assert;
    if (assertStep) {
      const match = /total=(\d+) failed=(\d+)/.exec(assertStep.message ?? '');
      if (!match) {
        checks.push({
          id: `target:${target}:count`,
          status: 'incomplete',
          detail: 'assert step did not report total/failed',
        });
      } else {
        entry.total = Number(match[1]);
        entry.failed = Number(match[2]);
        if (entry.failed !== 0) {
          checks.push({
            id: `target:${target}:count`,
            status: 'fail',
            detail: `${entry.failed} tests failed`,
          });
        } else if (entry.total < minTestCount) {
          checks.push({
            id: `target:${target}:count`,
            status: 'fail',
            detail: `expected at least ${minTestCount} tests, got ${entry.total}`,
          });
        } else {
          checks.push({
            id: `target:${target}:count`,
            status: 'pass',
            detail: `total=${entry.total} failed=0 (floor ${minTestCount})`,
          });
        }
      }
    }
    if (entry.steps.test && runDir && scope) {
      const scopeCheck = validateRetainedScope(runDir, entry.steps.test, scope);
      checks.push({ ...scopeCheck, id: `target:${target}:scope` });
      entry.scope = scope.status;
    }
    targets.set(target, entry);
  }

  for (const target of expected) {
    if (!targets.has(target)) {
      checks.push({
        id: `target:${target}`,
        status: 'incomplete',
        detail: 'target was not present in the actrun run record',
      });
    }
  }
  for (const target of targets.keys()) {
    if (!expected.includes(target)) {
      checks.push({
        id: `target:${target}`,
        status: 'fail',
        detail: 'unexpected target in the matrix',
      });
    }
  }

  const status = checks.some((check) => check.status === 'fail')
    ? 'fail'
    : checks.some((check) => check.status === 'incomplete')
      ? 'incomplete'
      : 'pass';
  return {
    status,
    checks,
    targets: [...targets.values()].map((entry) => ({
      target: entry.target,
      job: entry.job,
      total: entry.total,
      failed: entry.failed,
      scope: entry.scope ?? null,
    })),
  };
}

function validateHostedOnlySteps(run, gate) {
  const checks = [];
  const steps = allJobSteps(run);
  for (const name of gate.hostedOnlySteps ?? []) {
    const step = steps.get(name);
    if (!step) {
      checks.push({
        id: `hosted:${name}`,
        status: 'note',
        detail: 'not present in the run record (unsupported action or omitted step)',
      });
    } else if (step.conclusion === 'skipped') {
      checks.push({
        id: `hosted:${name}`,
        status: 'pass',
        detail: 'skipped locally as intended',
      });
    } else if (FORBIDDEN_LOCAL_STEPS.has(name)) {
      checks.push({
        id: `hosted:${name}`,
        status: 'fail',
        detail: `hosted-only step ran locally (${step.conclusion}); it must be skipped`,
      });
    } else {
      checks.push({
        id: `hosted:${name}`,
        status: 'warn',
        detail: `step ran locally (${step.conclusion}); the local flow expected it to be skipped`,
      });
    }
  }
  return checks;
}

/** Read the stdout/stderr log actrun kept for one step. */
function readTaskLog(runDir, taskId, stream) {
  if (!taskId) return '';
  const file = path.join(runDir, 'tasks', `${taskId.replace('/', '__')}.${stream}.log`);
  try {
    return fs.readFileSync(file, 'utf8');
  } catch {
    return '';
  }
}

/** Whether the maintained-scope selection is available in this worktree. */
function retainedScope() {
  const present = fs.existsSync(RETAINED_HELPER);
  return {
    status: present ? 'retained' : 'pending',
    helper: path.relative(REPO_ROOT, RETAINED_HELPER),
    detail: present
      ? 'compat/retained-test.mjs selects the retained packages; the dormant PCB, score and EPUB packages are not required'
      : 'compat/retained-test.mjs is not present yet; the run covers the full suite, including the dormant PCB, score and EPUB packages',
  };
}

/** The moon test step must report the scope the runner expects. */
function validateRetainedScope(runDir, step, scope) {
  const log = readTaskLog(runDir, step?.taskId, 'stdout');
  const marker = /^retained-scope: (\w+)/m.exec(log);
  if (!marker) {
    return {
      id: 'retained-scope',
      status: 'incomplete',
      detail: 'the moon test step did not report a retained-scope marker',
    };
  }
  if (marker[1] !== scope.status) {
    return {
      id: 'retained-scope',
      status: 'fail',
      detail: `the moon test step reported retained-scope ${marker[1]}, expected ${scope.status}`,
    };
  }
  return {
    id: 'retained-scope',
    status: scope.status === 'retained' ? 'pass' : 'note',
    detail: scope.detail,
  };
}

/** The site gate must have measured the server it started itself. */
function validateSiteServer(runDir, run) {
  const step = allJobSteps(run).get('Validate the site with vlmkit');
  if (!step) {
    return [
      {
        id: 'site-server',
        status: 'incomplete',
        detail: 'the vlmkit step is missing from the run record',
      },
    ];
  }
  const log = readTaskLog(runDir, step.taskId, 'stderr');
  const port = /^\+ port=(\d+)$/m.exec(log);
  const url = /^\+ url=http:\/\/127\.0\.0\.1:(\d+)$/m.exec(log);
  if (/Address already in use/.test(log)) {
    return [
      {
        id: 'site-server',
        status: 'fail',
        detail: 'the local site server could not bind its port',
      },
    ];
  }
  if (!port || !url) {
    return [
      {
        id: 'site-server',
        status: 'fail',
        detail: 'the vlmkit step did not report an ephemeral port and its URL',
      },
    ];
  }
  if (port[1] !== url[1]) {
    return [
      {
        id: 'site-server',
        status: 'fail',
        detail: `the vlmkit step bound port ${port[1]} but checked ${url[1]}`,
      },
    ];
  }
  if (/the local site server (did not come up|exited before the checks finished)/.test(log)) {
    return [
      {
        id: 'site-server',
        status: 'fail',
        detail: 'the local site server failed its readiness or liveness check',
      },
    ];
  }
  return [
    {
      id: 'site-server',
      status: 'pass',
      detail: `the vlmkit step started its own server on ephemeral port ${port[1]} and checked it stayed up`,
    },
  ];
}

function summarizeRun(run) {
  return {
    runId: run.run_id,
    status: run.status,
    conclusion: run.conclusion,
    state: run.state,
    ok: run.ok,
    exitCode: run.exit_code,
    event: run.event,
    headSha: run.headSha,
    beforeSha: run.before_sha,
    afterSha: run.after_sha,
    changedPaths: run.changed_paths ?? [],
    jobs: (run.jobs ?? []).map((job) => ({
      id: job.id,
      status: job.status,
      conclusion: job.conclusion,
      steps: (job.steps ?? []).map((step) => ({
        name: step.name,
        conclusion: step.conclusion,
        durationMs: step.duration_ms,
      })),
    })),
    steps: (run.steps ?? []).map((step) => ({
      id: step.id,
      status: step.status,
      required: step.required,
      durationMs: step.duration_ms,
      message: typeof step.message === 'string' ? step.message.slice(0, 2000) : '',
    })),
    artifacts: run.artifacts ?? [],
  };
}

async function runToLog({ command, args, cwd, logPath, env, timeoutMs }) {
  await fsp.mkdir(path.dirname(logPath), { recursive: true });
  const startedAt = Date.now();
  const header = [
    `# command: ${commandLine(command, args)}`,
    `# cwd: ${cwd}`,
    `# started: ${new Date(startedAt).toISOString()}`,
    '',
  ].join('\n');
  await fsp.writeFile(logPath, header, 'utf8');
  const out = fs.createWriteStream(logPath, { flags: 'a' });
  const child = spawn(command, args, {
    cwd,
    env: { ...process.env, ...env },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  let timedOut = false;
  let timer = null;
  if (timeoutMs && timeoutMs > 0) {
    timer = setTimeout(() => {
      timedOut = true;
      child.kill('SIGTERM');
      setTimeout(() => child.kill('SIGKILL'), 5000).unref();
    }, timeoutMs);
  }
  child.stdout.pipe(out, { end: false });
  child.stderr.pipe(out, { end: false });
  const result = await new Promise((resolve) => {
    child.on('error', (error) => {
      out.write(`\n# spawn error: ${error.message}\n`);
      resolve({ code: 127, signal: null, error: error.message });
    });
    child.on('close', (code, signal) => {
      resolve({ code: code ?? 1, signal, error: null });
    });
  });
  if (timer) clearTimeout(timer);
  await new Promise((resolve) => out.end(resolve));
  const durationMs = Date.now() - startedAt;
  await fsp.appendFile(
    logPath,
    `\n# exit: ${result.code}${result.signal ? ` signal=${result.signal}` : ''}${timedOut ? ' (timeout)' : ''}\n# duration_ms: ${durationMs}\n`,
    'utf8',
  );
  return { ...result, durationMs, timedOut, logPath };
}

async function findRunRecord(runRoot, runId) {
  if (runId) {
    const file = path.join(runRoot, runId, 'run.json');
    if (fs.existsSync(file)) {
      return { runId, file, record: readJson(file) };
    }
  }
  const entries = await fsp.readdir(runRoot, { withFileTypes: true }).catch(() => []);
  const dirs = entries
    .filter((entry) => entry.isDirectory() && /^run-\d+$/.test(entry.name))
    .map((entry) => ({ name: entry.name, number: Number(entry.name.slice(4)) }))
    .sort((a, b) => b.number - a.number);
  for (const dir of dirs) {
    const file = path.join(runRoot, dir.name, 'run.json');
    if (fs.existsSync(file)) {
      return { runId: dir.name, file, record: readJson(file) };
    }
  }
  return null;
}

function extractRunId(logText) {
  const matches = [...logText.matchAll(/^run_id=(\S+)$/gm)];
  return matches.length > 0 ? matches[matches.length - 1][1] : null;
}

function skipActionsForGate(gate) {
  // actrun asks before fetching third-party actions even when the step's
  // `if` would skip it. Skip the hosted-only actions explicitly so a local
  // run never fetches or executes them.
  const actions = [
    'actions/checkout@v4',
    'actions/setup-node@v4',
    'hustcer/setup-moonbit@v1',
  ];
  if (gate.id === 'site') {
    actions.push('actions/upload-pages-artifact@v3', 'actions/deploy-pages@v4');
  }
  return actions;
}

function gateCommand(gate, context) {
  if (gate.kind === 'command') {
    return { command: gate.command[0], args: gate.command.slice(1) };
  }
  // Do not pass --ref/--before/--after: actrun applies the workflow's push
  // branch filter when any of them is set, and the sentinel branch would make
  // the run skip. actrun auto-detects the current branch and HEAD instead.
  const args = [
    'workflow',
    'run',
    gate.workflow,
    '--local',
    '--no-nix',
    '--job',
    gate.job,
    '--run-root',
    context.runRoot,
    '--artifact-root',
    context.artifactRoot,
  ];
  for (const action of skipActionsForGate(gate)) {
    args.push('--skip-action', action);
  }
  return { command: ACTRUN, args };
}

async function runGate(gate, context) {
  const startedAt = Date.now();
  const logPath = path.join(context.evidenceDir, 'logs', `${gate.id.replace(/[^A-Za-z0-9_.-]+/g, '-')}.log`);
  const { command, args } = gateCommand(gate, context);
  const result = await runToLog({
    command,
    args,
    cwd: REPO_ROOT,
    logPath,
    timeoutMs: context.timeoutSeconds > 0 ? context.timeoutSeconds * 1000 : 0,
  });
  const logText = await fsp.readFile(logPath, 'utf8');
  const gateRecord = {
    id: gate.id,
    title: gate.title,
    workflow: gate.workflow,
    job: gate.job,
    description: gate.description,
    status: 'incomplete',
    exitCode: result.code,
    durationMs: result.durationMs,
    timedOut: result.timedOut,
    command: [command, ...args],
    commandLine: commandLine(command, args),
    log: path.relative(context.evidenceDir, logPath),
    checks: [],
    notes: [],
  };

  if (gate.kind === 'command') {
    if (result.code === 0) {
      gateRecord.status = 'pass';
      gateRecord.checks.push({
        id: 'command',
        status: 'pass',
        detail: 'command exited 0',
      });
    } else {
      gateRecord.status = 'fail';
      gateRecord.checks.push({
        id: 'command',
        status: 'fail',
        detail: `command exited ${result.code}${result.timedOut ? ' (timeout)' : ''}`,
      });
    }
    const warnings = logText
      .split('\n')
      .filter((line) => /warning\[/.test(line))
      .map((line) => line.trim());
    if (warnings.length > 0) {
      gateRecord.notes.push(`${warnings.length} lint warning(s) recorded in the log`);
    }
    return gateRecord;
  }

  const runId = extractRunId(logText);
  let found = null;
  try {
    found = await findRunRecord(context.runRoot, runId);
  } catch (error) {
    gateRecord.status = 'incomplete';
    gateRecord.checks.push({
      id: 'actrun-record',
      status: 'incomplete',
      detail: `the actrun run record could not be read: ${error.message}`,
    });
    return gateRecord;
  }
  if (!found) {
    gateRecord.status = 'incomplete';
    gateRecord.checks.push({
      id: 'actrun-record',
      status: 'incomplete',
      detail: 'actrun did not write a run record; the run cannot be verified',
    });
    return gateRecord;
  }

  const run = found.record;
  const runDir = path.dirname(found.file);
  gateRecord.actrun = {
    runId: found.runId,
    runRecord: path.relative(context.evidenceDir, found.file),
    ...summarizeRun(run),
  };

  if (result.code !== 0 || run.ok !== true || run.exit_code !== 0) {
    gateRecord.status = 'fail';
    gateRecord.checks.push({
      id: 'actrun-exit',
      status: 'fail',
      detail: `actrun exited ${result.code}; run record ok=${run.ok} exit_code=${run.exit_code} state=${run.state}`,
    });
  } else {
    gateRecord.checks.push({
      id: 'actrun-exit',
      status: 'pass',
      detail: `actrun exited 0; run record ok=true state=${run.state}`,
    });
  }

  let validation;
  if (gate.id === 'ci/test') {
    validation = validateCiTest(run, context.minTestCount.value, {
      runDir,
      scope: context.retainedScope,
    });
    gateRecord.targets = validation.targets;
  } else {
    validation = {
      status: 'pass',
      checks: validateRequiredSteps(run, gate.requiredSteps),
    };
  }
  gateRecord.checks.push(...validation.checks);

  const hostedChecks = validateHostedOnlySteps(run, gate);
  gateRecord.checks.push(...hostedChecks);

  if (gate.id === 'site') {
    gateRecord.checks.push(...validateSiteServer(runDir, run));
    const deployJobs = (run.jobs ?? []).filter((job) => job.id === 'deploy');
    if (deployJobs.length > 0) {
      gateRecord.checks.push({
        id: 'hosted:deploy-job',
        status: 'fail',
        detail: 'the deploy job ran locally; the local flow must never deploy',
      });
    } else {
      gateRecord.checks.push({
        id: 'hosted:deploy-job',
        status: 'pass',
        detail: 'the deploy job was not part of the local build run',
      });
    }
  }

  const hasFail = gateRecord.checks.some((check) => check.status === 'fail');
  const hasIncomplete = gateRecord.checks.some((check) => check.status === 'incomplete');
  if (hasFail) {
    gateRecord.status = 'fail';
  } else if (hasIncomplete) {
    gateRecord.status = 'incomplete';
  } else if (validation.status === 'fail') {
    gateRecord.status = 'fail';
  } else if (validation.status === 'incomplete') {
    gateRecord.status = 'incomplete';
  } else {
    gateRecord.status = 'pass';
  }

  if (gateRecord.status === 'pass' && gateRecord.checks.some((check) => check.status === 'warn')) {
    gateRecord.notes.push('one or more hosted-only steps ran locally; see the checks');
  }

  return gateRecord;
}

/** The overall result for a set of gate records. */
function overallResult(gates) {
  if (gates.length === 0) return { result: 'incomplete', exitCode: 2 };
  if (gates.some((gate) => gate.status === 'fail')) return { result: 'fail', exitCode: 1 };
  if (
    gates.some((gate) =>
      ['blocked', 'incomplete', 'skipped', 'not-run'].includes(gate.status),
    )
  ) {
    return { result: 'incomplete', exitCode: 2 };
  }
  // A deliberately selected subset can succeed, but must not be reported as
  // a successful full verification in machine-readable evidence.
  if (gates.some((gate) => gate.status === 'not-selected')) {
    return { result: 'partial-pass', exitCode: 0 };
  }
  return { result: 'pass', exitCode: 0 };
}

function renderSummary(manifest) {
  const lines = [];
  lines.push(`# Local verification — ${manifest.result.toUpperCase()}`);
  lines.push('');
  if (manifest.result === 'dry-run') {
    lines.push('> **DRY RUN — NOT A VERIFICATION RESULT.** No gate was executed.');
    lines.push('');
  }
  lines.push(`- Commit: \`${manifest.repo.head}\` (${manifest.repo.branch || 'detached HEAD'})`);
  lines.push(`- Tree: ${manifest.repo.dirty ? '**dirty**' : 'clean'}`);
  if (manifest.repo.dirty) {
    lines.push(`  - status entries: ${manifest.repo.statusCount}`);
    lines.push(`  - diff sha256: \`${manifest.repo.diffHeadSha256}\``);
    lines.push(`  - untracked files: ${manifest.repo.untracked.length}`);
  }
  lines.push(`- Evidence: \`${manifest.evidenceDir}\``);
  lines.push(`- Started: ${manifest.startedAt}`);
  lines.push(`- Finished: ${manifest.finishedAt}`);
  lines.push(`- Exit code: ${manifest.exitCode}`);
  if (manifest.retainedScope) {
    const scope = manifest.retainedScope;
    lines.push(
      `- Retained scope: ${scope.status}${scope.status === 'pending' ? ' (integration pending)' : ''} — ${scope.detail}`,
    );
  }
  if (manifest.subset) {
    lines.push(`- Subset: ${manifest.selectedGateIds.join(', ')}`);
  }
  lines.push('');
  lines.push('## Gates');
  lines.push('');
  lines.push('| Gate | Workflow / job | Status | Exit | Duration | Log |');
  lines.push('|---|---|---|---:|---:|---|');
  for (const gate of manifest.gates) {
    const workflow = gate.workflow ? `\`${gate.workflow}\` / \`${gate.job}\`` : '—';
    lines.push(
      `| \`${gate.id}\` | ${workflow} | ${gate.status} | ${gate.exitCode ?? '—'} | ${formatDuration(gate.durationMs)} | ${gate.log ? `\`${gate.log}\`` : '—'} |`,
    );
  }
  lines.push('');

  const problemChecks = [];
  for (const gate of manifest.gates) {
    for (const check of gate.checks ?? []) {
      if (check.status === 'fail' || check.status === 'incomplete' || check.status === 'warn') {
        problemChecks.push({ gate: gate.id, ...check });
      }
    }
  }
  if (problemChecks.length > 0) {
    lines.push('## Gate details');
    lines.push('');
    for (const check of problemChecks) {
      lines.push(`- \`${check.gate}\` ${check.status.toUpperCase()} \`${check.id}\`: ${check.detail}`);
    }
    lines.push('');
  }

  lines.push('## Prerequisites');
  lines.push('');
  lines.push('| Prerequisite | Status | Detail |');
  lines.push('|---|---|---|');
  for (const check of manifest.prerequisites) {
    lines.push(`| \`${check.id}\` | ${check.status} | ${check.detail} |`);
  }
  lines.push('');

  lines.push('## Hosted-only behavior (not run locally)');
  lines.push('');
  lines.push('| Item | Status | Reason |');
  lines.push('|---|---|---|');
  for (const item of manifest.hostedOnly) {
    lines.push(`| \`${item.id}\` | ${item.status} | ${item.reason} |`);
  }
  lines.push('');

  lines.push('## Commands');
  lines.push('');
  for (const gate of manifest.gates) {
    if (gate.commandLine) {
      lines.push(`- \`${gate.id}\`: \`${gate.commandLine}\``);
    }
  }
  lines.push('');

  lines.push('## Limitations');
  lines.push('');
  for (const limitation of manifest.limitations) {
    lines.push(`- ${limitation}`);
  }
  lines.push('');
  return `${lines.join('\n')}\n`;
}

async function writeEvidence(manifest, evidenceDir) {
  await fsp.mkdir(evidenceDir, { recursive: true });
  await fsp.writeFile(
    path.join(evidenceDir, 'manifest.json'),
    `${JSON.stringify(manifest, null, 2)}\n`,
    'utf8',
  );
  await fsp.writeFile(
    path.join(evidenceDir, 'summary.md'),
    renderSummary(manifest),
    'utf8',
  );
  await fsp.writeFile(
    path.join(evidenceDir, 'commands.txt'),
    `${manifest.gates
      .filter((gate) => gate.commandLine)
      .map((gate) => `${gate.id}\t${gate.commandLine}`)
      .join('\n')}\n`,
    'utf8',
  );
  await fsp.writeFile(
    path.join(evidenceDir, 'environment.json'),
    `${JSON.stringify(manifest.environment, null, 2)}\n`,
    'utf8',
  );
  await fsp.writeFile(
    path.join(evidenceDir, 'prerequisites.json'),
    `${JSON.stringify(manifest.prerequisites, null, 2)}\n`,
    'utf8',
  );
}

async function writeGitEvidence(evidenceDir, git) {
  await fsp.mkdir(evidenceDir, { recursive: true });
  await fsp.writeFile(path.join(evidenceDir, 'git-head.txt'), `${git.head}\n`, 'utf8');
  await fsp.writeFile(path.join(evidenceDir, 'git-branch.txt'), `${git.branch}\n`, 'utf8');
  await fsp.writeFile(path.join(evidenceDir, 'git-commit.txt'), `${git.commit}\n`, 'utf8');
  await fsp.writeFile(path.join(evidenceDir, 'git-status.txt'), `${git.status}\n`, 'utf8');
  await fsp.writeFile(path.join(evidenceDir, 'git-diff.patch'), git.diffHead, 'utf8');
  await fsp.writeFile(path.join(evidenceDir, 'git-diff-cached.patch'), git.diffCached, 'utf8');
  await fsp.writeFile(path.join(evidenceDir, 'git-diff-stat.txt'), `${git.diffStat}\n`, 'utf8');
  await fsp.writeFile(
    path.join(evidenceDir, 'git-untracked.txt'),
    `${git.untracked.join('\n')}\n`,
    'utf8',
  );
}

function makeManifest({ options, git, environment, prerequisites, evidenceDir, selectedGateIds }) {
  const now = new Date().toISOString();
  return {
    schemaVersion: 1,
    tool: 'bdf-local-verify',
    actrunVersion: environment.actrun,
    startedAt: now,
    finishedAt: null,
    result: 'running',
    exitCode: null,
    evidenceDir,
    subset: Boolean(options.only),
    selectedGateIds,
    repo: {
      root: git.root,
      head: git.head,
      branch: git.branch,
      before: git.before,
      describe: git.describe,
      commit: git.commit,
      dirty: git.dirty,
      status: git.status,
      statusCount: git.statusCount,
      diffSha256: git.diffSha256,
      diffCachedSha256: git.diffCachedSha256,
      diffHeadSha256: git.diffHeadSha256,
      untracked: git.untracked,
      evidenceFiles: {
        status: 'git-status.txt',
        diff: 'git-diff.patch',
        diffCached: 'git-diff-cached.patch',
        diffStat: 'git-diff-stat.txt',
        untracked: 'git-untracked.txt',
        commit: 'git-commit.txt',
      },
    },
    environment,
    prerequisites,
    gates: GATES.map((gate) => ({
      id: gate.id,
      title: gate.title,
      workflow: gate.workflow,
      job: gate.job,
      description: gate.description,
      status: 'not-run',
      exitCode: null,
      durationMs: null,
      command: null,
      commandLine: null,
      log: null,
      checks: [],
      notes: [],
    })),
    hostedOnly: HOSTED_ONLY,
    retainedScope: null,
    limitations: [
      'Local runs use the installed Node, MoonBit, Playwright and Python versions, not the GitHub-hosted runner image or the versions installed by actions/setup-node and hustcer/setup-moonbit.',
      'npm ci, moon update and npx playwright install --with-deps chromium are skipped locally. The run uses the existing node_modules, .mooncakes and Playwright Chromium; missing prerequisites block the affected gates instead of being skipped silently.',
      'The GitHub-hosted runner image, action setup steps, Pages artifact upload and Pages deployment are not exercised. Deployment is the separate manual workflow pages-deploy.yml, which the local flow never runs or dispatches.',
      'Local runs execute in the current worktree, including uncommitted changes. The manifest records the commit and dirty diff hashes; it is not a clean-checkout run.',
      'GitHub never runs the verification workflows: the only trigger is push with branches-ignore [**], which matches no branch, and there is no manual trigger. actrun 0.32.0 only accepts a push trigger and ignores branch filters, so the local flow still runs them.',
      'The workflow-lint gate uses actrun lint. Warnings are recorded but do not fail the gate.',
      'The ci/test gate runs all three matrix targets in one actrun run; the runner parses the per-target step names and the min-test-count assertion.',
      'The site gate runs the build job only. The deploy job is kept as the deployment definition and is never run locally.',
      'The ci/test gate uses compat/retained-test.mjs to select retained packages. If the selector is absent, it runs the full suite and records retained-scope pending.',
      'No network GitHub API calls, deployments, publishes, merges or pushes are performed by the local flow.',
    ],
  };
}

function printPlan(manifest) {
  console.log('bdf local verification plan');
  console.log(`commit ${shortSha(manifest.repo.head)} (${manifest.repo.branch || 'detached HEAD'}) ${manifest.repo.dirty ? 'dirty' : 'clean'}`);
  console.log(`evidence ${manifest.evidenceDir}`);
  console.log('');
  for (const gate of manifest.gates) {
    const selected = manifest.selectedGateIds.includes(gate.id);
    const prereqs = gate.requires ?? [];
    console.log(`${selected ? '*' : ' '} ${gate.id} — ${gate.title}`);
    if (gate.workflow) console.log(`    ${gate.workflow} / ${gate.job}`);
    if (gate.commandLine) console.log(`    ${gate.commandLine}`);
    if (prereqs.length > 0) console.log(`    requires: ${prereqs.join(', ')}`);
  }
  console.log('');
  console.log('DRY RUN — no gate was executed. This is not a verification result.');
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    console.log(USAGE);
    return 0;
  }
  if (options.list) {
    for (const gate of GATES) {
      console.log(`${gate.id}\t${gate.title}${gate.workflow ? `\t${gate.workflow} / ${gate.job}` : ''}`);
    }
    return 0;
  }

  const topLevel = tryExecText('git', ['rev-parse', '--show-toplevel']);
  if (!topLevel.ok || path.resolve(topLevel.text) !== REPO_ROOT) {
    throw new Error(`not a git worktree at ${REPO_ROOT}`);
  }

  const git = collectGitState();
  const environment = collectEnvironment();
  const prerequisites = await checkPrerequisites(environment);
  const prereqs = prerequisiteMap(prerequisites);
  const minTestCount = readMinTestCount();
  const scope = retainedScope();

  const allIds = GATES.map((gate) => gate.id);
  if (options.only) {
    const unknown = options.only.filter((id) => !allIds.includes(id));
    if (unknown.length > 0) {
      throw new Error(`unknown gate id(s): ${unknown.join(', ')}; known: ${allIds.join(', ')}`);
    }
  }
  if (options.skip) {
    const unknown = options.skip.filter((id) => !allIds.includes(id));
    if (unknown.length > 0) {
      throw new Error(`unknown gate id(s): ${unknown.join(', ')}; known: ${allIds.join(', ')}`);
    }
  }

  const selectedGateIds = options.only ? options.only : allIds;
  const skippedIds = new Set(options.skip ?? []);
  const stamp = utcStamp();
  const defaultName = `${stamp}-${shortSha(git.head)}${git.dirty ? '-dirty' : ''}`;
  const evidenceDir = options.evidenceDir
    ? path.resolve(REPO_ROOT, options.evidenceDir)
    : path.join(DEFAULT_EVIDENCE_ROOT, defaultName);

  if (fs.existsSync(evidenceDir) && fs.readdirSync(evidenceDir).length > 0 && !options.force) {
    throw new Error(`evidence directory is not empty: ${evidenceDir} (use --force to reuse it)`);
  }
  await fsp.mkdir(evidenceDir, { recursive: true });
  await writeGitEvidence(evidenceDir, git);

  const manifest = makeManifest({
    options,
    git,
    environment,
    prerequisites,
    evidenceDir,
    selectedGateIds,
  });
  manifest.minTestCount = minTestCount;
  manifest.retainedScope = scope;

  for (const gate of manifest.gates) {
    const definition = GATES.find((item) => item.id === gate.id);
    gate.requires = definition.requires;
    gate.hostedOnlySteps = definition.hostedOnlySteps;
    if (!selectedGateIds.includes(gate.id)) {
      gate.status = 'not-selected';
      gate.notes.push('not selected by --only');
    } else if (skippedIds.has(gate.id)) {
      gate.status = 'skipped';
      gate.notes.push('excluded by --skip; the full suite did not run');
    } else if (options.dryRun) {
      gate.status = 'planned';
      const { command, args } = gateCommand(definition, {
        runRoot: path.join(evidenceDir, 'actrun-runs'),
        artifactRoot: path.join(evidenceDir, 'actrun-artifacts'),
        git,
      });
      gate.command = [command, ...args];
      gate.commandLine = commandLine(command, args);
    }
  }

  if (options.dryRun) {
    manifest.result = 'dry-run';
    manifest.exitCode = 0;
    manifest.finishedAt = new Date().toISOString();
    await writeEvidence(manifest, evidenceDir);
    printPlan(manifest);
    return 0;
  }

  const context = {
    evidenceDir,
    runRoot: path.join(evidenceDir, 'actrun-runs'),
    artifactRoot: path.join(evidenceDir, 'actrun-artifacts'),
    git,
    timeoutSeconds: options.timeoutSeconds,
    minTestCount,
    retainedScope: scope,
  };

  console.log('bdf local verification');
  console.log(`commit ${shortSha(git.head)} (${git.branch || 'detached HEAD'}) ${git.dirty ? 'dirty' : 'clean'}`);
  console.log(`evidence ${evidenceDir}`);
  const missing = prerequisites.filter((check) => check.required && check.status !== 'ok');
  console.log(`prerequisites ${prerequisites.filter((check) => check.status === 'ok').length} ok, ${missing.length} missing`);
  if (missing.length > 0) {
    for (const check of missing) {
      console.log(`  missing ${check.id}: ${check.detail}`);
    }
  }
  console.log('');

  let stoppedAfter = null;
  const selectedDefinitions = GATES.filter((gate) => selectedGateIds.includes(gate.id));
  for (let index = 0; index < selectedDefinitions.length; index += 1) {
    const definition = selectedDefinitions[index];
    const gate = manifest.gates.find((item) => item.id === definition.id);
    if (gate.status === 'skipped') {
      console.log(`[${index + 1}/${selectedDefinitions.length}] ${gate.id} SKIPPED (--skip)`);
      continue;
    }
    if (stoppedAfter) {
      gate.status = 'not-run';
      gate.notes.push(`not run because ${stoppedAfter} failed and --keep-going was not set`);
      continue;
    }
    const missingForGate = missingPrerequisites(definition, prereqs);
    if (missingForGate.length > 0) {
      gate.status = 'blocked';
      gate.notes.push(...missingForGate);
      gate.checks.push({
        id: 'prerequisites',
        status: 'incomplete',
        detail: `missing prerequisites: ${missingForGate.join('; ')}`,
      });
      console.log(`[${index + 1}/${selectedDefinitions.length}] ${gate.id} BLOCKED`);
      for (const detail of missingForGate) console.log(`  ${detail}`);
      await writeEvidence(manifest, evidenceDir);
      continue;
    }

    console.log(`[${index + 1}/${selectedDefinitions.length}] ${gate.id} RUNNING`);
    const result = await runGate(definition, context);
    Object.assign(gate, result);
    console.log(
      `[${index + 1}/${selectedDefinitions.length}] ${gate.id} ${gate.status.toUpperCase()} (exit ${gate.exitCode ?? '—'}, ${formatDuration(gate.durationMs)})`,
    );
    for (const check of gate.checks.filter((item) => item.status === 'fail' || item.status === 'incomplete')) {
      console.log(`  ${check.status.toUpperCase()} ${check.id}: ${check.detail}`);
    }
    await writeEvidence(manifest, evidenceDir);
    if (gate.status === 'fail' && !options.keepGoing) {
      stoppedAfter = gate.id;
    }
  }

  const overall = overallResult(manifest.gates);
  manifest.result = overall.result;
  manifest.exitCode = overall.exitCode;
  manifest.finishedAt = new Date().toISOString();
  await writeEvidence(manifest, evidenceDir);

  console.log('');
  console.log(`result ${manifest.result.toUpperCase()} (exit ${manifest.exitCode})`);
  console.log(`summary ${path.join(evidenceDir, 'summary.md')}`);
  console.log(`manifest ${path.join(evidenceDir, 'manifest.json')}`);
  return manifest.exitCode;
}

export {
  DEPLOY_WORKFLOW,
  GATES,
  HOSTED_ONLY,
  WORKFLOW_DIR,
  checkXlsxOraclePrerequisite,
  gateCommand,
  missingPrerequisites,
  overallResult,
  parseArgs,
  readJson,
  readMinTestCount,
  renderSummary,
  retainedScope,
  runGate,
  validateCiTest,
  validateHostedOnlySteps,
  validateRequiredSteps,
  validateRetainedScope,
  validateSiteServer,
};

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main()
    .then((code) => {
      process.exitCode = code;
    })
    .catch((error) => {
      console.error(`local verification failed to start: ${error.message}`);
      if (error.stack) console.error(error.stack);
      process.exitCode = 2;
    });
}
