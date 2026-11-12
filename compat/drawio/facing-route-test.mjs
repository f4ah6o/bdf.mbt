// Real worker XML -> BDF regression, read using the independent upstream codec.
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { BdfDocument, BufferSource, decodeObject, NoopSink, walk } from '@bdfkit/core';
const root = resolve(import.meta.dirname, '../..');
const dir = mkdtempSync(join(tmpdir(), 'bdf-facing-route-'));
const near = (a, b) => assert.ok(Math.abs(a-b) < 0.0001, `${a} != ${b}`);
try {
  // Public AWS fixture: verify all four Current-page connections.
  // Set explicit rounded=0 to isolate route vertices; the rounded connector
  // test separately exercises the unchanged public fixture default.
  const xml = readFileSync(join(root, 'site/samples/aws.drawio'), 'utf8')
    .replaceAll('edgeStyle=orthogonalEdgeStyle;', 'edgeStyle=orthogonalEdgeStyle;rounded=0;');
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
  const expected = [
    [50,102.5,87.5,102.5,87.5,110,123.323,110],
    [170,110,228.323,110],
    [275,110,305,110,305,72.5,333.323,72.5],
    [275,110,305,110,305,140,333.323,140],
  ];
  for (let i=0;i<4;i++) {
    const line=strokes[i*2].path, marker=strokes[i*2+1].path;
    assert.equal(line.args.length,expected[i].length);
    [...line.args].forEach((v,k)=>near(v,expected[i][k]));
    assert.deepEqual([...marker.verbs],[0,1,1]);
    assert.equal(marker.args.length,6);
    // All four terminal segments now approach from the left; marker notch
    // lies to the right of both wings and on the terminal segment's y.
    assert.ok(marker.args[2]>marker.args[0] && marker.args[2]>marker.args[4]);
    near(marker.args[3],line.args[line.args.length-1]);
  }
  // e3 and e4 leave Lambda on the same centreline and share the initial trunk.
  assert.deepEqual([...strokes[4].path.args].slice(0,4), [...strokes[6].path.args].slice(0,4));
  console.log('AWS Current four facing routes: waypoints, common trunk and rightward markers passed');

} finally { rmSync(dir, {recursive:true, force:true}); }
