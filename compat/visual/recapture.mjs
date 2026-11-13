import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
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
// baseline of the continuous pairs, and optionally the variant of a pair known to paint a BDF page; it is not a general
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
//
// The caller's baselinePng/variantPng callbacks are the authoritative filename contract. Derive the
// heatmap and triptych names from the variant path instead of suffix-matching directory entries: a
// suffix match makes `wide` own `...-ultra-wide.png`, so restoring the painted `wide` capture would
// overwrite the recovered `ultra-wide` one even though the merged report says `ultra-wide` came from
// the retry. Deriving exact paths also preserves arbitrary prefixes such as
// `compat_continuous_region-baseline-wide.png`.
const artifactPaths = (viewport, baselinePng, variantPng) => {
  const baseline = baselinePng(viewport);
  const variant = variantPng(viewport);
  const withSuffix = suffix => (variant.endsWith('.png') ? `${variant.slice(0, -'.png'.length)}${suffix}.png` : `${variant}${suffix}`);
  return {
    baseline,
    variant,
    heatmap: withSuffix('_heatmap'),
    triptych: withSuffix('-triptych'),
  };
};

const existingArtifacts = (viewport, baselinePng, variantPng) =>
  Object.entries(artifactPaths(viewport, baselinePng, variantPng)).filter(([, file]) => existsSync(file));

// Only these report fields are independent viewport records. Omission in a capture means
// that capture supplied no record; it must never revive a record from the other capture.
const viewportSections = {
  heatmapRegions: 'perViewport',
  paletteDiffs: 'perViewport',
  textRowShifts: 'perViewport',
  componentBboxDiffs: 'perViewport',
  shiftOrigins: 'perViewport',
  shiftAccumulations: 'perViewport',
  gridSuggestions: 'suggestions',
};
const countSections = ['computedStyleDiffPerViewport', 'authoredStyleDiffPerViewport', 'domPositionDiffPerViewport'];
const metadataKeys = ['dir', 'baseline', 'variants', 'viewports', 'strict', 'approvalPath', 'reportPath'];

const mergePerViewport = (firstList = [], retryList = [], blankViewports) => [
  ...firstList.filter(item => !blankViewports.has(item.viewport)),
  ...retryList.filter(item => blankViewports.has(item.viewport)),
];

const variants = (firstList = [], retryList = []) => {
  const first = new Map(firstList.map(entry => [entry.variantFile, entry]));
  const retry = new Map(retryList.map(entry => [entry.variantFile, entry]));
  return [...new Set([...first.keys(), ...retry.keys()])].map(variantFile => ({ variantFile, first: first.get(variantFile), retry: retry.get(variantFile) }));
};

// A mixed capture has no truthful whole-capture summary. In particular, vlmkit truncates some
// entries/samples to 100/200 records, so recomputing selector/property totals from them can invent
// a clean result. Keep original JSON reports, expose adopted per-viewport counts separately, and
// omit incomplete aggregate sections instead of emitting a partial standard vlmkit schema.
// Unknown future fields are also omitted and named, rather than copied from the wrong capture.
const mergeReport = (first, retried, blankViewports, originalReports) => {
  const retriedResults = new Map(retried.results.map(result => [result.viewport, result]));
  const merged = Object.fromEntries(metadataKeys.filter(key => key in first).map(key => [key, first[key]]));
  merged.results = first.results.map(result => blankViewports.has(result.viewport) ? retriedResults.get(result.viewport) : result);
  const known = new Set([...metadataKeys, 'results', ...Object.keys(viewportSections)]);
  const unavailableFields = [...new Set([...Object.keys(first), ...Object.keys(retried)])].filter(key => !known.has(key)).sort();
  for (const [key, listKey] of Object.entries(viewportSections)) {
    if (!(key in first) && !(key in retried)) continue;
    merged[key] = variants(first[key], retried[key]).map(entry => ({
      variantFile: entry.variantFile,
      [listKey]: mergePerViewport(entry.first?.[listKey], entry.retry?.[listKey], blankViewports),
    })).filter(entry => entry[listKey].length > 0);
  }
  const viewportCounts = {};
  const expectedViewports = first.results.map(result => result.viewport);
  for (const key of countSections) {
    if (!(key in first) && !(key in retried)) continue;
    viewportCounts[key] = variants(first[key], retried[key]).map(entry => {
      const byViewport = mergePerViewport(entry.first?.result?.byViewport, entry.retry?.result?.byViewport, blankViewports);
      const missingViewports = expectedViewports.filter(viewport => !byViewport.some(item => item.viewport === viewport && Number.isSafeInteger(item.count) && item.count >= 0));
      const countsComplete = missingViewports.length === 0 && byViewport.length === expectedViewports.length;
      return { variantFile: entry.variantFile, byViewport, countsComplete, ...(countsComplete ? { totalDiffs: byViewport.reduce((sum, item) => sum + item.count, 0) } : { missingViewports }) };
    });
  }
  merged.recapture = {
    adoptedCaptureByViewport: Object.fromEntries(expectedViewports.map(viewport => [viewport, blankViewports.has(viewport) ? 'retry' : 'first'])),
    originalReports,
    unavailableFields,
    viewportCounts,
    note: 'Whole-capture diagnostics were not recomputed. Missing diagnostics are unavailable, not evidence of no difference. Original JSON reports are retained; their artifact paths refer to the capture directory, not immutable image archives.',
  };
  return merged;
};

// Run `capture` once. If a checked screenshot came back blank, run it again and require that the
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
export async function captureWithRecapture({ capture, reportPath, baselinePng, variantPng, run, label, checkVariant = false, log = console.log }) {
  const target = path.dirname(reportPath);
  await run(capture);
  const firstRaw = readFileSync(reportPath);
  const first = JSON.parse(firstRaw.toString('utf8'));
  const blank = first.results.filter(result => blankCapture(baselinePng(result.viewport)) || (checkVariant && blankCapture(variantPng(result.viewport))));
  if (blank.length === 0) return first;

  const blankViewports = new Set(blank.map(result => result.viewport));
  const reportName = path.parse(reportPath).name;
  const originalReports = { first: `${reportName}.first.json`, retry: `${reportName}.retry.json` };
  writeFileSync(path.join(target, originalReports.first), firstRaw);

  // Keep every artifact of the viewports that painted, and drop the blank ones so a retry that
  // writes no heatmap leaves none behind.
  const kept = new Map();
  for (const result of first.results) {
    if (blankViewports.has(result.viewport)) continue;
    kept.set(result.viewport, new Map(existingArtifacts(result.viewport, baselinePng, variantPng).map(([, file]) => [file, readFileSync(file)])));
  }
  for (const viewport of blankViewports) {
    for (const [, file] of existingArtifacts(viewport, baselinePng, variantPng)) rmSync(file, { force: true });
  }

  log(`${label}: ${checkVariant ? 'baseline or variant' : 'baseline'} capture was blank at ${[...blankViewports].join(', ')} — recapturing`);
  const retryPath = path.join(target, originalReports.retry);
  const failurePath = path.join(target, `${reportName}.recapture-failure.json`);
  // Distinguish a retry that never wrote a report from the first report still on disk.
  rmSync(reportPath, { force: true });
  let retried;
  let merged;
  let failure;
  let retrySaved = false;
  try {
    await run(capture);
    const retryRaw = readFileSync(reportPath);
    writeFileSync(retryPath, retryRaw);
    retrySaved = true;
    retried = JSON.parse(retryRaw.toString('utf8'));
    for (const viewport of blankViewports) {
      if (!retried.results.some(result => result.viewport === viewport)) throw new Error(`${label}: retry report is missing viewport ${viewport}`);
    }

    const stillBlank = retried.results.filter(result => blankViewports.has(result.viewport) && blankCapture(baselinePng(result.viewport)));
    if (stillBlank.length > 0) {
      throw new Error(`${label}: baseline capture is still blank at ${stillBlank.map(result => result.viewport).join(', ')} after a retry — the page never painted, so the pixel comparison cannot judge it`);
    }
    if (checkVariant) {
      const stillBlankVariant = retried.results.filter(result => blankViewports.has(result.viewport) && blankCapture(variantPng(result.viewport)));
      if (stillBlankVariant.length > 0) {
        throw new Error(`${label}: variant capture is still blank at ${stillBlankVariant.map(result => result.viewport).join(', ')} after a retry — the page never painted, so the pixel comparison cannot judge it`);
      }
    }
    merged = mergeReport(first, retried, blankViewports, originalReports);
    writeFileSync(reportPath, JSON.stringify(merged, null, 2));
  } catch (error) {
    failure = error;
    // The runner may fail after writing a partial or even invalid report. Preserve it byte-for-byte.
    if (!retrySaved && existsSync(reportPath)) {
      try {
        writeFileSync(retryPath, readFileSync(reportPath));
        retrySaved = true;
      } catch (saveError) {
        failure = new AggregateError([failure, saveError], `${label}: retry and retry-report preservation failed`);
      }
    }
  }

  // Restore first-pass evidence even when the runner throws or the retry stays blank.
  try {
    for (const [viewport, files] of kept) {
      for (const [, file] of existingArtifacts(viewport, baselinePng, variantPng)) rmSync(file, { force: true });
      for (const [file, buffer] of files) writeFileSync(file, buffer);
    }
  } catch (restoreError) {
    failure = failure ? new AggregateError([failure, restoreError], `${label}: retry and artifact restoration failed`) : restoreError;
  }
  if (failure) {
    writeFileSync(reportPath, firstRaw);
    writeFileSync(failurePath, JSON.stringify({
      status: 'failed',
      message: String(failure),
      firstReport: originalReports.first,
      retryReport: retrySaved ? originalReports.retry : null,
      note: 'The primary report and nonblank viewport artifacts are from the first capture; a retry report, when present, is retained separately.',
    }, null, 2));
    throw failure;
  }

  log(`${label}: whole-capture diagnostics unavailable after mixed capture (${merged.recapture.unavailableFields.join(', ') || 'none supplied'}); see original reports ${originalReports.first} and ${originalReports.retry}`);
  return merged;
}

// vlmkit's human formatter does not understand our unavailable-field metadata and infers
// "image-only mode" from omitted DOM sections. Do not ask it for a whole-capture narrative
// after mixing evidence. Keep normal captures on the existing formatter path.
export async function summarizeCapture({ report, reportPath, run, log = console.log }) {
  if (!report.recapture) {
    await run(['diff', 'agent', reportPath, '--no-history']);
    return;
  }
  const evidence = report.recapture;
  log(`Mixed capture: adopted viewport results are in ${reportPath}; whole-capture diagnostic analysis is unavailable. The diff agent narrative is omitted because it cannot represent this limitation.`);
  log(`Adopted evidence: ${Object.entries(evidence.adoptedCaptureByViewport).map(([viewport, capture]) => `${viewport}=${capture}`).join(', ')}.`);
  log(`Unavailable fields: ${evidence.unavailableFields.join(', ') || 'none supplied'}. Original JSON reports: ${evidence.originalReports.first}, ${evidence.originalReports.retry}. Missing diagnostics do not mean no difference.`);
}
