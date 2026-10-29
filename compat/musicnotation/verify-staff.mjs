import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { staff, drum } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const samples = JSON.parse(await readFile(new URL('./staff.json', import.meta.url)));
for (const [i, c] of samples.staff.entries()) assert.deepEqual(JSON.parse(staff(c.keys,c.channel,c.program)),c.want,`staff ${i}`);
for (const [i, want] of samples.drums.entries()) assert.deepEqual(JSON.parse(drum(i)),want,`drum ${i}`);
console.log(`${samples.staff.length} staff selections and ${samples.drums.length} drum mappings match upstream.`);
