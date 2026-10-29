import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { decode_only } from '../../_build/js/debug/build/compat/csv/csv.js';

// Hash every two-byte sequence in each encoding and in important multibyte
// decoder states. Digests come from Go's upstream decoders.
const expected = JSON.parse(await readFile(new URL('./pairs.json', import.meta.url)));
const prefixes = { 'euc-jp-triples': [0x8f], 'iso-jis0208': [0x1b, 0x24, 0x42], 'iso-jis0212': [0x1b, 0x24, 0x28, 0x44], 'iso-katakana': [0x1b, 0x28, 0x49], 'iso-roman': [0x1b, 0x28, 0x4a] };
for (const [name, digest] of Object.entries(expected)) {
  if (name.startsWith('single:')) {
    const hash = createHash('sha256');
    for (let i = 0; i < 256; i++) {
      const decoded = Buffer.from(decode_only(Uint8Array.of(i), name.slice(7)));
      const length = Buffer.allocUnsafe(4); length.writeUInt32BE(decoded.length);
      hash.update(length); hash.update(decoded);
    }
    assert.equal(hash.digest('hex'), digest, name);
    continue;
  }
  if (name === 'gb18030-ranges') {
    const hash = createHash('sha256');
    for (let i = 0; i < 39420; i++) {
      const bytes = Uint8Array.of(Math.floor(i / 12600) + 0x81, Math.floor(i / 1260) % 10 + 0x30, Math.floor(i / 10) % 126 + 0x81, i % 10 + 0x30);
      const decoded = Buffer.from(decode_only(bytes, 'gb18030'));
      const length = Buffer.allocUnsafe(4); length.writeUInt32BE(decoded.length);
      hash.update(length); hash.update(decoded);
    }
    assert.equal(hash.digest('hex'), digest, name);
    continue;
  }
  const prefix = prefixes[name] ?? [];
  const label = name === 'euc-jp-triples' ? 'euc-jp' : name.startsWith('iso-') ? 'iso-2022-jp' : name;
  const hash = createHash('sha256');
  for (let i = 0; i < 65536; i++) {
    if (!prefix.length && (i === 0xfffe || i === 0xfeff)) continue;
    const bytes = Uint8Array.of(...prefix, i >> 8, i & 255);
    const decoded = Buffer.from(decode_only(bytes, label));
    const length = Buffer.allocUnsafe(4); length.writeUInt32BE(decoded.length);
    hash.update(length); hash.update(decoded);
  }
  assert.equal(hash.digest('hex'), digest, name);
}
console.log('CSV Japanese, Chinese, Korean, Windows-1252 and UTF-16 decoders match upstream for all tested byte sequences.');
