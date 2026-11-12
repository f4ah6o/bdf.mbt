import assert from 'node:assert/strict';
import { xlsx_format_sections } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./sections.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_format_sections(c.code)), c.want, `format sections case ${i}`);
console.log(`${cases.length} XLSX number format section splits match upstream.`);
