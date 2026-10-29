import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_layout } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./layout.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_layout(Buffer.from(c.input, 'base64'), c.part, c.mdw, c.line)), [c.want[0], c.want[1], c.want[2].map(([count, size]) => [count, Math.fround(size)]), c.want[3].map(([count, size]) => [count, Math.fround(size)])], `worksheet layout case ${i}`);
console.log(`${cases.length} XLSX initial view extents and row and column runs match upstream.`);
