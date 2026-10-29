import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { musicxml_detect_text } from '../../_build/js/debug/build/compat/musicxml/musicxml.js';
const cases = JSON.parse(await readFile(new URL('./detect.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(musicxml_detect_text(Buffer.from(c.input ?? '', 'base64'))), c.want, `case ${i}`);
console.log(`${cases.length} MusicXML text detection cases match upstream.`);
