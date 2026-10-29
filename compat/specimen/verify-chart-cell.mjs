import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { begin_chart_cells, paint_chart_cell, specimen_page_object } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const {files, cases} = JSON.parse(gunzipSync(await readFile(new URL('./chart-cell.json.gz', import.meta.url))));
const decoded = Object.fromEntries(Object.entries(files).map(([name, data]) => [name, gunzipSync(Buffer.from(data, 'base64'))]));
for (const [i, {name, index, outlined, glyphHash, height, object, cells}] of cases.entries()) {
  const page = begin_chart_cells(decoded[name], index, glyphHash, outlined, height);
  for (const cell of cells) paint_chart_cell(page, cell.Glyph, cell.X, cell.Y, cell.W, cell.H, cell.Alt);
  const actual = Buffer.from(specimen_page_object(page));
  const expected = Buffer.from(object, 'base64');
  assert.ok(actual.equals(expected), `case ${i} (${name}, face ${index}, outlined=${outlined}): object; first difference ${actual.findIndex((v, k) => v !== expected[k])}, lengths ${actual.length}/${expected.length}`);
}
console.log(`${cases.length * 200} character-chart glyph cells match upstream byte for byte.`);
