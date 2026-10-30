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
const ignoredSheetFeatures = JSON.parse(await readFile(new URL('./ignored-sheet-features.json', import.meta.url)));
assert.equal(ignoredSheetFeatures.length, 320, 'ignored sheet feature fixture count');
for (const [j, c] of ignoredSheetFeatures.entries()) await verifyCase(c, `ignored sheet feature ${j}`);
const ignoredSheetExtensions = JSON.parse(await readFile(new URL('./ignored-sheet-extensions.json', import.meta.url)));
assert.equal(ignoredSheetExtensions.length, 160, 'ignored sheet extension fixture count');
for (const [j, c] of ignoredSheetExtensions.entries()) await verifyCase(c, `ignored sheet extension ${j}`);
const unsupportedSheetExtensions = JSON.parse(await readFile(new URL('./ignored-sheet-extensions-unsupported.json', import.meta.url)));
assert.equal(unsupportedSheetExtensions.length, 8, 'unsupported sheet extension fixture count');
for (const encoded of unsupportedSheetExtensions) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'extended conditional formats must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /extended conditional formatting/);
}
const sheetAutoFilter = JSON.parse(await readFile(new URL('./sheet-autofilter.json', import.meta.url)));
assert.equal(sheetAutoFilter.length, 256, 'sheet autofilter fixture count');
for (const [j, c] of sheetAutoFilter.entries()) await verifyCase(c, `sheet autofilter ${j}`);
const sheetAutoFilterTiles = JSON.parse(await readFile(new URL('./sheet-autofilter-tiles.json', import.meta.url)));
assert.equal(sheetAutoFilterTiles.length, 128, 'sheet autofilter tile fixture count');
for (const [j, c] of sheetAutoFilterTiles.entries()) await verifyCase(c, `sheet autofilter tiles ${j}`);
const sheetNotes = JSON.parse(await readFile(new URL('./sheet-notes.json', import.meta.url)));
assert.equal(sheetNotes.length, 192, 'sheet note fixture count');
for (const [j, c] of sheetNotes.entries()) await verifyCase(c, `sheet notes ${j}`);
const sheetNotesFilter = JSON.parse(await readFile(new URL('./sheet-notes-filter.json', import.meta.url)));
assert.equal(sheetNotesFilter.length, 128, 'sheet note and autofilter fixture count');
for (const [j, c] of sheetNotesFilter.entries()) await verifyCase(c, `sheet notes and autofilter ${j}`);
const sheetMissingParts = JSON.parse(await readFile(new URL('./sheet-missing-parts.json', import.meta.url)));
assert.equal(sheetMissingParts.length, 160, 'missing sheet part fixture count');
for (const [j, c] of sheetMissingParts.entries()) await verifyCase(c, `missing sheet part ${j}`);
const unsupportedSheetParts = JSON.parse(await readFile(new URL('./sheet-missing-parts-unsupported.json', import.meta.url)));
assert.equal(unsupportedSheetParts.length, 8, 'unsupported sheet part fixture count');
for (const encoded of unsupportedSheetParts) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'active sheet parts must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /worksheet feature/);
}
const baseFills = JSON.parse(await readFile(new URL('./base-fill.json', import.meta.url)));
assert.equal(baseFills.length, 240, 'row and column fill fixture count');
for (const [j, c] of baseFills.entries()) await verifyCase(c, `base fill ${j}`);
const baseBorders = JSON.parse(await readFile(new URL('./base-border.json', import.meta.url)));
assert.equal(baseBorders.length, 240, 'row and column border fixture count');
for (const [j, c] of baseBorders.entries()) await verifyCase(c, `base border ${j}`);
const plainRuns = JSON.parse(await readFile(new URL('./plain-run.json', import.meta.url)));
assert.equal(plainRuns.length, 120, 'plain rich-text run fixture count');
for (const [j, c] of plainRuns.entries()) await verifyCase(c, `plain run ${j}`);
const multiplePlainRuns = JSON.parse(await readFile(new URL('./multiple-plain-runs-safe.json', import.meta.url)));
assert.equal(multiplePlainRuns.length, 240, 'multiple plain run fixture count');
for (const [j, c] of multiplePlainRuns.entries()) await verifyCase(c, `multiple plain runs ${j}`);
const richRunLegacy = JSON.parse(await readFile(new URL('./rich-run-legacy.json', import.meta.url)));
assert.equal(richRunLegacy.length, 98, 'rich-run legacy fixture count');
for (const [j, c] of richRunLegacy.entries()) await verifyCase(c, `rich-run legacy ${j}`);
const richRunData = JSON.parse(await readFile(new URL('./rich-run-data.json', import.meta.url)));
assert.equal(richRunData.length, 336, 'rich-run data fixture count');
for (const [j, c] of richRunData.entries()) await verifyCase(c, `rich-run data ${j}`);
const richRunWrap = JSON.parse(await readFile(new URL('./rich-run-wrap.json', import.meta.url)));
assert.equal(richRunWrap.length, 168, 'rich-run wrap fixture count');
for (const [j, c] of richRunWrap.entries()) await verifyCase(c, `rich-run wrap ${j}`);
const richRunIdentity = JSON.parse(await readFile(new URL('./rich-run-identity.json', import.meta.url)));
assert.equal(richRunIdentity.length, 160, 'rich-run identity fixture count');
for (const [j, c] of richRunIdentity.entries()) await verifyCase(c, `rich-run identity ${j}`);
const singleStyledRun = JSON.parse(await readFile(new URL('./single-styled-run.json', import.meta.url)));
assert.equal(singleStyledRun.length, 384, 'single styled run fixture count');
for (const [j, c] of singleStyledRun.entries()) await verifyCase(c, `single styled run ${j}`);
const singleStyledRunConditional = JSON.parse(await readFile(new URL('./single-styled-run-conditional.json', import.meta.url)));
assert.equal(singleStyledRunConditional.length, 192, 'single styled run-conditional fixture count');
for (const [j, c] of singleStyledRunConditional.entries()) await verifyCase(c, `single styled run-conditional ${j}`);
const singleStyledRunVariants = JSON.parse(await readFile(new URL('./single-styled-run-variants.json', import.meta.url)));
assert.equal(singleStyledRunVariants.length, 320, 'single styled run-variants fixture count');
for (const [j, c] of singleStyledRunVariants.entries()) await verifyCase(c, `single styled run-variants ${j}`);
const singleStyledRunLegacy = JSON.parse(await readFile(new URL('./single-styled-run-legacy.json', import.meta.url)));
assert.equal(singleStyledRunLegacy.length, 2, 'single styled run-legacy fixture count');
for (const [j, c] of singleStyledRunLegacy.entries()) await verifyCase(c, `single styled run-legacy ${j}`);
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
const conditionalNegativeBlank = JSON.parse(await readFile(new URL('./conditional-negative-blank.json', import.meta.url)));
assert.equal(conditionalNegativeBlank.length, 161, 'negative blank and boolean reference fixture count');
for (const [j, c] of conditionalNegativeBlank.entries()) await verifyCase(c, `negative blank and boolean reference ${j}`);
const conditionalPredicates = JSON.parse(await readFile(new URL('./conditional-predicates.json', import.meta.url)));
assert.equal(conditionalPredicates.length, 161, 'blank and error predicate fixture count');
for (const [j, c] of conditionalPredicates.entries()) await verifyCase(c, `blank and error predicate ${j}`);
const conditionalText = JSON.parse(await readFile(new URL('./conditional-text.json', import.meta.url)));
assert.equal(conditionalText.length, 257, 'conditional text fixture count');
for (const [j, c] of conditionalText.entries()) await verifyCase(c, `conditional text ${j}`);
const conditionalTop = JSON.parse(await readFile(new URL('./conditional-top.json', import.meta.url)));
assert.equal(conditionalTop.length, 257, 'conditional top and bottom fixture count');
for (const [j, c] of conditionalTop.entries()) await verifyCase(c, `conditional top and bottom ${j}`);
const conditionalAverage = JSON.parse(await readFile(new URL('./conditional-average.json', import.meta.url)));
assert.equal(conditionalAverage.length, 257, 'conditional average fixture count');
for (const [j, c] of conditionalAverage.entries()) await verifyCase(c, `conditional average ${j}`);
const conditionalStdDev = JSON.parse(await readFile(new URL('./conditional-stddev.json', import.meta.url)));
assert.equal(conditionalStdDev.length, 417, 'conditional standard deviation fixture count');
for (const [j, c] of conditionalStdDev.entries()) await verifyCase(c, `conditional standard deviation ${j}`);
const conditionalDuplicate = JSON.parse(await readFile(new URL('./conditional-duplicate.json', import.meta.url)));
assert.equal(conditionalDuplicate.length, 385, 'conditional duplicate and unique fixture count');
for (const [j, c] of conditionalDuplicate.entries()) await verifyCase(c, `conditional duplicate and unique ${j}`);
const unsupportedConditionalDuplicate = JSON.parse(await readFile(new URL('./conditional-duplicate-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalDuplicate.length, 8, 'unsupported conditional duplicate fixture count');
for (const encoded of unsupportedConditionalDuplicate) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional duplicate must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const conditionalLargeStdDev = JSON.parse(await readFile(new URL('./conditional-large-stddev.json', import.meta.url)));
assert.equal(conditionalLargeStdDev.length, 433, 'large conditional standard deviation fixture count');
for (const [j, c] of conditionalLargeStdDev.entries()) await verifyCase(c, `large conditional standard deviation ${j}`);
const conditionalOverflowMean = JSON.parse(await readFile(new URL('./conditional-overflow-mean.json', import.meta.url)));
assert.equal(conditionalOverflowMean.length, 465, 'overflowed conditional mean fixture count');
for (const [j, c] of conditionalOverflowMean.entries()) await verifyCase(c, `overflowed conditional mean ${j}`);
const conditionalDisjoint = JSON.parse(await readFile(new URL('./conditional-disjoint.json', import.meta.url)));
assert.equal(conditionalDisjoint.length, 288, 'disjoint conditional format fixture count');
for (const [j, c] of conditionalDisjoint.entries()) await verifyCase(c, `disjoint conditional ${j}`);
const conditionalDisjointMoving = JSON.parse(await readFile(new URL('./conditional-disjoint-moving.json', import.meta.url)));
assert.equal(conditionalDisjointMoving.length, 512, 'disjoint moving conditional format fixture count');
for (const [j, c] of conditionalDisjointMoving.entries()) await verifyCase(c, `disjoint moving conditional ${j}`);
const conditionalSameStyle = JSON.parse(await readFile(new URL('./conditional-same-style.json', import.meta.url)));
assert.equal(conditionalSameStyle.length, 512, 'same-style conditional format fixture count');
for (const [j, c] of conditionalSameStyle.entries()) await verifyCase(c, `same-style conditional ${j}`);
const conditionalIdenticalBlocks = JSON.parse(await readFile(new URL('./conditional-identical-blocks.json', import.meta.url)));
assert.equal(conditionalIdenticalBlocks.length, 29, 'identical conditional block fixture count');
for (const [j, c] of conditionalIdenticalBlocks.entries()) await verifyCase(c, `identical conditional blocks ${j}`);
const conditionalSameRuleStyle = JSON.parse(await readFile(new URL('./conditional-same-rule-style.json', import.meta.url)));
assert.equal(conditionalSameRuleStyle.length, 512, 'same-style conditional rule fixture count');
for (const [j, c] of conditionalSameRuleStyle.entries()) await verifyCase(c, `same-style conditional rules ${j}`);
const conditionalDisjointMatches = JSON.parse(await readFile(new URL('./conditional-disjoint-matches.json', import.meta.url)));
assert.equal(conditionalDisjointMatches.length, 512, 'disjoint conditional matches fixture count');
for (const [j, c] of conditionalDisjointMatches.entries()) await verifyCase(c, `disjoint conditional matches ${j}`);
const conditionalNonfiniteAverage = JSON.parse(await readFile(new URL('./conditional-nonfinite-average.json', import.meta.url)));
assert.equal(conditionalNonfiniteAverage.length, 705, 'nonfinite conditional average fixture count');
for (const [j, c] of conditionalNonfiniteAverage.entries()) await verifyCase(c, `nonfinite conditional average ${j}`);
const unsupportedConditionalNonfiniteAverage = JSON.parse(await readFile(new URL('./conditional-nonfinite-average-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalNonfiniteAverage.length, 8, 'unsupported nonfinite conditional average fixture count');
for (const encoded of unsupportedConditionalNonfiniteAverage) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional average must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalOverflowMean = JSON.parse(await readFile(new URL('./conditional-overflow-mean-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalOverflowMean.length, 8, 'unsupported overflowed conditional mean fixture count');
for (const encoded of unsupportedConditionalOverflowMean) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional average must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalLargeStdDev = JSON.parse(await readFile(new URL('./conditional-large-stddev-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalLargeStdDev.length, 8, 'unsupported large conditional standard deviation fixture count');
for (const encoded of unsupportedConditionalLargeStdDev) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported large conditional standard deviation must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalStdDev = JSON.parse(await readFile(new URL('./conditional-stddev-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalStdDev.length, 8, 'unsupported conditional standard deviation fixture count');
for (const encoded of unsupportedConditionalStdDev) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional standard deviation must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalAverage = JSON.parse(await readFile(new URL('./conditional-average-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalAverage.length, 8, 'unsupported conditional average fixture count');
for (const encoded of unsupportedConditionalAverage) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional average must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalTop = JSON.parse(await readFile(new URL('./conditional-top-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalTop.length, 8, 'unsupported conditional top fixture count');
for (const encoded of unsupportedConditionalTop) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional top must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalText = JSON.parse(await readFile(new URL('./conditional-text-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalText.length, 8, 'unsupported conditional text fixture count');
for (const encoded of unsupportedConditionalText) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional text must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalPredicates = JSON.parse(await readFile(new URL('./conditional-predicates-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalPredicates.length, 8, 'unsupported conditional predicate fixture count');
for (const encoded of unsupportedConditionalPredicates) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional predicates must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const conditionalNegativeString = JSON.parse(await readFile(new URL('./conditional-negative-string.json', import.meta.url)));
assert.equal(conditionalNegativeString.length, 289, 'negative numeric string reference fixture count');
for (const [j, c] of conditionalNegativeString.entries()) await verifyCase(c, `negative numeric string reference ${j}`);
const unsupportedConditionalNegativeString = JSON.parse(await readFile(new URL('./conditional-negative-string-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalNegativeString.length, 8, 'unsupported negative numeric string fixture count');
for (const encoded of unsupportedConditionalNegativeString) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported negative numeric string must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalNegativeBlank = JSON.parse(await readFile(new URL('./conditional-negative-blank-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalNegativeBlank.length, 9, 'unsupported negative blank reference fixture count');
for (const encoded of unsupportedConditionalNegativeBlank) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional references must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
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
const conditionalLiteral = JSON.parse(await readFile(new URL('./conditional-literal.json', import.meta.url)));
assert.equal(conditionalLiteral.length, 361, 'conditional literal fixture count');
for (const [j, c] of conditionalLiteral.entries()) await verifyCase(c, `conditional literal ${j}`);
const conditionalMovingLiteral = JSON.parse(await readFile(new URL('./conditional-moving-literal.json', import.meta.url)));
assert.equal(conditionalMovingLiteral.length, 434, 'moving conditional literal fixture count');
for (const [j, c] of conditionalMovingLiteral.entries()) await verifyCase(c, `moving conditional literal ${j}`);
const conditionalTypedReference = JSON.parse(await readFile(new URL('./conditional-typed-reference.json', import.meta.url)));
assert.equal(conditionalTypedReference.length, 233, 'typed conditional reference fixture count');
for (const [j, c] of conditionalTypedReference.entries()) await verifyCase(c, `typed conditional reference ${j}`);
const conditionalInvalidReference = JSON.parse(await readFile(new URL('./conditional-invalid-reference.json', import.meta.url)));
assert.equal(conditionalInvalidReference.length, 241, 'invalid conditional reference fixture count');
for (const [j, c] of conditionalInvalidReference.entries()) await verifyCase(c, `invalid conditional reference ${j}`);
const unsupportedConditionalInvalidReference = JSON.parse(await readFile(new URL('./conditional-invalid-reference-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalInvalidReference.length, 8, 'unsupported invalid conditional reference fixture count');
for (const encoded of unsupportedConditionalInvalidReference) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional reference must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalTypedReference = JSON.parse(await readFile(new URL('./conditional-typed-reference-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalTypedReference.length, 8, 'unsupported typed conditional reference fixture count');
for (const encoded of unsupportedConditionalTypedReference) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported typed conditional reference must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalMovingLiteral = JSON.parse(await readFile(new URL('./conditional-moving-literal-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalMovingLiteral.length, 8, 'unsupported moving conditional literal fixture count');
for (const encoded of unsupportedConditionalMovingLiteral) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported moving conditional literal must be rejected');
  assert.match(xlsx_render_error(input, 'none', true), /conditional formatting/);
}
const unsupportedConditionalLiteral = JSON.parse(await readFile(new URL('./conditional-literal-unsupported.json', import.meta.url)));
assert.equal(unsupportedConditionalLiteral.length, 9, 'unsupported conditional literal fixture count');
for (const encoded of unsupportedConditionalLiteral) {
  const input = Buffer.from(encoded, 'base64');
  assert.equal(xlsx_render_basic(input, 'none', true).length, 0, 'unsupported conditional literal must be rejected');
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
console.log(`${i} basic XLSX renderings, ${ignoredSheetFeatures.length + ignoredSheetExtensions.length} ignored sheet feature cases, ${sheetAutoFilter.length + sheetAutoFilterTiles.length} autofilters, ${sheetNotes.length + sheetNotesFilter.length} notes, ${sheetMissingParts.length} missing part cases, ${baseFills.length} base fills, ${baseBorders.length} base borders, ${plainRuns.length + multiplePlainRuns.length + richRunLegacy.length + richRunData.length + richRunWrap.length + richRunIdentity.length + singleStyledRun.length + singleStyledRunConditional.length + singleStyledRunVariants.length + singleStyledRunLegacy.length} plain runs, ${links.length + percentLinks.length} links, and ${inactiveCF.length + activeCF.length + conditionalFill.length + conditionalBorder.length + conditionalOps.length + conditionalBetween.length + conditionalEquals.length + conditionalLiteral.length + conditionalMovingLiteral.length + conditionalTypedReference.length + conditionalInvalidReference.length + conditionalAbsolute.length + conditionalSingleRef.length + conditionalAxisRef.length + conditionalMovingRef.length + conditionalNegativeRef.length + conditionalNegativeBlank.length + conditionalNegativeString.length + conditionalPredicates.length + conditionalText.length + conditionalTop.length + conditionalAverage.length + conditionalStdDev.length + conditionalLargeStdDev.length + conditionalOverflowMean.length + conditionalNonfiniteAverage.length + conditionalDisjoint.length + conditionalDisjointMoving.length + conditionalSameStyle.length + conditionalIdenticalBlocks.length + conditionalSameRuleStyle.length + conditionalDisjointMatches.length + conditionalDuplicate.length + conditionalBlank.length + conditionalPaintBlank.length} conditional formats match upstream.`);
