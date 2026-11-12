// Local-only bdf.mbt candidate capture for the DocuWorks fidelity gate.
//
// This adapter never captures genuine DocuWorks, never installs software and
// never prints PASS. It validates a reviewed corpus manifest, converts each
// input with the already-built native JS converter, renders every page in
// Chromium at the recorded DPI, and writes an immutable run directory with
// PNGs, hashes, dimensions, text, warnings and a candidate manifest that
// compat/xdw/verify.mjs can read.
import { randomUUID } from 'node:crypto';
import { createReadStream, existsSync, lstatSync, mkdirSync, readFileSync, realpathSync, renameSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { createRequire } from 'node:module';
import { dirname, extname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { PNG } from 'pngjs';
import { localPath, sha256, verify } from './verify.mjs';

const defaultRepoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const MAX_PAGE_PIXELS = 20_000_000;
const MAX_PNG_BYTES = 64 * 1024 * 1024;
const MAX_REQUESTS = 500;
const USAGE = `usage: node compat/xdw/capture.mjs --corpus CORPUS.json --out DIR [--dpi 96] [--timeout-ms 120000]

Captures the bdf.mbt candidate only. It does not capture genuine DocuWorks,
does not install anything and never prints PASS. The output directory must not
exist. A CAPTURED run writes candidate.json, capture.json and candidate/*.png;
an INCOMPLETE or ERROR run keeps capture.json and any partial PNGs but writes
no candidate.json.`;

const need = (ok, message) => { if (!ok) throw new Error(message); };
const nonempty = value => typeof value === 'string' && value.trim().length > 0;

export function parseArgs(argv) {
  const args = { dpi: 96, timeoutMs: 120000 };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--help' || arg === '-h') { args.help = true; continue; }
    if (arg === '--corpus' || arg === '--out' || arg === '--dpi' || arg === '--timeout-ms') {
      const value = argv[++i];
      need(value !== undefined, `${arg} requires a value`);
      if (arg === '--corpus') args.corpusFile = value;
      else if (arg === '--out') args.outDir = value;
      else if (arg === '--dpi') args.dpi = Number(value);
      else args.timeoutMs = Number(value);
      continue;
    }
    throw new Error(`unknown argument: ${arg}`);
  }
  if (args.help) return args;
  need(nonempty(args.corpusFile), '--corpus is required');
  need(nonempty(args.outDir), '--out is required');
  need(Number.isSafeInteger(args.dpi) && args.dpi > 0 && args.dpi <= 600, '--dpi must be an integer from 1 to 600');
  need(Number.isSafeInteger(args.timeoutMs) && args.timeoutMs > 0 && args.timeoutMs <= 2_147_483_647, '--timeout-ms must be an integer from 1 to 2147483647');
  return args;
}

// Reuse the verifier's corpus validation so the capture adapter accepts exactly
// the manifest the gate accepts. verify() returns NOT_RUN when no capture
// manifests are supplied, after validating the corpus and every input hash.
export function readCorpus(corpusFile) {
  const check = verify({ corpusFile });
  need(check.status === 'NOT_RUN', `corpus validation returned ${check.status}, expected NOT_RUN`);
  const corpus = JSON.parse(readFileSync(corpusFile, 'utf8'));
  const root = dirname(resolve(corpusFile));
  const documents = corpus.documents.map(doc => ({ ...doc, path: localPath(root, doc.file) }));
  need(check.documents === documents.length, 'corpus validation document count mismatch');
  need(check.expectedPages === corpus.expectedPages, 'corpus validation page count mismatch');
  return { corpus, documents, root };
}

// Resolve a path under root and refuse anything that escapes it, including a
// symlink target. The capture server uses this for every static file.
export function resolveContained(root, name) {
  const rootReal = realpathSync(root);
  const file = resolve(rootReal, name);
  const rel = relative(rootReal, file);
  need(rel !== '..' && !rel.startsWith(`..${sep}`) && !isAbsolute(rel), `path escapes root: ${name}`);
  let real;
  try {
    real = realpathSync(file);
  } catch (error) {
    // A missing file is a 404 for the server, not a containment failure.
    if (error.code === 'ENOENT') return file;
    throw error;
  }
  const realRel = relative(rootReal, real);
  need(realRel !== '..' && !realRel.startsWith(`..${sep}`) && !isAbsolute(realRel), `path escapes root: ${name}`);
  return real;
}

export function checkRuntime(repoRoot = defaultRepoRoot) {
  const workerPath = join(repoRoot, '_build/js/debug/build/native_converter_worker/native_converter_worker.js');
  need(existsSync(workerPath), `native converter worker is not built: ${workerPath}. Run \`moon build --target js\` first.`);
  const corePath = join(repoRoot, 'node_modules/@bdfkit/core/dist/index.js');
  const renderPath = join(repoRoot, 'node_modules/@bdfkit/render/dist/index.js');
  need(existsSync(corePath) && existsSync(renderPath), `bdfkit runtime is not installed: ${corePath} or ${renderPath} is missing. Run \`npm install\` first.`);
  const workerBytes = readFileSync(workerPath);
  need(workerBytes.length > 0, `native converter worker is empty: ${workerPath}. Rebuild it.`);
  return {
    workerPath,
    converter: {
      path: relative(repoRoot, workerPath).split(sep).join('/'),
      sha256: sha256(workerBytes),
      bytes: workerBytes.length,
      mtime: statSync(workerPath).mtime.toISOString(),
    },
  };
}

export function readGit(repoRoot = defaultRepoRoot) {
  const commitResult = spawnSync('git', ['rev-parse', 'HEAD'], { cwd: repoRoot, encoding: 'utf8' });
  need(commitResult.status === 0, `git rev-parse HEAD failed: ${(commitResult.stderr || commitResult.error?.message || '').trim()}`);
  const commit = commitResult.stdout.trim();
  need(/^[a-f0-9]{40}$/.test(commit), `git rev-parse HEAD returned an invalid commit: ${commit}`);
  const statusResult = spawnSync('git', ['status', '--porcelain'], { cwd: repoRoot, encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 });
  if (statusResult.status !== 0) {
    return { commit, dirty: null, status: [], statusError: (statusResult.stderr || statusResult.error?.message || '').trim() };
  }
  const status = statusResult.stdout.trim().split('\n').filter(Boolean);
  return { commit, dirty: status.length > 0, status: status.slice(0, 100) };
}

export function readVersion(repoRoot = defaultRepoRoot) {
  try {
    const match = readFileSync(join(repoRoot, 'moon.mod'), 'utf8').match(/^version\s*=\s*"([^"]+)"/m);
    return match ? match[1] : 'unknown';
  } catch {
    return 'unknown';
  }
}

export function readPlaywrightVersion(repoRoot = defaultRepoRoot) {
  try {
    return createRequire(import.meta.url)('playwright/package.json').version;
  } catch {
    try {
      return JSON.parse(readFileSync(join(repoRoot, 'node_modules/playwright/package.json'), 'utf8')).version ?? 'unknown';
    } catch {
      return 'unknown';
    }
  }
}

export function prepareOutputDir(outDir) {
  const outPath = resolve(outDir);
  try {
    lstatSync(outPath);
    throw new Error(`output directory already exists: ${outPath}`);
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  const parent = dirname(outPath);
  need(existsSync(parent), `output parent does not exist: ${parent}`);
  const tmpDir = join(parent, `.xdw-capture-${process.pid}-${randomUUID().slice(0, 8)}`);
  mkdirSync(tmpDir, { recursive: false, mode: 0o700 });
  mkdirSync(join(tmpDir, 'candidate'), { recursive: false, mode: 0o700 });
  return { outPath, tmpDir };
}

const contentTypes = {
  '.html': 'text/html; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.xdw': 'application/octet-stream',
};

function serveFile(request, response, file, type) {
  let stat;
  try { stat = statSync(file); } catch { response.writeHead(404).end(); return; }
  if (!stat.isFile()) { response.writeHead(404).end(); return; }
  response.writeHead(200, {
    'Content-Type': type,
    'Content-Length': stat.size,
    'Cache-Control': 'no-store',
    'X-Content-Type-Options': 'nosniff',
  });
  if (request.method === 'HEAD') { response.end(); return; }
  createReadStream(file).on('error', () => response.destroy()).pipe(response);
}

export async function startCaptureServer({ repoRoot = defaultRepoRoot, inputs = new Map() }) {
  const staticRoots = [
    ['/compat/xdw/', join(repoRoot, 'compat/xdw')],
    ['/node_modules/@bdfkit/', join(repoRoot, 'node_modules/@bdfkit')],
    ['/_build/js/debug/build/native_converter_worker/', join(repoRoot, '_build/js/debug/build/native_converter_worker')],
  ];
  const requests = [];
  let requestsTruncated = false;
  const server = createServer((request, response) => {
    let pathname;
    try {
      pathname = decodeURIComponent(new URL(request.url, 'http://127.0.0.1').pathname);
    } catch {
      response.writeHead(400).end();
      return;
    }
    response.on('finish', () => {
      if (requests.length < MAX_REQUESTS) requests.push({ method: request.method, path: pathname, status: response.statusCode });
      else requestsTruncated = true;
    });
    if (request.method !== 'GET' && request.method !== 'HEAD') { response.writeHead(405).end(); return; }
    if (pathname.startsWith('/input/')) {
      const input = inputs.get(pathname.slice('/input/'.length));
      if (!input) { response.writeHead(404).end(); return; }
      serveFile(request, response, input.path, 'application/octet-stream');
      return;
    }
    for (const [prefix, root] of staticRoots) {
      if (!pathname.startsWith(prefix)) continue;
      const name = pathname.slice(prefix.length);
      if (!name) { response.writeHead(404).end(); return; }
      let file;
      try { file = resolveContained(root, name); } catch { response.writeHead(403).end(); return; }
      serveFile(request, response, file, contentTypes[extname(file)] ?? 'application/octet-stream');
      return;
    }
    response.writeHead(404).end();
  });
  try {
    await new Promise((resolveListen, rejectListen) => {
      server.once('error', rejectListen);
      server.listen(0, '127.0.0.1', resolveListen);
    });
  } catch (error) {
    server.close();
    throw error;
  }
  const address = server.address();
  return {
    server,
    baseUrl: `http://127.0.0.1:${address.port}`,
    requests,
    get requestsTruncated() { return requestsTruncated; },
    close: () => new Promise(resolveClose => {
      server.closeAllConnections?.();
      server.close(resolveClose);
    }),
  };
}

// The BDF text index uses the same separators as the renderer's joinRuns:
// Sep.SPACE is 1, Sep.BREAK is 2, and a layer change is a blank line.
export function joinTextRuns(runs) {
  let text = '';
  for (let i = 0; i < runs.length; i++) {
    const run = runs[i];
    need(typeof run.text === 'string', 'text run is not a string');
    if (i > 0) {
      if (run.b !== runs[i - 1].b) text += '\n\n';
      else if (run.sep === 2) text += '\n';
      else if (run.sep === 1) text += ' ';
    }
    text += run.text;
  }
  return text;
}

export function inspectPng(bytes, expected = {}) {
  const buffer = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes);
  need(buffer.length >= 33, 'not a PNG');
  need(buffer.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')), 'not a PNG');
  need(buffer.toString('ascii', 12, 16) === 'IHDR', 'not a PNG');
  const width = buffer.readUInt32BE(16);
  const height = buffer.readUInt32BE(20);
  need(width > 0 && height > 0, 'invalid PNG dimensions');
  need(width * height <= MAX_PAGE_PIXELS, `PNG is ${width}x${height}, over the 20 million pixel limit`);
  need(buffer.length <= MAX_PNG_BYTES, 'PNG exceeds the 64 MiB limit');
  if (expected.width !== undefined) need(width === expected.width, `PNG width ${width} does not match expected ${expected.width}`);
  if (expected.height !== undefined) need(height === expected.height, `PNG height ${height} does not match expected ${expected.height}`);
  const image = PNG.sync.read(buffer);
  need(image.width === width && image.height === height, 'decoded PNG dimensions mismatch');
  let blank = true;
  for (let i = 0; i < image.data.length; i += 4) {
    const alpha = image.data[i + 3] / 255;
    if ([0, 1, 2].some(channel => 255 - alpha * (255 - image.data[i + channel]) < 245)) { blank = false; break; }
  }
  return { width, height, blank };
}

export function statusFor(capture) {
  if (capture.errors.length > 0) return 'ERROR';
  if (capture.mismatches.length > 0 || capture.warnings.length > 0) return 'INCOMPLETE';
  return 'CAPTURED';
}

// candidate.json is a success artifact. Incomplete or failed runs keep
// capture.json and any partial PNGs so the failure stays diagnosable, but they
// must not leave a manifest that the verifier could consume as if the capture
// had succeeded. Unknown dirty provenance is never coerced to false.
export function buildCandidate(capture, pages) {
  if (capture.status !== 'CAPTURED') return null;
  if (typeof capture.dirty !== 'boolean') return null;
  if (!Array.isArray(pages) || pages.length === 0) return null;
  return {
    schema: 1,
    role: 'candidate',
    engine: 'bdf.mbt',
    version: capture.version,
    commit: capture.commit,
    createdAt: capture.createdAt,
    platform: capture.platform,
    fonts: capture.fonts.assumption,
    dpi: capture.dpi,
    status: capture.status,
    dirty: capture.dirty,
    pages,
  };
}

function withTimeout(promise, ms, label) {
  let timer;
  return Promise.race([
    promise,
    new Promise((_, reject) => { timer = setTimeout(() => reject(new Error(`${label} timed out after ${ms} ms`)), ms); }),
  ]).finally(() => clearTimeout(timer));
}

function writeJson(file, value) {
  writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`, { mode: 0o600 });
}

export async function capture({ corpusFile, outDir, dpi = 96, timeoutMs = 120000, repoRoot = defaultRepoRoot }) {
  const started = Date.now();
  const { corpus, documents } = readCorpus(corpusFile);
  const runtime = checkRuntime(repoRoot);
  const git = readGit(repoRoot);
  const version = readVersion(repoRoot);
  const playwrightVersion = readPlaywrightVersion(repoRoot);
  const createdAt = new Date().toISOString();
  const { outPath, tmpDir } = prepareOutputDir(outDir);
  const capture = {
    schema: 1,
    status: 'ERROR',
    oracle: 'NOT_RUN',
    oracleReason: 'This adapter captures only the bdf.mbt candidate; it does not capture genuine DocuWorks. CAPTURED is not PASS.',
    createdAt,
    commit: git.commit,
    dirty: git.dirty,
    gitStatus: git.status,
    statusError: git.statusError ?? null,
    version: `${version}+native_converter_worker.${runtime.converter.sha256.slice(0, 12)}`,
    platform: '',
    browser: null,
    playwright: playwrightVersion,
    converter: runtime.converter,
    dpi,
    fonts: { assumption: '', loaded: [] },
    corpus: {
      file: resolve(corpusFile),
      sha256: sha256(readFileSync(corpusFile)),
      documents: documents.length,
      expectedPages: corpus.expectedPages,
    },
    documents: [],
    pages: [],
    mismatches: [],
    warnings: [],
    errors: [],
    externalRequests: [],
    pageErrors: [],
    consoleErrors: [],
    failedRequests: [],
    requests: [],
    requestsTruncated: false,
    durationMs: 0,
  };
  if (git.dirty === null) {
    capture.errors.push({ kind: 'git-status', message: `git status failed: ${git.statusError || 'unknown error'}` });
  }
  const candidatePages = [];
  const fontFaces = new Map();
  let candidate = null;
  let browser = null;
  let server = null;
  try {
    const { chromium } = await import('playwright').catch(error => {
      throw new Error(`Playwright is not installed: ${error.message}. Run \`npm install\` first.`);
    });
    browser = await chromium.launch({ headless: true }).catch(error => {
      throw new Error(`Chromium is not available: ${error.message}. Run \`npx playwright install chromium\` first.`);
    });
    capture.browser = { name: 'chromium', version: browser.version() };
    capture.platform = `${process.platform} ${process.arch}; Chromium ${browser.version()}; Playwright ${playwrightVersion}`;
    const inputs = new Map();
    const inputTokens = new Map();
    for (const doc of documents) {
      const token = randomUUID();
      inputs.set(token, { path: doc.path });
      inputTokens.set(doc.id, token);
    }
    server = await startCaptureServer({ repoRoot, inputs });
    capture.requests = server.requests;
    const context = await browser.newContext({ deviceScaleFactor: 1 });
    const captureOrigin = new URL(server.baseUrl).origin;
    await context.route('**/*', route => {
      const url = new URL(route.request().url());
      if ((url.protocol === 'http:' || url.protocol === 'https:') && url.origin !== captureOrigin) {
        capture.externalRequests.push(url.href);
        return route.abort();
      }
      return route.continue();
    });
    const page = await context.newPage();
    page.on('pageerror', error => capture.pageErrors.push(String(error?.stack ?? error)));
    page.on('console', message => { if (message.type() === 'error') capture.consoleErrors.push(message.text()); });
    page.on('requestfailed', request => capture.failedRequests.push({ url: request.url(), failure: request.failure()?.errorText ?? '' }));
    await page.goto(`${server.baseUrl}/compat/xdw/capture.html`, { waitUntil: 'load', timeout: timeoutMs });
    await page.waitForFunction(() => window.__xdwCaptureReady === true, null, { timeout: timeoutMs });
    capture.browser.userAgent = await page.evaluate(() => navigator.userAgent);
    for (const doc of documents) {
      const docRecord = {
        id: doc.id,
        file: doc.file,
        inputSha256: doc.sha256,
        servedInputSha256: '',
        expectedPages: doc.pages,
        convertedPages: 0,
        format: '',
        summary: '',
        warnings: [],
        pages: [],
        mismatches: [],
        errors: [],
      };
      try {
        const token = inputTokens.get(doc.id);
        need(token, `no input token for ${doc.id}`);
        const opened = await withTimeout(
          page.evaluate(({ inputUrl, name, timeoutMs }) => window.__xdwCapture.open(inputUrl, name, timeoutMs), { inputUrl: `/input/${token}`, name: doc.file, timeoutMs }),
          timeoutMs,
          `convert ${doc.id}`,
        );
        docRecord.servedInputSha256 = typeof opened.inputSha256 === 'string' ? opened.inputSha256 : '';
        docRecord.format = typeof opened.format === 'string' ? opened.format : '';
        docRecord.summary = typeof opened.summary === 'string' ? opened.summary : '';
        docRecord.warnings = Array.isArray(opened.warnings) ? opened.warnings : [];
        if (!Array.isArray(opened.warnings)) docRecord.errors.push({ kind: 'converter-warnings', message: 'converter warnings were not an array' });
        need(Array.isArray(opened.pages), 'converter returned no page list');
        docRecord.convertedPages = opened.pages.length;
        if (opened.pages.length !== doc.pages) {
          docRecord.mismatches.push({ kind: 'page-count', expected: doc.pages, actual: opened.pages.length });
        }
        need(docRecord.servedInputSha256 === doc.sha256, `served input hash mismatch for ${doc.id}: ${docRecord.servedInputSha256} != ${doc.sha256}`);
        for (let index = 0; index < opened.pages.length; index++) {
          const pageNumber = index + 1;
          const rendered = await withTimeout(
            page.evaluate(({ index, dpi }) => window.__xdwCapture.renderPage(index, dpi), { index, dpi }),
            timeoutMs,
            `render ${doc.id}:${pageNumber}`,
          );
          need(typeof rendered.png === 'string' && rendered.png.startsWith('data:image/png;base64,'), `page ${pageNumber} did not return a PNG data URL`);
          const bytes = Buffer.from(rendered.png.slice('data:image/png;base64,'.length), 'base64');
          const png = inspectPng(bytes, { width: rendered.width, height: rendered.height });
          const image = `candidate/${doc.id}-${pageNumber}.png`;
          writeFileSync(join(tmpDir, image), bytes, { mode: 0o600 });
          const text = joinTextRuns(rendered.runs);
          const declared = pageNumber <= doc.pages;
          const declaredBlank = doc.blankPages.includes(pageNumber);
          const pageRecord = {
            document: doc.id,
            page: pageNumber,
            declared,
            image,
            sha256: sha256(bytes),
            width: png.width,
            height: png.height,
            pageWidth: rendered.pageWidth,
            pageHeight: rendered.pageHeight,
            text,
            textRuns: rendered.runs.length,
            warnings: docRecord.warnings,
            blank: png.blank,
            declaredBlank,
          };
          docRecord.pages.push(pageRecord);
          capture.pages.push(pageRecord);
          if (!declared) docRecord.mismatches.push({ kind: 'extra-page', page: pageNumber });
          if (png.blank && !declaredBlank) docRecord.mismatches.push({ kind: 'blank-page', page: pageNumber });
          if (!png.blank && declaredBlank) docRecord.mismatches.push({ kind: 'unexpected-content', page: pageNumber });
          if (declared) {
            candidatePages.push({
              document: doc.id,
              page: pageNumber,
              inputSha256: doc.sha256,
              image,
              sha256: pageRecord.sha256,
              width: png.width,
              height: png.height,
              text,
              warnings: docRecord.warnings,
            });
          }
          for (const face of rendered.fonts ?? []) {
            const key = `${face.family}|${face.weight}|${face.style}|${face.status}`;
            if (!fontFaces.has(key)) fontFaces.set(key, face);
          }
        }
        for (let pageNumber = opened.pages.length + 1; pageNumber <= doc.pages; pageNumber++) {
          docRecord.mismatches.push({ kind: 'missing-page', page: pageNumber });
        }
      } catch (error) {
        docRecord.errors.push({ kind: 'document', message: error.message, stack: error.stack });
      } finally {
        await withTimeout(page.evaluate(() => window.__xdwCapture.close()), 5000, `close ${doc.id}`).catch(() => {});
      }
      if (docRecord.warnings.length > 0) {
        capture.warnings.push(...docRecord.warnings.map(message => ({ document: doc.id, kind: 'converter', message })));
        docRecord.mismatches.push({ kind: 'converter-warning', count: docRecord.warnings.length });
      }
      capture.documents.push(docRecord);
      capture.mismatches.push(...docRecord.mismatches.map(mismatch => ({ document: doc.id, ...mismatch })));
      capture.errors.push(...docRecord.errors.map(error => ({ document: doc.id, ...error })));
    }
    if (capture.externalRequests.length > 0) capture.errors.push({ kind: 'external-request', message: `blocked ${capture.externalRequests.length} external request(s)`, urls: capture.externalRequests.slice(0, 20) });
    if (capture.pageErrors.length > 0) capture.errors.push({ kind: 'page-error', message: capture.pageErrors.join('\n') });
    if (capture.failedRequests.length > 0) capture.errors.push({ kind: 'request-failed', message: `recorded ${capture.failedRequests.length} failed request(s)`, requests: capture.failedRequests.slice(0, 20) });
    if (capture.consoleErrors.length > 0) capture.warnings.push({ kind: 'console-error', messages: capture.consoleErrors.slice(0, 20) });
    if (candidatePages.length === 0) capture.errors.push({ kind: 'candidate', message: 'no candidate pages were captured' });
  } catch (error) {
    capture.errors.push({ kind: 'capture', message: error.message, stack: error.stack });
  } finally {
    await browser?.close().catch(() => {});
    await server?.close().catch(() => {});
  }
  capture.durationMs = Date.now() - started;
  if (server) capture.requestsTruncated = server.requestsTruncated;
  capture.fonts = {
    assumption: fontFaces.size > 0
      ? `Embedded BDF font faces loaded: ${[...new Set([...fontFaces.values()].map(face => face.family))].join(', ')}; other text uses Chromium system fallback (not pinned).`
      : 'No embedded BDF font faces were loaded; text uses Chromium system font fallback (not pinned).',
    loaded: [...fontFaces.values()],
  };
  capture.status = statusFor(capture);
  candidate = buildCandidate(capture, candidatePages);
  try {
    writeJson(join(tmpDir, 'capture.json'), capture);
    if (candidate) writeJson(join(tmpDir, 'candidate.json'), candidate);
    renameSync(tmpDir, outPath);
  } catch (error) {
    rmSync(tmpDir, { recursive: true, force: true });
    throw error;
  }
  return { capture, candidate, outDir: outPath };
}

function summary({ capture, candidate, outDir }) {
  return {
    status: capture.status,
    oracle: capture.oracle,
    output: outDir,
    candidate: candidate ? join(outDir, 'candidate.json') : null,
    documents: capture.documents.length,
    pages: capture.pages.length,
    warnings: capture.warnings.length,
    mismatches: capture.mismatches.length,
    errors: capture.errors.length,
  };
}

export async function main(argv = process.argv.slice(2)) {
  try {
    const args = parseArgs(argv);
    if (args.help) { console.log(USAGE); return 0; }
    const result = await capture(args);
    console.log(JSON.stringify(summary(result), null, 2));
    return result.capture.status === 'CAPTURED' ? 0 : 1;
  } catch (error) {
    console.log(JSON.stringify({ status: 'ERROR', oracle: 'NOT_RUN', reason: error.message }, null, 2));
    return 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  process.exitCode = await main();
}
