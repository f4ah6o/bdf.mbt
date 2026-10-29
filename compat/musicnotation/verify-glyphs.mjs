import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { glyph } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const samples = JSON.parse(await readFile(new URL('./glyphs.json', import.meta.url)));
const normalize = value => JSON.parse(JSON.stringify(value));
for (const c of samples) assert.deepEqual(normalize(JSON.parse(glyph(c.name))),normalize(c),`glyph ${c.name}`);
assert.equal(glyph('not-a-symbol'), 'null');
console.log(`${samples.length} Bravura glyph outlines and metrics match upstream.`);
