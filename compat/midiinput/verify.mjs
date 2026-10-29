import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { detect, unwrap, header, varlen } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';

const fixture = JSON.parse(await readFile(new URL('./upstream.json', import.meta.url)));
const input = value => Buffer.from(value ?? '', 'base64');
for (const [i, item] of fixture.inputs.entries()) {
  const bytes = input(item.input);
  assert.equal(detect(bytes), item.detect, `detect ${i}`);
  const actual = JSON.parse(unwrap(bytes));
  if (!actual.error) {
    for (const key of ['smf', 'title', 'copyright']) actual[key] = Buffer.from(actual[key]).toString('hex');
  }
  assert.deepEqual(actual, item.unwrap, `unwrap ${i}`);
}
for (const [i, item] of fixture.headers.entries()) {
  assert.deepEqual(JSON.parse(header(input(item.input), item.tick)), item.want, `header ${i}`);
}
for (const [i, item] of fixture.varlens.entries()) {
  assert.deepEqual(JSON.parse(varlen(input(item.input))), item.want, `varlen ${i}`);
}
console.log(`${fixture.inputs.length} input, ${fixture.headers.length} header, and ${fixture.varlens.length} variable-length cases match upstream.`);
