import assert from 'node:assert/strict';
import { xlsx_numeric } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./numeric.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_numeric(c.code, c.value)), [c.pieces, c.general], `numeric case ${i}: ${c.value}, ${c.code}`);
console.log(`${cases.length} XLSX numeric displays match upstream.`);
