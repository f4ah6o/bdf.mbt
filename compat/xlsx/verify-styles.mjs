import assert from 'node:assert/strict';
import { xlsx_styles } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./styles.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_styles(Buffer.from(c.input, 'base64'))), c.want, `XLSX styles case ${i}`);
console.log(`${cases.length} XLSX font and cell format sets match upstream.`);
