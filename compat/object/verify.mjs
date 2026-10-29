import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { roundtrip_object, roundtrip_paths, build_object, build_complete_object, build_auto_object } from '../../_build/js/debug/build/compat/object/object.js';

const fixture = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
for (const [name, roundtrip] of [['object', roundtrip_object], ['paths', roundtrip_paths]]) {
  const input = Buffer.from(fixture[name], 'base64');
  assert.deepEqual(Buffer.from(roundtrip(input)), input, name);
}
assert.deepEqual(Buffer.from(build_object()), Buffer.from(fixture.built, 'base64'), 'built object');
assert.deepEqual(Buffer.from(build_complete_object()), Buffer.from(fixture.object, 'base64'), 'complete built object');
assert.deepEqual(Buffer.from(build_auto_object()), Buffer.from(fixture.auto, 'base64'), 'automatic bounds');
console.log('Object and path resources round-trip byte-for-byte with upstream.');
