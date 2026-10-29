import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { staff_events } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const samples = JSON.parse(await readFile(new URL('./events.json', import.meta.url)));
for (const [i, c] of samples.entries()) {
  assert.deepEqual(JSON.parse(staff_events(c.measures,c.beats,c.notes,c.lyricTicks,c.lyricTexts,c.staff,c.percussion)),c.want,`events ${i}`);
}
console.log(`${samples.length} staff event sets match upstream.`);
