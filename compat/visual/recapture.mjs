import { readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
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

// The per-viewport artifacts `vlmkit diff html` writes: the two screenshots plus the diagnostics it
// emits for a viewport that differs. A retry only replaces the viewports that were blank, so these
// are the files that have to move with them.
const belongsToViewport = (name, viewport) =>
  name.endsWith(`-${viewport}.png`) || name.endsWith(`-${viewport}_heatmap.png`) || name.endsWith(`-${viewport}-triptych.png`);

const filesFor = (dir, viewport) => readdirSync(dir).filter(name => belongsToViewport(name, viewport));

// Per-viewport lists appear either directly (`heatmapRegions[].perViewport`) or under `result`
// (`computedStyleDiffPerViewport[].result.byViewport`). Both merge the same way: the first capture
// wins for the viewports that painted, the retry supplies the ones that were blank.
const mergePerViewport = (firstList = [], retryList = [], blankViewports) => {
  const firstByViewport = new Map(firstList.map(item => [item.viewport, item]));
  const retryByViewport = new Map(retryList.map(item => [item.viewport, item]));
  return [...new Set([...firstByViewport.keys(), ...retryByViewport.keys()])]
    .map(viewport => blankViewports.has(viewport) ? retryByViewport.get(viewport) : firstByViewport.get(viewport))
    .filter(Boolean);
};

// The report has to describe the evidence that is actually judged, so every per-viewport list is
// merged viewport by viewport. The cross-viewport rollups inside `result` (`bySelectorProperty`,
// `samples`, `entries`) are not re-derived; they stay as the first capture recorded them.
const mergeReport = (first, retried, blankViewports) => {
  const retriedResults = new Map(retried.results.map(result => [result.viewport, result]));
  const merged = {
    ...first,
    results: first.results.map(result => blankViewports.has(result.viewport) ? retriedResults.get(result.viewport) : result),
  };
  for (const key of ['heatmapRegions', 'computedStyleDiffPerViewport', 'authoredStyleDiffPerViewport', 'domPositionDiffPerViewport']) {
    if (!Array.isArray(first[key])) continue;
    const retriedByVariant = new Map((retried[key] ?? []).map(entry => [entry.variantFile, entry]));
    merged[key] = first[key].map(entry => {
      const retryEntry = retriedByVariant.get(entry.variantFile);
      if (!retryEntry) return entry;
      if (key === 'heatmapRegions') {
        return { ...entry, perViewport: mergePerViewport(entry.perViewport, retryEntry.perViewport, blankViewports) };
      }
      const byViewport = mergePerViewport(entry.result?.byViewport, retryEntry.result?.byViewport, blankViewports);
      return { ...entry, result: { ...entry.result, byViewport, totalDiffs: byViewport.reduce((sum, item) => sum + (item.count ?? 0), 0) } };
    });
  }
  return merged;
};

// Run `capture` once. If any baseline screenshot came back blank, run it again and require that the
// retry painted: a retry that is still blank means the page never rendered, which the pixel
// comparison cannot judge, so it fails loudly instead of reporting a 100% visual difference.
//
// The retry re-captures every viewport, so the first capture is kept for the viewports that painted
// and only the blank ones are replaced — screenshots, heatmap, triptych and report entries alike.
// Without that, a real difference seen on the first pass is overwritten by a clean retry and the
// comparison passes on evidence the run never had.
//
// This is a one-shot mitigation for a capture race, not a fix for it: the page is still screenshotted
// straight after `networkidle` with no readiness wait, so a capture can still be blank, and a retry
// that is blank too fails the run rather than recovering it.
export async function captureWithRecapture({ capture, reportPath, baselinePng, variantPng, run, label, log = console.log }) {
  const target = path.dirname(reportPath);
  await run(capture);
  const first = JSON.parse(readFileSync(reportPath, 'utf8'));
  const blank = first.results.filter(result => blankCapture(baselinePng(result.viewport)));
  if (blank.length === 0) return first;

  const blankViewports = new Set(blank.map(result => result.viewport));

  // Keep every artifact of the viewports that painted, and drop the blank ones so a retry that
  // writes no heatmap leaves none behind.
  const kept = new Map();
  for (const result of first.results) {
    if (blankViewports.has(result.viewport)) continue;
    kept.set(result.viewport, new Map(filesFor(target, result.viewport).map(name => [name, readFileSync(path.join(target, name))])));
  }
  for (const viewport of blankViewports) {
    for (const name of filesFor(target, viewport)) rmSync(path.join(target, name), { force: true });
  }

  log(`${label}: baseline capture was blank at ${[...blankViewports].join(', ')} — recapturing`);
  await run(capture);
  const retried = JSON.parse(readFileSync(reportPath, 'utf8'));

  const stillBlank = retried.results.filter(result => blankViewports.has(result.viewport) && blankCapture(baselinePng(result.viewport)));
  if (stillBlank.length > 0) {
    throw new Error(`${label}: baseline capture is still blank at ${stillBlank.map(result => result.viewport).join(', ')} after a retry — the page never painted, so the pixel comparison cannot judge it`);
  }

  // Put the kept viewports back exactly as the first capture left them: the retry re-captured every
  // viewport, so its screenshots and diagnostics must not stand in for evidence it did not produce.
  for (const [viewport, files] of kept) {
    for (const name of filesFor(target, viewport)) rmSync(path.join(target, name), { force: true });
    for (const [name, buffer] of files) writeFileSync(path.join(target, name), buffer);
  }

  const merged = mergeReport(first, retried, blankViewports);
  writeFileSync(reportPath, JSON.stringify(merged, null, 2));
  return merged;
}
