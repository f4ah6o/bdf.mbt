import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { xlsx_store_sheet, xlsx_store_sheet_summary } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./store-sheet.json', import.meta.url)));
for (const [i, c] of cases.entries()) {
  const args = [Buffer.from(c.input, 'base64'), c.part, c.locale, c.mode];
  assert.deepEqual(JSON.parse(xlsx_store_sheet_summary(...args)), [c.counter, c.warnings], `sheet table warnings case ${i}`);
  const doc = await BdfDocument.open(new BufferSource(xlsx_store_sheet(...args)));
  assert.deepEqual(doc.manifest.tables ?? [], c.tables, `sheet table manifest case ${i}`);
}
console.log(`${cases.length} XLSX sheet table collections match upstream.`);
