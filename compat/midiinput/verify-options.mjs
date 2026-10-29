import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { midi_document_options } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./options.json.gz', import.meta.url))));
for (const [i, c] of cases.entries()) {
  const [bytes, warnings, counts] = JSON.parse(midi_document_options(Buffer.from(c.input, 'base64'), c.time, c.key, c.pages, c.tab));
  const document = await BdfDocument.open(new BufferSource(Uint8Array.from(bytes)));
  assert.deepEqual(document.manifest.meta, { ...c.want.meta, generator: c.want.meta.generator || "bdf-go/0.1" }, `metadata ${i}`);
  assert.deepEqual(document.manifest.views, c.want.views, `views ${i}`);
  assert.deepEqual(document.manifest.parts.map(p => [p.t, p.h]), c.want.parts, `parts ${i}`);
  assert.deepEqual(warnings, c.want.warnings, `warnings ${i}`);
  assert.deepEqual(counts, c.want.counts, `counts ${i}`);
}
console.log(`${cases.length} MIDI documents with notation and page options match upstream metadata, views, parts, warnings, and counts.`);
