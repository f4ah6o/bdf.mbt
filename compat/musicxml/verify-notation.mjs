import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { musicxml_notation } from '../../_build/js/debug/build/compat/musicxml/musicxml.js';
const cases = JSON.parse(await readFile(new URL('./notation.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(musicxml_notation(Buffer.from(c.input, 'base64'), c.ticks, c.acc, c.alter)), c.want, `MusicXML notation case ${i}`);
console.log(`${cases.length} MusicXML time, clef, note value and accidental cases match upstream.`);
