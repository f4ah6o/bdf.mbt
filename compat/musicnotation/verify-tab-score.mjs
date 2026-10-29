import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { score_guitar } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./tab_score.json.gz', import.meta.url))));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(score_guitar(Buffer.from(c.input, 'base64'))), c.want, `case ${i}`);
console.log(`${cases.length} MIDI scores' guitar fingerings match upstream.`);
