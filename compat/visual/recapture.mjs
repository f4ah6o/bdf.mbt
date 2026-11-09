import { readFileSync, writeFileSync } from 'node:fs';
import { PNG } from 'pngjs';

// `vlmkit diff html` screenshots each page straight after `networkidle` and never settles it, so a
// fixture whose first paint lands after that idle window is captured as an empty page. The
// continuous fixtures render asynchronously once their fetch resolves, which puts them inside the
// window: a loaded machine can lose the race and report a 100% diff against a blank baseline.
//
// A capture counts as blank only when every pixel is opaque white. Any content at all — a glyph, a
// border, a background tint, a scrollbar — leaves a non-white pixel and is never treated as blank,
// so a page that is legitimately mostly white is not a false positive. The check is applied to the
// baseline of the continuous pairs, whose fixtures always paint a BDF page; it is not a general
// "is this page empty" test and must not be pointed at a page that is meant to be blank.
export const blankCapture = file => {
  const png = PNG.sync.read(readFileSync(file));
  for (let i = 0; i < png.data.length; i += 4) {
    if (png.data[i] !== 255 || png.data[i + 1] !== 255 || png.data[i + 2] !== 255 || png.data[i + 3] !== 255) return false;
  }
  return true;
};

// Run `capture` once. If any baseline screenshot came back blank, run it again and require that the
// retry painted: a retry that is still blank means the page never rendered, which the pixel
// comparison cannot judge, so it fails loudly instead of reporting a 100% visual difference.
//
// The retry re-captures every viewport, so the first capture is kept for the viewports that painted
// and only the blank ones are replaced. Without that, a real difference seen on the first pass is
// overwritten by a clean retry and the comparison passes on evidence the run never had.
export async function captureWithRecapture({ capture, reportPath, baselinePng, variantPng, run, label, log = console.log }) {
  await run(capture);
  const first = JSON.parse(readFileSync(reportPath, 'utf8'));
  const blank = first.results.filter(result => blankCapture(baselinePng(result.viewport)));
  if (blank.length === 0) return first;

  const blankViewports = new Set(blank.map(result => result.viewport));
  const kept = new Map();
  for (const result of first.results) {
    if (blankViewports.has(result.viewport)) continue;
    kept.set(result.viewport, {
      baseline: readFileSync(baselinePng(result.viewport)),
      variant: readFileSync(variantPng(result.viewport)),
    });
  }

  log(`${label}: baseline capture was blank at ${[...blankViewports].join(', ')} — recapturing`);
  await run(capture);
  const retried = JSON.parse(readFileSync(reportPath, 'utf8'));

  const stillBlank = retried.results.filter(result => blankViewports.has(result.viewport) && blankCapture(baselinePng(result.viewport)));
  if (stillBlank.length > 0) {
    throw new Error(`${label}: baseline capture is still blank at ${stillBlank.map(result => result.viewport).join(', ')} after a retry — the page never painted, so the pixel comparison cannot judge it`);
  }

  for (const [viewport, pngs] of kept) {
    writeFileSync(baselinePng(viewport), pngs.baseline);
    writeFileSync(variantPng(viewport), pngs.variant);
  }
  const retriedByViewport = new Map(retried.results.map(result => [result.viewport, result]));
  const merged = {
    ...first,
    results: first.results.map(result => blankViewports.has(result.viewport) ? retriedByViewport.get(result.viewport) : result),
  };
  writeFileSync(reportPath, JSON.stringify(merged, null, 2));
  return merged;
}
