import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { music_text_fonts } from '../../_build/js/debug/build/compat/musicnotation/musicnotation.js';
const cases = JSON.parse(await readFile(new URL('./text_fonts.json', import.meta.url)));
const fonts = new Map([['', Buffer.alloc(0)]]);
for (const file of new Set(cases.map(c => c.file))) if (file) fonts.set(file, await readFile(new URL(`../font/fixtures/${file}`, import.meta.url)));
for (const [i, c] of cases.entries()) assert.deepEqual(JSON.parse(music_text_fonts(c.file, fonts.get(c.file), c.flags)), c.want, `case ${i}`);
console.log(`${cases.length} music font embedding and font records match upstream.`);
