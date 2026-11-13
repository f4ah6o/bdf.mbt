// Real worker XML -> BDF regression, read using the independent upstream codec.
// Checks the Legacy page block arrows against the official draw.io v32.7.1
// capture in /tmp/bdf-official-compare/legacy-edges.json: default endSize 6,
// strokeWidth 1, applied through the page transform page = 0.75*src - 10/-12.
import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { resolve, join } from 'node:path';
import { execFileSync } from 'node:child_process';
import { BdfDocument, BufferSource, decodeObject, NoopSink, walk } from '@bdfkit/core';

const root = resolve(import.meta.dirname, '../..');
const dir = mkdtempSync(join(tmpdir(), 'bdf-block-marker-'));
// Official legacy-edges.json prints source units to 2 decimals, so page
// values carry up to 0.00375 of rounding plus f32 storage error.
const near = (a, b) => assert.ok(Math.abs(a - b) < 0.005, `${a} != ${b}`);
const x = src => src * 0.75 - 10;
const y = src => src * 0.75 - 12;
try {
  // Public AWS fixture, unmodified: the Legacy page has 11 endArrow=block
  // edges with endFill=1 and no explicit endSize (upstream default 6).
  const input = join(root, 'site/samples/aws.drawio');
  const output = join(dir, 'aws.bdf');
  execFileSync(process.execPath, [join(root, 'compat/drawio/oracle-worker.mjs')], {
    env: {...process.env, INPUT: input, OUTPUT: output,
      WORKER_TARGET: join(root, '_build/js/debug/build/native_converter_worker/native_converter_worker.js')},
    timeout: 65000,
  });
  const doc = await BdfDocument.open(new BufferSource(readFileSync(output)));
  // page 0 is "Current icons"; the Legacy AWS17 page is its own view.
  assert.equal(doc.manifest.views.length, 2);
  const object = decodeObject(
    await doc.part(doc.manifest.views[1].pages[0].layers[0].obj));

  class Strokes extends NoopSink {
    width = 0; strokes = []; fills = [];
    line(width) { this.width = width; }
    beginPath() {}
    strokePath(index) { this.strokes.push({width: this.width, path: object.paths[index].inline}); }
    fillPath(index) { this.fills.push(object.paths[index].inline); }
  }
  const sink = new Strokes();
  walk(object, sink);

  const firstPoint = p => [p.args[0], p.args[1]];
  const byStart = list => (px, py) => list.find(
    s => Math.abs(s.path.args[0] - px) < 0.005 && Math.abs(s.path.args[1] - py) < 0.005);

  // A block marker stroke is one closed three-point triangle at the edge pen
  // width, and every one is also filled (upstream fillAndStroke).
  const markerStrokes = sink.strokes.filter(s =>
    [...s.path.verbs].length === 4 && s.path.verbs[3] === 4 && s.width === 1);
  assert.equal(markerStrokes.length, 11);
  for (const stroke of markerStrokes) {
    const [mx, my] = firstPoint(stroke.path);
    assert.ok(sink.fills.some(f =>
      Math.abs(f.args[0] - mx) < 0.0001 && Math.abs(f.args[1] - my) < 0.0001),
      `marker at ${mx},${my} must also be filled (endFill=1)`);
  }

  // Official legacy edge "M 86 331.5 L 178.88 331.5" with marker
  // "M 185.88 331.5 L 178.88 335 L 178.88 328 Z".
  const line = byStart(sink.strokes)(x(86), y(331.5));
  const marker = byStart(sink.strokes)(x(185.88), y(331.5));
  assert.ok(line && marker, 'horizontal block line and marker found');
  assert.deepEqual([...line.path.verbs], [0, 1]);
  assert.deepEqual([...marker.path.verbs], [0, 1, 1, 4]);
  near(line.path.args[2], x(178.88)); near(line.path.args[3], y(331.5));
  near(marker.path.args[2], x(178.88)); near(marker.path.args[3], y(335));
  near(marker.path.args[4], x(178.88)); near(marker.path.args[5], y(328));
  near(line.width, 1); near(marker.width, 1);
  assert.ok(sink.fills.some(f => Math.abs(f.args[2] - x(178.88)) < 0.005
      && Math.abs(f.args[3] - y(335)) < 0.005), 'block marker fill stroked');

  // Official vertical legacy edge "M 225.25 378 L 225.25 471.88" with
  // marker "M 225.25 478.88 L 221.75 471.88 L 228.75 471.88 Z".
  const vline = byStart(sink.strokes)(x(225.25), y(378));
  const vmarker = byStart(sink.strokes)(x(225.25), y(478.88));
  assert.ok(vline && vmarker, 'vertical block line and marker found');
  near(vline.path.args[2], x(225.25)); near(vline.path.args[3], y(471.88));
  near(vmarker.path.args[2], x(221.75)); near(vmarker.path.args[3], y(471.88));
  near(vmarker.path.args[4], x(228.75)); near(vmarker.path.args[5], y(471.88));

  // Official dashed replication edge "M 564.5 523 L 746.88 523" with
  // marker "M 753.88 523 L 746.88 526.5 L 746.88 519.5 Z".
  const dline = byStart(sink.strokes)(x(564.5), y(523));
  const dmarker = byStart(sink.strokes)(x(753.88), y(523));
  assert.ok(dline && dmarker, 'dashed block line and marker found');
  near(dline.path.args[2], x(746.88)); near(dline.path.args[3], y(523));
  near(dmarker.path.args[2], x(746.88)); near(dmarker.path.args[3], y(526.5));
  near(dmarker.path.args[4], x(746.88)); near(dmarker.path.args[5], y(519.5));

  // Exercise classic notch, unfilled markers and a nondefault pen through
  // the real converter too, not just the standalone geometry helper.
  const variantInput = join(dir, 'classic.drawio');
  const variantOutput = join(dir, 'classic.bdf');
  writeFileSync(variantInput, readFileSync(input, 'utf8')
    .replaceAll('endArrow=block;endFill=1;',
      'endArrow=classic;endFill=0;strokeWidth=2;'));
  execFileSync(process.execPath, [join(root, 'compat/drawio/oracle-worker.mjs')], {
    env: {...process.env, INPUT:variantInput, OUTPUT:variantOutput,
      WORKER_TARGET:join(root,'_build/js/debug/build/native_converter_worker/native_converter_worker.js')},
    timeout:65000,
  });
  const variantDoc = await BdfDocument.open(new BufferSource(readFileSync(variantOutput)));
  const variant = decodeObject(await variantDoc.part(variantDoc.manifest.views[1].pages[0].layers[0].obj));
  class VariantSink extends NoopSink {
    width=0; strokes=[]; fills=[];
    line(width) { this.width=width; }
    strokePath(index) { this.strokes.push({width:this.width,path:variant.paths[index].inline}); }
    fillPath(index) { this.fills.push(variant.paths[index].inline); }
  }
  const v = new VariantSink(); walk(variant,v);
  const cm = byStart(v.strokes)(x(184.764),y(331.5));
  assert.ok(cm,'classic sw2 marker found');
  assert.deepEqual([...cm.path.verbs],[0,1,1,1,4]);
  assert.equal(cm.path.args.length,8); near(cm.width,2);
  near(cm.path.args[4],x(178.764)); near(cm.path.args[5],y(331.5));
  const cl = byStart(v.strokes)(x(86),y(331.5));
  assert.ok(cl,'classic line found'); near(cl.path.args[2],x(178.764));
  assert.ok(!v.fills.some(f=>Math.abs(f.args[0]-x(184.764))<0.005
    &&Math.abs(f.args[1]-y(331.5))<0.005),'endFill0 emits no marker fill');
  console.log('AWS Legacy block-marker integration: 11 block triangles, official '
    + 'apex/wing/shortened-line geometry, default size 6 and sw 1 passed');
} finally { rmSync(dir, {recursive: true, force: true}); }
