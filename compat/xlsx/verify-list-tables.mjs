import assert from 'node:assert/strict';
import { xlsx_list_tables } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./list-tables.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_list_tables(Buffer.from(c.input, 'base64'), c.part)), c.want, `XLSX ListObjects case ${i}`);
console.log(`${cases.length} XLSX sheet table references match upstream.`);
