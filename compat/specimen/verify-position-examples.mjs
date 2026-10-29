import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { new_feature_planner, gpos_feature_examples } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const {files, cases} = JSON.parse(gunzipSync(await readFile(new URL('./position-examples.json.gz', import.meta.url))));
const decoded = Object.fromEntries(Object.entries(files).map(([name, data]) => [name, gunzipSync(Buffer.from(data, 'base64'))]));
function compare(actual, expected, where) {
  if (typeof expected === 'number' && typeof actual === 'number') assert.ok(Math.abs(actual - expected) < 1e-10, `${where}: ${actual} != ${expected}`);
  else if (Array.isArray(expected)) { assert.equal(actual.length, expected.length, where); expected.forEach((value, i) => compare(actual[i], value, `${where}[${i}]`)); }
  else if (expected && typeof expected === 'object') { assert.deepEqual(Object.keys(actual).sort(), Object.keys(expected).sort(), where); for (const key of Object.keys(expected)) compare(actual[key], expected[key], `${where}.${key}`); }
  else assert.deepEqual(actual, expected, where);
}
let groups = 0, items = 0;
for (const [i, {name, index, limit, groups: expected}] of cases.entries()) {
  const planner = new_feature_planner(decoded[name], index);
  for (const group of expected) {
    const actual = JSON.parse(gpos_feature_examples(planner, group.group, limit));
    compare(actual, group, `case ${i} (${name}, face ${index}, limit ${limit}), group ${group.group}`);
    groups++; items += group.items.length;
  }
}
console.log(`${items} positioning examples in ${groups} feature groups match upstream across ${cases.length} font faces.`);
