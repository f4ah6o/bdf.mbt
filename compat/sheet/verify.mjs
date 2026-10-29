import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { column_fixture, wrap_fixture, row_fixture, line_break_fixture, geometry_fixture, drawing_summary, drawing_tile } from '../../_build/js/debug/build/compat/sheet/sheet.js';

const fixtures = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
for (const [index, widths] of fixtures.entries()) {
  assert.deepEqual(JSON.parse(column_fixture(index)), widths, 'sheet columns ' + index);
}
const wraps = JSON.parse(await readFile(new URL('./wrap.json', import.meta.url)));
for (const { Text, Width, Lines } of wraps) {
  assert.deepEqual(JSON.parse(wrap_fixture(Text, Width)), Lines, 'line wrap: ' + JSON.stringify(Text));
}
const heights = JSON.parse(await readFile(new URL('./heights.json', import.meta.url)));
for (const [index, expected] of heights.entries()) {
  assert.deepEqual(JSON.parse(row_fixture(index)), expected, 'sheet rows ' + index);
}
const geometries = JSON.parse(await readFile(new URL('./geometry.json', import.meta.url)));
for (const [index, expected] of geometries.entries()) {
  assert.deepEqual(JSON.parse(geometry_fixture(index)), expected, 'sheet geometry ' + index);
}
const drawings = JSON.parse(await readFile(new URL('./drawing.json', import.meta.url)));
for (const [index, expected] of drawings.entries()) {
  const tiles = JSON.parse(drawing_summary(index));
  assert.equal(tiles.length, expected.parts.length, 'tile count ' + index);
  for (const [i, tile] of tiles.entries()) {
    const bytes = Buffer.from(drawing_tile(index, i));
    assert.deepEqual(bytes, Buffer.from(expected.parts[i].data, 'base64'), 'tile bytes ' + index + ':' + i);
    assert.equal(tile.drawn ? expected.tiles?.[tile.x + ',' + tile.y] : undefined, tile.drawn ? expected.parts[i].hash : undefined);
  }
}
const expectedDigests = (await readFile(new URL('./break-sha256.txt', import.meta.url), 'utf8')).trim().split('\n');
for (let mode = 0; mode < expectedDigests.length; mode++) {
  const breaks = Buffer.alloc(0x110000);
  for (let code = 0; code < breaks.length; code++) breaks[code] = line_break_fixture(mode, code) ? 1 : 0;
  const digest = createHash('sha256').update(breaks).digest('hex');
  assert.equal(digest, expectedDigests[mode], 'Unicode break mode ' + mode);
}
console.log('Sheet geometry, row heights and line wrapping match upstream fixtures.');
