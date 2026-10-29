import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_formatted_number, xlsx_formatted_text } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./formatted.json', import.meta.url)));
for (const [i, c] of cases.entries()) {
  const actual = c.kind === 'text' ? xlsx_formatted_text(c.code, c.text) : xlsx_formatted_number(c.code, c.value, c.date1904);
  assert.deepEqual(JSON.parse(actual), c.want, `formatted case ${i}: ${c.code}, ${c.kind === 'text' ? c.text : c.value}`);
}
console.log(`${cases.length} XLSX formatted cells match upstream.`);
