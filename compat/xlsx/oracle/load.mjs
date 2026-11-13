// A selected run never falls back to the checkout when an output is missing.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { strictSha } from './strict-hash.mjs';
import { fixtureName, lock, lockSha, strictLock, strictLockSha, noteNames, readNotes, sha, valueSha, validateRawNotes } from './contract.mjs';

let receiptPromise;
async function receipt() {
  return receiptPromise ??= (async () => {
    const root = process.env.BDF_XLSX_FIXTURE_ROOT, runId = process.env.BDF_XLSX_RUN_ID, receiptSha = process.env.BDF_XLSX_RECEIPT_SHA;
    if (!root || !path.isAbsolute(root) || !runId || !/^[a-f0-9]{64}$/.test(receiptSha ?? '')) throw Error('XLSX run root, run ID and receipt SHA required');
    const bytes = await readFile(path.join(root, 'receipt.json'));
    assert.equal(sha(bytes), receiptSha, 'XLSX receipt integrity');
    const value = JSON.parse(bytes);
    assert.equal(value.version, 1); assert.equal(value.lockSha, lockSha); assert.equal(value.strictLockSha, strictLockSha); assert.equal(value.runId, runId);
    assert.equal(value.binarySha256, lock.build.binarySha256);
    assert.deepEqual(Object.keys(value.files).sort(), [...Object.keys(lock.fixtures), ...Object.keys(lock.extras)].sort());
    return { root, value };
  })();
}
export async function loadRunFixture(target) {
  const name = fixtureName(target), { root, value: run } = await receipt();
  const bytes = await readFile(path.join(root, 'compat/xlsx', name));
  assert.equal(sha(bytes), run.files[name], `XLSX run output integrity ${name}`);
  // Even though notes use the fixed static expectations, their raw generated
  // counterparts must still exist and retain the bytes validated at generation.
  if (noteNames.has(name)) {
    const notes = await readNotes();
    await validateRawNotes(name, JSON.parse(bytes), notes);
    return structuredClone(notes[name]);
  }
  const parsed = JSON.parse(bytes);
  assert.equal(valueSha(parsed), lock.fixtures[name].sha256, `XLSX generated fixture ${name}`);
  assert.equal(strictSha(parsed), strictLock.fixtures[name], `XLSX strict fixture ${name}`);
  return parsed;
}
