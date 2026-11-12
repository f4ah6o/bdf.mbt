// Diagnostic only: a multiset check describes note changes; it does not
// establish rendering equivalence or change the ordered migration gate.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { isDeepStrictEqual, parseArgs } from 'node:util';
import path from 'node:path';
import { BdfDocument, BufferSource, decodeObject, walk } from '@bdfkit/core';
import { loadFixture } from '../fixtures.mjs';

const { values } = parseArgs({ options: { generated: { type: 'string' }, comparison: { type: 'string' } } });
if (!values.generated || !values.comparison) throw Error('--generated <fixture-root> --comparison <strict-report> required');
const report = JSON.parse(await readFile(values.comparison));
const names = ['sheet-multiple-notes-filter.json', 'sheet-multiple-notes-legacy.json', 'sheet-multiple-notes.json'];
if (report.version !== 1 || !isDeepStrictEqual(report.differences.map(d => d.file).sort(), names)) throw Error('Unexpected differences; investigate the complete strict report');

function sequence(object) {
  let fill = 0;
  const operations = [], notes = [];
  const sink = new Proxy({}, { get(_target, prop) { return (...input) => {
    const args = input.map(x => ArrayBuffer.isView(x) ? Array.from(x) : x);
    if (prop === 'fillColor') { fill = args[0]; if (fill === 0xe02020ff) return; }
    if (prop === 'fillPath' && fill === 0xe02020ff) {
      const note = object.paths[args[0]].inline;
      assert.ok(note, 'note path must be inline');
      notes.push(JSON.stringify([Array.from(note.verbs), Array.from(note.args), args[1]]));
      return;
    }
    if (['fillPath', 'strokePath', 'clipPath', 'fillPathAt'].includes(prop)) {
      const item = object.paths[args[0]].inline;
      if (item) args[0] = [Array.from(item.verbs), Array.from(item.args)];
    }
    operations.push([prop, args]);
  }; } });
  walk(object, sink);
  return { other: { bbox: object.bbox, strings: object.strings, fonts: object.fonts, paints: object.paints, images: object.images, objects: object.objects, operations }, notes };
}
const frequencies = entries => entries.reduce((m, item) => m.set(item, (m.get(item) ?? 0) + 1), new Map());
const results = [];
for (const difference of report.differences) {
  const before = await loadFixture('./' + difference.file);
  const after = JSON.parse(await readFile(path.join(values.generated, 'compat/xlsx', difference.file)));
  assert.equal(before.length, after.length);
  const actualChanges = before.flatMap((entry, index) => isDeepStrictEqual(entry, after[index]) ? [] : [index]);
  assert.deepEqual(actualChanges, difference.changes.map(c => c.index), 'report must describe these actual files');
  let reordered = 0, otherDifferences = 0, noteFrequencyDifferences = 0;
  for (const change of difference.changes) {
    assert.deepEqual(change.keys, ['bdf']);
    const index = change.index;
    const { bdf: oldBdf, ...oldInput } = before[index], { bdf: newBdf, ...newInput } = after[index];
    assert.deepEqual(oldInput, newInput);
    const old = await BdfDocument.open(new BufferSource(Buffer.from(oldBdf, 'base64')));
    const fresh = await BdfDocument.open(new BufferSource(Buffer.from(newBdf, 'base64')));
    assert.deepEqual(old.manifest.meta, fresh.manifest.meta);
    assert.deepEqual(old.manifest.tables ?? [], fresh.manifest.tables ?? []);
    assert.equal(old.manifest.views.length, fresh.manifest.views.length);
    let caseReordered = false;
    for (let i = 0; i < old.manifest.views.length; i++) {
      const { tiles: oldTiles, ...oldView } = old.manifest.views[i], { tiles: newTiles, ...newView } = fresh.manifest.views[i];
      assert.deepEqual(oldView, newView);
      assert.deepEqual(Object.keys(oldTiles).sort(), Object.keys(newTiles).sort());
      for (const key of Object.keys(oldTiles)) {
        const a = sequence(decodeObject(await old.part(oldTiles[key]))), b = sequence(decodeObject(await fresh.part(newTiles[key])));
        if (!isDeepStrictEqual(a.other, b.other)) otherDifferences++;
        if (!isDeepStrictEqual(frequencies(a.notes), frequencies(b.notes))) noteFrequencyDifferences++;
        if (!isDeepStrictEqual(a.notes, b.notes)) caseReordered = true;
      }
    }
    if (caseReordered) reordered++;
  }
  results.push({ file: difference.file, differingCases: difference.changes.length, casesWithNoteOrderChange: reordered, otherObjectDifferences: otherDifferences, noteFrequencyDifferences });
}
console.log(JSON.stringify({ diagnosticOnly: true, renderingEquivalenceEstablished: false, results }, null, 2));
