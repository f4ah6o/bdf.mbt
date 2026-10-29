import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource, parseHeader } from '@bdfkit/core';
import { encrypt_bdf_password, encrypt_bdf_ecdh } from '../../_build/js/debug/build/browser/browser.js';

const input = await readFile(new URL('../visual/fixture.bdf', import.meta.url));
const original = await BdfDocument.open(new BufferSource(input));
const jwk = JSON.parse(await readFile(new URL('../visual/encrypted-fixture/test-private.jwk', import.meta.url)));
const { d, ...publicJwk } = jwk;
const publicKey = await crypto.subtle.importKey('jwk', publicJwk, { name: 'ECDH', namedCurve: 'P-256' }, true, []);
const privateKey = await crypto.subtle.importKey('jwk', jwk, { name: 'ECDH', namedCurve: 'P-256' }, false, ['deriveKey']);
const rawPublic = new Uint8Array(await crypto.subtle.exportKey('raw', publicKey));
const password = await encrypt_bdf_password(input, 'ＡＢＣ', 1000);
const passwordAgain = await encrypt_bdf_password(input, 'ＡＢＣ', 1000);
const ecdh = await encrypt_bdf_ecdh(input, rawPublic);
assert.notDeepEqual(password, passwordAgain, 'fresh keys and nonces');

for (const [name, data, options] of [
  ['password', password, { password: 'ABC' }],
  ['ecdh', ecdh, { keyPair: { publicKey, privateKey } }],
]) {
  const header = parseHeader(data);
  assert.equal(header.flags, 1, name + ' encrypted flag');
  const source = new BufferSource(data);
  const outer = await source.manifest();
  assert.equal(outer.encryption.cipher, 'A256GCM');
  assert.equal(outer.encryption.keys[0].type, name === 'password' ? 'password' : 'ecdh');
  assert.equal(outer.parts.length, original.manifest.parts.length + 1);
  const nonces = new Set();
  for (const entry of outer.parts) {
    const stored = await source.stored(entry);
    assert.equal(entry.t, 'sealed');
    assert.equal(entry.h, createHash('sha256').update(stored).digest('hex').slice(0, 32));
    const nonce = Buffer.from(stored.subarray(0, 12)).toString('hex');
    assert.ok(!nonces.has(nonce), 'duplicate GCM nonce');
    nonces.add(nonce);
  }
  const opened = await BdfDocument.open(source, options);
  assert.deepEqual(opened.manifest.views, original.manifest.views, name + ' views');
  assert.deepEqual(opened.manifest.meta, original.manifest.meta, name + ' metadata');
  for (const entry of original.manifest.parts) {
    assert.deepEqual(Buffer.from(await opened.part(entry.h)), Buffer.from(await original.part(entry.h)), name + ' part');
  }
  const corrupt = Uint8Array.from(data);
  const first = outer.parts[0];
  corrupt[header.manifestOff + header.manifestLen + (first.off ?? 0) + first.len - 1] ^= 1;
  await assert.rejects(BdfDocument.open(new BufferSource(corrupt), options), undefined, name + ' altered ciphertext');
}
await assert.rejects(BdfDocument.open(new BufferSource(password), { password: 'wrong' }));
const wrongPair = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveKey']);
await assert.rejects(BdfDocument.open(new BufferSource(ecdh), { keyPair: wrongPair }));
await assert.rejects(encrypt_bdf_password(input, '', 1000));
await assert.rejects(encrypt_bdf_password(input, 'valid', 10000001));
await assert.rejects(encrypt_bdf_password(input, 'valid', -1));
await assert.rejects(encrypt_bdf_password(password, 'valid', 1000));
await assert.rejects(encrypt_bdf_ecdh(input, new Uint8Array(65)));
const defaultIterations = await encrypt_bdf_password(input, 'valid', 0);
assert.equal((await new BufferSource(defaultIterations).manifest()).encryption.keys[0].iter, 600000);
console.log('Password and P-256 BDF encryption interoperates with upstream and rejects invalid input.');
