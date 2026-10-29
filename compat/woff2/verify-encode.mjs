import assert from 'node:assert/strict';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { chromium } from 'playwright';
import { encode_woff2, encode_bytes, encode_error, decode_woff2, decode_valid, decode_bytes } from '../../_build/js/debug/build/compat/woff2/woff2.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./encode.json.gz', import.meta.url))));
const visual = [];
await mkdir('_build/woff2-encoded', {recursive:true});
for (const [i, test] of cases.entries()) {
  const input = Buffer.from(test.input ?? '', 'base64');
  const result = encode_woff2(input);
  assert.equal(encode_error(result), test.error, `${test.name}: error`);
  if (test.error) continue;
  const encoded = Buffer.from(encode_bytes(result));
  assert.equal(encoded.subarray(0, 4).toString(), 'wOF2', test.name);
  const decoded = decode_woff2(encoded);
  assert.equal(decode_valid(decoded), true, test.name);
  assert.deepEqual(Buffer.from(decode_bytes(decoded)), Buffer.from(test.decoded, 'base64'), `${test.name}: decoded tables`);
  await writeFile(`_build/woff2-encoded/${i}.woff2`, encoded);
  await writeFile(`_build/woff2-encoded/${i}.sfnt`, Buffer.from(test.decoded, 'base64'));
  if (test.name === 'stix.ttf' || test.name === 'stix.otf') visual.push({name:test.name, input:[...input], encoded:[...encoded]});
}
const browser = await chromium.launch({headless: true});
try {
  const page = await browser.newPage();
  for (const test of visual) {
    const equal = await page.evaluate(async ({name, input, encoded}) => {
      const original = new FontFace('original', new Uint8Array(input));
      const converted = new FontFace('converted', new Uint8Array(encoded));
      await original.load(); await converted.load(); document.fonts.add(original); document.fonts.add(converted);
      const render = family => { const canvas = document.createElement('canvas'); canvas.width = 480; canvas.height = 110; const ctx = canvas.getContext('2d'); ctx.fillStyle='#111'; ctx.font=`42px ${family}`; ctx.fillText('ABC fi Ω αβγ 123', 2, 70); return [...ctx.getImageData(0, 0, canvas.width, canvas.height).data]; };
      const a = render('original'), b = render('converted'); document.fonts.delete(original); document.fonts.delete(converted);
      return a.length === b.length && a.every((value, i) => value === b[i]);
    }, test);
    assert.equal(equal, true, `${test.name}: browser glyph rendering`);
  }
  await page.close();
} finally { await browser.close(); }
console.log(`${cases.length} WOFF2 encoding inputs match upstream table semantics; ${visual.length} fonts render identically in Chromium.`);
