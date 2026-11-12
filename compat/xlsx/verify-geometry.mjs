import assert from 'node:assert/strict';
import { xlsx_geometry } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./geometry.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_geometry(Buffer.from(c.input, 'base64'), c.part)), c.want, `XLSX geometry case ${i}`);
console.log(`${cases.length} XLSX sheet geometry cases match upstream.`);
