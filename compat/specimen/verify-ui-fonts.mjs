import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import { new_texter, texter_add_font, record_ui_text, finish_ui_fonts, ui_font_summary, ui_font_records } from '../../_build/js/debug/build/compat/specimen/specimen.js';
const {files, cases} = JSON.parse(gunzipSync(await readFile(new URL('./ui-fonts.json.gz', import.meta.url))));
for (const {fonts, system, noSubset, ignore, texts, records, parts, warnings} of cases) {
  const texter = new_texter();
  for (const name of [...fonts].sort()) texter_add_font(texter, name, gunzipSync(Buffer.from(files[name], 'base64')));
  texts.forEach((text, i) => record_ui_text(texter, text, 12, i === 1));
  const embedded = finish_ui_fonts(texter, system, noSubset, ignore);
  assert.deepEqual(JSON.parse(ui_font_summary(embedded)), {parts, warnings}, `font resources: ${fonts}, system=${system}, noSubset=${noSubset}, ignore=${ignore}`);
  texts.forEach((text, i) => assert.deepEqual(JSON.parse(ui_font_records(embedded, text, 12, i === 1)), records[i], `font records: ${fonts}, text=${text}, system=${system}, noSubset=${noSubset}, ignore=${ignore}`));
}
console.log(`${cases.length} UI font embedding cases match upstream.`);
