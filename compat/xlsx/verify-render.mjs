import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { xlsx_render_basic, xlsx_render_warnings, xlsx_render_error } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const index = JSON.parse(await readFile(new URL('./render/index.json', import.meta.url)));
assert.ok(index.files.length > 0, 'XLSX rendering fixture list must not be empty');
let i = 0;
for (const file of index.files) {
  assert.match(file, /^\d{3}\.json$/, 'invalid XLSX rendering fixture name');
  const cases = JSON.parse(await readFile(new URL(`./render/${file}`, import.meta.url)));
  for (const c of cases) {
    const expected = await BdfDocument.open(new BufferSource(Buffer.from(c.bdf, 'base64')));
    const actual = await BdfDocument.open(new BufferSource(xlsx_render_basic(Buffer.from(c.input, 'base64'), c.mode, c.no_index)));
    assert.deepEqual(JSON.parse(xlsx_render_warnings(Buffer.from(c.input, 'base64'), c.mode, c.no_index)), c.warnings ?? [], `XLSX warnings ${i}`);
    assert.deepEqual(actual.manifest.meta, expected.manifest.meta, `XLSX metadata ${i}`);
    assert.deepEqual(actual.manifest.views, expected.manifest.views, `XLSX view ${i}`);
    assert.deepEqual(actual.manifest.tables ?? [], expected.manifest.tables ?? [], `XLSX tables ${i}`);
    assert.equal(actual.manifest.parts.length, expected.manifest.parts.length, `XLSX parts ${i}`);
    for (const [j, p] of actual.manifest.parts.entries()) assert.deepEqual(Buffer.from(await actual.part(p.h)), Buffer.from(await expected.part(expected.manifest.parts[j].h)), `XLSX object ${i}:${j}`);
    i++;
  }
}
assert.equal(i, index.count, 'XLSX rendering fixture count');
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
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'painting base styles must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /row or column styles with (fills|borders)/);
}
console.log(`${i} basic XLSX renderings match upstream.`);
