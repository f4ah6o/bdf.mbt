// Keep byte-level XLSX state emission intact when word-processing builders
// opt into state deduplication. These fixtures contain repeated FONT ops.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { xlsx_render_result } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';

const open = (bdf) => BdfDocument.open(new BufferSource(Buffer.from(bdf, 'base64')));
let checked = 0;
for (const [file, index] of [['003.json', 750], ['003.json', 751], ['003.json', 861], ['004.json', 155]]) {
  const cases = JSON.parse(await readFile(new URL(`./render/${file}`, import.meta.url)));
  const c = cases[index];
  const label = `${file}:${index}`;
  const result = JSON.parse(xlsx_render_result(Buffer.from(c.input, 'base64'), c.mode, c.no_index));
  assert.ok(result.bdf, `${label}: ${result.error}`);
  const actual = await open(result.bdf);
  const expected = await open(c.bdf);
  assert.deepEqual(result.warnings ?? [], c.warnings ?? [], `${label}: warnings`);
  assert.deepEqual(actual.manifest.meta, expected.manifest.meta, `${label}: metadata`);
  assert.deepEqual(actual.manifest.views, expected.manifest.views, `${label}: views`);
  assert.deepEqual(actual.manifest.tables ?? [], expected.manifest.tables ?? [], `${label}: tables`);
  assert.equal(actual.manifest.parts.length, expected.manifest.parts.length, `${label}: part count`);
  for (const [j, part] of actual.manifest.parts.entries()) {
    assert.deepEqual(
      Buffer.from(await actual.part(part.h)),
      Buffer.from(await expected.part(expected.manifest.parts[j].h)),
      `${label}: part ${j}`,
    );
  }
  checked++;
}
console.log(`emission-test: ${checked} cases match all upstream parts exactly`);
