import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, symlinkSync, truncateSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { PNG } from 'pngjs';
import { buildCandidate, inspectPng, joinTextRuns, parseArgs, prepareOutputDir, readCorpus, readGit, resolveContained, statusFor } from './capture.mjs';
import { localPath, sha256, verify } from './verify.mjs';

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'xdw-capture-unit-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const source = Buffer.from('SYNTHETIC CAPTURE CONTRACT TEST ONLY, NOT AN XDW');
  writeFileSync(join(root, 'sample.xdw'), source);
  const corpus = {
    schema: 1,
    expectedDocuments: 1,
    expectedPages: 1,
    thresholds: { channelDelta: 0, maxChangedRatio: 0 },
    thresholdRationale: 'Synthetic exact comparison, not a real-world accuracy threshold',
    documents: [{
      id: 'sample',
      file: 'sample.xdw',
      sha256: sha256(source),
      pages: 1,
      blankPages: [],
      access: 'public',
      source: 'https://example.com/synthetic-test',
      licenseNotes: 'Original synthetic test bytes, never a real document',
    }],
  };
  const corpusFile = join(root, 'corpus.json');
  const save = () => writeFileSync(corpusFile, JSON.stringify(corpus));
  save();
  return { root, source, corpus, corpusFile, save };
}

function inkPng() {
  const png = new PNG({ width: 4, height: 4 });
  png.data.fill(255);
  png.data[0] = 0;
  return PNG.sync.write(png);
}

test('parseArgs requires corpus and output and bounds dpi and timeout', () => {
  assert.deepEqual(parseArgs(['--corpus', 'c.json', '--out', 'run']), { dpi: 96, timeoutMs: 120000, corpusFile: 'c.json', outDir: 'run' });
  assert.equal(parseArgs(['--corpus', 'c.json', '--out', 'run', '--dpi', '144']).dpi, 144);
  assert.equal(parseArgs(['--corpus', 'c.json', '--out', 'run', '--timeout-ms', '2147483647']).timeoutMs, 2147483647);
  assert.throws(() => parseArgs([]), /--corpus is required/);
  assert.throws(() => parseArgs(['--corpus', 'c.json']), /--out is required/);
  assert.throws(() => parseArgs(['--corpus', 'c.json', '--out', 'run', '--dpi', '0']), /--dpi/);
  assert.throws(() => parseArgs(['--corpus', 'c.json', '--out', 'run', '--dpi', '601']), /--dpi/);
  assert.throws(() => parseArgs(['--corpus', 'c.json', '--out', 'run', '--timeout-ms', '0']), /--timeout-ms/);
  assert.throws(() => parseArgs(['--corpus', 'c.json', '--out', 'run', '--timeout-ms', '1.5']), /--timeout-ms/);
  assert.throws(() => parseArgs(['--corpus', 'c.json', '--out', 'run', '--timeout-ms', '2147483648']), /--timeout-ms/);
  assert.throws(() => parseArgs(['--corpus', 'c.json', '--out', 'run', '--unknown']), /unknown argument/);
  assert.throws(() => parseArgs(['--corpus']), /requires a value/);
});

test('readCorpus returns the validated document path and hash', t => {
  const f = fixture(t);
  const { corpus, documents } = readCorpus(f.corpusFile);
  assert.equal(corpus.expectedPages, 1);
  assert.equal(documents.length, 1);
  assert.equal(documents[0].id, 'sample');
  assert.equal(documents[0].sha256, sha256(f.source));
  assert.equal(documents[0].path, realpathSync(join(f.root, 'sample.xdw')));
});

const invalidCorpus = [
  ['source hash mismatch', f => { f.corpus.documents[0].sha256 = '0'.repeat(64); }, /source hash/],
  ['document count mismatch', f => { f.corpus.expectedDocuments = 2; }, /document count/],
  ['page count mismatch', f => { f.corpus.expectedPages = 2; }, /page count/],
  ['duplicate document id', f => { f.corpus.documents.push({ ...f.corpus.documents[0] }); f.corpus.expectedDocuments = 2; }, /duplicate/],
  ['private source', f => { f.corpus.documents[0].access = 'private'; }, /provenance/],
  ['missing source', f => { delete f.corpus.documents[0].source; }, /provenance/],
  ['missing license notes', f => { f.corpus.documents[0].licenseNotes = ''; }, /provenance/],
  ['invalid blank page', f => { f.corpus.documents[0].blankPages = [2]; }, /blank page/],
  ['absolute path', f => { f.corpus.documents[0].file = '/etc/hostname'; }, /relative/],
  ['parent traversal', f => {
    const outside = join(f.root, '..', `${basename(f.root)}-outside.xdw`);
    writeFileSync(outside, 'outside');
    f.corpus.documents[0].file = `../${basename(outside)}`;
    return () => rmSync(outside, { force: true });
  }, /escapes/],
  ['symlink escape', f => { symlinkSync('/etc/hostname', join(f.root, 'escape.xdw')); f.corpus.documents[0].file = 'escape.xdw'; }, /escapes/],
  ['oversized input', f => { writeFileSync(join(f.root, 'large.xdw'), ''); truncateSync(join(f.root, 'large.xdw'), 64 * 1024 * 1024 + 1); f.corpus.documents[0].file = 'large.xdw'; }, /64 MiB/],
];
for (const [name, change, pattern] of invalidCorpus) {
  test(`readCorpus rejects ${name}`, t => {
    const f = fixture(t);
    const cleanup = change(f);
    f.save();
    try {
      assert.throws(() => readCorpus(f.corpusFile), pattern);
    } finally {
      if (typeof cleanup === 'function') cleanup();
    }
  });
}

test('resolveContained keeps files inside the root and rejects escapes', t => {
  const root = mkdtempSync(join(tmpdir(), 'xdw-capture-paths-'));
  const outside = join(root, '..', `${basename(root)}-outside.txt`);
  t.after(() => {
    rmSync(root, { recursive: true, force: true });
    rmSync(outside, { force: true });
  });
  writeFileSync(join(root, 'inside.txt'), 'inside');
  writeFileSync(join(root, '..foo'), 'dotdot-prefixed name, still inside');
  writeFileSync(outside, 'outside');
  symlinkSync('/etc/hostname', join(root, 'escape.txt'));
  const rootReal = realpathSync(root);
  assert.equal(resolveContained(root, 'inside.txt'), join(rootReal, 'inside.txt'));
  assert.equal(resolveContained(root, '..foo'), join(rootReal, '..foo'));
  assert.equal(resolveContained(root, 'missing.txt'), join(rootReal, 'missing.txt'));
  assert.throws(() => resolveContained(root, `../${basename(outside)}`), /escapes/);
  assert.throws(() => resolveContained(root, 'escape.txt'), /escapes/);
});

test('Windows parent traversal is rejected by both containment helpers', { skip: process.platform !== 'win32' }, t => {
  const root = mkdtempSync(join(tmpdir(), 'xdw-capture-winpaths-'));
  const outside = join(root, '..', `${basename(root)}-outside.txt`);
  t.after(() => {
    rmSync(root, { recursive: true, force: true });
    rmSync(outside, { force: true });
  });
  writeFileSync(outside, 'outside');
  assert.throws(() => resolveContained(root, `..\\${basename(outside)}`), /escapes/);
  assert.throws(() => localPath(root, `..\\${basename(outside)}`), /escapes/);
});

test('joinTextRuns follows the renderer separator rules', () => {
  assert.equal(joinTextRuns([]), '');
  assert.equal(joinTextRuns([{ b: 0, sep: 2, text: 'Hello' }, { b: 0, sep: 1, text: 'World' }]), 'Hello World');
  assert.equal(joinTextRuns([{ b: 0, sep: 2, text: 'Hello' }, { b: 0, sep: 2, text: 'World' }]), 'Hello\nWorld');
  assert.equal(joinTextRuns([{ b: 0, sep: 2, text: 'Hello' }, { b: 0, sep: 0, text: 'World' }]), 'HelloWorld');
  assert.equal(joinTextRuns([{ b: 0, sep: 2, text: 'Hello' }, { b: 1, sep: 1, text: 'World' }]), 'Hello\n\nWorld');
  assert.throws(() => joinTextRuns([{ b: 0, sep: 0, text: 1 }]), /not a string/);
});

test('inspectPng reports dimensions and blank pages after compositing on white', () => {
  const png = new PNG({ width: 4, height: 4 });
  png.data.fill(255);
  const white = PNG.sync.write(png);
  assert.deepEqual(inspectPng(white, { width: 4, height: 4 }), { width: 4, height: 4, blank: true });
  png.data[0] = 0;
  const ink = PNG.sync.write(png);
  assert.deepEqual(inspectPng(ink), { width: 4, height: 4, blank: false });
  const transparent = new PNG({ width: 4, height: 4 });
  transparent.data.fill(0);
  assert.equal(inspectPng(PNG.sync.write(transparent)).blank, true);
  assert.throws(() => inspectPng(Buffer.from('not PNG')), /not a PNG/);
  assert.throws(() => inspectPng(white, { width: 8, height: 8 }), /does not match/);
});

test('prepareOutputDir creates a private temp directory and refuses an existing output', t => {
  const root = mkdtempSync(join(tmpdir(), 'xdw-capture-out-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const { outPath, tmpDir } = prepareOutputDir(join(root, 'run'));
  assert.equal(outPath, join(root, 'run'));
  assert.ok(existsSync(tmpDir));
  assert.ok(existsSync(join(tmpDir, 'candidate')));
  if (process.platform !== 'win32') {
    assert.equal(statSync(tmpDir).mode & 0o777, 0o700);
    assert.equal(statSync(join(tmpDir, 'candidate')).mode & 0o777, 0o700);
  }
  rmSync(tmpDir, { recursive: true, force: true });
  mkdirSync(outPath);
  assert.throws(() => prepareOutputDir(outPath), /already exists/);
});

test('statusFor never returns PASS', () => {
  assert.equal(statusFor({ errors: [], mismatches: [], warnings: [] }), 'CAPTURED');
  assert.equal(statusFor({ errors: [], mismatches: [{ kind: 'page-count' }], warnings: [] }), 'INCOMPLETE');
  assert.equal(statusFor({ errors: [], mismatches: [], warnings: [{ kind: 'converter' }] }), 'INCOMPLETE');
  assert.equal(statusFor({ errors: [{ kind: 'capture' }], mismatches: [], warnings: [] }), 'ERROR');
  assert.notEqual(statusFor({ errors: [], mismatches: [], warnings: [] }), 'PASS');
});

test('buildCandidate emits a manifest only for a fully captured run', () => {
  const pages = [{ document: 'sample', page: 1 }];
  const base = {
    status: 'CAPTURED',
    dirty: false,
    version: '0.1.0',
    commit: 'a'.repeat(40),
    createdAt: '2026-11-12T00:00:00Z',
    platform: 'synthetic',
    fonts: { assumption: 'synthetic' },
    dpi: 96,
  };
  const candidate = buildCandidate(base, pages);
  assert.equal(candidate.role, 'candidate');
  assert.equal(candidate.engine, 'bdf.mbt');
  assert.equal(candidate.status, 'CAPTURED');
  assert.equal(candidate.dirty, false);
  assert.deepEqual(candidate.pages, pages);
  assert.equal(buildCandidate({ ...base, status: 'INCOMPLETE' }, pages), null);
  assert.equal(buildCandidate({ ...base, status: 'ERROR' }, pages), null);
  assert.equal(buildCandidate({ ...base, dirty: null }, pages), null);
  assert.equal(buildCandidate(base, []), null);
});

test('readGit preserves dirty provenance instead of inventing it', t => {
  const root = mkdtempSync(join(tmpdir(), 'xdw-capture-git-'));
  const plain = mkdtempSync(join(tmpdir(), 'xdw-capture-nogit-'));
  t.after(() => {
    rmSync(root, { recursive: true, force: true });
    rmSync(plain, { recursive: true, force: true });
  });
  const git = (...args) => spawnSync('git', args, { cwd: root, encoding: 'utf8' });
  const init = git('init', '-q');
  assert.equal(init.status, 0, init.stderr);
  const commit = git('-c', 'user.email=synthetic@example.com', '-c', 'user.name=Synthetic', 'commit', '--allow-empty', '-q', '-m', 'init');
  assert.equal(commit.status, 0, commit.stderr);
  const clean = readGit(root);
  assert.equal(clean.dirty, false);
  assert.deepEqual(clean.status, []);
  assert.equal(clean.statusError, undefined);
  writeFileSync(join(root, 'untracked.txt'), 'x');
  const dirty = readGit(root);
  assert.equal(dirty.dirty, true);
  assert.ok(dirty.status.some(line => line.includes('untracked.txt')));
  assert.throws(() => readGit(plain), /git rev-parse HEAD failed/);
});

test('synthetic oracle and candidate manifests pass the verifier', t => {
  const f = fixture(t);
  const bytes = inkPng();
  mkdirSync(join(f.root, 'oracle'));
  mkdirSync(join(f.root, 'candidate'));
  writeFileSync(join(f.root, 'oracle/sample-1.png'), bytes);
  writeFileSync(join(f.root, 'candidate/sample-1.png'), bytes);
  const page = {
    document: 'sample',
    page: 1,
    inputSha256: sha256(f.source),
    sha256: sha256(bytes),
    width: 4,
    height: 4,
    text: 'synthetic',
    warnings: [],
  };
  const oracle = {
    schema: 1,
    role: 'oracle',
    engine: 'DocuWorks',
    version: 'synthetic',
    createdAt: '2026-11-12T00:00:00Z',
    platform: 'synthetic',
    fonts: 'synthetic',
    dpi: 96,
    pages: [{ ...page, image: 'oracle/sample-1.png' }],
  };
  const candidate = buildCandidate({
    status: 'CAPTURED',
    dirty: false,
    version: '0.1.0',
    commit: 'a'.repeat(40),
    createdAt: '2026-11-12T00:00:00Z',
    platform: 'synthetic',
    fonts: { assumption: 'synthetic' },
    dpi: 96,
  }, [{ ...page, image: 'candidate/sample-1.png' }]);
  const oracleFile = join(f.root, 'oracle.json');
  const candidateFile = join(f.root, 'candidate.json');
  writeFileSync(oracleFile, JSON.stringify(oracle));
  writeFileSync(candidateFile, JSON.stringify(candidate));
  const report = verify({ corpusFile: f.corpusFile, oracleFile, candidateFile });
  assert.equal(report.status, 'PASS');
  assert.equal(report.candidate.status, 'CAPTURED');
  assert.equal(report.candidate.dirty, false);
  assert.equal(report.comparedPages, 1);
});

test('verifier rejects a candidate manifest that is not CAPTURED', t => {
  const f = fixture(t);
  const bytes = inkPng();
  mkdirSync(join(f.root, 'oracle'));
  mkdirSync(join(f.root, 'candidate'));
  writeFileSync(join(f.root, 'oracle/sample-1.png'), bytes);
  writeFileSync(join(f.root, 'candidate/sample-1.png'), bytes);
  const page = {
    document: 'sample',
    page: 1,
    inputSha256: sha256(f.source),
    sha256: sha256(bytes),
    width: 4,
    height: 4,
    text: 'synthetic',
    warnings: [],
  };
  const oracle = {
    schema: 1,
    role: 'oracle',
    engine: 'DocuWorks',
    version: 'synthetic',
    createdAt: '2026-11-12T00:00:00Z',
    platform: 'synthetic',
    fonts: 'synthetic',
    dpi: 96,
    pages: [{ ...page, image: 'oracle/sample-1.png' }],
  };
  const candidate = {
    schema: 1,
    role: 'candidate',
    engine: 'bdf.mbt',
    version: '0.1.0',
    commit: 'a'.repeat(40),
    createdAt: '2026-11-12T00:00:00Z',
    platform: 'synthetic',
    fonts: 'synthetic',
    dpi: 96,
    status: 'INCOMPLETE',
    dirty: false,
    pages: [{ ...page, image: 'candidate/sample-1.png' }],
  };
  const oracleFile = join(f.root, 'oracle.json');
  const candidateFile = join(f.root, 'candidate.json');
  writeFileSync(oracleFile, JSON.stringify(oracle));
  writeFileSync(candidateFile, JSON.stringify(candidate));
  assert.throws(() => verify({ corpusFile: f.corpusFile, oracleFile, candidateFile }), /status must be CAPTURED/);
});
