import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { styled_summary, styled_tile } from '../../_build/js/debug/build/compat/sheet/sheet.js';
const cases = JSON.parse(await readFile(new URL('./styled.json', import.meta.url)));
let failures = 0;
for (const [index, expected] of cases.entries()) {
  const scenario = expected.scenario;
  const summary = JSON.parse(styled_summary(expected.style, scenario));
  const geometry = JSON.parse(summary.geometry);
  try {
    assert.deepEqual(geometry.cols, expected.cols);
    assert.deepEqual(geometry.rows, expected.rows);
    assert.equal(geometry.frozen, expected.freeze?.rows ?? 0);
    assert.equal(summary.tiles.length, expected.parts.length);
    for (const [i, tile] of summary.tiles.entries()) {
      const actual = Buffer.from(styled_tile(expected.style, scenario, i));
      const reference = Buffer.from(expected.parts[i].data, 'base64');
      const byte = actual.findIndex((value, offset) => value !== reference[offset]);
      assert.ok(actual.equals(reference), `tile ${i}: first byte ${byte}, lengths ${actual.length}/${reference.length}`);
      assert.equal(tile.drawn ? expected.tiles?.[tile.x + ',' + tile.y] : undefined, tile.drawn ? expected.parts[i].hash : undefined);
    }
  } catch (error) {
    if (failures++ < 20) console.error(expected.style, scenario, error.message);
  }
}
assert.equal(failures, 0, `${failures} styled grids differ from upstream`);
console.log(`All ${cases.length} styled grids match upstream.`);
