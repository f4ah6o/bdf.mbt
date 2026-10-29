import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_color } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./color.json', import.meta.url)));
for (const [i, c] of cases.entries()) {
  const actual = JSON.parse(xlsx_color(c.kind, c.rgb, c.index, c.tint));
  for (let j = 0; j < 3; j++) assert.ok(Math.abs(actual[j] - c.want[j]) < 1e-14, `color case ${i}, component ${j}`);
  assert.equal(actual[3], c.want[3], `color case ${i}, RGBA`);
}
console.log(`${cases.length} XLSX resolved colors match upstream.`);
