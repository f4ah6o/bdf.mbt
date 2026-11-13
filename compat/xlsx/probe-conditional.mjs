import assert from 'node:assert/strict';
import { isDeepStrictEqual } from 'node:util';
import { BdfDocument, BufferSource, decodeObject, walk, NoopSink } from '@bdfkit/core';
import { xlsx_render_basic, xlsx_render_warnings } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
import { lock } from './oracle/contract.mjs';

// Fast probe for the XLSX conditional-format fixtures: compares the BDF the
// converter renders against the expected BDF of the fixture, and prints the
// cases and object instructions that differ. It converts only the fixtures
// named on the command line, so it stays quick next to verify-render.mjs.
//
// Run after building the JS target and provisioning the oracle:
//   node compat/xlsx/oracle/run-suite.mjs --script compat/xlsx/probe-conditional.mjs -- conditional-missing-dxf-stop-matrix.json
//   node compat/xlsx/oracle/run-suite.mjs --script compat/xlsx/probe-conditional.mjs -- --all-conditional
// Options:
//   --verbose      decode every differing part (fills, paths, text)
//   --text-only    compare views and text index only, not object parts
//   --only a,b,c   probe only these case indices

class OpSink extends NoopSink {
  constructor() {
    super();
    this.events = [];
    this.fill = 0;
    this.stroke = 0;
    this.currentFont = -1;
    this.currentSize = 0;
  }
  save() { this.events.push(['save']); }
  restore() { this.events.push(['restore']); }
  transform(a, b, c, d, e, f) { this.events.push(['transform', n(a), n(b), n(c), n(d), n(e), n(f)]); }
  translate(x, y) { this.events.push(['translate', n(x), n(y)]); }
  scale(x, y) { this.events.push(['scale', n(x), n(y)]); }
  clipRect(x, y, w, h) { this.events.push(['clipRect', n(x), n(y), n(w), n(h)]); }
  fillColor(rgba) { this.fill = rgba >>> 0; this.events.push(['fillColor', hex(this.fill)]); }
  fillPaint(paint) { this.events.push(['fillPaint', paint]); }
  strokeColor(rgba) { this.stroke = rgba >>> 0; this.events.push(['strokeColor', hex(this.stroke)]); }
  strokePaint(paint) { this.events.push(['strokePaint', paint]); }
  line(width, cap, join, miter) { this.events.push(['line', n(width), cap, join, n(miter)]); }
  font(font, size) { this.currentFont = font; this.currentSize = size; this.events.push(['font', font, n(size)]); }
  textStyle(a, b, c, d) { this.events.push(['textStyle', a, b, c, n(d)]); }
  fillRect(x, y, w, h) { this.events.push(['fillRect', n(x), n(y), n(w), n(h), hex(this.fill)]); }
  strokeRect(x, y, w, h) { this.events.push(['strokeRect', n(x), n(y), n(w), n(h), hex(this.stroke)]); }
  fillPath(path, rule) { this.events.push(['fillPath', path, rule, hex(this.fill)]); }
  strokePath(path) { this.events.push(['strokePath', path, hex(this.stroke)]); }
  fillText(text, x, y, advance) { this.events.push(['fillText', text, n(x), n(y), n(advance), this.currentFont, n(this.currentSize)]); }
  strokeText(text, x, y, advance) { this.events.push(['strokeText', text, n(x), n(y), n(advance)]); }
  image(img, x, y, w, h) { this.events.push(['image', img, n(x), n(y), n(w), n(h)]); }
  use(obj) { this.events.push(['use', obj]); }
  useAt(obj, x, y) { this.events.push(['useAt', obj, n(x), n(y)]); }
  alpha(a) { this.events.push(['alpha', n(a)]); }
  groupBegin(a, b, x, y, w, h) { this.events.push(['groupBegin', n(a), b, n(x), n(y), n(w), n(h)]); }
  groupEnd() { this.events.push(['groupEnd']); }
}

function n(v) { return typeof v === 'number' ? Math.round(v * 1000) / 1000 : v; }
function hex(v) { return (v >>> 0).toString(16).padStart(8, '0'); }

function firstDiff(a, b) {
  const len = Math.max(a.length, b.length);
  for (let i = 0; i < len; i++) {
    if (!isDeepStrictEqual(a[i], b[i])) {
      return { at: i, actual: a[i], expected: b[i], beforeActual: a.slice(Math.max(0, i - 2), i), beforeExpected: b.slice(Math.max(0, i - 2), i) };
    }
  }
  return null;
}

async function objectDetail(actual, expected, index) {
  const a = decodeObject(await actual.part(actual.manifest.parts[index].h));
  const e = decodeObject(await expected.part(expected.manifest.parts[index].h));
  const detail = {};
  for (const field of ['opset', 'bbox', 'strings', 'paints', 'fonts', 'images', 'objects']) {
    if (!isDeepStrictEqual(a[field], e[field])) detail[field] = { actual: a[field], expected: e[field] };
  }
  if (!Buffer.from(a.ops).equals(Buffer.from(e.ops))) {
    const sinkA = new OpSink();
    const sinkE = new OpSink();
    walk(a, sinkA);
    walk(e, sinkE);
    detail.ops = firstDiff(sinkA.events, sinkE.events) ?? { actualBytes: a.ops.length, expectedBytes: e.ops.length };
  }
  return detail;
}

function viewDetail(actual, expected) {
  const viewsA = actual.manifest.views;
  const viewsE = expected.manifest.views;
  if (viewsA.length !== viewsE.length) return { viewCount: [viewsA.length, viewsE.length] };
  const detail = [];
  for (let i = 0; i < viewsA.length; i++) {
    for (const key of new Set([...Object.keys(viewsA[i]), ...Object.keys(viewsE[i])])) {
      if (!isDeepStrictEqual(viewsA[i][key], viewsE[i][key])) detail.push({ view: i, field: key, actual: viewsA[i][key], expected: viewsE[i][key] });
    }
  }
  return detail;
}

async function partDiff(actual, expected) {
  if (actual.manifest.parts.length !== expected.manifest.parts.length) {
    return [{ field: 'parts.length', actual: actual.manifest.parts.length, expected: expected.manifest.parts.length }];
  }
  const diffs = [];
  for (let i = 0; i < actual.manifest.parts.length; i++) {
    const a = Buffer.from(await actual.part(actual.manifest.parts[i].h));
    const e = Buffer.from(await expected.part(expected.manifest.parts[i].h));
    if (a.equals(e)) continue;
    const detail = { part: i, type: actual.manifest.parts[i].t, actualBytes: a.length, expectedBytes: e.length };
    if (actual.manifest.parts[i].t === 'obj' && expected.manifest.parts[i].t === 'obj') {
      try {
        detail.object = await objectDetail(actual, expected, i);
      } catch (error) {
        detail.decodeError = String((error && error.message) || error);
      }
    }
    diffs.push(detail);
    if (diffs.length >= 5) break;
  }
  return diffs;
}

async function compareCase(c, label) {
  if (typeof c.input !== 'string' || typeof c.bdf !== 'string') return { kind: 'skipped' };
  const input = Buffer.from(c.input, 'base64');
  const produced = xlsx_render_basic(input, c.mode, c.no_index);
  if (produced.length === 0) return { kind: 'unsupported' };
  const actual = await BdfDocument.open(new BufferSource(produced));
  const expected = await BdfDocument.open(new BufferSource(Buffer.from(c.bdf, 'base64')));
  const diffs = [];
  try {
    assert.deepEqual(JSON.parse(xlsx_render_warnings(input, c.mode, c.no_index)), c.warnings ?? []);
  } catch {
    diffs.push({ field: 'warnings', actual: JSON.parse(xlsx_render_warnings(input, c.mode, c.no_index)), expected: c.warnings ?? [] });
  }
  for (const field of ['meta', 'tables']) {
    if (!isDeepStrictEqual(actual.manifest[field], expected.manifest[field])) diffs.push({ field, actual: actual.manifest[field], expected: expected.manifest[field] });
  }
  if (!isDeepStrictEqual(actual.manifest.views, expected.manifest.views)) diffs.push({ field: 'views', detail: viewDetail(actual, expected) });
  const parts = await partDiff(actual, expected);
  if (parts.length) diffs.push({ field: 'parts', detail: parts });
  return { kind: diffs.length === 0 ? 'match' : 'diff', label, diffs };
}

const args = process.argv.slice(2);
const verbose = args.includes('--verbose');
const textOnly = args.includes('--text-only');
const onlyArg = args.indexOf('--only');
const only = onlyArg >= 0 ? new Set(args[onlyArg + 1].split(',').map(Number)) : null;
const files = args.filter((a, i) => !a.startsWith('--') && !(onlyArg >= 0 && i === onlyArg + 1));
if (args.includes('--all-conditional')) {
  for (const name of Object.keys(lock.fixtures).sort()) {
    if (/^conditional-.*\.json$/.test(name) && !name.includes('unsupported') && !name.includes('inputs')) files.push(name);
  }
}
if (files.length === 0) {
  console.error('usage: probe-conditional.mjs <fixture.json>... [--verbose] [--text-only] [--only 1,2,5]');
  process.exit(2);
}
let totalDiffer = 0;
for (const file of files) {
  const cases = await loadFixture(`./${file}`);
  const differences = [];
  let compared = 0;
  let unsupported = 0;
  let skipped = 0;
  const details = [];
  for (const [j, c] of cases.entries()) {
    if (only && !only.has(j)) continue;
    const result = await compareCase(c);
    if (result.kind === 'skipped') { skipped++; continue; }
    if (result.kind === 'unsupported') { unsupported++; continue; }
    compared++;
    if (result.kind === 'diff') {
      differences.push(j);
      if (details.length < (verbose ? Infinity : 3)) details.push({ index: j, diffs: result.diffs });
    }
  }
  totalDiffer += differences.length;
  console.log(`${file}: ${differences.length} differ / ${compared} compared` + (unsupported ? `, ${unsupported} unsupported` : '') + (skipped ? `, ${skipped} skipped` : ''));
  if (differences.length) console.log('  indices: ' + JSON.stringify(differences));
  for (const d of details) console.log('  ' + JSON.stringify(d));
}
console.log(`total differing cases: ${totalDiffer}`);
