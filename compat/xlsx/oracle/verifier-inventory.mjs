// A missing or changed verifier cannot silently reduce coverage.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { lock, sha } from './contract.mjs';
const manifestBytes = await readFile(new URL('./verifiers.manifest', import.meta.url));
export const verifierManifestSha = sha(manifestBytes);
const manifest = JSON.parse(manifestBytes);
if (manifest.version !== 1 || manifest.baseline !== lock.baseline || !Array.isArray(manifest.verifiers) || !Array.isArray(manifest.checks)) throw Error('Invalid verifier inventory');
export function compareVerifierNames(expected, actual) {
  assert.deepEqual([...actual].sort(), [...expected].sort(), 'verifier inventory');
}
export async function validateVerifiers(root = fileURLToPath(new URL('../../../', import.meta.url))) {
  const actual = [];
  for (const dir of ['compat/ooxml', 'compat/xlsx']) {
    for (const name of (await readdir(path.join(root, dir))).filter(x => /^verify-.+\.mjs$/.test(x) && x !== 'verify-all.mjs')) actual.push(`${dir}/${name}`);
  }
  compareVerifierNames(manifest.verifiers, actual);
  assert.deepEqual(Object.keys(manifest.hashes).sort(), [...manifest.verifiers, ...manifest.checks].sort());
  for (const [name, digest] of Object.entries(manifest.hashes)) {
    if (!/^compat\/(xlsx|ooxml)\/[\w/-]+\.mjs$/.test(name) || name.split('/').includes('..')) throw Error(`Invalid verifier path: ${name}`);
    assert.equal(sha(await readFile(path.join(root, name))), digest, `verifier changed: ${name}`);
  }
  return { verifiers: actual.length, checks: manifest.checks.length };
}
