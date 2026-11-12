import assert from 'node:assert/strict';
import { xlsx_reference } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./reference.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_reference(c.input, c.column)), c.want, `XLSX reference case ${i}`);
console.log(`${cases.length} XLSX references and strings match upstream.`);
