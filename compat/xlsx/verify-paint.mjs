import assert from 'node:assert/strict';
import { xlsx_paint } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./paint.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_paint(Buffer.from(c.input, 'base64'))), c.want, `XLSX paint styles case ${i}`);
console.log(`${cases.length} XLSX fill and border sets match upstream.`);
