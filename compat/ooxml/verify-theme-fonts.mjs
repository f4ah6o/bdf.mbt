import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { ooxml_theme_fonts } from '../../_build/js/debug/build/compat/ooxml/ooxml.js';
const cases = JSON.parse(await readFile(new URL('./theme-fonts.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(ooxml_theme_fonts(Buffer.from(c.input, 'base64'))), c.want, `theme fonts case ${i}`);
console.log(`${cases.length} OOXML theme font schemes match upstream.`);
