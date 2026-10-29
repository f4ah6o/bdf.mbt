import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { detect_fixture, plotter_fixture } from '../../_build/js/debug/build/compat/csv/csv.js';

const fixtures = JSON.parse(await readFile(new URL('./detect.json', import.meta.url)));
for (const [index, fixture] of fixtures.entries()) {
  const data = Buffer.from(fixture.Data ?? '', 'base64');
  assert.equal(detect_fixture(data), fixture.Detected, 'CSV detection ' + index);
  assert.equal(plotter_fixture(data.subarray(0, 1024)), fixture.Plotter, 'plotter detection ' + index);
}
console.log('CSV detection matches upstream signatures, plotter exclusions and malformed inputs.');
