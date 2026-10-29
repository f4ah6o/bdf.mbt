import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { musicxml_unpitched_note } from '../../_build/js/debug/build/compat/musicxml/musicxml.js';
const cases = JSON.parse(await readFile(new URL('./unpitched.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(musicxml_unpitched_note(Buffer.from(c.input, 'base64'), JSON.stringify(c.instruments))), c.want, `MusicXML unpitched note case ${i}`);
console.log(`${cases.length} MusicXML percussion notes match upstream.`);
