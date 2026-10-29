import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { mml_document } from '../../_build/js/debug/build/compat/mml/mml.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./document.json.gz', import.meta.url))));
for (const [i, c] of cases.entries()) {
  const [bytes, warnings, counts] = JSON.parse(mml_document(Buffer.from(c.input, 'base64'), c.dialect, c.octave, c.program, c.width, c.height, c.sp, c.title, c.noText, c.noPlay, c.select, c.tab));
  const document = await BdfDocument.open(new BufferSource(Uint8Array.from(bytes)));
  assert.deepEqual(document.manifest.meta, { ...c.want.meta, generator: c.want.meta.generator || 'bdf-go/0.1' }, `metadata ${i}`);
  assert.deepEqual(document.manifest.views, c.want.views, `views ${i}`);
  assert.deepEqual(document.manifest.parts.map(p => [p.t, p.h]), c.want.parts, `parts ${i}`);
  assert.deepEqual(warnings, c.want.warnings, `warnings ${i}`);
  assert.deepEqual(counts, c.want.counts, `counts ${i}`);
}
console.log(`${cases.length} MML score and TAB documents match upstream metadata, views, parts, warnings, and counts.`);
