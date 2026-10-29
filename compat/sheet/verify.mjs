import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { column_fixture } from '../../_build/js/debug/build/compat/sheet/sheet.js';

const fixtures = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
for (const [index, widths] of fixtures.entries()) {
  assert.deepEqual(JSON.parse(column_fixture(index)), widths, 'sheet columns ' + index);
}
console.log('Fitted sheet column widths match upstream without installed fonts.');
