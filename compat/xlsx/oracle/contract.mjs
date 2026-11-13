// Pinned data contract shared by the generator and the runtime fixture loader.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { gunzipSync } from 'node:zlib';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { BdfDocument, BufferSource } from '@bdfkit/core';
import { strictSha } from './strict-hash.mjs';

export const fixtureRoot = fileURLToPath(new URL('../', import.meta.url));
export const sha = data => createHash('sha256').update(data).digest('hex');
export const valueSha = value => sha(JSON.stringify(value));
export const lockBytes = await readFile(new URL('./lock.manifest', import.meta.url));
export const lock = JSON.parse(lockBytes);
if (lock.version !== 1 || lock.baseline !== 'ab0b102ced2ef6e43bdb00590daff83d0f316986' || lock.build?.binarySha256 !== '6425c89b0af6753bfc03735695f655e7d4d11c7fcaab33b325049fe2b6fc7035') throw Error('Invalid pinned XLSX oracle lock');
const notes = ['sheet-multiple-notes-filter.json', 'sheet-multiple-notes-legacy.json', 'sheet-multiple-notes.json'];
const extras = ['percent-links-unsupported.json', 'rich-run-data-unsupported.json', 'rich-run-wrap-unsupported.json', 'sheet-multiple-notes-filter-unsupported.json', 'sheet-multiple-notes-unsupported.json', 'sheet-notes-filter-unsupported.json'];
assert.equal(Object.keys(lock.fixtures).length, 804); assert.equal(Object.keys(lock.seedHashes).length, 44);
assert.equal(lock.retained.length, 26); assert.equal(Object.keys(lock.noteCases).length, 264);
assert.deepEqual(Object.keys(lock.extras).sort(), extras);
assert.equal(lock.tests.length, 724);
export const noteNames = new Set(notes);
export const lockSha = sha(lockBytes);
export const strictLockBytes = await readFile(new URL('./strict-lock.manifest', import.meta.url));
export const strictLock = JSON.parse(strictLockBytes);
export const strictLockSha = sha(strictLockBytes);
assert.equal(strictLock.version, 1); assert.equal(strictLock.baseline, lock.baseline);
for (const key of ['fixtures', 'extras', 'noteCases']) assert.deepEqual(Object.keys(strictLock[key]).sort(), Object.keys(lock[key]).sort(), `strict ${key} inventory`);

async function bundle(name, expected) {
  const raw = await readFile(new URL(`./${name}.data`, import.meta.url));
  if (sha(raw) !== expected) throw Error(`XLSX ${name} bundle integrity failure`);
  return JSON.parse(gunzipSync(raw));
}
let inputsPromise, notesPromise;
export async function readInputs() {
  return inputsPromise ??= (async () => {
    const input = await bundle('inputs', lock.inputBundleSha256);
    const names = [...new Set([...Object.keys(lock.seedHashes), ...lock.retained.map(x => x.file)])].sort();
    assert.deepEqual(Object.keys(input).sort(), names, 'input bundle inventory');
    assert.deepEqual(Object.keys(strictLock.inputs).sort(), names, 'strict input inventory');
    for (const name of names) assert.equal(strictSha(input[name]), strictLock.inputs[name], `strict input ${name}`);
    for (const [name, hash] of Object.entries(lock.seedHashes)) assert.equal(valueSha(input[name]), hash, `input seed ${name}`);
    for (const entry of lock.retained) assert.equal(valueSha(input[entry.file]), entry.sha256, `retained input ${entry.file}`);
    return input;
  })();
}
export async function readNotes() {
  return notesPromise ??= (async () => {
    const data = await bundle('notes', lock.noteBundleSha256);
    assert.deepEqual(Object.keys(data).sort(), notes, 'static notes inventory');
    let count = 0;
    for (const file of notes) {
      const cases = data[file];
      assert.ok(Array.isArray(cases)); assert.equal(cases.length, lock.fixtures[file].count);
      assert.equal(valueSha(cases), lock.fixtures[file].sha256, `static notes ${file}`);
      assert.equal(strictSha(cases), strictLock.fixtures[file], `strict static notes ${file}`);
      for (const [i, entry] of cases.entries()) {
        assert.equal(valueSha(entry), lock.noteCases[`${file}#${i}`], `static note ID ${file}#${i}`);
        assert.equal(strictSha(entry), strictLock.noteCases[`${file}#${i}`], `strict static note ID ${file}#${i}`); count++;
      }
    }
    assert.equal(count, 264); return data;
  })();
}
export function fixtureName(target) {
  const url = target instanceof URL ? target : typeof target === 'string' && target.startsWith('.') ? new URL(target, new URL('../', import.meta.url)) : null;
  if (!url || url.protocol !== 'file:') throw Error('Invalid XLSX fixture path');
  const rel = path.relative(fixtureRoot, fileURLToPath(url));
  if (!rel || rel.startsWith('..' + path.sep) || path.isAbsolute(rel) || !Object.hasOwn(lock.fixtures, rel)) throw Error(`Unknown XLSX fixture: ${rel}`);
  return rel;
}

export async function validateRawNotes(name, raw, notes) {
  if (!noteNames.has(name)) throw Error(`Not a notes fixture: ${name}`);
  const original = notes[name]; assert.ok(Array.isArray(raw)); assert.equal(raw.length, original.length);
  for (const [i, entry] of original.entries()) {
    const { bdf: a, ...before } = entry, { bdf: b, ...after } = raw[i];
    assert.equal(typeof a, 'string'); assert.equal(typeof b, 'string');
    assert.deepEqual(before, after, `${name} input/options ${i}`);
    const bytes = Buffer.from(b, 'base64');
    if (!b || bytes.toString('base64') !== b) throw Error(`Invalid notes BDF base64: ${name}#${i}`);
    const doc = await BdfDocument.open(new BufferSource(bytes));
    for (const part of doc.manifest.parts) {
      const contents = await doc.part(part.h);
      assert.equal(sha(contents).slice(0, 32), part.h, `notes BDF part hash ${name}#${i}`);
    }
  }
}
