import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource, decodeObject, walk } from '@bdfkit/core';
import { xlsx_render_basic, xlsx_render_warnings } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
function normalize(object) {
  let fill = 0;
  const operations = [], notes = [];
  const sink = new Proxy({}, {get(_target, prop) {return (...input) => {
    const args = Array.from(input, x => ArrayBuffer.isView(x) ? Array.from(x) : x);
    if (prop === 'fillColor') { fill = args[0]; if (fill === 0xe02020ff) return; }
    if (prop === 'fillPath' && fill === 0xe02020ff) {
      const path = object.paths[args[0]].inline;
      assert.ok(path, 'note path must be inline');
      notes.push(JSON.stringify([Array.from(path.verbs), Array.from(path.args), args[1]]));
      return;
    }
    if (['fillPath', 'strokePath', 'clipPath', 'fillPathAt'].includes(prop)) {
      const path = object.paths[args[0]].inline;
      if (path) args[0] = [Array.from(path.verbs), Array.from(path.args)];
    }
    operations.push([prop, args]);
  };}});
  walk(object, sink);
  return {bbox: object.bbox, strings: object.strings, fonts: object.fonts, paints: object.paints, images: object.images, objects: object.objects, operations, notes: notes.sort()};
}
let checked = 0;
for (const [file, count] of [['sheet-multiple-notes.json', 128], ['sheet-multiple-notes-filter.json', 128], ['sheet-multiple-notes-legacy.json', 8]]) {
const cases = JSON.parse(await readFile(new URL(`./${file}`, import.meta.url)));
assert.equal(cases.length, count, `${file} fixture count`);
for (const [j, c] of cases.entries()) {
  const input = Buffer.from(c.input, 'base64');
  const expected = await BdfDocument.open(new BufferSource(Buffer.from(c.bdf, 'base64')));
  const actual = await BdfDocument.open(new BufferSource(xlsx_render_basic(input, c.mode, c.no_index)));
  assert.deepEqual(JSON.parse(xlsx_render_warnings(input, c.mode, c.no_index)), c.warnings ?? [], `warnings ${j}`);
  assert.deepEqual(actual.manifest.meta, expected.manifest.meta, `metadata ${j}`);
  assert.deepEqual(actual.manifest.tables ?? [], expected.manifest.tables ?? [], `tables ${j}`);
  assert.equal(actual.manifest.parts.length, expected.manifest.parts.length, `part count ${j}`);
  assert.equal(actual.manifest.views.length, expected.manifest.views.length);
  for (let i=0;i<actual.manifest.views.length;i++) {
    const a=actual.manifest.views[i], e=expected.manifest.views[i];
    const {tiles: at, ...av}=a, {tiles: et, ...ev}=e;
    assert.deepEqual(av, ev, `view ${j}:${i}`);
    assert.deepEqual(Object.keys(at).sort(), Object.keys(et).sort(), `tiles ${j}:${i}`);
    for (const key of Object.keys(at)) {
      assert.deepEqual(normalize(decodeObject(await actual.part(at[key]))), normalize(decodeObject(await expected.part(et[key]))), `object ${j}:${i}:${key}`);
    }
  }
}
checked += cases.length;
}
console.log(`${checked} multi-note cases match upstream with unordered note paths`);
