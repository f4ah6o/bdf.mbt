import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_table_values, xlsx_used } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./table-values.json', import.meta.url)));
for (const [i, c] of cases.entries()) {
  const input = Buffer.from(c.input, 'base64');
  assert.deepEqual(JSON.parse(xlsx_used(input, c.part)), c.range, `table range case ${i}`);
  assert.equal(Buffer.from(xlsx_table_values(input, c.part, c.locale, JSON.stringify(c.names))).toString('base64'), c.parquet, `table bytes case ${i}`);
}
console.log(`${cases.length} XLSX worksheet value tables match upstream Parquet bytes.`);
