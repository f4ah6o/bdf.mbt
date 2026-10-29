import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { timeline } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const samples = JSON.parse(await readFile(new URL('./timeline.json', import.meta.url)));
for (const [i, c] of samples.entries()) {
  const actual = JSON.parse(timeline(c.end,c.times,c.keys,c.tempos,c.histogram,0,c.timeOverride,c.keyOverride));
  assert.deepEqual(actual,c.want,`timeline ${i}`);
}
console.log(`${samples.length} measure, key and tempo timelines match upstream.`);
