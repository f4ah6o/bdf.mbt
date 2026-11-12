import assert from 'node:assert/strict';
import { xlsx_iso_date } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./dates.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_iso_date(c.input, c.date1904)), c.want, `XLSX date case ${i} ${JSON.stringify(c.input)}`);
console.log(`${cases.length} XLSX ISO dates and times match upstream.`);
