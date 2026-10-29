import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { quantize } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const samples = JSON.parse(await readFile(new URL('./quantize.json', import.meta.url)));
for (const [i, c] of samples.entries()) {
  assert.deepEqual(JSON.parse(quantize(c.measures,c.notes)),c.want,`quantize ${i}`);
}
console.log(`${samples.length} music beat grids and quantized note sets match upstream.`);
