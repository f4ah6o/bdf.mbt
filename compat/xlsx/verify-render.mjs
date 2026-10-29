import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { xlsx_render_basic, xlsx_render_warnings, xlsx_render_error } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const index = JSON.parse(await readFile(new URL('./render/index.json', import.meta.url)));
assert.ok(index.files.length > 0, 'XLSX rendering fixture list must not be empty');
let i = 0;
async function verifyCase(c, label) {
  const expected = await BdfDocument.open(new BufferSource(Buffer.from(c.bdf, 'base64')));
  const actual = await BdfDocument.open(new BufferSource(xlsx_render_basic(Buffer.from(c.input, 'base64'), c.mode, c.no_index)));
  assert.deepEqual(JSON.parse(xlsx_render_warnings(Buffer.from(c.input, 'base64'), c.mode, c.no_index)), c.warnings ?? [], `XLSX warnings ${label}`);
  assert.deepEqual(actual.manifest.meta, expected.manifest.meta, `XLSX metadata ${label}`);
  assert.deepEqual(actual.manifest.views, expected.manifest.views, `XLSX view ${label}`);
  assert.deepEqual(actual.manifest.tables ?? [], expected.manifest.tables ?? [], `XLSX tables ${label}`);
  assert.equal(actual.manifest.parts.length, expected.manifest.parts.length, `XLSX parts ${label}`);
  for (const [j, p] of actual.manifest.parts.entries()) assert.deepEqual(Buffer.from(await actual.part(p.h)), Buffer.from(await expected.part(expected.manifest.parts[j].h)), `XLSX object ${label}:${j}`);
}
for (const file of index.files) {
  assert.match(file, /^\d{3}\.json$/, 'invalid XLSX rendering fixture name');
  const cases = JSON.parse(await readFile(new URL(`./render/${file}`, import.meta.url)));
  for (const c of cases) {
    await verifyCase(c, i);
    i++;
  }
}
assert.equal(i, index.count, 'XLSX rendering fixture count');
const baseFills = JSON.parse(await readFile(new URL('./base-fill.json', import.meta.url)));
assert.equal(baseFills.length, 240, 'row and column fill fixture count');
for (const [j, c] of baseFills.entries()) await verifyCase(c, `base fill ${j}`);
const baseBorders = JSON.parse(await readFile(new URL('./base-border.json', import.meta.url)));
assert.equal(baseBorders.length, 240, 'row and column border fixture count');
for (const [j, c] of baseBorders.entries()) await verifyCase(c, `base border ${j}`);
const plainRuns = JSON.parse(await readFile(new URL('./plain-run.json', import.meta.url)));
assert.equal(plainRuns.length, 120, 'plain rich-text run fixture count');
for (const [j, c] of plainRuns.entries()) await verifyCase(c, `plain run ${j}`);
const unsupportedRuns = JSON.parse(await readFile(new URL('./plain-run-unsupported.json', import.meta.url)));
assert.equal(unsupportedRuns.length, 8, 'unsupported rich-text run fixture count');
for (const encoded of unsupportedRuns) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported rich-text runs must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /rich text/);
}
const largeFill = Buffer.from(JSON.parse(await readFile(new URL('./base-fill-too-large.json', import.meta.url))), 'base64');
assert.equal(xlsx_render_basic(largeFill, 'none', true).length, 0, 'oversized base fills must be rejected');
assert.match(xlsx_render_error(largeFill, 'none', true), /row or column fill exceeds the supported view size/);
const largeBorder = Buffer.from(JSON.parse(await readFile(new URL('./base-border-too-large.json', import.meta.url))), 'base64');
assert.equal(xlsx_render_basic(largeBorder, 'none', true).length, 0, 'oversized base borders must be rejected');
assert.match(xlsx_render_error(largeBorder, 'none', true), /row or column border exceeds the supported view size/);
const styled = JSON.parse(await readFile(new URL('./cells.json', import.meta.url)))[0];
assert.equal(xlsx_render_basic(Buffer.from(styled.input, 'base64'), 'none', true).length, 0, 'unsupported styled workbook must be rejected');
const rich = JSON.parse(await readFile(new URL('./cells.json', import.meta.url)))[7];
assert.equal(xlsx_render_basic(Buffer.from(rich.input, 'base64'), 'none', true).length, 0, 'unsupported rich strings must be rejected');
const autoHeight = JSON.parse(await readFile(new URL('./auto-height.json', import.meta.url)));
assert.ok(xlsx_render_basic(Buffer.from(autoHeight, 'base64'), 'none', true).length, 'nondefault font sizes on auto-height rows must convert');
const unsupportedBase = JSON.parse(await readFile(new URL('./base-style-unsupported.json', import.meta.url)));
assert.equal(unsupportedBase.length, 4, 'row and column fill and border fixtures');
for (const encoded of unsupportedBase) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported base styles must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /row or column styles with (fills|complex borders)/);
}
console.log(`${i} basic XLSX renderings, ${baseFills.length} base fills, ${baseBorders.length} base borders, and ${plainRuns.length} plain runs match upstream.`);
