import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { prepare_outlines, specimen_path } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const load = async file => JSON.parse(gunzipSync(await readFile(new URL(file, import.meta.url))));
const sources = [...await load('../font/outlines.json.gz'), ...await load('../font/cff-outlines.json.gz')];
const expected = await load('./paths.json.gz');
assert.equal(sources.length, expected.length);
let count = 0;
for (let i = 0; i < sources.length; i++) {
  const {name, input, index = 0, cases} = sources[i];
  assert.equal(cases.length, expected[i].length);
  if (!cases.length) continue;
  const outlines = prepare_outlines(gunzipSync(Buffer.from(input, 'base64')), index);
  for (let j = 0; j < cases.length; j++) {
    const actual = Buffer.from(specimen_path(outlines, cases[j].glyph));
    const want = expected[i][j] === null ? Buffer.alloc(0) : Buffer.from(expected[i][j], 'base64');
    assert.ok(actual.equals(want), `${name}, glyph ${cases[j].glyph}: path bytes differ`);
    count++;
  }
}
console.log(`${count} specimen BDF paths match upstream.`);
