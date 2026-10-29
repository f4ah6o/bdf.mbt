import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { track_meta } from '../../_build/js/debug/build/compat/midiinput/midiinput.js';

const samples = JSON.parse(await readFile(new URL('./meta.json', import.meta.url)));
const hex = value => Buffer.from(value).toString('hex');
for (const [i, sample] of samples.entries()) {
  const actual = JSON.parse(track_meta(Buffer.from(sample.input ?? '', 'base64')));
  for (const key of ['name', 'instrument', 'copyright']) actual[key] = hex(actual[key]);
  actual.channels = actual.channels.map(hex);
  actual.texts = actual.texts.map(([tick, kind, text]) => [tick, kind, hex(text)]);
  assert.deepEqual(actual, sample.want, `track meta ${i}`);
}
console.log(`${samples.length} track metadata cases match upstream.`);
