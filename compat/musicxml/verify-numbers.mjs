import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { musicxml_numbers } from '../../_build/js/debug/build/compat/musicxml/musicxml.js';
const cases = JSON.parse(await readFile(new URL('./numbers.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(musicxml_numbers(c.max, JSON.stringify(c.input))), c.want, `MusicXML numbering case ${i}`);
console.log(`${cases.length} MusicXML voice and verse numbering sequences match upstream.`);
