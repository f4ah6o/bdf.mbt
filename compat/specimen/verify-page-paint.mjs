import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { new_texter, texter_add_font, record_ui_text, finish_ui_fonts, prepare_page_batch, page_batch_layout, begin_specimen_page, paint_page_band, specimen_page_object } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const {files, face, cases} = JSON.parse(gunzipSync(await readFile(new URL('./page-paint.json.gz', import.meta.url))));
const raw = gunzipSync(Buffer.from(face, 'base64'));
let pageCount = 0;
for (const [i, {fonts, system, noSubset, ignore, glyphHash, sampleHash, advance, bands, pages}] of cases.entries()) {
  const texter = new_texter();
  for (const name of [...fonts].sort()) texter_add_font(texter, name, gunzipSync(Buffer.from(files[name], 'base64')));
  for (const band of bands) record_ui_text(texter, band.Text, 11, band.Bold);
  const embedded = finish_ui_fonts(texter, system, noSubset, ignore);
  const batch = prepare_page_batch(raw, glyphHash, sampleHash, embedded, bands.map(b => b.Height), bands.map(b => b.Space), bands.map(b => b.Keep), bands.map(b => b.Anchor));
  const layout = JSON.parse(page_batch_layout(batch));
  assert.equal(layout.length, pages.length, `case ${i}: page count`);
  for (const [j, strip] of layout.entries()) {
    assert.equal(strip.height, pages[j].height, `case ${i}, page ${j}: height`);
    const page = begin_specimen_page(batch, j);
    for (const [index, y] of strip.bands) {
      const band = bands[index];
      paint_page_band(batch, page, y, band.Text, band.Bold, band.Color, band.Target, advance);
    }
    assert.ok(Buffer.from(specimen_page_object(page)).equals(Buffer.from(pages[j].object, 'base64')), `case ${i}, page ${j}: object`);
    pageCount++;
  }
}
console.log(`${pageCount} specimen pages in ${cases.length} scrolls match upstream byte for byte.`);
