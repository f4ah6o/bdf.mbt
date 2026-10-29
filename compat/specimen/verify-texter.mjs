import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { new_texter, texter_add_font, measure_text, texter_usage } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const {files, configurations} = JSON.parse(gunzipSync(await readFile(new URL('./texter.json.gz', import.meta.url))));
let count = 0;
for (const {fonts, cases, used, missing} of configurations) {
  const texter = new_texter();
  for (const name of [...fonts].sort()) texter_add_font(texter, name, gunzipSync(Buffer.from(files[name], 'base64')));
  for (const {text, size, bold, maxWidth, ...expected} of cases) {
    const actual = JSON.parse(measure_text(texter, text, size, bold, maxWidth));
    const label = `${fonts.join(',')}, ${JSON.stringify(text)}, size=${size}, bold=${bold}, width=${maxWidth}`;
    const close = (a, b) => assert.ok(Math.abs(a - b) <= 1e-10 * Math.max(1, Math.abs(b)), `${label}: ${a} != ${b}`);
    close(actual.width, expected.width);
    assert.equal(actual.runs.length, expected.runs.length, label);
    for (let i = 0; i < actual.runs.length; i++) {
      const {x, width, ...run} = actual.runs[i];
      const {x: expectedX, width: expectedWidth, ...want} = expected.runs[i];
      close(x, expectedX); close(width, expectedWidth);
      assert.deepEqual(run, want, label);
    }
    assert.equal(actual.fit, expected.fit, label);
    assert.deepEqual(actual.wrap, expected.wrap, label);
    count++;
  }
  assert.deepEqual(JSON.parse(texter_usage(texter)), {used, missing}, `font usage for ${fonts.join(",")}`);
}
console.log(`${count} specimen text measurements and wrapping cases match upstream.`);
