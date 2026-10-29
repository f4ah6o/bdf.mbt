import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { table_fixture } from '../../_build/js/debug/build/compat/csv/csv.js';

const cases = JSON.parse(await readFile(new URL('./table.json', import.meta.url)));
for (const { Input, Kind, Value } of cases) {
  const actual = JSON.parse(table_fixture(Input));
  assert.equal(actual.kind, Kind, Input);
  if (Kind === 'number' && actual.value !== Value) {
    assert.ok(Object.is(Number(actual.value), Number(Value)), Input);
  } else {
    assert.equal(actual.value, Value, Input);
  }
}
console.log('CSV table types and UTC dates match upstream fixtures.');
