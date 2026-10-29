import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { midi_document } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./document.json.gz', import.meta.url))));
for (const [i, c] of cases.entries()) {
  const [bytes, warnings, counts, summary, seconds] = JSON.parse(midi_document(Buffer.from(c.input, 'base64'), c.width, c.height, c.sp, c.title, c.noText, c.noPlay, c.select));
  const document = await BdfDocument.open(new BufferSource(Uint8Array.from(bytes)));
  assert.deepEqual(document.manifest.meta, { ...c.want.meta, generator: c.want.meta.generator || "bdf-go/0.1" }, `metadata ${i}`);
  assert.deepEqual(document.manifest.views, c.want.views, `views ${i}`);
  assert.deepEqual(document.manifest.parts.map(p => [p.t, p.h]), c.want.parts, `parts ${i}`);
  assert.deepEqual(warnings, c.want.warnings, `warnings ${i}`);
  assert.deepEqual(counts, c.want.counts, `counts ${i}`);
  assert.equal(summary, c.want.summary, `summary ${i}`);
  assert.equal(seconds, c.want.seconds, `seconds ${i}`);
}
console.log(`${cases.length} MIDI score-view documents match upstream metadata, views, parts, warnings, and counts.`);
