import assert from 'node:assert/strict';
import { xlsx_parse_format, xlsx_select_format, xlsx_format_layouts } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./formats.json');
for (const [i, c] of cases.entries()) {
  assert.deepEqual(JSON.parse(xlsx_parse_format(c.code)), c.want, `format case ${i}: ${c.code}`);
  assert.deepEqual(JSON.parse(xlsx_format_layouts(c.code)), c.layouts, `format layout ${i}: ${c.code}`);
  for (const [j, value] of [-1000, -12.5, -1, 0, 1, 100, 101].entries()) {
    assert.deepEqual(JSON.parse(xlsx_select_format(c.code, value)), c.picks[j], `format case ${i}, value ${value}: ${c.code}`);
  }
}
console.log(`${cases.length} XLSX number formats parse identically to upstream.`);
