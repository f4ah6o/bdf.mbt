// Report raw BDF differences without reordering, normalizing, or classifying
// them as equivalent. Static expected notes are selected independently.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { noteNames, readNotes, sha } from './contract.mjs';

export function noteDifferences(original, raw) {
  const differences = [];
  let compared = 0;
  for (const file of noteNames) {
    assert.equal(raw[file].length, original[file].length);
    for (const [index, entry] of original[file].entries()) {
      const actual = raw[file][index]; compared++;
      if (entry.bdf !== actual.bdf) differences.push({
        id: `${file}#${index}`,
        staticBdfSha256: sha(Buffer.from(entry.bdf, 'base64')),
        rawBdfSha256: sha(Buffer.from(actual.bdf, 'base64')),
      });
    }
  }
  assert.equal(compared, 264);
  return { compared, differences };
}
export async function readNoteDifferences(output) {
  const raw = {};
  for (const file of noteNames) raw[file] = JSON.parse(await readFile(path.join(output, 'compat/xlsx', file)));
  return noteDifferences(await readNotes(), raw);
}
