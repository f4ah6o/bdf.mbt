import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { score_tab_cues } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./tab_cues.json.gz', import.meta.url))));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(score_tab_cues(Buffer.from(c.input, 'base64'), c.width, c.height, c.sp, c.title, c.division, c.selected)), c.want, `case ${i}`);
console.log(`${cases.length} MIDI scores' TAB playback cues match upstream.`);
