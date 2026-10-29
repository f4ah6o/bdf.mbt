import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { musicxml_mxl } from '../../_build/js/debug/build/compat/musicxml/musicxml.js';
const cases = JSON.parse(await readFile(new URL('./mxl.json', import.meta.url)));
for (const [i, c] of cases.entries()) {
  const want = [c.want[0], c.want[1] === null ? null : [...Buffer.from(c.want[1], 'base64')], c.want[2]];
  assert.deepEqual(JSON.parse(musicxml_mxl(Buffer.from(c.input, 'base64'))), want, `MXL case ${i}`);
}
console.log(`${cases.length} MusicXML and MXL inputs match upstream detection and score selection.`);
