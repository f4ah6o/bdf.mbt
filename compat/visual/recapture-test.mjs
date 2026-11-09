import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { PNG } from 'pngjs';
import { blankCapture, captureWithRecapture } from './recapture.mjs';

const white = [255, 255, 255, 255];
const ink = [0, 0, 0, 255];
const viewports = ['wide', 'desktop', 'mobile'];
const dir = mkdtempSync(path.join(tmpdir(), 'recapture-test-'));

const writePng = (file, width, height, pixel) => {
  const png = new PNG({ width, height });
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    const [r, g, b, a] = pixel(x, y);
    const i = (y * width + x) * 4;
    png.data[i] = r; png.data[i + 1] = g; png.data[i + 2] = b; png.data[i + 3] = a;
  }
  writeFileSync(file, PNG.sync.write(png));
};

const changedPixels = (a, b) => {
  let changed = 0;
  for (let i = 0; i < a.data.length; i += 4) {
    if (a.data[i] !== b.data[i] || a.data[i + 1] !== b.data[i + 1] || a.data[i + 2] !== b.data[i + 2] || a.data[i + 3] !== b.data[i + 3]) changed++;
  }
  return changed;
};

// A fake `vlmkit diff html`: each call rewrites the report and both screenshots for every viewport,
// so a test can decide what the first capture and the retry each produce.
const harness = ({ baseline, variant }) => {
  const target = mkdtempSync(path.join(dir, 'target-'));
  const reportPath = path.join(target, 'diff-report.json');
  const baselinePng = viewport => path.join(target, `baseline-${viewport}.png`);
  const variantPng = viewport => path.join(target, `variant-${viewport}.png`);
  let calls = 0;
  const run = async () => {
    const step = calls++;
    writeFileSync(reportPath, JSON.stringify({ results: viewports.map(viewport => ({ viewport, pass: step })) }));
    for (const viewport of viewports) {
      writePng(baselinePng(viewport), 8, 8, baseline(step, viewport));
      writePng(variantPng(viewport), 8, 8, variant(step, viewport));
    }
  };
  return { capture: ['diff', 'html'], reportPath, baselinePng, variantPng, run, label: 'test', log: () => {}, calls: () => calls };
};

const worstRatio = h => {
  let worst = 0;
  for (const viewport of viewports) {
    const a = PNG.sync.read(readFileSync(h.baselinePng(viewport)));
    const b = PNG.sync.read(readFileSync(h.variantPng(viewport)));
    worst = Math.max(worst, changedPixels(a, b) / (a.width * a.height));
  }
  return worst;
};

const ratioFor = (h, viewport) => {
  const a = PNG.sync.read(readFileSync(h.baselinePng(viewport)));
  const b = PNG.sync.read(readFileSync(h.variantPng(viewport)));
  return changedPixels(a, b) / (a.width * a.height);
};

// 1. An all-white capture is blank.
const blankFile = path.join(dir, 'blank.png');
writePng(blankFile, 8, 8, () => white);
assert.equal(blankCapture(blankFile), true, 'an all-white capture is blank');
console.log('ok 1 - an all-white capture is blank');

// 2. A page that is white except for one pixel is not blank, so a legitimately white page is never
//    mistaken for a failed capture.
const mostlyWhite = path.join(dir, 'mostly-white.png');
writePng(mostlyWhite, 8, 8, (x, y) => (x === 7 && y === 7 ? ink : white));
assert.equal(blankCapture(mostlyWhite), false, 'a single painted pixel is not blank');
console.log('ok 2 - a mostly white page with one painted pixel is not blank');

// 3. A painted baseline is never recaptured, and a genuine variant difference survives untouched.
{
  const h = harness({
    baseline: () => (x, y) => (x === 0 && y === 0 ? ink : white),
    variant: () => (x, y) => (x === 1 && y === 1 ? ink : white),
  });
  const report = await captureWithRecapture(h);
  assert.equal(h.calls(), 1, 'a painted baseline is not recaptured');
  assert.equal(report.results.length, 3, 'the first report is returned');
  assert.ok(worstRatio(h) > 0.0005, 'a genuine difference is still there for the caller to judge');
  console.log('ok 3 - a painted baseline is not recaptured and a real difference is preserved');
}

// 4. A blank baseline is recaptured once, and the retry that paints is accepted.
{
  const h = harness({
    baseline: step => step === 0 ? () => white : (x, y) => (x === 0 && y === 0 ? ink : white),
    variant: () => (x, y) => (x === 0 && y === 0 ? ink : white),
  });
  const report = await captureWithRecapture(h);
  assert.equal(h.calls(), 2, 'a blank baseline is recaptured exactly once');
  assert.equal(report.results.length, 3, 'the retry report is returned');
  for (const viewport of viewports) assert.equal(blankCapture(h.baselinePng(viewport)), false, 'the retry painted');
  assert.equal(worstRatio(h), 0, 'the recovered capture matches the variant');
  console.log('ok 4 - a blank baseline recovers on the retry');
}

// 5. A retry that is still blank fails loudly instead of reporting a 100% visual difference.
{
  const h = harness({ baseline: () => () => white, variant: () => () => white });
  await assert.rejects(
    () => captureWithRecapture(h),
    /still blank at wide, desktop, mobile after a retry — the page never painted/,
    'a still-blank retry must fail',
  );
  assert.equal(h.calls(), 2, 'a still-blank retry is not retried again');
  console.log('ok 5 - a retry that is still blank fails loudly');
}

// 6. The retry cannot hide a real difference: once the baseline paints, a variant that genuinely
//    differs still exceeds the 0.05% threshold.
{
  const h = harness({
    baseline: step => step === 0 ? () => white : (x, y) => (x === 0 && y === 0 ? ink : white),
    variant: () => () => white,
  });
  const report = await captureWithRecapture(h);
  assert.equal(h.calls(), 2, 'the blank baseline was recaptured');
  assert.equal(report.results.length, 3);
  assert.ok(worstRatio(h) > 0.0005, 'a genuine difference still fails the pixel assertion after a retry');
  console.log('ok 6 - a genuine difference still fails after a retry');
}

// 7. A retry must replace only the viewport that was blank. The first pass sees a real 3.125%
//    difference at wide and a blank baseline at mobile; the retry paints every viewport and its
//    wide capture matches its baseline. Keeping the retry's wide images would turn a real
//    difference into a pass, so the first wide capture has to survive.
{
  const painted = (x, y) => (x === 0 && y === 0 ? ink : white);
  const wideVariant = (x, y) => (x <= 2 && y === 0 ? ink : white); // two pixels more than the baseline
  const h = harness({
    baseline: (step, viewport) => (step === 0 && viewport === 'mobile' ? () => white : painted),
    variant: (step, viewport) => (step === 0 && viewport === 'wide' ? wideVariant : painted),
  });
  const report = await captureWithRecapture(h);
  assert.equal(h.calls(), 2, 'the blank mobile baseline was recaptured');
  assert.equal(ratioFor(h, 'wide'), 2 / 64, 'the first wide capture is kept, so its 3.125% difference survives');
  assert.ok(ratioFor(h, 'wide') > 0.0005, 'the real wide difference still fails the pixel assertion');
  assert.equal(blankCapture(h.baselinePng('mobile')), false, 'the blank mobile viewport was replaced by the retry');
  assert.equal(ratioFor(h, 'mobile'), 0, 'the recovered mobile viewport matches');
  assert.equal(report.results.find(result => result.viewport === 'wide').pass, 0, 'the report keeps the first wide result');
  assert.equal(report.results.find(result => result.viewport === 'mobile').pass, 1, 'the report takes the recovered mobile result');
  console.log('ok 7 - a retry replaces only the blank viewport and keeps a real difference elsewhere');
}

console.log('\nrecapture: 7 pass, 0 fail');
