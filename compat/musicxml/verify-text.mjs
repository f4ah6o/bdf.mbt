import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { musicxml_text } from '../../_build/js/debug/build/compat/musicxml/musicxml.js';
const cases = JSON.parse(await readFile(new URL('./text.json', import.meta.url)));
for (const [i, c] of cases.entries()) {
  const want = [c.want[0], [...Buffer.from(c.want[1] ?? '', 'base64')], c.want[2]];
  assert.deepEqual(JSON.parse(musicxml_text(Buffer.from(c.input ?? '', 'base64'))), want, `case ${i}`);
}
console.log(`${cases.length} MusicXML XML text repair cases match upstream.`);
