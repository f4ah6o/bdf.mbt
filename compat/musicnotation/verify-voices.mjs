import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { voices } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const samples = JSON.parse(await readFile(new URL('./voices.json', import.meta.url)));
for (const [i, c] of samples.entries()) {
  assert.deepEqual(JSON.parse(voices(c.measures,c.beats,c.notes,c.percussion)),c.want,`voices ${i}`);
}
console.log(`${samples.length} chord and voice assignments match upstream.`);
