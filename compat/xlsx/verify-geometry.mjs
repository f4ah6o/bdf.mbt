import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_geometry } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./geometry.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_geometry(Buffer.from(c.input, 'base64'), c.part)), c.want, `XLSX geometry case ${i}`);
console.log(`${cases.length} XLSX sheet geometry cases match upstream.`);
