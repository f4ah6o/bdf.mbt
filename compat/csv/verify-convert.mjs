import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { convert_fixture, convert_summary } from '../../_build/js/debug/build/compat/csv/csv.js';

const cases = JSON.parse(await readFile(new URL('./conversion.json', import.meta.url)));
for (const [index, sample] of cases.entries()) {
  const input = sample.input;
  const args = [Buffer.from(input.Data, 'base64'), input.Name, input.Title, input.Charset,
    input.Delimiter, input.Quote, input.Header, input.Mode, input.NoTextIndex, input.TableStyle];
  const actual = await BdfDocument.open(new BufferSource(convert_fixture(...args)));
  const expected = await BdfDocument.open(new BufferSource(Buffer.from(sample.bdf, 'base64')));
  const summary = JSON.parse(convert_summary(...args));
  for (const key of ['charset', 'bom', 'header', 'rows', 'columns', 'summary']) {
    assert.deepEqual(summary[key], sample[key], 'CSV ' + index + ' ' + key);
  }
  assert.deepEqual(summary.warnings, sample.warnings ?? [], 'CSV warnings ' + index);
  assert.deepEqual(actual.manifest.meta, expected.manifest.meta, 'CSV metadata ' + index);
  assert.deepEqual(actual.manifest.views, expected.manifest.views, 'CSV view ' + index);
  assert.deepEqual(actual.manifest.tables ?? [], expected.manifest.tables ?? [], 'CSV tables ' + index);
  assert.equal(actual.manifest.parts.length, expected.manifest.parts.length, 'CSV parts ' + index);
  for (const [i, part] of actual.manifest.parts.entries()) {
    const other = expected.manifest.parts[i];
    assert.equal(part.h, other.h, 'CSV part hash ' + index + ':' + i);
    assert.equal(part.t, other.t, 'CSV part type ' + index + ':' + i);
    assert.deepEqual(Buffer.from(await actual.part(part.h)), Buffer.from(await expected.part(other.h)), 'CSV part ' + index + ':' + i);
  }
}
console.log('CSV no-font BDF conversion matches upstream documents.');
