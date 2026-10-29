import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { gunzipSync, brotliDecompressSync } from 'node:zlib';
import { chromium } from 'playwright';
import { encode_woff2, encode_bytes, encode_error, decode_woff2, decode_valid, decode_bytes } from '../../_build/js/debug/build/compat/woff2/woff2.js';
const cases = JSON.parse(gunzipSync(await readFile(new URL('./encode.json.gz', import.meta.url))));
function unpackWoff(data) {
  let pos = 48;
  const count = data.readUInt16BE(12), compressed = data.readUInt32BE(20);
  const read128 = () => { let v=0, b; do { b=data[pos++]; v=v*128+(b&127); } while (b&128); return v; };
  for (let i=0; i<count; i++) {
    const flags=data[pos++], idx=flags&63;
    let tag = idx===10 ? 'glyf' : idx===11 ? 'loca' : '';
    if (idx===63) { tag=data.subarray(pos,pos+4).toString('latin1'); pos+=4; }
    read128();
    const transformed = tag==='glyf' || tag==='loca' ? (flags>>6)===0 : (flags>>6)!==0;
    if (transformed) read128();
  }
  return {directory:data.subarray(48,pos), stream:brotliDecompressSync(data.subarray(pos,pos+compressed))};
}
const visual = [];
await mkdir('_build/woff2-encoded', {recursive:true});
for (const [i, test] of cases.entries()) {
  const input = test.base ? Buffer.from(cases.find(c => c.name === test.base).input, 'base64') : Buffer.from(test.input ?? '', 'base64');
  for (const [pos, value] of test.patches ?? []) input[pos] ^= value;
  const result = encode_woff2(input);
  assert.equal(encode_error(result), test.error, `${test.name}: error`);
  if (test.error) continue;
  const encoded = Buffer.from(encode_bytes(result));
  assert.equal(encoded.subarray(0, 4).toString(), 'wOF2', test.name);
  if (test.encoded) {
    const actualLayout = unpackWoff(encoded), expectedLayout = unpackWoff(Buffer.from(test.encoded, 'base64'));
    assert.deepEqual(actualLayout.directory, expectedLayout.directory, `${test.name}: WOFF2 directory`);
    assert.deepEqual(actualLayout.stream, expectedLayout.stream, `${test.name}: transformed table stream`);
  }
  const decoded = decode_woff2(encoded);
  assert.equal(decode_valid(decoded), true, test.name);
  const decodedBytes = Buffer.from(decode_bytes(decoded));
  if (test.decodedHash) assert.equal(createHash('sha256').update(decodedBytes).digest('hex'), test.decodedHash, `${test.name}: decoded tables`);
  else assert.deepEqual(decodedBytes, Buffer.from(test.decoded, 'base64'), `${test.name}: decoded tables`);
  await writeFile(`_build/woff2-encoded/${i}.woff2`, encoded);
  await writeFile(`_build/woff2-encoded/${i}.sfnt`, decodedBytes);
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
console.log(`${cases.length} WOFF2 encoding inputs match upstream transformed tables and decoded SFNTs; ${visual.length} fonts render identically in Chromium.`);
