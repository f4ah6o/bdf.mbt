// Diagnostic inventory only: this does not permit extra files in the migration gate.
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { isDeepStrictEqual } from 'node:util';

const emptyHash = '4f53cda18c2baa0c0354bb5f9a3ecbe5ed12ab4d8e11ba873c2f11161202b945';
const inventory = [
  ['percent-links-unsupported.json', 'input-array', 3, '0196a3dc5fb961f390c85371d40285fcef2043bef31225fde0b5aa4c6ab49c66'],
  ...['rich-run-data', 'rich-run-wrap', 'sheet-multiple-notes-filter', 'sheet-multiple-notes', 'sheet-notes-filter'].map(name => [`${name}-unsupported.json`, 'input-array', 0, emptyHash]),
];

export function auditSideproducts(extra, outputs, expected = inventory) {
  if (!Array.isArray(extra) || !isDeepStrictEqual([...extra].sort(), expected.map(x => x[0]).sort())) {
    throw Error('Sideproduct inventory changed; investigate the strict comparison report');
  }
  return expected.map(([file, kind, count, expectedHash]) => {
    const data = outputs.get(file);
    const valid = kind === 'single-input' ? typeof data === 'string' && data.length > 0
      : Array.isArray(data) && data.length === count && data.every(x => typeof x === 'string' && x.length > 0);
    const hash = createHash('sha256').update(JSON.stringify(data) ?? '').digest('hex');
    if (!valid || hash !== expectedHash) throw Error(`Sideproduct content changed: ${file}`);
    return { file, kind, inputs: count, sha256: hash };
  });
}

async function main() {
  const { values } = parseArgs({ options: { generated: { type: 'string' }, comparison: { type: 'string' } } });
  if (!values.generated || !values.comparison) throw Error('--generated <fixture-root> --comparison <strict-report> required');
  const comparison = JSON.parse(await readFile(values.comparison, 'utf8'));
  if (comparison.version !== 1) throw Error('Expected version 1 strict comparison report');
  const outputs = new Map();
  // Read only the known names; the report inventory must also match exactly.
  for (const [file] of inventory) outputs.set(file, JSON.parse(await readFile(path.join(values.generated, 'compat/xlsx', file), 'utf8')));
  const files = auditSideproducts(comparison.extra, outputs);
  console.log(JSON.stringify({ diagnosticOnly: true, strictGateUnchanged: true, files }, null, 2));
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) await main();
