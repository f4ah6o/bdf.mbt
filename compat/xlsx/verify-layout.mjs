import assert from 'node:assert/strict';
import { xlsx_layout } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./layout.json');
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(xlsx_layout(Buffer.from(c.input, 'base64'), c.part, c.mdw, c.line)), [c.want[0], c.want[1], c.want[2].map(([count, size]) => [count, Math.fround(size)]), c.want[3].map(([count, size]) => [count, Math.fround(size)])], `worksheet layout case ${i}`);
console.log(`${cases.length} XLSX initial view extents and row and column runs match upstream.`);
