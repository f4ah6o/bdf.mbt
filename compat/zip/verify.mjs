import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { zip_read } from '../../_build/js/debug/build/compat/zip/zip.js';
const cases = JSON.parse(await readFile(new URL('./cases.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(zip_read(Buffer.from(c.input ?? '', 'base64'))), c.want, `ZIP case ${i}`);
console.log(`${cases.length} ZIP archives match the upstream Go reader.`);
