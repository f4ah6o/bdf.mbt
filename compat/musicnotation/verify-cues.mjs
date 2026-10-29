import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { score_cues } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./cues.json.gz', import.meta.url))));
for (const [i, c] of cases.entries()) assert.deepEqual(Buffer.from(JSON.parse(score_cues(Buffer.from(c.input, 'base64'), c.width, c.height, c.sp, c.title, c.division))), Buffer.from(c.want, 'base64'), `case ${i}`);
console.log(`${cases.length} MIDI playback cue indexes match upstream byte for byte.`);
