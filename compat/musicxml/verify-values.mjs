import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { musicxml_values } from '../../_build/js/debug/build/compat/musicxml/musicxml.js';
const cases = JSON.parse(await readFile(new URL('./values.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(musicxml_values(c.input)), c.want, `MusicXML value case ${i}: ${JSON.stringify(c.input)}`);
console.log(`${cases.length} MusicXML numeric and ending values match upstream.`);
