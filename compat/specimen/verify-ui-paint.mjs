import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { new_texter, texter_add_font, record_ui_text, finish_ui_fonts, prepare_ui_painter, paint_ui_label, paint_ui_sample, paint_ui_glyphs, ui_painter_object } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const {files, face, cases} = JSON.parse(gunzipSync(await readFile(new URL('./ui-paint.json.gz', import.meta.url))));
const glyphFace = gunzipSync(Buffer.from(face, 'base64'));
for (const [i, {fonts, system, noSubset, ignore, docLanguage, glyphHash, sampleHash, events, advance, object}] of cases.entries()) {
  const texter = new_texter();
  for (const name of [...fonts].sort()) texter_add_font(texter, name, gunzipSync(Buffer.from(files[name], 'base64')));
  for (const event of events) record_ui_text(texter, event.Text, event.Size, event.Bold);
  const embedded = finish_ui_fonts(texter, system, noSubset, ignore);
  const painter = prepare_ui_painter(glyphFace, docLanguage, glyphHash, sampleHash, embedded);
  events.forEach((event, j) => {
    paint_ui_label(painter, event.Text, event.X, event.Y, event.Size, event.Bold, event.Color, event.Align);
    if (j % 2 === 0) paint_ui_sample(painter, j % 4 === 0);
    if (j % 3 === 0) paint_ui_glyphs(painter, advance);
  });
  assert.ok(Buffer.from(ui_painter_object(painter)).equals(Buffer.from(object, 'base64')), `UI paint case ${i}: ${fonts}`);
}
console.log(`${cases.length} UI text and glyph painting objects match upstream byte for byte.`);
