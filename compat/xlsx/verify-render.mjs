import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { xlsx_render_basic } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./render.json', import.meta.url)));
for (const [i, c] of cases.entries()) {
  const expected = await BdfDocument.open(new BufferSource(Buffer.from(c.bdf, 'base64')));
  const actual = await BdfDocument.open(new BufferSource(xlsx_render_basic(Buffer.from(c.input, 'base64'), c.mode, c.no_index)));
  assert.deepEqual(actual.manifest.meta, expected.manifest.meta, `XLSX metadata ${i}`);
  assert.deepEqual(actual.manifest.views, expected.manifest.views, `XLSX view ${i}`);
  assert.deepEqual(actual.manifest.tables ?? [], expected.manifest.tables ?? [], `XLSX tables ${i}`);
  assert.equal(actual.manifest.parts.length, expected.manifest.parts.length, `XLSX parts ${i}`);
  for (const [j, p] of actual.manifest.parts.entries()) assert.deepEqual(Buffer.from(await actual.part(p.h)), Buffer.from(await expected.part(expected.manifest.parts[j].h)), `XLSX object ${i}:${j}`);
}
const styled = JSON.parse(await readFile(new URL('./table-values.json', import.meta.url))).at(-1);
assert.equal(xlsx_render_basic(Buffer.from(styled.input, 'base64'), 'none', true).length, 0, 'unsupported styled workbook must be rejected');
const rich = JSON.parse(await readFile(new URL('./cells.json', import.meta.url)))[7];
assert.equal(xlsx_render_basic(Buffer.from(rich.input, 'base64'), 'none', true).length, 0, 'unsupported rich strings must be rejected');
console.log(`${cases.length} basic XLSX renderings match upstream.`);
