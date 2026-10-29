import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { xlsx_render_basic, xlsx_render_warnings, xlsx_render_error } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const index = JSON.parse(await readFile(new URL('./render/index.json', import.meta.url)));
assert.ok(index.files.length > 0, 'XLSX rendering fixture list must not be empty');
let i = 0;
async function verifyCase(c, label) {
  const expected = await BdfDocument.open(new BufferSource(Buffer.from(c.bdf, 'base64')));
  const actual = await BdfDocument.open(new BufferSource(xlsx_render_basic(Buffer.from(c.input, 'base64'), c.mode, c.no_index)));
  assert.deepEqual(JSON.parse(xlsx_render_warnings(Buffer.from(c.input, 'base64'), c.mode, c.no_index)), c.warnings ?? [], `XLSX warnings ${label}`);
  assert.deepEqual(actual.manifest.meta, expected.manifest.meta, `XLSX metadata ${label}`);
  assert.deepEqual(actual.manifest.views, expected.manifest.views, `XLSX view ${label}`);
  assert.deepEqual(actual.manifest.tables ?? [], expected.manifest.tables ?? [], `XLSX tables ${label}`);
  assert.equal(actual.manifest.parts.length, expected.manifest.parts.length, `XLSX parts ${label}`);
  for (const [j, p] of actual.manifest.parts.entries()) assert.deepEqual(Buffer.from(await actual.part(p.h)), Buffer.from(await expected.part(expected.manifest.parts[j].h)), `XLSX object ${label}:${j}`);
}
for (const file of index.files) {
  assert.match(file, /^\d{3}\.json$/, 'invalid XLSX rendering fixture name');
  const cases = JSON.parse(await readFile(new URL(`./render/${file}`, import.meta.url)));
  for (const c of cases) {
    await verifyCase(c, i);
    i++;
  }
}
assert.equal(i, index.count, 'XLSX rendering fixture count');
const baseFills = JSON.parse(await readFile(new URL('./base-fill.json', import.meta.url)));
assert.equal(baseFills.length, 240, 'row and column fill fixture count');
for (const [j, c] of baseFills.entries()) await verifyCase(c, `base fill ${j}`);
const baseBorders = JSON.parse(await readFile(new URL('./base-border.json', import.meta.url)));
assert.equal(baseBorders.length, 240, 'row and column border fixture count');
for (const [j, c] of baseBorders.entries()) await verifyCase(c, `base border ${j}`);
const plainRuns = JSON.parse(await readFile(new URL('./plain-run.json', import.meta.url)));
assert.equal(plainRuns.length, 120, 'plain rich-text run fixture count');
for (const [j, c] of plainRuns.entries()) await verifyCase(c, `plain run ${j}`);
const links = JSON.parse(await readFile(new URL('./links.json', import.meta.url)));
assert.equal(links.length, 200, 'hyperlink fixture count');
for (const [j, c] of links.entries()) await verifyCase(c, `hyperlink ${j}`);
const percentLinks = JSON.parse(await readFile(new URL('./percent-links.json', import.meta.url)));
assert.equal(percentLinks.length, 200, 'percent-encoded hyperlink fixture count');
for (const [j, c] of percentLinks.entries()) await verifyCase(c, `percent-encoded hyperlink ${j}`);
const inactiveCF = JSON.parse(await readFile(new URL('./inactive-cf.json', import.meta.url)));
assert.equal(inactiveCF.length, 161, 'inactive conditional format fixture count');
for (const [j, c] of inactiveCF.entries()) await verifyCase(c, `inactive conditional format ${j}`);
const activeCF = JSON.parse(await readFile(new URL('./active-cf.json', import.meta.url)));
assert.equal(activeCF.length, 161, 'conditional font fixture count');
for (const [j, c] of activeCF.entries()) await verifyCase(c, `conditional font ${j}`);
const conditionalFill = JSON.parse(await readFile(new URL('./conditional-fill.json', import.meta.url)));
assert.equal(conditionalFill.length, 161, 'conditional fill fixture count');
for (const [j, c] of conditionalFill.entries()) await verifyCase(c, `conditional fill ${j}`);
const conditionalBorder = JSON.parse(await readFile(new URL('./conditional-border.json', import.meta.url)));
assert.equal(conditionalBorder.length, 161, 'conditional border fixture count');
for (const [j, c] of conditionalBorder.entries()) await verifyCase(c, `conditional border ${j}`);
const conditionalOps = JSON.parse(await readFile(new URL('./conditional-ops.json', import.meta.url)));
assert.equal(conditionalOps.length, 161, 'conditional comparison fixture count');
for (const [j, c] of conditionalOps.entries()) await verifyCase(c, `conditional comparison ${j}`);
const conditionalBetween = JSON.parse(await readFile(new URL('./conditional-between.json', import.meta.url)));
assert.equal(conditionalBetween.length, 161, 'conditional interval fixture count');
for (const [j, c] of conditionalBetween.entries()) await verifyCase(c, `conditional interval ${j}`);
const conditionalEquals = JSON.parse(await readFile(new URL('./conditional-equals.json', import.meta.url)));
assert.equal(conditionalEquals.length, 161, 'conditional formula prefix fixture count');
for (const [j, c] of conditionalEquals.entries()) await verifyCase(c, `conditional formula prefix ${j}`);
const conditionalAbsolute = JSON.parse(await readFile(new URL('./conditional-absolute.json', import.meta.url)));
assert.equal(conditionalAbsolute.length, 161, 'absolute conditional reference fixture count');
for (const [j, c] of conditionalAbsolute.entries()) await verifyCase(c, `absolute conditional reference ${j}`);
const conditionalSingleRef = JSON.parse(await readFile(new URL('./conditional-single-ref.json', import.meta.url)));
assert.equal(conditionalSingleRef.length, 161, 'single-cell conditional reference fixture count');
for (const [j, c] of conditionalSingleRef.entries()) await verifyCase(c, `single-cell conditional reference ${j}`);
const conditionalAxisRef = JSON.parse(await readFile(new URL('./conditional-axis-ref.json', import.meta.url)));
assert.equal(conditionalAxisRef.length, 161, 'axis-aligned conditional reference fixture count');
for (const [j, c] of conditionalAxisRef.entries()) await verifyCase(c, `axis-aligned conditional reference ${j}`);
const conditionalMovingRef = JSON.parse(await readFile(new URL('./conditional-moving-ref.json', import.meta.url)));
assert.equal(conditionalMovingRef.length, 169, 'moving conditional reference fixture count');
for (const [j, c] of conditionalMovingRef.entries()) await verifyCase(c, `moving conditional reference ${j}`);
const conditionalNegativeRef = JSON.parse(await readFile(new URL('./conditional-negative-ref.json', import.meta.url)));
assert.equal(conditionalNegativeRef.length, 161, 'negative conditional reference fixture count');
for (const [j, c] of conditionalNegativeRef.entries()) await verifyCase(c, `negative conditional reference ${j}`);
const unsupportedConditionalNegativeRef = JSON.parse(await readFile(new URL('./conditional-negative-ref-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalNegativeRef.length, 8, 'unsupported negative conditional reference fixture count');
for (const encoded of unsupportedConditionalNegativeRef) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional references must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalMovingRef = JSON.parse(await readFile(new URL('./conditional-moving-ref-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalMovingRef.length, 8, 'unsupported moving conditional reference fixture count');
for (const encoded of unsupportedConditionalMovingRef) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional references must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalAxisRef = JSON.parse(await readFile(new URL('./conditional-axis-ref-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalAxisRef.length, 8, 'unsupported axis-aligned conditional reference fixture count');
for (const encoded of unsupportedConditionalAxisRef) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional references must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalSingleRef = JSON.parse(await readFile(new URL('./conditional-single-ref-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalSingleRef.length, 8, 'unsupported single-cell conditional reference fixture count');
for (const encoded of unsupportedConditionalSingleRef) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional references must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalAbsolute = JSON.parse(await readFile(new URL('./conditional-absolute-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalAbsolute.length, 8, 'unsupported conditional reference fixture count');
for (const encoded of unsupportedConditionalAbsolute) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional references must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalEquals = JSON.parse(await readFile(new URL('./conditional-equals-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalEquals.length, 8, 'unsupported conditional formula prefix fixture count');
for (const encoded of unsupportedConditionalEquals) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional formulas must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalBetween = JSON.parse(await readFile(new URL('./conditional-between-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalBetween.length, 8, 'unsupported conditional interval fixture count');
for (const encoded of unsupportedConditionalBetween) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional intervals must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const conditionalBlank = JSON.parse(await readFile(new URL('./conditional-blank.json', import.meta.url)));
assert.equal(conditionalBlank.length, 161, 'conditional blank-cell fixture count');
for (const [j, c] of conditionalBlank.entries()) await verifyCase(c, `conditional blank cell ${j}`);
const conditionalPaintBlank = JSON.parse(await readFile(new URL('./conditional-paint-blank.json', import.meta.url)));
assert.equal(conditionalPaintBlank.length, 166, 'conditional blank-cell paint fixture count');
for (const [j, c] of conditionalPaintBlank.entries()) await verifyCase(c, `conditional blank-cell paint ${j}`);
const unsupportedConditionalPaintBlank = JSON.parse(await readFile(new URL('./conditional-paint-blank-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalPaintBlank.length, 9, 'unsupported conditional blank-cell paint fixture count');
for (const encoded of unsupportedConditionalPaintBlank) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional blank-cell paints must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalBlank = JSON.parse(await readFile(new URL('./conditional-blank-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalBlank.length, 8, 'unsupported conditional blank-cell fixture count');
for (const encoded of unsupportedConditionalBlank) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional blank-cell styles must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalOps = JSON.parse(await readFile(new URL('./conditional-ops-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalOps.length, 8, 'unsupported conditional comparison fixture count');
for (const encoded of unsupportedConditionalOps) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional fills must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalBorder = JSON.parse(await readFile(new URL('./conditional-border-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalBorder.length, 8, 'unsupported conditional border fixture count');
for (const encoded of unsupportedConditionalBorder) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional borders must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalFill = JSON.parse(await readFile(new URL('./conditional-fill-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalFill.length, 8, 'unsupported conditional fill fixture count');
for (const encoded of unsupportedConditionalFill) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional fills must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedActiveCF = JSON.parse(await readFile(new URL('./active-cf-unsupported.json', import.meta.url)));
assert.equal(unsupportedActiveCF.length, 8, 'unsupported conditional font fixture count');
for (const encoded of unsupportedActiveCF) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional styles must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedCF = JSON.parse(await readFile(new URL('./inactive-cf-unsupported.json', import.meta.url)));
assert.equal(unsupportedCF.length, 8, 'unsupported conditional format fixture count');
for (const encoded of unsupportedCF) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional formats must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedLinks = JSON.parse(await readFile(new URL('./links-unsupported.json', import.meta.url)));
assert.equal(unsupportedLinks.length, 3, 'unsupported hyperlink fixture count');
for (const [j, encoded] of unsupportedLinks.entries()) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported links must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), j < 2 ? /unsupported hyperlink URL/ : /links exceed the supported tile budget/);
}
const unsupportedRuns = JSON.parse(await readFile(new URL('./plain-run-unsupported.json', import.meta.url)));
assert.equal(unsupportedRuns.length, 8, 'unsupported rich-text run fixture count');
for (const encoded of unsupportedRuns) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported rich-text runs must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /rich text/);
}
const largeFill = Buffer.from(JSON.parse(await readFile(new URL('./base-fill-too-large.json', import.meta.url))), 'base64');
assert.equal(xlsx_render_basic(largeFill, 'none', true).length, 0, 'oversized base fills must be rejected');
assert.match(xlsx_render_error(largeFill, 'none', true), /row or column fill exceeds the supported view size/);
const largeBorder = Buffer.from(JSON.parse(await readFile(new URL('./base-border-too-large.json', import.meta.url))), 'base64');
assert.equal(xlsx_render_basic(largeBorder, 'none', true).length, 0, 'oversized base borders must be rejected');
assert.match(xlsx_render_error(largeBorder, 'none', true), /row or column border exceeds the supported view size/);
const styled = JSON.parse(await readFile(new URL('./cells.json', import.meta.url)))[0];
assert.equal(xlsx_render_basic(Buffer.from(styled.input, 'base64'), 'none', true).length, 0, 'unsupported styled workbook must be rejected');
const autoHeight = JSON.parse(await readFile(new URL('./auto-height.json', import.meta.url)));
assert.ok(xlsx_render_basic(Buffer.from(autoHeight, 'base64'), 'none', true).length, 'nondefault font sizes on auto-height rows must convert');
const unsupportedBase = JSON.parse(await readFile(new URL('./base-style-unsupported.json', import.meta.url)));
assert.equal(unsupportedBase.length, 4, 'row and column fill and border fixtures');
for (const encoded of unsupportedBase) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported base styles must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /row or column styles with (fills|complex borders)/);
}
console.log(`${i} basic XLSX renderings, ${baseFills.length} base fills, ${baseBorders.length} base borders, ${plainRuns.length} plain runs, ${links.length + percentLinks.length} links, and ${inactiveCF.length + activeCF.length + conditionalFill.length + conditionalBorder.length + conditionalOps.length + conditionalBetween.length + conditionalEquals.length + conditionalAbsolute.length + conditionalSingleRef.length + conditionalAxisRef.length + conditionalMovingRef.length + conditionalNegativeRef.length + conditionalBlank.length + conditionalPaintBlank.length} conditional formats match upstream.`);
