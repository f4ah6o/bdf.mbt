import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { xlsx_builtin } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
const cases = JSON.parse(await readFile(new URL('./builtin.json', import.meta.url)));
for (const c of cases) assert.equal(xlsx_builtin(c.id, c.locale), c.want, `format ${c.id}, locale ${c.locale}`);
console.log(`${cases.length} XLSX built-in number formats match upstream.`);
