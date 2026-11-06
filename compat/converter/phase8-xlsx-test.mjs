import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import { BdfDocument, BufferSource, decodeTextIndex } from '@bdfkit/core';
import { xlsx_with_font } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';

const root = resolve(import.meta.dirname, '../..');
const data = new Uint8Array(await readFile(resolve(root, 'demo/samples/basic.xlsx')));
const font = new Uint8Array(await readFile(resolve(root, 'demo/samples/stix.ttf')));
const out = JSON.parse(xlsx_with_font(data, font));
assert.equal(out.error, undefined, out.error);
assert.ok(out.warnings.every(w => w.includes('no calculated value')), 'XLSX font conversion warnings: ' + JSON.stringify(out.warnings));
const doc = await BdfDocument.open(new BufferSource(Buffer.from(out.bdf, 'base64')));
const fonts = doc.manifest.parts.filter(part => part.t === 'font');
assert.ok(fonts.length > 0, 'XLSX embeds a font part');
const view = doc.manifest.views[0];
const text = view.textIndex ? decodeTextIndex(await doc.part(view.textIndex)).map(run => run.text).join('\n') : '';
assert.ok(text.length > 0, 'XLSX font conversion has text');
console.log(`Phase 8 XLSX: ${fonts.length} font part(s) embedded, ${view.tiles?.length ?? 0} sheet tile(s).`);
