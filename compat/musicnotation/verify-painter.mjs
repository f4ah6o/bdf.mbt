import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { paint_graphics } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./painter.json.gz', import.meta.url))));
for (const [i, c] of cases.entries()) {
  const [paths, object] = JSON.parse(paint_graphics(c.ops, c.sp, c.ox, c.oy));
  assert.deepEqual(Buffer.from(paths), Buffer.from(c.paths, 'base64'), `paths ${i}`);
  assert.deepEqual(Buffer.from(object), Buffer.from(c.object, 'base64'), `object ${i}`);
}
console.log(`${cases.length} BDF music graphics objects and glyph collections match upstream byte for byte.`);
