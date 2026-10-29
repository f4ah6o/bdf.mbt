import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { convert_specimen, converted_specimen_bytes, converted_specimen_report } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const {files, cases} = JSON.parse(gunzipSync(await readFile(new URL('./convert.json.gz', import.meta.url))));
const decoded = Object.fromEntries(Object.entries(files).map(([name, data]) => [name, gunzipSync(Buffer.from(data, 'base64'))]));
let partCount = 0, pageCount = 0;
for (const [i, c] of cases.entries()) {
  const where = `${c.name}, case ${i}`;
  const output = convert_specimen(decoded[c.name], c.uiFont ? decoded['stix.ttf'] : new Uint8Array(), c.selection, c.title, c.text, c.system, c.noIndex, c.noSubset, c.ignore);
  const report = JSON.parse(converted_specimen_report(output));
  assert.deepEqual(report, {summary: c.summary, warnings: c.warnings}, `${where}: report`);
  const doc = await BdfDocument.open(new BufferSource(converted_specimen_bytes(output)));
  const meta = {...doc.manifest.meta}; delete meta.generator;
  assert.deepEqual(meta, c.meta, `${where}: metadata`);
  assert.deepEqual(doc.manifest.views, c.views, `${where}: views`);
  const actualParts = new Map(doc.manifest.parts.map(part => [part.h, part]));
  assert.equal(actualParts.size, c.parts.length, `${where}: part count`);
  for (const expected of c.parts) {
    const part = actualParts.get(expected.hash);
    assert.ok(part, `${where}: missing ${expected.type} part ${expected.hash}`);
    assert.equal(part.t, expected.type, `${where}: part type`);
    assert.deepEqual(Buffer.from(await doc.part(expected.hash)), Buffer.from(expected.data, 'base64'), `${where}: ${expected.type} bytes`);
    partCount++;
  }
  pageCount += c.views.reduce((sum, view) => sum + view.pages.length, 0);
}
console.log(`${cases.length} complete font conversions: ${pageCount} pages and ${partCount} parts match upstream.`);
