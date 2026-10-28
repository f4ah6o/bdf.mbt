import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { BdfDocument, BufferSource, parseHeader } from '@bdfkit/core';
import { fixture, fixture_for_part } from '../../_build/js/debug/build/compat/writer/writer.js';

const bytes = fixture();
const header = parseHeader(bytes);
assert.equal(header.manifestEnc, 'deflate-raw');
const doc = await BdfDocument.open(new BufferSource(bytes));
assert.equal(doc.manifest.meta.source, 'test');
assert.equal(doc.manifest.views.length, 30);
assert.equal(doc.manifest.views[29].id, 'view29');
assert.equal(doc.manifest.parts.length, 2);
assert.equal(doc.manifest.tables[0].part, doc.manifest.parts[0].h);
for (const [index, expected] of [Buffer.from('abc'), Buffer.alloc(1000, 97)].entries()) {
  const part = doc.manifest.parts[index];
  assert.equal(part.h, createHash('sha256').update(expected).digest('hex').slice(0, 32));
  assert.equal(part.enc, index === 0 ? 'identity' : 'deflate-raw');
  assert.deepEqual(Buffer.from(await doc.part(part.h)), expected);
}
for (const length of [0, 1, 55, 56, 63, 64, 65, 127, 128, 129, 511, 512, 513, 1024, 4096]) {
  const data = Buffer.from(Array.from({ length }, (_, i) => (i * 71 + length) & 255));
  const document = await BdfDocument.open(new BufferSource(fixture_for_part(data)));
  const part = document.manifest.parts[0];
  assert.equal(part.h, createHash('sha256').update(data).digest('hex').slice(0, 32));
  assert.deepEqual(Buffer.from(await document.part(part.h)), data);
}
console.log('MoonBit BDF writer: upstream reader opens compressed manifest and parts.');
