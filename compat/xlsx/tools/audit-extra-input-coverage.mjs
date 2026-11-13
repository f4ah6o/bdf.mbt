// Read-only exact input-byte search. This does not claim behavioral coverage.
import { readdir, readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { loadFixture } from '../fixtures.mjs';

const { values } = parseArgs({ options: { generated: { type: 'string' } } });
if (!values.generated) throw Error('--generated <fixture-root> required');
const output = path.join(values.generated, 'compat/xlsx');
const single = JSON.parse(await readFile(path.join(output, 'base-border-tint-too-large.json')));
const links = JSON.parse(await readFile(path.join(output, 'percent-links-unsupported.json')));
if (typeof single !== 'string' || !Array.isArray(links) || links.length !== 3 || links.some(x => typeof x !== 'string')) throw Error('Unexpected sideproduct shape');
const cases = [single, ...links].map((encoded, i) => ({
  id: i === 0 ? 'base-border-tint-too-large.json#0' : `percent-links-unsupported.json#${i - 1}`,
  bytes: Buffer.from(encoded, 'base64'), matches: [],
}));
for (const c of cases) c.sha256 = createHash('sha256').update(c.bytes).digest('hex');
const root = fileURLToPath(new URL('../', import.meta.url));
const files = (await readdir(root, { recursive: true })).filter(f => f.endsWith('.json') && !f.startsWith('store/')).sort();
function visit(value, file, location) {
  if (typeof value === 'string') {
    for (const c of cases) {
      // Base64 input lengths are small; only decode plausible matches.
      if (Math.abs(value.length - 4 * Math.ceil(c.bytes.length / 3)) <= 2 && /^[A-Za-z0-9+/]*={0,2}$/.test(value) && Buffer.from(value, 'base64').equals(c.bytes)) c.matches.push({ file, location });
    }
  } else if (Array.isArray(value)) {
    value.forEach((entry, index) => visit(entry, file, `${location}[${index}]`));
  } else if (value && typeof value === 'object') {
    for (const [key, entry] of Object.entries(value)) visit(entry, file, `${location}.${key}`);
  }
}
for (const file of files) visit(await loadFixture('./' + file), file, '$');
console.log(JSON.stringify({ diagnosticOnly: true, exactInputMatchesOnly: true, filesSearched: files.length, cases: cases.map(({ id, sha256, bytes, matches }) => ({ id, sha256, byteLength: bytes.length, matches })) }, null, 2));
