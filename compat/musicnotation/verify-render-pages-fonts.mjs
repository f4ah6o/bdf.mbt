import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { render_pages_fonts } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./render_pages_fonts.json.gz', import.meta.url))));
const fonts = new Map();
for (const file of new Set(cases.map(c => c.file))) fonts.set(file, await readFile(new URL(`../font/fixtures/${file}`, import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(render_pages_fonts(Buffer.from(c.input, 'base64'), c.file, fonts.get(c.file), c.width, c.height, c.sp, c.title)), c.want, `case ${i}`);
console.log(`${cases.length} MIDI scores' embedded-font BDF pages match upstream.`);
