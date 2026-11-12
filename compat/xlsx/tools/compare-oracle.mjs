// Migration-only gate. No tolerance, sorting, normalization or rebaseline.
import { readdir, readFile, writeFile } from 'node:fs/promises';
import { isDeepStrictEqual, parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { loadFixture } from '../fixtures.mjs';
const { values } = parseArgs({ options: { generated: { type: 'string' }, report: { type: 'string' } } });
if (!values.generated || !values.report) throw new Error('--generated <fixture-root> --report <file> required');
const root = fileURLToPath(new URL('../', import.meta.url));
const generated = path.resolve(values.generated, 'compat/xlsx');
const files = (await readdir(root, { recursive: true })).filter(f => f.endsWith('.json') && !f.startsWith('store/')).sort();
const output = { version: 1, compared: 0, equal: [], missing: [], differences: [], failures: [], extra: [] };
const generatedFiles = (await readdir(generated, { recursive: true })).filter(f => f.endsWith('.json')).sort();
output.extra = generatedFiles.filter(file => !files.includes(file));
const digest = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
for (const file of files) {
  try {
    let fresh;
    try { fresh = JSON.parse(await readFile(path.join(generated, file), 'utf8')); }
    catch (error) { if (error.code === 'ENOENT') { output.missing.push(file); continue; } throw error; }
    const previous = await loadFixture(`./${file}`);
    output.compared++;
    if (isDeepStrictEqual(previous, fresh)) { output.equal.push(file); continue; }
    const changes = [];
    if (Array.isArray(previous) && Array.isArray(fresh)) {
      for (let i = 0; i < Math.max(previous.length, fresh.length); i++) {
        if (isDeepStrictEqual(previous[i], fresh[i])) continue;
        const before = previous[i], after = fresh[i];
        const keys = before && after && typeof before === 'object' && typeof after === 'object'
          ? Object.keys({ ...before, ...after }).filter(key => !isDeepStrictEqual(before[key], after[key])) : [];
        changes.push({ index: i, keys });
      }
    }
    output.differences.push({ file, previousHash: digest(previous), generatedHash: digest(fresh),
      previousCount: Array.isArray(previous) ? previous.length : null,
      generatedCount: Array.isArray(fresh) ? fresh.length : null, changes });
  } catch (error) { output.failures.push({ file, error: error.message }); }
}
await writeFile(values.report, JSON.stringify(output, null, 2) + '\n');
console.log(JSON.stringify({ compared: output.compared, equal: output.equal.length,
  missing: output.missing.length, extra: output.extra.length, different: output.differences.length, failures: output.failures.length }));
if (output.extra.length || output.missing.length || output.differences.length || output.failures.length) process.exitCode = 1;
