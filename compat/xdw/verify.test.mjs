import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, rmSync, symlinkSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { PNG } from 'pngjs';
import { verify, sha256 } from './verify.mjs';
function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'xdw-fidelity-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const source = Buffer.from('SYNTHETIC CONTRACT TEST ONLY, NOT AN XDW');
  writeFileSync(join(root, 'sample.xdw'), source);
  const png = new PNG({ width: 4, height: 4 }); png.data.fill(255); png.data[0] = 0; png.data[1] = 0; png.data[2] = 0;
  const image = PNG.sync.write(png); writeFileSync(join(root, 'page.png'), image);
  const corpus = { schema: 1, expectedDocuments: 1, expectedPages: 1, thresholds: { channelDelta: 0, maxChangedRatio: 0 }, thresholdRationale: 'Synthetic exact comparison, not a real-world accuracy threshold', documents: [{ id: 'sample', file: 'sample.xdw', access: 'public', source: 'https://example.com/synthetic-test', licenseNotes: 'Original synthetic test bytes, never a real document', sha256: sha256(source), pages: 1, blankPages: [] }] };
  const page = { document: 'sample', page: 1, inputSha256: sha256(source), image: 'page.png', sha256: sha256(image), width: 4, height: 4, text: 'hello', warnings: [] };
  const oracle = { schema: 1, role: 'oracle', engine: 'DocuWorks', version: 'synthetic-test', createdAt: '2026-11-12T00:00:00Z', platform: 'synthetic-test', fonts: 'synthetic-test', dpi: 96, pages: [{ ...page }] };
  const candidate = { ...oracle, role: 'candidate', engine: 'bdf.mbt', commit: 'a'.repeat(40), pages: [{ ...page }] };
  const paths = { corpusFile: join(root, 'corpus.json'), oracleFile: join(root, 'oracle.json'), candidateFile: join(root, 'candidate.json') };
  const save = () => { writeFileSync(paths.corpusFile, JSON.stringify(corpus)); writeFileSync(paths.oracleFile, JSON.stringify(oracle)); writeFileSync(paths.candidateFile, JSON.stringify(candidate)); };
  return { root, corpus, oracle, candidate, png, paths, save, run: () => { save(); return verify(paths); } };
}
test('identical synthetic evidence passes and counts every page', t => { const f = fixture(t); assert.equal(f.run().status, 'PASS'); assert.equal(f.run().comparedPages, 1); });
test('missing oracle is NOT_RUN and CLI exits 2', t => { const f = fixture(t); f.save(); assert.equal(verify({ corpusFile: f.paths.corpusFile }).status, 'NOT_RUN'); const r = spawnSync(process.execPath, ['compat/xdw/verify.mjs', f.paths.corpusFile], { encoding: 'utf8' }); assert.equal(r.status, 2); assert.equal(JSON.parse(r.stdout).status, 'NOT_RUN'); });
const invalid = [
  ['missing document id', f => delete f.corpus.documents[0].id, /document id/],
  ['numeric document id', f => f.corpus.documents[0].id = 123, /document id/],
  ['empty corpus', f => f.corpus.documents = [], /at least/],
  ['wrong document count', f => f.corpus.expectedDocuments = 2, /document count/],
  ['wrong total page count', f => f.corpus.expectedPages = 2, /page count/],
  ['duplicate document', f => { f.corpus.documents.push({ ...f.corpus.documents[0] }); f.corpus.expectedDocuments = 2; }, /duplicate/],
  ['missing source', f => f.corpus.documents[0].file = 'absent.xdw', /ENOENT/],
  ['source hash changed', f => f.corpus.documents[0].sha256 = '0'.repeat(64), /source hash/],
  ['private source rejected', f => f.corpus.documents[0].access = 'private', /provenance/],
  ['missing page', f => f.candidate.pages = [], /missing sample:1/],
  ['duplicate page', f => f.candidate.pages.push({ ...f.candidate.pages[0] }), /duplicate/],
  ['extra page', f => f.candidate.pages[0].page = 2, /unexpected/],
  ['wrong source association', f => f.candidate.pages[0].inputSha256 = '0'.repeat(64), /input hash/],
  ['missing image', f => f.candidate.pages[0].image = 'absent.png', /ENOENT/],
  ['image changed', f => f.candidate.pages[0].sha256 = '0'.repeat(64), /image hash/],
  ['image dimensions lied', f => f.candidate.pages[0].width = 8, /PNG dimensions/],
  ['large allocation refused', f => f.candidate.pages[0].width = 20000001, /dimensions/],
  ['dpi mismatch', f => f.candidate.dpi = 72, /dpi/],
  ['missing environment', f => delete f.oracle.fonts, /fonts/],
  ['upstream is not pure oracle', f => f.oracle.engine = 'ezpzxdw', /genuine/],
  ['warnings are not clean', f => f.candidate.pages[0].warnings = ['skipped record'], /warnings/],
  ['unknown text is not empty text', f => delete f.candidate.pages[0].text, /text/],
  ['invalid ratio', f => f.corpus.thresholds.maxChangedRatio = 1, /threshold/],
  ['path escape via symlink', f => { symlinkSync('/etc/hostname', join(f.root, 'escape')); f.corpus.documents[0].file = 'escape'; }, /escapes/],
];
for (const [name, change, pattern] of invalid) test(name, t => { const f = fixture(t); change(f); assert.throws(f.run, pattern); });
test('real pixel and text differences fail', t => { const f = fixture(t); f.png.data[4] = 0; const b = PNG.sync.write(f.png); writeFileSync(join(f.root, 'different.png'), b); Object.assign(f.candidate.pages[0], { image: 'different.png', sha256: sha256(b), text: 'wrong' }); const r = f.run(); assert.equal(r.status, 'FAIL'); assert.equal(r.results[0].changedPixels, 1); assert.equal(r.results[0].textEqual, false); });
for (const alpha of [0, 255]) test(`blank capture rejected alpha=${alpha}`, t => { const f = fixture(t); f.png.data.fill(255); for (let i = 3; i < f.png.data.length; i += 4) f.png.data[i] = alpha; const b = PNG.sync.write(f.png); writeFileSync(join(f.root, 'blank.png'), b); Object.assign(f.candidate.pages[0], { image: 'blank.png', sha256: sha256(b) }); assert.throws(f.run, /blank/); });
test('malformed PNG rejected even with valid checksum', t => { const f = fixture(t); const b = Buffer.from('not PNG'); writeFileSync(join(f.root, 'bad.png'), b); Object.assign(f.candidate.pages[0], { image: 'bad.png', sha256: sha256(b) }); assert.throws(f.run, /not a PNG/); });
// Regression: pngjs accepts a second IHDR and follows its dimensions.
// The gate must reject it before decode, not compare undefined pixel values.
test('duplicate IHDR cannot shrink the decoded image into a false pass', t => {
  const f = fixture(t);
  const large = PNG.sync.write(f.png);
  const smallPng = new PNG({ width: 1, height: 1 }); smallPng.data.fill(255);
  const small = PNG.sync.write(smallPng);
  const b = Buffer.concat([large.subarray(0, 33), small.subarray(8)]);
  writeFileSync(join(f.root, 'duplicate.png'), b);
  Object.assign(f.candidate.pages[0], { image: 'duplicate.png', sha256: sha256(b) });
  assert.throws(f.run, /duplicate IHDR/);
});
test('interlaced PNG rejected before the unbounded decoder branch', t => {
  const f = fixture(t); const b = PNG.sync.write(f.png); b[28] = 1;
  writeFileSync(join(f.root, 'interlaced.png'), b);
  Object.assign(f.candidate.pages[0], { image: 'interlaced.png', sha256: sha256(b) });
  assert.throws(f.run, /interlaced/);
});

// Deterministic generated cases: pixel count and boundary thresholds must agree
// with the known mutation count, independently of file encoding.
test('generated pixel mutations obey exact threshold boundaries', t => {
  for (let count = 1; count <= 15; count++) {
    const f = fixture(t);
    for (let p = 1; p <= count; p++) f.png.data[p * 4] = 0;
    const b = PNG.sync.write(f.png);
    writeFileSync(join(f.root, 'changed.png'), b);
    Object.assign(f.candidate.pages[0], { image: 'changed.png', sha256: sha256(b) });
    f.corpus.thresholds.maxChangedRatio = count / 16;
    const accepted = f.run();
    assert.equal(accepted.results[0].changedPixels, count);
    assert.equal(accepted.status, 'PASS');
    f.corpus.thresholds.maxChangedRatio = (count - 0.5) / 16;
    assert.equal(f.run().status, 'FAIL');
    f.corpus.thresholds.maxChangedRatio = count / 16;
    f.candidate.pages[0].text = 'different';
    assert.equal(f.run().status, 'FAIL');
  }
});
