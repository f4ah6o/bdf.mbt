import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { decodeObject, extractContent } from '@bdfkit/core';

const dir = new URL('.', import.meta.url);
const parentBytes = readFileSync(new URL('parent.bobj', dir));
const childBytes = readFileSync(new URL('child.bobj', dir));
const testSource = readFileSync(new URL('../../render/text_test.mbt', dir), 'utf8');
for (const [name, expected] of [['parent', parentBytes], ['child', childBytes]]) {
  const match = testSource.match(new RegExp(`let ${name} = @core\\.decode_object_resources\\(\\s*b"([^"]+)"\\s*,?\\s*\\)`));
  assert.ok(match, `missing embedded ${name} fixture`);
  const embedded = Buffer.from([...match[1].matchAll(/\\x([0-9a-f]{2})/g)].map(m => parseInt(m[1], 16)));
  assert.deepEqual(embedded, expected, `embedded ${name} fixture differs`);
}
const parent = decodeObject(parentBytes);
const child = decodeObject(childBytes);
const hash = readFileSync(new URL('child.hash', dir), 'utf8');
const { runs, links } = extractContent(parent, h => h === hash ? child : undefined);
assert.deepEqual(runs.map(r => r.text), ['Hello', 'World', 'second', 'wrapped', 'outlined', 'child', 'drawn by a child', 'orphan']);
assert.deepEqual(runs.map(r => r.sep), [2, 1, 1, 0, 1, 1, 1, 1]);
assert.deepEqual(runs.map(r => r.ordinal), [0, 1, 2, 3, 4, 5, 6, 7]);
assert.deepEqual([runs[4].x, runs[4].y, runs[4].altText, runs[4].lang], [5, 45, true, 'ja']);
assert.deepEqual([runs[5].x, runs[5].y, runs[5].advance, runs[5].matrix], [105, 107, 12, [1, 0, 0, 1, 100, 100]]);
assert.deepEqual([runs[6].x, runs[6].y, runs[6].advance, runs[6].altText], [52, 150, 20, true]);
assert.deepEqual([runs[7].x, runs[7].y, runs[7].altText], [0, 0, true]);
assert.deepEqual(links.map(({x, y, w, h, after, url}) => ({x, y, w, h, after, url})), [{x:14, y:31, w:4, h:3, after:6, url:'https://example.org/'}]);
const transformed = extractContent(parent, h => h === hash ? child : undefined, [2, 0, 0, 3, 4, 5]);
assert.deepEqual([transformed.runs[5].x, transformed.runs[5].y], [214, 326]);
assert.deepEqual([transformed.links[0].x, transformed.links[0].y, transformed.links[0].w, transformed.links[0].h], [32, 98, 8, 9]);
console.log('Upstream text extraction matches the MoonBit fixture expectations.');
