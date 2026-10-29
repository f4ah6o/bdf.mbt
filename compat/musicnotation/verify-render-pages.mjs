import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { render_pages } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./render_pages.json.gz', import.meta.url))));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(render_pages(Buffer.from(c.input, 'base64'), c.width, c.height, c.sp, c.title)), c.want, `case ${i}`);
console.log(`${cases.length} MIDI scores' BDF page and glyph hashes match upstream.`);
