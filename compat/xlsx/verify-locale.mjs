import assert from 'node:assert/strict';
import { xlsx_locale } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./locale.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_locale(Buffer.from(c.input, 'base64'))), c.want, `XLSX locale case ${i}`);
console.log(`${cases.length} OOXML metadata and XLSX locales match upstream.`);
