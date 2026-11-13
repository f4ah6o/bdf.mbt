// Real worker XML -> BDF regression, read using the independent upstream codec.
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { BdfDocument, BufferSource, decodeObject, NoopSink, walk } from '@bdfkit/core';
const root = resolve(import.meta.dirname, '../..');
const dir = mkdtempSync(join(tmpdir(), 'bdf-open-arrow-'));
const near = (a, b) => assert.ok(Math.abs(a-b) < 0.0001, `${a} != ${b}`);
try {
  // Public AWS fixture: Current e2 is the straight API Gateway -> Lambda edge.
  // Fix the style to strokeWidth2; its source geometry and label anchors stay unchanged.
  const xml = readFileSync(join(root, 'site/samples/aws.drawio'), 'utf8')
    .replaceAll('endSize=10;', 'endSize=10;strokeWidth=2;');
  const input = join(dir, 'aws.drawio'), output = join(dir, 'aws.bdf');
  writeFileSync(input, xml);
  execFileSync(process.execPath, [join(root, 'compat/drawio/oracle-worker.mjs')], {
    env: {...process.env, INPUT: input, OUTPUT: output,
      WORKER_TARGET: join(root, '_build/js/debug/build/native_converter_worker/native_converter_worker.js')},
    timeout: 65000,
  });
  const doc = await BdfDocument.open(new BufferSource(readFileSync(output)));
  const object = decodeObject(await doc.part(doc.manifest.views[0].pages[0].layers[0].obj));
  class Strokes extends NoopSink {
    width = 0; paths = [];
    line(width) { this.width = width; }
    strokePath(index) { this.paths.push({width:this.width, path:object.paths[index].inline}); }
  }
  const sink = new Strokes(); walk(object, sink);
  // Four edges contribute line+marker; earlier strokes are group outlines.
  const strokes = sink.paths.slice(-8);
  assert.equal(strokes.length, 8);
  const line = strokes[2], marker = strokes[3];
  assert.deepEqual([...line.path.verbs], [0,1]);
  assert.deepEqual([...marker.path.verbs], [0,1,1]);
  // Source->page transform is x*.75-10, y*.75-10 for this immutable fixture.
  assert.equal(line.path.args.length, 4);
  assert.equal(marker.path.args.length, 6);
  const expectedLine = [170,110,315.528*.75-10,110];
  const expectedMarker = [305.764*.75-10,166*.75-10,317.764*.75-10,110,305.764*.75-10,154*.75-10];
  [...line.path.args].forEach((n,i)=>near(n,expectedLine[i]));
  [...marker.path.args].forEach((n,i)=>near(n,expectedMarker[i]));
  // CAD path coordinates are scaled to pt; pen widths remain explicit source values.
  near(line.width, 2); near(marker.width, 2);
  console.log('AWS e2 open-arrow integration: shortened line, V geometry, strokeWidth2 passed');
} finally { rmSync(dir, {recursive:true, force:true}); }
