import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { PNG } from 'pngjs';
import { captureWithRecapture, summarizeCapture } from './recapture.mjs';

const viewports = ['wide', 'desktop', 'mobile'];
const item = (viewport, tag) => ({ viewport, tag });
const entry = (variantFile, perViewport) => ({ variantFile, perViewport });
const sectionKeys = ['heatmapRegions', 'paletteDiffs', 'textRowShifts', 'componentBboxDiffs', 'shiftOrigins', 'shiftAccumulations'];
const countKeys = ['computedStyleDiffPerViewport', 'authoredStyleDiffPerViewport', 'domPositionDiffPerViewport'];
let checks = 0;

async function fixture(first, retry, { blank = true } = {}) {
  const target = mkdtempSync(path.join(tmpdir(), 'recapture-diagnostics-'));
  const reports = [];
  const log = [];
  const baselinePng = viewport => path.join(target, `baseline-${viewport}.png`);
  const variantPng = viewport => path.join(target, `variant-${viewport}.png`);
  const reportPath = path.join(target, 'diff-report.json');
  let calls = 0;
  const run = async () => {
    const step = calls++;
    for (const viewport of viewports) for (const name of ['baseline', 'variant']) {
      const png = new PNG({ width: 8, height: 8 });
      png.data.fill(255);
      if (!(blank && step === 0 && viewport === 'mobile' && name === 'baseline')) png.data.fill(0, 0, 3);
      writeFileSync(path.join(target, `${name}-${viewport}.png`), PNG.sync.write(png));
    }
    const report = {
      dir: '.', baseline: 'baseline.html', variants: ['variant.html'],
      viewports: viewports.map(label => ({ label, width: 8, height: 8 })), strict: false, reportPath,
      results: viewports.map(viewport => ({ viewport, variantFile: 'variant.html', pass: step })),
      ...(step === 0 ? first : retry),
    };
    reports.push(JSON.parse(JSON.stringify(report)));
    writeFileSync(reportPath, JSON.stringify(report));
  };
  const report = await captureWithRecapture({ capture: [], reportPath, baselinePng, variantPng, run, label: 'diagnostic regression', log: message => log.push(message) });
  return { target, reports, report, calls, log };
}

for (const key of sectionKeys) {
  const old = entry('a', [item('wide', 'first-wide'), item('mobile', 'stale-mobile')]);
  const fresh = entry('a', [item('wide', 'ignored-retry-wide'), item('mobile', 'retry-mobile')]);
  for (const retry of [{}, { [key]: [] }, { [key]: [entry('other', [])] }]) {
    const { report } = await fixture({ [key]: [old] }, retry);
    assert.deepEqual(report[key], [entry('a', [item('wide', 'first-wide')])], `${key}: an omitted retry field/entry must remove stale mobile diagnostics`);
    checks++;
  }
  for (const first of [{}, { [key]: [] }]) {
    const { report } = await fixture(first, { [key]: [fresh] });
    assert.deepEqual(report[key], [entry('a', [item('mobile', 'retry-mobile')])], `${key}: a new retry field/entry must be adopted only for mobile`);
    checks++;
  }
  const { report } = await fixture({ [key]: [old, entry('removed', [item('mobile', 'stale-only')])] }, {
    [key]: [fresh, entry('added', [item('mobile', 'new-only')])],
  });
  assert.deepEqual(report[key], [entry('a', [item('wide', 'first-wide'), item('mobile', 'retry-mobile')]), entry('added', [item('mobile', 'new-only')])]);
  checks++;
}

// More than one suggestion can belong to a viewport. A Map(viewport, item) loses entries.
{
  const { report } = await fixture({ gridSuggestions: [{ variantFile: 'a', suggestions: [item('wide', 'first-1'), item('wide', 'first-2'), item('mobile', 'stale')] }] }, {
    gridSuggestions: [{ variantFile: 'a', suggestions: [item('wide', 'ignore'), item('mobile', 'retry-1'), item('mobile', 'retry-2')] }],
  });
  assert.deepEqual(report.gridSuggestions, [{ variantFile: 'a', suggestions: [item('wide', 'first-1'), item('wide', 'first-2'), item('mobile', 'retry-1'), item('mobile', 'retry-2')] }]);
  checks++;
}

for (const key of countKeys) {
  const counts = values => values.map((count, i) => ({ viewport: viewports[i], count }));
  const result = values => ({ totalDiffs: 999, byViewport: counts(values), bySelectorProperty: [{ samples: [{ viewport: 'mobile', value: 'stale' }] }], entries: ['truncated'], universalPairs: ['stale'], byPathProperty: ['stale'] });
  const { report } = await fixture({ [key]: [{ variantFile: 'a', result: result([1, 2, 99]) }] }, { [key]: [{ variantFile: 'a', result: result([9, 9, 3]) }] });
  assert.equal(Object.hasOwn(report, key), false, `${key}: incomplete aggregate must not masquerade as a standard vlmkit section`);
  assert.deepEqual(report.recapture.viewportCounts[key], [{ variantFile: 'a', byViewport: counts([1, 2, 3]), countsComplete: true, totalDiffs: 6 }]);
  assert.ok(report.recapture.unavailableFields.includes(key));
  checks++;
  const missing = await fixture({ [key]: [{ variantFile: 'a', result: result([1, 2, 99]) }] }, {});
  assert.deepEqual(missing.report.recapture.viewportCounts[key], [{ variantFile: 'a', byViewport: counts([1, 2]), countsComplete: false, missingViewports: ['mobile'] }]);
  assert.equal(Object.hasOwn(missing.report.recapture.viewportCounts[key][0], 'totalDiffs'), false, 'missing counts are not zero');
  checks++;
}

// Preserve originals and explain every unsupported aggregate, including future unknown fields.
{
  const first = { computedStyleDiff: [{ result: { entries: ['stale'] } }], componentGeometryProfiles: ['stale'], stateDiffs: ['unmergeable'], futureDiagnostic: ['first'] };
  const retry = { paletteDiffs: [], futureDiagnostic: ['retry'], futureAddedDiagnostic: ['new'] };
  const h = await fixture(first, retry);
  for (const key of ['computedStyleDiff', 'componentGeometryProfiles', 'stateDiffs', 'futureDiagnostic', 'futureAddedDiagnostic']) {
    assert.equal(Object.hasOwn(h.report, key), false);
    assert.ok(h.report.recapture.unavailableFields.includes(key));
  }
  assert.deepEqual(h.report.recapture.adoptedCaptureByViewport, { wide: 'first', desktop: 'first', mobile: 'retry' });
  for (const [index, name] of ['first', 'retry'].entries()) {
    const file = path.join(h.target, h.report.recapture.originalReports[name]);
    assert.deepEqual(JSON.parse(readFileSync(file, 'utf8')), h.reports[index]);
  }
  assert.ok(h.log.some(message => message.includes('unavailable') && message.includes('original reports')));
  checks++;
}

// With no retry the original report remains intact, including diagnostics we do not merge.
{
  const h = await fixture({ futureDiagnostic: ['keep'], computedStyleDiff: ['keep'] }, {}, { blank: false });
  assert.equal(h.calls, 1);
  assert.deepEqual(h.report, h.reports[0]);
  assert.equal(existsSync(path.join(h.target, 'diff-report.first.json')), false);
  checks++;
}

// A missing retry viewport cannot be silently converted to a null result or zero diagnostic.
await assert.rejects(() => fixture({}, { results: [{ viewport: 'wide' }, { viewport: 'desktop' }] }), /missing.*mobile/i);
checks++;
// The existing formatter cannot express unavailable aggregates and otherwise labels these
// reports as image-only mode. Mixed captures must not emit that unsupported conclusion.
{
  const h = await fixture({ computedStyleDiff: ['unavailable'] }, {});
  const messages = [];
  await summarizeCapture({ report: h.report, reportPath: 'mixed.json', run: async () => assert.fail('do not invoke the unsupported formatter for mixed evidence'), log: message => messages.push(message) });
  assert.ok(messages.some(message => message.includes('unavailable') && message.includes('narrative is omitted')));
  assert.ok(messages.some(message => message.includes('diff-report.first.json') && message.includes('diff-report.retry.json')));
  assert.ok(messages.some(message => message.includes('mobile=retry') && message.includes('wide=first')));
  checks++;
  const calls = [];
  await summarizeCapture({ report: {}, reportPath: 'ordinary.json', run: async args => calls.push(args), log: () => assert.fail('ordinary captures keep the standard formatter') });
  assert.deepEqual(calls, [['diff', 'agent', 'ordinary.json', '--no-history']]);
  checks++;
}

console.log(`recapture diagnostics: ${checks} pass, 0 fail`);
export const diagnosticChecks = checks;
