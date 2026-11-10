// Generated and regression tests for the continuous-capture recapture path.
//
// Fixed seed: 0x5eed2026. The independent oracle below rebuilds the expected
// mixed report with plain arrays and `find`, not with recapture.mjs's internal
// Maps. Generated fixtures vary viewports, blank sets, diagnostics, counts,
// metadata and unknown fields; the oracle and the implementation must agree.
//
// The harness writes real PNGs, so blank detection, artifact preservation and
// first/retry viewport selection are exercised through the public API.

import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { PNG } from 'pngjs';
import { blankCapture, captureWithRecapture, summarizeCapture } from './recapture.mjs';

const SEED = 0x5eed2026;
const SEED_TEXT = '0x5eed2026';
const NOTE =
  'Whole-capture diagnostics were not recomputed. Missing diagnostics are unavailable, not evidence of no difference. Original JSON reports are retained; their artifact paths refer to the capture directory, not immutable image archives.';
const metadataKeys = ['dir', 'baseline', 'variants', 'viewports', 'strict', 'approvalPath', 'reportPath'];
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
const viewportPool = ['wide', 'ultra-wide', 'desktop', 'mobile', 'tablet', 'ultrawide', 'narrow'];
const variantPool = ['a.html', 'b.html', 'c.html'];

function mulberry32(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

const rand = mulberry32(SEED);
const pick = (items) => items[Math.floor(rand() * items.length)];
const subset = (items, min, max) => {
  const count = min + Math.floor(rand() * (max - min + 1));
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy.slice(0, count);
};

const WHITE = [255, 255, 255, 255];
const TRANSPARENT_WHITE = [255, 255, 255, 0];
const OFF_WHITE = [254, 255, 255, 255];
const INK = [0, 0, 0, 255];

function writePng(file, width, height, pixel) {
  const png = new PNG({ width, height });
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const [r, g, b, a] = pixel(x, y);
      const i = (y * width + x) * 4;
      png.data[i] = r;
      png.data[i + 1] = g;
      png.data[i + 2] = b;
      png.data[i + 3] = a;
    }
  }
  const buffer = PNG.sync.write(png);
  writeFileSync(file, buffer);
  return buffer;
}

const color = (step, viewportIndex, kind) => [step === 0 ? 10 : 20, viewportIndex * 10 + kind, 30, 255];

function makeReport(step, viewports, { completeCounts, includeExtra = false, variantFiles = null }) {
  const report = {};
  for (const key of metadataKeys) {
    if (rand() < 0.7) {
      if (key === 'viewports') report[key] = viewports.map((label) => ({ label, width: 2, height: 2 }));
      else if (key === 'variants') report[key] = ['variant.html'];
      else if (key === 'strict') report[key] = false;
      else if (key === 'dir') report[key] = '.';
      else if (key === 'baseline') report[key] = 'baseline.html';
      else if (key === 'approvalPath') report[key] = 'approval.json';
      else report[key] = 'diff-report.json';
    }
  }
  report.results = viewports.map((viewport) => ({
    viewport,
    variantFile: 'variant.html',
    pass: step,
    marker: step === 0 ? 'first' : 'retry',
  }));
  if (includeExtra) {
    report.results.push({ viewport: 'extra', variantFile: 'variant.html', pass: step, marker: 'extra' });
  }
  for (const [key, listKey] of Object.entries(viewportSections)) {
    if (rand() < 0.25) continue;
    const entries = [];
    for (const variantFile of variantFiles ?? subset(variantPool, 1, 2)) {
      const items = [];
      for (const viewport of viewports) {
        const count = Math.floor(rand() * 4);
        for (let i = 0; i < count; i++) {
          items.push({ viewport, tag: `${key}:${variantFile}:${step}:${viewport}:${i}` });
        }
      }
      entries.push({ variantFile, [listKey]: items });
    }
    report[key] = entries;
  }
  for (const key of countSections) {
    if (!completeCounts && rand() < 0.25) continue;
    const entries = [];
    for (const variantFile of variantFiles ?? subset(variantPool, 1, 2)) {
      const byViewport = [];
      for (const viewport of viewports) {
        if (completeCounts) {
          byViewport.push({ viewport, count: Math.floor(rand() * 100), source: step });
          continue;
        }
        const roll = rand();
        if (roll < 0.2) continue;
        if (roll < 0.3) byViewport.push({ viewport, count: -1, source: step });
        else if (roll < 0.4) byViewport.push({ viewport, count: 1.5, source: step });
        else if (roll < 0.5) byViewport.push({ viewport, count: '3', source: step });
        else if (roll < 0.6) byViewport.push({ viewport, count: null, source: step });
        else if (roll < 0.7) byViewport.push({ viewport, count: 2 ** 53, source: step });
        else if (roll < 0.8) byViewport.push({ viewport, count: true, source: step });
        else byViewport.push({ viewport, count: Math.floor(rand() * 100), source: step });
      }
      entries.push({
        variantFile,
        result: {
          byViewport,
          totalDiffs: 999,
          bySelectorProperty: [{ samples: [{ viewport: 'stale' }] }],
          entries: ['truncated'],
          byPathProperty: ['stale'],
        },
      });
    }
    report[key] = entries;
  }
  for (let i = 0; i < 2; i++) {
    if (rand() < 0.3) report[`future${i}`] = { step, value: Math.floor(rand() * 10) };
  }
  return report;
}

// Independent oracle: plain arrays and find for section merging, with a
// separate retry-result lookup. It does not call recapture.mjs's merge helpers.
function oracleMerge(first, retried, blankViewports, originalReports) {
  const expectedViewports = first.results.map((result) => result.viewport);
  const merged = {};
  for (const key of metadataKeys) if (key in first) merged[key] = first[key];
  const retriedResults = new Map(retried.results.map((result) => [result.viewport, result]));
  merged.results = first.results.map((result) =>
    blankViewports.has(result.viewport) ? retriedResults.get(result.viewport) : result,
  );
  const known = new Set([...metadataKeys, 'results', ...Object.keys(viewportSections)]);
  const unavailableFields = [...new Set([...Object.keys(first), ...Object.keys(retried)])]
    .filter((key) => !known.has(key))
    .sort();
  for (const [key, listKey] of Object.entries(viewportSections)) {
    if (!(key in first) && !(key in retried)) continue;
    const firstEntries = first[key] ?? [];
    const retryEntries = retried[key] ?? [];
    const variantFiles = [...new Set([...firstEntries.map((entry) => entry.variantFile), ...retryEntries.map((entry) => entry.variantFile)])];
    const entries = [];
    for (const variantFile of variantFiles) {
      const firstEntry = firstEntries.find((entry) => entry.variantFile === variantFile);
      const retryEntry = retryEntries.find((entry) => entry.variantFile === variantFile);
      const items = [
        ...(firstEntry?.[listKey] ?? []).filter((item) => !blankViewports.has(item.viewport)),
        ...(retryEntry?.[listKey] ?? []).filter((item) => blankViewports.has(item.viewport)),
      ];
      if (items.length > 0) entries.push({ variantFile, [listKey]: items });
    }
    merged[key] = entries;
  }
  const viewportCounts = {};
  for (const key of countSections) {
    if (!(key in first) && !(key in retried)) continue;
    const firstEntries = first[key] ?? [];
    const retryEntries = retried[key] ?? [];
    const variantFiles = [...new Set([...firstEntries.map((entry) => entry.variantFile), ...retryEntries.map((entry) => entry.variantFile)])];
    viewportCounts[key] = variantFiles.map((variantFile) => {
      const firstEntry = firstEntries.find((entry) => entry.variantFile === variantFile);
      const retryEntry = retryEntries.find((entry) => entry.variantFile === variantFile);
      const byViewport = [
        ...(firstEntry?.result?.byViewport ?? []).filter((item) => !blankViewports.has(item.viewport)),
        ...(retryEntry?.result?.byViewport ?? []).filter((item) => blankViewports.has(item.viewport)),
      ];
      const missingViewports = expectedViewports.filter(
        (viewport) =>
          !byViewport.some(
            (item) => item.viewport === viewport && Number.isSafeInteger(item.count) && item.count >= 0,
          ),
      );
      const countsComplete = missingViewports.length === 0 && byViewport.length === expectedViewports.length;
      return {
        variantFile,
        byViewport,
        countsComplete,
        ...(countsComplete ? { totalDiffs: byViewport.reduce((sum, item) => sum + item.count, 0) } : { missingViewports }),
      };
    });
  }
  merged.recapture = {
    adoptedCaptureByViewport: Object.fromEntries(
      expectedViewports.map((viewport) => [viewport, blankViewports.has(viewport) ? 'retry' : 'first']),
    ),
    originalReports,
    unavailableFields,
    viewportCounts,
    note: NOTE,
  };
  return merged;
}

// Direct source-ownership invariants. These do not reuse the oracle's merge
// loop: each adopted result, diagnostic item and count is compared with the
// capture named by adoptedCaptureByViewport, and count completeness is
// recomputed from the merged byViewport array itself.
function assertSourceOwnership(first, retried, report, blankViewports) {
  const expectedViewports = first.results.map((result) => result.viewport);
  assert.deepEqual(
    report.results.map((result) => result.viewport),
    expectedViewports,
    `seed ${SEED_TEXT}: merged results must keep the first capture's viewport order`,
  );
  for (const viewport of expectedViewports) {
    const source = blankViewports.has(viewport) ? retried : first;
    const expected = source.results.find((result) => result.viewport === viewport);
    const actual = report.results.find((result) => result.viewport === viewport);
    assert.deepEqual(
      actual,
      expected,
      `seed ${SEED_TEXT}: result for ${viewport} must come from ${blankViewports.has(viewport) ? 'retry' : 'first'}`,
    );
  }
  assert.deepEqual(
    report.recapture.adoptedCaptureByViewport,
    Object.fromEntries(
      expectedViewports.map((viewport) => [viewport, blankViewports.has(viewport) ? 'retry' : 'first']),
    ),
    `seed ${SEED_TEXT}: adopted capture map must name the source of every viewport`,
  );
  for (const key of metadataKeys) {
    if (key in first) {
      assert.deepEqual(report[key], first[key], `seed ${SEED_TEXT}: metadata ${key} must come from the first capture`);
    } else {
      assert.equal(Object.hasOwn(report, key), false, `seed ${SEED_TEXT}: metadata ${key} must not be invented`);
    }
  }
  const known = new Set([...metadataKeys, 'results', ...Object.keys(viewportSections)]);
  const expectedUnavailable = [...new Set([...Object.keys(first), ...Object.keys(retried)])]
    .filter((key) => !known.has(key))
    .sort();
  assert.deepEqual(
    report.recapture.unavailableFields,
    expectedUnavailable,
    `seed ${SEED_TEXT}: unavailable fields must be the omitted source fields`,
  );

  for (const [key, listKey] of Object.entries(viewportSections)) {
    const firstEntries = first[key] ?? [];
    const retryEntries = retried[key] ?? [];
    const actualEntries = report[key] ?? [];
    const variantFiles = [...new Set([...firstEntries.map((entry) => entry.variantFile), ...retryEntries.map((entry) => entry.variantFile)])];
    const expectedVariantFiles = variantFiles.filter((variantFile) => {
      const firstEntry = firstEntries.find((entry) => entry.variantFile === variantFile);
      const retryEntry = retryEntries.find((entry) => entry.variantFile === variantFile);
      return (
        (firstEntry?.[listKey] ?? []).some((item) => !blankViewports.has(item.viewport)) ||
        (retryEntry?.[listKey] ?? []).some((item) => blankViewports.has(item.viewport))
      );
    });
    assert.deepEqual(
      actualEntries.map((entry) => entry.variantFile),
      expectedVariantFiles,
      `seed ${SEED_TEXT}: ${key} must omit variants with no adopted items`,
    );
    for (const entry of actualEntries) {
      const firstEntry = firstEntries.find((item) => item.variantFile === entry.variantFile);
      const retryEntry = retryEntries.find((item) => item.variantFile === entry.variantFile);
      for (const item of entry[listKey] ?? []) {
        assert.ok(
          expectedViewports.includes(item.viewport),
          `seed ${SEED_TEXT}: ${key} ${entry.variantFile} invented viewport ${item.viewport}`,
        );
      }
      for (const viewport of expectedViewports) {
        const source = blankViewports.has(viewport) ? retryEntry : firstEntry;
        const expectedTags = (source?.[listKey] ?? [])
          .filter((item) => item.viewport === viewport)
          .map((item) => item.tag)
          .sort();
        const actualTags = (entry[listKey] ?? [])
          .filter((item) => item.viewport === viewport)
          .map((item) => item.tag)
          .sort();
        assert.deepEqual(
          actualTags,
          expectedTags,
          `seed ${SEED_TEXT}: ${key} ${entry.variantFile} ${viewport} must come from ${blankViewports.has(viewport) ? 'retry' : 'first'}`,
        );
      }
    }
  }

  const expectedCountKeys = countSections.filter((key) => key in first || key in retried);
  assert.deepEqual(
    Object.keys(report.recapture.viewportCounts),
    expectedCountKeys,
    `seed ${SEED_TEXT}: viewportCounts must contain exactly the supplied count sections`,
  );
  for (const key of expectedCountKeys) {
    const firstEntries = first[key] ?? [];
    const retryEntries = retried[key] ?? [];
    const actualEntries = report.recapture.viewportCounts[key] ?? [];
    const variantFiles = [...new Set([...firstEntries.map((entry) => entry.variantFile), ...retryEntries.map((entry) => entry.variantFile)])];
    assert.deepEqual(
      actualEntries.map((entry) => entry.variantFile),
      variantFiles,
      `seed ${SEED_TEXT}: ${key} must keep every supplied variant`,
    );
    for (const entry of actualEntries) {
      const firstEntry = firstEntries.find((item) => item.variantFile === entry.variantFile);
      const retryEntry = retryEntries.find((item) => item.variantFile === entry.variantFile);
      for (const viewport of expectedViewports) {
        const source = blankViewports.has(viewport) ? retryEntry : firstEntry;
        const expected = (source?.result?.byViewport ?? []).filter((item) => item.viewport === viewport);
        const actual = entry.byViewport.filter((item) => item.viewport === viewport);
        assert.deepEqual(
          actual,
          expected,
          `seed ${SEED_TEXT}: ${key} ${entry.variantFile} ${viewport} count must come from ${blankViewports.has(viewport) ? 'retry' : 'first'}`,
        );
      }
      const valid = (item) => Number.isSafeInteger(item.count) && item.count >= 0;
      const missingViewports = expectedViewports.filter(
        (viewport) => !entry.byViewport.some((item) => item.viewport === viewport && valid(item)),
      );
      const countsComplete = missingViewports.length === 0 && entry.byViewport.length === expectedViewports.length;
      assert.equal(
        entry.countsComplete,
        countsComplete,
        `seed ${SEED_TEXT}: ${key} ${entry.variantFile} completeness must follow the merged counts`,
      );
      if (countsComplete) {
        assert.equal(
          entry.totalDiffs,
          entry.byViewport.reduce((sum, item) => sum + item.count, 0),
          `seed ${SEED_TEXT}: ${key} ${entry.variantFile} total must sum the merged counts`,
        );
        assert.equal(Object.hasOwn(entry, 'missingViewports'), false, `seed ${SEED_TEXT}: complete counts must not list missing viewports`);
      } else {
        assert.deepEqual(
          entry.missingViewports,
          missingViewports,
          `seed ${SEED_TEXT}: ${key} ${entry.variantFile} must name exactly the missing viewports`,
        );
        assert.equal(Object.hasOwn(entry, 'totalDiffs'), false, `seed ${SEED_TEXT}: incomplete counts must not invent a total`);
      }
    }
  }
}

const artifactNames = (viewport) => ({
  baseline: `baseline-${viewport}.png`,
  variant: `variant-${viewport}.png`,
  heatmap: `variant-${viewport}_heatmap.png`,
  triptych: `variant-${viewport}-triptych.png`,
});

// The real caller in compat/visual/compare.mjs uses arbitrary prefixes, not
// the synthetic baseline-/variant- names above.
const compareNames = (viewport) => ({
  baseline: `compat_continuous_region-baseline-${viewport}.png`,
  variant: `compat_continuous_region-moon-${viewport}.png`,
  heatmap: `compat_continuous_region-moon-${viewport}_heatmap.png`,
  triptych: `compat_continuous_region-moon-${viewport}-triptych.png`,
});

async function captureCase({
  viewports,
  blankViewports,
  first,
  retry,
  firstMode = 'normal',
  retryMode = 'normal',
  omitFirst = () => false,
  omitRetry = () => false,
  namesFor = artifactNames,
}) {
  const target = mkdtempSync(path.join(tmpdir(), 'recapture-pbt-'));
  const reportPath = path.join(target, 'diff-report.json');
  const buffers = [new Map(), new Map()];
  const reports = [];
  let calls = 0;
  const run = async () => {
    const step = calls++;
    if (step === 0 && firstMode === 'throw') throw new Error('first boom');
    if (step === 1 && retryMode === 'throw') throw new Error('retry boom');
    if (step === 0 && firstMode === 'missing-report') {
      rmSync(reportPath, { force: true });
      return;
    }
    if (step === 1 && retryMode === 'missing-report') {
      rmSync(reportPath, { force: true });
      return;
    }
    if (step === 0 && firstMode === 'malformed') {
      writeFileSync(reportPath, '{');
      return;
    }
    if (step === 1 && retryMode === 'malformed') {
      writeFileSync(reportPath, '{');
      return;
    }
    const stepBuffers = new Map();
    for (const [index, viewport] of viewports.entries()) {
      const names = namesFor(viewport);
      const blank = step === 0 && blankViewports.has(viewport);
      const baselineFile = path.join(target, names.baseline);
      const missingBaseline =
        (step === 0 && firstMode === 'missing-baseline' && blank) ||
        (step === 1 && retryMode === 'missing-baseline' && blankViewports.has(viewport));
      if (missingBaseline) {
        rmSync(baselineFile, { force: true });
      } else {
        let pixel = color(step, index, 0);
        if (step === 0 && blank) {
          if (firstMode === 'transparent-white') pixel = TRANSPARENT_WHITE;
          else if (firstMode === 'off-white') pixel = OFF_WHITE;
          else pixel = WHITE;
        } else if (step === 1 && blankViewports.has(viewport)) {
          if (retryMode === 'still-blank') pixel = WHITE;
          else if (retryMode === 'transparent-white') pixel = TRANSPARENT_WHITE;
          else if (retryMode === 'off-white') pixel = OFF_WHITE;

        }
        stepBuffers.set(`${viewport}:baseline`, writePng(baselineFile, 2, 2, () => pixel));
      }
      stepBuffers.set(`${viewport}:variant`, writePng(path.join(target, names.variant), 2, 2, () => color(step, index, 1)));
      for (const [kind, name] of [['heatmap', names.heatmap], ['triptych', names.triptych]]) {
        const omit = step === 0 ? omitFirst(viewport, kind) : omitRetry(viewport, kind);
        const file = path.join(target, name);
        if (omit) {
          rmSync(file, { force: true });
          stepBuffers.delete(`${viewport}:${kind}`);
        } else {
          stepBuffers.set(`${viewport}:${kind}`, writePng(file, 2, 2, () => color(step, index, kind === 'heatmap' ? 2 : 3)));
        }
      }
    }
    buffers[step] = stepBuffers;
    writeFileSync(reportPath, JSON.stringify(step === 0 ? first : retry));
    reports.push(JSON.parse(JSON.stringify(step === 0 ? first : retry)));
  };
  const capture = () =>
    captureWithRecapture({
      capture: [],
      reportPath,
      baselinePng: (viewport) => path.join(target, namesFor(viewport).baseline),
      variantPng: (viewport) => path.join(target, namesFor(viewport).variant),
      run,
      label: 'pbt',
      log: () => {},
    });
  return { target, reportPath, reports, calls: () => calls, buffers, capture };
}

function assertArtifacts(target, viewports, blankViewports, buffers, namesFor = artifactNames) {
  for (const viewport of viewports) {
    const names = namesFor(viewport);
    const expectedStep = blankViewports.has(viewport) ? 1 : 0;
    for (const kind of ['baseline', 'variant', 'heatmap', 'triptych']) {
      const file = path.join(target, names[kind]);
      const expected = buffers[expectedStep]?.get(`${viewport}:${kind}`);
      if (expected === undefined) {
        assert.equal(existsSync(file), false, `seed ${SEED_TEXT}: ${viewport} ${kind} should be absent`);
      } else {
        assert.ok(existsSync(file), `seed ${SEED_TEXT}: ${viewport} ${kind} should exist`);
        assert.deepEqual(readFileSync(file), expected, `seed ${SEED_TEXT}: ${viewport} ${kind} is not the adopted capture`);
        const other = buffers[1 - expectedStep]?.get(`${viewport}:${kind}`);
        if (other !== undefined) {
          assert.equal(
            other.equals(expected),
            false,
            `seed ${SEED_TEXT}: ${viewport} ${kind} fixture must distinguish the two captures`,
          );
          assert.equal(
            readFileSync(file).equals(other),
            false,
            `seed ${SEED_TEXT}: ${viewport} ${kind} must not be the other capture's bytes`,
          );
        }
      }
    }
  }
}

let checks = 0;
const ok = (message) => {
  checks++;
  if (process.env.RECAPTURE_PBT_VERBOSE) console.log(`ok ${checks} - ${message}`);
};

// 1. blankCapture only treats every opaque-white pixel as blank.
{
  const dir = mkdtempSync(path.join(tmpdir(), 'recapture-pbt-blank-'));
  try {
    const cases = [
      ['all-white', 2, 2, () => WHITE, true],
      ['one-ink', 2, 2, (x, y) => (x === 0 && y === 0 ? INK : WHITE), false],
      ['transparent-white', 2, 2, () => TRANSPARENT_WHITE, false],
      ['off-white', 2, 2, () => OFF_WHITE, false],
      ['one-alpha-254', 2, 2, (x, y) => (x === 0 && y === 0 ? [255, 255, 255, 254] : WHITE), false],
      ['one-rgb-254', 2, 2, (x, y) => (x === 0 && y === 0 ? [254, 255, 255, 255] : WHITE), false],
      ['all-ink', 2, 2, () => INK, false],
      ['one-pixel-white', 1, 1, () => WHITE, true],
    ];
    for (const [name, width, height, pixel, expected] of cases) {
      const file = path.join(dir, `${name}.png`);
      writePng(file, width, height, pixel);
      assert.equal(blankCapture(file), expected, `seed ${SEED_TEXT}: blankCapture ${name}`);
    }
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
ok('blankCapture distinguishes opaque white from content and transparency');

// 2. Generated success cases: first/retry evidence, diagnostics and artifacts.
let generatedCases = 0;
let completeCountCases = 0;
let unavailableFieldCases = 0;
for (let caseIndex = 0; caseIndex < 32; caseIndex++) {
  const viewports = subset(viewportPool, 1, 4);
  const blankViewports = new Set(rand() < 0.5 ? [] : subset(viewports, 1, viewports.length));
  const completeCounts = caseIndex % 2 === 0;
  const sharedVariants = completeCounts ? subset(variantPool, 1, 2) : null;
  const first = makeReport(0, viewports, { completeCounts, variantFiles: sharedVariants });
  const retry = makeReport(1, viewports, { completeCounts, includeExtra: rand() < 0.2, variantFiles: sharedVariants });
  const omitFirst = (viewport, kind) => rand() < 0.25 || (kind === 'triptych' && rand() < 0.2);
  const omitRetry = (viewport, kind) => rand() < 0.25 || (kind === 'triptych' && rand() < 0.2);
  const h = await captureCase({ viewports, blankViewports, first, retry, omitFirst, omitRetry });
  try {
    const report = await h.capture();
    if (blankViewports.size === 0) {
      assert.equal(h.calls(), 1, `seed ${SEED_TEXT} case ${caseIndex}: a painted first capture must not retry`);
      assert.deepEqual(report, h.reports[0], `seed ${SEED_TEXT} case ${caseIndex}: first report changed`);
      assert.equal(existsSync(path.join(h.target, 'diff-report.first.json')), false);
      assertArtifacts(h.target, viewports, blankViewports, h.buffers);
    } else {
      assert.equal(h.calls(), 2, `seed ${SEED_TEXT} case ${caseIndex}: a blank baseline must retry once`);
      const expected = oracleMerge(h.reports[0], h.reports[1], blankViewports, {
        first: 'diff-report.first.json',
        retry: 'diff-report.retry.json',
      });
      assert.deepEqual(report, expected, `seed ${SEED_TEXT} case ${caseIndex}: merged report differs from oracle`);
      assertSourceOwnership(h.reports[0], h.reports[1], report, blankViewports);
      assert.deepEqual(
        JSON.parse(readFileSync(path.join(h.target, 'diff-report.first.json'), 'utf8')),
        h.reports[0],
        `seed ${SEED_TEXT} case ${caseIndex}: first original report changed`,
      );
      assert.deepEqual(
        JSON.parse(readFileSync(path.join(h.target, 'diff-report.retry.json'), 'utf8')),
        h.reports[1],
        `seed ${SEED_TEXT} case ${caseIndex}: retry original report changed`,
      );
      assertArtifacts(h.target, viewports, blankViewports, h.buffers);
      if (Object.values(report.recapture.viewportCounts).some((entries) => entries.some((entry) => entry.countsComplete))) completeCountCases++;
      if (report.recapture.unavailableFields.length > 0) unavailableFieldCases++;
    }
    generatedCases++;
  } finally {
    rmSync(h.target, { recursive: true, force: true });
  }
}
assert.ok(completeCountCases > 0, `seed ${SEED_TEXT}: generated cases never produced a complete viewport count`);
assert.ok(unavailableFieldCases > 0, `seed ${SEED_TEXT}: generated cases never produced unavailable fields`);
ok('generated first/retry reports match the independent merge oracle and artifact ownership');

// 3. Retry success adopts only the blank viewport.
{
  const viewports = ['wide', 'mobile'];
  const blankViewports = new Set(['mobile']);
  const first = makeReport(0, viewports, { completeCounts: true });
  const retry = makeReport(1, viewports, { completeCounts: true });
  const success = await captureCase({ viewports, blankViewports, first, retry });
  try {
    const report = await success.capture();
    assert.equal(success.calls(), 2);
    assert.equal(report.results.find((result) => result.viewport === 'wide').pass, 0);
    assert.equal(report.results.find((result) => result.viewport === 'mobile').pass, 1);
    assert.deepEqual(report.recapture.adoptedCaptureByViewport, { wide: 'first', mobile: 'retry' });
    assertSourceOwnership(first, retry, report, blankViewports);
  } finally {
    rmSync(success.target, { recursive: true, force: true });
  }
}
ok('retry success adopts only the blank viewport');

// 3b. Overlapping viewport labels must not steal each other's artifacts. A
//     suffix match makes `wide` own `...-ultra-wide.png`; restoring the painted
//     wide capture would then overwrite the recovered ultra-wide one. Use the
//     real compare.mjs-style prefixes, not the synthetic baseline-/variant-
//     names, so the callback contract is exercised too.
{
  const viewports = ['wide', 'ultra-wide'];
  const blankViewports = new Set(['ultra-wide']);
  const first = makeReport(0, viewports, { completeCounts: true });
  const retry = makeReport(1, viewports, { completeCounts: true });
  const h = await captureCase({ viewports, blankViewports, first, retry, namesFor: compareNames });
  try {
    const report = await h.capture();
    assert.equal(h.calls(), 2);
    assert.equal(report.results.find((result) => result.viewport === 'wide').pass, 0);
    assert.equal(report.results.find((result) => result.viewport === 'ultra-wide').pass, 1);
    assertSourceOwnership(first, retry, report, blankViewports);
    assertArtifacts(h.target, viewports, blankViewports, h.buffers, compareNames);
    const recovered = h.buffers[1].get('ultra-wide:baseline');
    const recoveredPath = path.join(h.target, compareNames('ultra-wide').baseline);
    assert.deepEqual(
      readFileSync(recoveredPath),
      recovered,
      `seed ${SEED_TEXT}: the recovered ultra-wide baseline must survive the wide restore`,
    );
    assert.equal(
      blankCapture(recoveredPath),
      false,
      `seed ${SEED_TEXT}: the recovered ultra-wide baseline must not be the blank first capture`,
    );
  } finally {
    rmSync(h.target, { recursive: true, force: true });
  }
}
ok('overlapping viewport labels keep their own recovered artifacts with compare.mjs prefixes');

// 3c. Generated overlapping-label cases: every blank set and both source
//     directions, with the independent oracle and direct ownership checks.
{
  let overlappingCases = 0;
  for (let caseIndex = 0; caseIndex < 8; caseIndex++) {
    const viewports = ['wide', 'ultra-wide'];
    const blankViewports = new Set(rand() < 0.5 ? [] : subset(viewports, 1, viewports.length));
    const first = makeReport(0, viewports, { completeCounts: true });
    const retry = makeReport(1, viewports, { completeCounts: true });
    const h = await captureCase({ viewports, blankViewports, first, retry, namesFor: compareNames });
    try {
      const report = await h.capture();
      if (blankViewports.size === 0) {
        assert.equal(h.calls(), 1, `seed ${SEED_TEXT} overlap case ${caseIndex}: painted captures must not retry`);
        assert.deepEqual(report, h.reports[0], `seed ${SEED_TEXT} overlap case ${caseIndex}: first report changed`);
      } else {
        assert.equal(h.calls(), 2, `seed ${SEED_TEXT} overlap case ${caseIndex}: blank capture must retry once`);
        assert.deepEqual(
          report,
          oracleMerge(h.reports[0], h.reports[1], blankViewports, {
            first: 'diff-report.first.json',
            retry: 'diff-report.retry.json',
          }),
          `seed ${SEED_TEXT} overlap case ${caseIndex}: merged report differs from oracle`,
        );
        assertSourceOwnership(h.reports[0], h.reports[1], report, blankViewports);
      }
      assertArtifacts(h.target, viewports, blankViewports, h.buffers, compareNames);
      overlappingCases++;
    } finally {
      rmSync(h.target, { recursive: true, force: true });
    }
  }
  assert.equal(overlappingCases, 8, `seed ${SEED_TEXT}: generated overlap cases did not all run`);
}
ok('generated overlapping viewport labels keep per-viewport artifact ownership');

// 4. Explicit fail-closed cases.
{
  const viewports = ['wide', 'mobile'];
  const blankViewports = new Set(['mobile']);
  const first = makeReport(0, viewports, { completeCounts: true });
  const retry = makeReport(1, viewports, { completeCounts: true });
  const missingViewport = { ...retry, results: retry.results.filter((result) => result.viewport !== 'mobile') };
  const missingNonBlank = { ...retry, results: retry.results.filter((result) => result.viewport !== 'wide') };
  const extraViewport = { ...retry, results: [...retry.results, { viewport: 'extra', pass: 1 }] };
  const duplicateViewport = { ...retry, results: [...retry.results, retry.results.find((result) => result.viewport === 'mobile')] };

  const cases = [
    ['missing blank viewport', { retry: missingViewport }, /missing viewport mobile/],
    ['missing retry baseline', { retryMode: 'missing-baseline' }, /ENOENT|no such file/i],
    ['retry throws', { retryMode: 'throw' }, /retry boom/],
    ['retry report missing', { retryMode: 'missing-report' }, /ENOENT|no such file/i],
    ['retry report malformed', { retryMode: 'malformed' }, /JSON|Unexpected/],
    ['first throws', { firstMode: 'throw' }, /first boom/],
    ['first report missing', { firstMode: 'missing-report' }, /ENOENT|no such file/i],
    ['first report malformed', { firstMode: 'malformed' }, /JSON|Unexpected/],
    ['first baseline missing', { firstMode: 'missing-baseline' }, /ENOENT|no such file/i],
  ];
  for (const [name, options, pattern] of cases) {
    const h = await captureCase({ viewports, blankViewports, first, retry, ...options });
    try {
      await assert.rejects(h.capture(), pattern, `seed ${SEED_TEXT}: ${name} must fail closed`);
    } finally {
      rmSync(h.target, { recursive: true, force: true });
    }
  }

  // A still-blank retry is a distinct failure: it must reject with the exact
  // viewport, after exactly one retry, and leave both original reports behind.
  // Do not wrap this in a catch that could turn an assertion failure into a
  // pass.
  {
    const h = await captureCase({ viewports, blankViewports, first, retry, retryMode: 'still-blank' });
    try {
      await assert.rejects(
        h.capture(),
        /pbt: baseline capture is still blank at mobile after a retry — the page never painted/,
        `seed ${SEED_TEXT}: a still-blank retry must reject with the exact viewport`,
      );
      assert.equal(h.calls(), 2, `seed ${SEED_TEXT}: a still-blank retry is attempted exactly once`);
      assert.equal(
        existsSync(path.join(h.target, 'diff-report.first.json')),
        true,
        `seed ${SEED_TEXT}: the first report must be retained before the retry`,
      );
      assert.equal(
        existsSync(path.join(h.target, 'diff-report.retry.json')),
        true,
        `seed ${SEED_TEXT}: the retry report must be retained before the still-blank check`,
      );
      assert.equal(
        blankCapture(path.join(h.target, 'baseline-mobile.png')),
        true,
        `seed ${SEED_TEXT}: the retry baseline must still be blank`,
      );
    } finally {
      rmSync(h.target, { recursive: true, force: true });
    }
  }

  const missingNonBlankCase = await captureCase({ viewports, blankViewports, first, retry: missingNonBlank });
  try {
    const report = await missingNonBlankCase.capture();
    assert.equal(missingNonBlankCase.calls(), 2);
    assert.equal(report.results.find((result) => result.viewport === 'wide').pass, 0);
    assert.equal(report.results.find((result) => result.viewport === 'mobile').pass, 1);
  } finally {
    rmSync(missingNonBlankCase.target, { recursive: true, force: true });
  }

  const extraCase = await captureCase({ viewports, blankViewports, first, retry: extraViewport });
  try {
    const report = await extraCase.capture();
    assert.equal(report.results.length, 2, 'an extra retry viewport must not enter the adopted results');
    assert.equal(report.results.some((result) => result.viewport === 'extra'), false);
  } finally {
    rmSync(extraCase.target, { recursive: true, force: true });
  }

  const duplicateCase = await captureCase({ viewports, blankViewports, first, retry: duplicateViewport });
  try {
    const report = await duplicateCase.capture();
    assert.equal(report.results.length, 2);
    assert.equal(report.results.find((result) => result.viewport === 'mobile').pass, 1);
  } finally {
    rmSync(duplicateCase.target, { recursive: true, force: true });
  }
}
ok('missing viewports, malformed reports and missing evidence fail closed; still-blank retries reject exactly');

// 5. Transparent and off-white retry captures are not blank; zero-size is.
{
  const viewports = ['wide', 'mobile'];
  const blankViewports = new Set(['mobile']);
  const first = makeReport(0, viewports, { completeCounts: true });
  const retry = makeReport(1, viewports, { completeCounts: true });
  for (const mode of ['transparent-white', 'off-white']) {
    const h = await captureCase({ viewports, blankViewports, first, retry, retryMode: mode });
    try {
      const report = await h.capture();
      assert.equal(h.calls(), 2);
      assert.equal(report.results.find((result) => result.viewport === 'mobile').pass, 1);
    } finally {
      rmSync(h.target, { recursive: true, force: true });
    }
  }
  for (const mode of ['transparent-white', 'off-white']) {
    const h = await captureCase({ viewports, blankViewports, first, retry, firstMode: mode });
    try {
      const report = await h.capture();
      assert.equal(h.calls(), 1, `seed ${SEED_TEXT}: a ${mode} first capture is not blank`);
      assert.deepEqual(report, h.reports[0]);
    } finally {
      rmSync(h.target, { recursive: true, force: true });
    }
  }
}
ok('transparent/off-white captures are content, not blank');

// 5b. Viewport counts: first non-blank + retry blank, never a stale count,
//     never a zero for a missing count, and no total when the set is incomplete.
{
  const viewports = ['wide', 'mobile'];
  const blankViewports = new Set(['mobile']);
  const base = makeReport(0, viewports, { completeCounts: true });
  const retryBase = makeReport(1, viewports, { completeCounts: true });
  const withCounts = (report, counts) => ({
    ...report,
    computedStyleDiffPerViewport: [{ variantFile: 'a.html', result: { byViewport: counts } }],
  });

  const complete = await captureCase({
    viewports,
    blankViewports,
    first: withCounts(base, [{ viewport: 'wide', count: 1 }, { viewport: 'mobile', count: 99 }]),
    retry: withCounts(retryBase, [{ viewport: 'wide', count: 9 }, { viewport: 'mobile', count: 3 }]),
  });
  try {
    const report = await complete.capture();
    const entry = report.recapture.viewportCounts.computedStyleDiffPerViewport[0];
    assert.deepEqual(entry.byViewport, [{ viewport: 'wide', count: 1 }, { viewport: 'mobile', count: 3 }]);
    assert.equal(entry.countsComplete, true);
    assert.equal(entry.totalDiffs, 4);
  } finally {
    rmSync(complete.target, { recursive: true, force: true });
  }

  const retryWithoutCounts = { ...retryBase };
  delete retryWithoutCounts.computedStyleDiffPerViewport;
  const missing = await captureCase({
    viewports,
    blankViewports,
    first: withCounts(base, [{ viewport: 'wide', count: 1 }, { viewport: 'mobile', count: 99 }]),
    retry: retryWithoutCounts,
  });
  try {
    const report = await missing.capture();
    const entry = report.recapture.viewportCounts.computedStyleDiffPerViewport[0];
    assert.deepEqual(entry.byViewport, [{ viewport: 'wide', count: 1 }]);
    assert.equal(entry.countsComplete, false);
    assert.deepEqual(entry.missingViewports, ['mobile']);
    assert.equal(Object.hasOwn(entry, 'totalDiffs'), false, 'a missing count must not become zero');
  } finally {
    rmSync(missing.target, { recursive: true, force: true });
  }

  const extra = await captureCase({
    viewports,
    blankViewports,
    first: withCounts(base, [{ viewport: 'wide', count: 1 }, { viewport: 'mobile', count: 99 }, { viewport: 'extra', count: 5 }]),
    retry: withCounts(retryBase, [{ viewport: 'wide', count: 9 }, { viewport: 'mobile', count: 3 }]),
  });
  try {
    const report = await extra.capture();
    const entry = report.recapture.viewportCounts.computedStyleDiffPerViewport[0];
    assert.equal(entry.countsComplete, false, 'an unexpected viewport count must not be complete');
    assert.equal(Object.hasOwn(entry, 'totalDiffs'), false);
    assert.deepEqual(entry.missingViewports, [], 'the expected viewports are present; the extra one is not adopted');
  } finally {
    rmSync(extra.target, { recursive: true, force: true });
  }
}
ok('viewport counts adopt first/retry evidence and fail closed on missing or extra counts');

// 6. summarizeCapture keeps ordinary captures on the formatter path and never
//    asks the formatter to narrate a mixed capture.
{
  const calls = [];
  await summarizeCapture({
    report: {},
    reportPath: 'ordinary.json',
    run: async (args) => calls.push(args),
    log: () => assert.fail('ordinary captures keep the standard formatter'),
  });
  assert.deepEqual(calls, [['diff', 'agent', 'ordinary.json', '--no-history']]);

  const messages = [];
  const mixed = {
    recapture: {
      adoptedCaptureByViewport: { wide: 'first', mobile: 'retry' },
      originalReports: { first: 'diff-report.first.json', retry: 'diff-report.retry.json' },
      unavailableFields: ['computedStyleDiffPerViewport', 'futureDiagnostic'],
    },
  };
  await summarizeCapture({
    report: mixed,
    reportPath: 'mixed.json',
    run: async () => assert.fail('mixed captures must not invoke the unsupported formatter'),
    log: (message) => messages.push(message),
  });
  assert.ok(messages.some((message) => message.includes('narrative is omitted')));
  assert.ok(messages.some((message) => message.includes('wide=first') && message.includes('mobile=retry')));
  assert.ok(messages.some((message) => message.includes('computedStyleDiffPerViewport') && message.includes('futureDiagnostic')));
  assert.ok(messages.some((message) => message.includes('diff-report.first.json') && message.includes('diff-report.retry.json')));
}
ok('summarizeCapture omits the unsupported narrative for mixed evidence');

console.log(`recapture PBT: ${checks} checks pass, 0 fail (seed ${SEED_TEXT}, ${generatedCases} generated cases)`);
export const recapturePbtChecks = checks;
export const recaptureGeneratedCases = generatedCases;
