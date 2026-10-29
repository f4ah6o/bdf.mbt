import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { mml_decode } from '../../_build/js/debug/build/compat/mml/mml.js';
const cases = JSON.parse(await readFile(new URL('./decode.json', import.meta.url)));
for (const [i, c] of cases.entries()) assert.equal(mml_decode(Buffer.from(c.input, 'base64')), c.want, `case ${i}`);
console.log(`${cases.length} MML decoding cases match upstream.`);
