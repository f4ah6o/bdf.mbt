import assert from 'node:assert/strict';
import { xlsx_cells } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./cells.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_cells(Buffer.from(c.input, 'base64'), c.part)), c.want, `XLSX cells case ${i}`);
console.log(`${cases.length} XLSX worksheet cell sets match upstream.`);
