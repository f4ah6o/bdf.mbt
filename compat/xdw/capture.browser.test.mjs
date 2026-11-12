import { test } from 'node:test';
import assert from 'node:assert/strict';
import { copyFileSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { PNG } from 'pngjs';
import { sha256 } from './verify.mjs';

const repoRoot = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const demo = join(repoRoot, 'site/samples/demo.xdw');
const worker = join(repoRoot, '_build/js/debug/build/native_converter_worker/native_converter_worker.js');

function corpusFor(input, pages) {
  return {
    schema: 1,
    expectedDocuments: 1,
    expectedPages: pages,
    thresholds: { channelDelta: 0, maxChangedRatio: 0 },
    thresholdRationale: 'Synthetic smoke fixture; not a real-world accuracy threshold',
    documents: [{
      id: 'demo',
      file: 'demo.xdw',
      sha256: sha256(readFileSync(input)),
      pages,
      blankPages: [],
      access: 'public',
      source: 'https://github.com/f4ah6o/bdf.mbt/blob/main/site/samples/demo.xdw',
      licenseNotes: 'In-repository sample; see the repository LICENSE. Smoke fixture only, not a reviewed corpus.',
    }],
  };
}

test('browser smoke captures every demo.xdw page and never claims PASS', { timeout: 180000 }, t => {
  assert.ok(existsSync(worker), `native converter worker is not built: ${worker}. Run \`moon build --target js\` first.`);
  const root = mkdtempSync(join(tmpdir(), 'xdw-capture-browser-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const input = join(root, 'demo.xdw');
  copyFileSync(demo, input);
  const corpus = corpusFor(input, 1);
  const corpusFile = join(root, 'corpus.json');
  writeFileSync(corpusFile, JSON.stringify(corpus, null, 2));
  const out = join(root, 'out');
  const run = spawnSync(process.execPath, ['compat/xdw/capture.mjs', '--corpus', corpusFile, '--out', out, '--dpi', '96'], { cwd: repoRoot, encoding: 'utf8', timeout: 180000 });
  assert.equal(run.status, 0, `capture failed:\nstdout:\n${run.stdout}\nstderr:\n${run.stderr}`);
  const summary = JSON.parse(run.stdout);
  assert.equal(summary.status, 'CAPTURED');
  assert.equal(summary.oracle, 'NOT_RUN');
  assert.equal(summary.candidate, join(out, 'candidate.json'));
  assert.equal(summary.documents, 1);
  assert.equal(summary.pages, 1);
  assert.equal(summary.warnings, 0);
  assert.equal(summary.mismatches, 0);
  assert.equal(summary.errors, 0);
  assert.ok(!run.stdout.includes('"PASS"'));

  const candidate = JSON.parse(readFileSync(join(out, 'candidate.json'), 'utf8'));
  assert.equal(candidate.schema, 1);
  assert.equal(candidate.role, 'candidate');
  assert.equal(candidate.engine, 'bdf.mbt');
  assert.match(candidate.commit, /^[a-f0-9]{40}$/);
  assert.equal(candidate.dpi, 96);
  assert.equal(candidate.status, 'CAPTURED');
  assert.equal(typeof candidate.dirty, 'boolean');
  assert.ok(candidate.platform.includes('Chromium'));
  assert.ok(candidate.fonts.length > 0);
  assert.equal(candidate.pages.length, 1);
  const page = candidate.pages[0];
  assert.equal(page.document, 'demo');
  assert.equal(page.page, 1);
  assert.equal(page.inputSha256, corpus.documents[0].sha256);
  assert.equal(page.image, 'candidate/demo-1.png');
  assert.equal(page.width, 794);
  assert.equal(page.height, 560);
  assert.deepEqual(page.warnings, []);
  assert.ok(page.text.includes('DocuWorks'));
  assert.ok(page.text.includes('bdf.mbt'));
  const pngBytes = readFileSync(join(out, page.image));
  assert.equal(sha256(pngBytes), page.sha256);
  const png = PNG.sync.read(pngBytes);
  assert.equal(png.width, page.width);
  assert.equal(png.height, page.height);

  const capture = JSON.parse(readFileSync(join(out, 'capture.json'), 'utf8'));
  assert.equal(capture.status, 'CAPTURED');
  assert.equal(capture.oracle, 'NOT_RUN');
  assert.match(capture.commit, /^[a-f0-9]{40}$/);
  assert.equal(typeof capture.dirty, 'boolean');
  assert.equal(capture.statusError, null);
  assert.equal(capture.dpi, 96);
  assert.ok(capture.browser.version.length > 0);
  assert.ok(capture.fonts.assumption.length > 0);
  assert.equal(capture.converter.sha256, sha256(readFileSync(worker)));
  assert.equal(capture.corpus.sha256, sha256(readFileSync(corpusFile)));
  assert.equal(capture.documents.length, 1);
  assert.equal(capture.documents[0].inputSha256, corpus.documents[0].sha256);
  assert.equal(capture.documents[0].servedInputSha256, corpus.documents[0].sha256);
  assert.equal(capture.documents[0].convertedPages, 1);
  assert.equal(capture.pages.length, 1);
  assert.equal(capture.pages[0].declared, true);
  assert.equal(capture.pages[0].blank, false);
  assert.equal(capture.pages[0].declaredBlank, false);
  assert.equal(capture.mismatches.length, 0);
  assert.equal(capture.warnings.length, 0);
  assert.equal(capture.errors.length, 0);
  assert.equal(capture.externalRequests.length, 0);
  assert.equal(capture.pageErrors.length, 0);
  assert.equal(capture.requestsTruncated, false);
  assert.ok(capture.requests.some(request => request.path.startsWith('/input/') && request.status === 200));

  const verifyRun = spawnSync(process.execPath, ['compat/xdw/verify.mjs', corpusFile], { cwd: repoRoot, encoding: 'utf8' });
  assert.equal(verifyRun.status, 2);
  assert.equal(JSON.parse(verifyRun.stdout).status, 'NOT_RUN');

  const before = sha256(readFileSync(join(out, 'candidate.json')));
  const again = spawnSync(process.execPath, ['compat/xdw/capture.mjs', '--corpus', corpusFile, '--out', out, '--dpi', '96'], { cwd: repoRoot, encoding: 'utf8', timeout: 180000 });
  assert.equal(again.status, 1);
  const againSummary = JSON.parse(again.stdout);
  assert.equal(againSummary.status, 'ERROR');
  assert.match(againSummary.reason, /already exists/);
  assert.equal(sha256(readFileSync(join(out, 'candidate.json'))), before);
});

test('incomplete capture keeps diagnostics and partial PNGs but writes no candidate.json', { timeout: 180000 }, t => {
  assert.ok(existsSync(worker), `native converter worker is not built: ${worker}. Run \`moon build --target js\` first.`);
  const root = mkdtempSync(join(tmpdir(), 'xdw-capture-incomplete-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const input = join(root, 'demo.xdw');
  copyFileSync(demo, input);
  // demo.xdw has one page; declaring two makes the run incomplete.
  const corpus = corpusFor(input, 2);
  const corpusFile = join(root, 'corpus.json');
  writeFileSync(corpusFile, JSON.stringify(corpus, null, 2));
  const out = join(root, 'out');
  const run = spawnSync(process.execPath, ['compat/xdw/capture.mjs', '--corpus', corpusFile, '--out', out, '--dpi', '96'], { cwd: repoRoot, encoding: 'utf8', timeout: 180000 });
  assert.equal(run.status, 1, `capture should fail:\nstdout:\n${run.stdout}\nstderr:\n${run.stderr}`);
  const summary = JSON.parse(run.stdout);
  assert.equal(summary.status, 'INCOMPLETE');
  assert.equal(summary.oracle, 'NOT_RUN');
  assert.equal(summary.candidate, null);
  assert.equal(summary.pages, 1);
  assert.equal(summary.mismatches, 2);
  assert.equal(summary.errors, 0);
  assert.ok(!existsSync(join(out, 'candidate.json')), 'incomplete capture must not leave a consumable candidate manifest');
  const capture = JSON.parse(readFileSync(join(out, 'capture.json'), 'utf8'));
  assert.equal(capture.status, 'INCOMPLETE');
  assert.equal(capture.oracle, 'NOT_RUN');
  assert.ok(capture.mismatches.some(mismatch => mismatch.kind === 'page-count' && mismatch.expected === 2 && mismatch.actual === 1));
  assert.ok(capture.mismatches.some(mismatch => mismatch.kind === 'missing-page' && mismatch.page === 2));
  assert.equal(capture.pages.length, 1);
  assert.ok(existsSync(join(out, capture.pages[0].image)), 'partial PNGs stay for diagnosis');
  const verifyRun = spawnSync(process.execPath, ['compat/xdw/verify.mjs', corpusFile, join(root, 'oracle.json'), join(out, 'candidate.json')], { cwd: repoRoot, encoding: 'utf8' });
  assert.equal(verifyRun.status, 1);
  assert.equal(JSON.parse(verifyRun.stdout).status, 'ERROR');
});
