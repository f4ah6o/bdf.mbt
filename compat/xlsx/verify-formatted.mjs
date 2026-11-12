import assert from 'node:assert/strict';
import { xlsx_formatted_number, xlsx_formatted_text } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./formatted.json');
for (const [i, c] of cases.entries()) {
  const actual = c.kind === 'text' ? xlsx_formatted_text(c.code, c.text) : xlsx_formatted_number(c.code, c.value, c.date1904);
  assert.deepEqual(JSON.parse(actual), c.want, `formatted case ${i}: ${c.code}, ${c.kind === 'text' ? c.text : c.value}`);
}
console.log(`${cases.length} XLSX formatted cells match upstream.`);
