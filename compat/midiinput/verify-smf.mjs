import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { generated_smf } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./smf.json.gz', import.meta.url))));
for (const [i, c] of cases.entries()) assert.deepEqual(Buffer.from(JSON.parse(generated_smf(Buffer.from(c.input, 'base64')))), Buffer.from(c.want, 'base64'), `case ${i}`);
console.log(`${cases.length} regenerated MIDI performances match upstream byte for byte.`);
