import assert from 'node:assert/strict';
import { xlsx_range } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./range.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_range(c.input)), c.want, `XLSX range case ${i}: ${JSON.stringify(c.input)}`);
console.log(`${cases.length} XLSX ranges match upstream.`);
