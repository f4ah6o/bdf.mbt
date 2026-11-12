import assert from 'node:assert/strict';
import { xlsx_builtin } from '../../_build/js/debug/build/compat/xlsx/xlsx.js';
import { loadFixture } from './fixtures.mjs';
const cases = await loadFixture('./builtin.json');
for (const c of cases) assert.equal(xlsx_builtin(c.id, c.locale), c.want, `format ${c.id}, locale ${c.locale}`);
console.log(`${cases.length} XLSX built-in number formats match upstream.`);
