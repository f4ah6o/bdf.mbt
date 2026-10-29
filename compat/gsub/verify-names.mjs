import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { tag_names, type_name } from '../../_build/js/debug/build/compat/gsub/gsub.js';
const {tags, types} = JSON.parse(await readFile(new URL('./names.json', import.meta.url)));
for (const {tag, ...expected} of tags) {
  assert.deepEqual(JSON.parse(tag_names(tag)), expected, `tag ${JSON.stringify(tag)}`);
}
for (const {typ, gpos, name} of types) {
  assert.equal(type_name(typ, gpos), name, `lookup type ${typ}, gpos=${gpos}`);
}
console.log(`${tags.length} OpenType tags and ${types.length} lookup types match upstream.`);
