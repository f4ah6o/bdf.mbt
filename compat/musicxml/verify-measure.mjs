import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { musicxml_measure } from '../../_build/js/debug/build/compat/musicxml/musicxml.js';
const cases = JSON.parse(await readFile(new URL('./measure.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(musicxml_measure(Buffer.from(c.input, 'base64'), c.div, c.beats, c.beatType, c.transpose)), c.want, `MusicXML measure case ${i}`);
console.log(`${cases.length} MusicXML measure rhythm cases match upstream.`);
