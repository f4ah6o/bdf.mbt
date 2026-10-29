import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { guitar_fingering } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./tab_fingering.json.gz', import.meta.url))));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(guitar_fingering(c.raw, c.preset)), c.want, `case ${i}`);
console.log(`${cases.length} guitar fingering sequences match upstream.`);
