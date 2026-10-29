import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { musicxml_header } from '../../_build/js/debug/build/compat/musicxml/musicxml.js';
const cases = JSON.parse(await readFile(new URL('./header.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(musicxml_header(Buffer.from(c.input, 'base64'))), c.want, `MusicXML header case ${i}`);
console.log(`${cases.length} MusicXML score headers match upstream.`);
