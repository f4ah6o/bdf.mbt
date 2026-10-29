import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { musicxml_pitch_note } from '../../_build/js/debug/build/compat/musicxml/musicxml.js';
const cases = JSON.parse(await readFile(new URL('./note.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(musicxml_pitch_note(Buffer.from(c.input, 'base64'), c.transpose)), c.want, `MusicXML pitch note case ${i}`);
console.log(`${cases.length} MusicXML pitched note cases match upstream.`);
