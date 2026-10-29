import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { divide_values } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const samples = JSON.parse(await readFile(new URL('./values.json', import.meta.url)));
for (const [i, c] of samples.entries()) {
  assert.deepEqual(JSON.parse(divide_values(c.start,c.end,c.beat,c.length,c.compound,c.rest)),c.want,`values ${i}`);
}
console.log(`${samples.length} note and rest value divisions match upstream.`);
