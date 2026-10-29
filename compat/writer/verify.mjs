import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { BdfDocument, BufferSource, SplitSource, parseHeader } from '@bdfkit/core';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { fixture, fixture_for_part, split_manifest, split_part, writer_split_manifest, writer_split_part, join_split } from '../../_build/js/debug/build/compat/writer/writer.js';

const bytes = fixture();
const header = parseHeader(bytes);
assert.equal(header.manifestEnc, 'deflate-raw');
const doc = await BdfDocument.open(new BufferSource(bytes));
assert.equal(doc.manifest.meta.source, 'test');
assert.equal(doc.manifest.meta.generator, 'bdf-go/0.1');
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

const files = new Map();
const server = createServer((request, response) => {
  const data = files.get(request.url);
  if (!data) { response.writeHead(404).end(); return; }
  response.end(data);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
try {
  const jwk = JSON.parse(await readFile(new URL('../visual/encrypted-fixture/test-private.jwk', import.meta.url)));
  const privateKey = await crypto.subtle.importKey('jwk', jwk, { name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveKey']);
  const { d, ...publicJwk } = jwk;
  const publicKey = await crypto.subtle.importKey('jwk', publicJwk, { name: 'ECDH', namedCurve: 'P-256' }, true, []);
  const cases = [
    { name: 'writer', data: bytes, direct: true },
    { name: 'upstream', data: await readFile(new URL('../visual/fixture.bdf', import.meta.url)) },
    { name: 'password', data: await readFile(new URL('../visual/encrypted-fixture/password.bdf', import.meta.url)), options: { password: 'pass' } },
    { name: 'ecdh', data: await readFile(new URL('../visual/encrypted-fixture/ecdh.bdf', import.meta.url)), options: { keyPair: { privateKey, publicKey } } },
  ];
  for (const sample of cases) {
    const manifestBytes = sample.direct ? writer_split_manifest() : split_manifest(sample.data);
    const manifest = JSON.parse(Buffer.from(manifestBytes).toString('utf8'));
    const parts = manifest.parts.map((entry, index) => sample.direct ? writer_split_part(index) : split_part(sample.data, index));
    assert.ok(manifest.parts.every(entry => entry.off === 0), sample.name + ' split offsets');
    files.set('/' + sample.name + '/manifest.json', manifestBytes);
    for (const [index, entry] of manifest.parts.entries()) files.set('/' + sample.name + '/parts/' + entry.h, parts[index]);
    const original = await BdfDocument.open(new BufferSource(sample.data), sample.options);
    const split = await BdfDocument.open(new SplitSource(`http://127.0.0.1:${server.address().port}/${sample.name}/`), sample.options);
    const joinedBytes = join_split(manifestBytes, parts);
    const joined = await BdfDocument.open(new BufferSource(joinedBytes), sample.options);
    for (const actual of [split, joined]) {
      assert.deepEqual(actual.manifest.views, original.manifest.views, sample.name + ' views');
      assert.deepEqual(actual.manifest.meta, original.manifest.meta, sample.name + ' metadata');
      for (const entry of original.manifest.parts) {
        assert.deepEqual(Buffer.from(await actual.part(entry.h)), Buffer.from(await original.part(entry.h)), sample.name + ' part ' + entry.h);
      }
    }
    const extended = { ...manifest, customExtension: { value: 'preserved' } };
    const withExtension = join_split(Buffer.from(JSON.stringify(extended)), parts);
    const outputManifest = JSON.parse(Buffer.from(split_manifest(withExtension)).toString('utf8'));
    assert.deepEqual(outputManifest.customExtension, extended.customExtension);
    const identity = manifest.parts.findIndex((entry, index) => entry.enc === 'identity' && parts[index].length);
    if (identity >= 0) {
      const corrupt = parts.map(part => Uint8Array.from(part));
      corrupt[identity][0] ^= 1;
      assert.throws(() => join_split(manifestBytes, corrupt), undefined, sample.name + ' corrupt part');
    }
  }
  for (const sample of cases.slice(1)) {
    const directory = sample.name === 'upstream'
      ? new URL('../visual/split-fixture/', import.meta.url)
      : new URL(`../visual/encrypted-fixture/${sample.name}-split/`, import.meta.url);
    const manifestBytes = await readFile(new URL('manifest.json', directory));
    const manifest = JSON.parse(manifestBytes);
    const parts = await Promise.all(manifest.parts.map(entry => readFile(new URL('parts/' + entry.h, directory))));
    const original = await BdfDocument.open(new BufferSource(sample.data), sample.options);
    const joined = await BdfDocument.open(new BufferSource(join_split(manifestBytes, parts)), sample.options);
    assert.deepEqual(joined.manifest.views, original.manifest.views, sample.name + ' upstream split views');
    for (const entry of original.manifest.parts) {
      assert.deepEqual(Buffer.from(await joined.part(entry.h)), Buffer.from(await original.part(entry.h)), sample.name + ' upstream split part');
    }
  }
} finally { await new Promise(resolve => server.close(resolve)); }
console.log('Split and single BDF output opens with upstream readers, including encrypted documents.');
