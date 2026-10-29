import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_parse_format, xlsx_select_format } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./formats.json', import.meta.url)));
for (const [i, c] of cases.entries()) {
  assert.deepEqual(JSON.parse(xlsx_parse_format(c.code)), c.want, `format case ${i}: ${c.code}`);
  for (const [j, value] of [-1000, -12.5, -1, 0, 1, 100, 101].entries()) {
    assert.deepEqual(JSON.parse(xlsx_select_format(c.code, value)), c.picks[j], `format case ${i}, value ${value}: ${c.code}`);
  }
}
console.log(`${cases.length} XLSX number formats parse identically to upstream.`);
