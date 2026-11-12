import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import { releaseMetadata } from '../tools/release-metadata.mjs';
const sha = 'a'.repeat(40);
test('ordinary staging never becomes publishable', () => {
  assert.equal(releaseMetadata([], 'bdf.mbt'), null);
  assert.throws(() => releaseMetadata(['--source-sha', sha], 'bdf.mbt'));
});
test('release requires exact public identity and provenance', () => {
  const result = releaseMetadata(['--release-version', '2026.11.0', '--source-sha', sha], 'bdf.mbt');
  assert.equal(result.version, '2026.11.0');
  assert.equal(result.private, false);
  assert.equal(result.gitHead, sha);
  assert.equal(result.repository.url, 'git+https://github.com/f4ah6o/bdf.mbt.git');
  assert.equal(result.publishConfig.registry, 'https://registry.npmjs.org/');
  for (const bad of ['', '../2026.11.0', '2026.01.0', '2026.13.0', '2026.11.01', '1.2.3', '2026.11.0-beta']) {
    assert.throws(() => releaseMetadata(['--release-version', bad, '--source-sha', sha], 'bdf.mbt'));
  }
  assert.throws(() => releaseMetadata(['--release-version', '2026.11.0'], 'bdf.mbt'));
  assert.throws(() => releaseMetadata(['--release-version', '2026.11.0', '--source-sha', sha], 'other'));
  assert.throws(() => releaseMetadata(['--release-version', '2026.11.0', '--source-sha', sha, '--staging-version', '1.0.0'], 'bdf.mbt'));
});
test('CalVer metadata accepts semver-compatible month buckets', () => {
  for (let year = 2000; year <= 2100; year++) for (let month = 1; month <= 12; month++) {
    const version = `${year}.${month}.${(year * month) % 97}`;
    assert.equal(releaseMetadata(['--release-version', version, '--source-sha', sha], 'bdf.mbt').version, version);
  }
});
test('release workflow is manual and tokenless, never part of local gates', () => {
  const text = readFileSync(new URL('../../.github/workflows/npm-release.yaml', import.meta.url), 'utf8');
  const on = /^on:\n((?:[ \t].*\n|\n)*)/m.exec(text)[1];
  assert.match(on, /workflow_dispatch/); assert.doesNotMatch(on, /push:|pull_request|schedule/);
  assert.match(on, /default: false/);
  assert.match(text, /f4ah6o\/calver-action@[a-f0-9]{40}/);
  assert.match(text, /format: YYYY.MM.PATCH/); assert.match(text, /timezone: Asia\/Tokyo/);
  assert.match(text, /id-token: write/); assert.match(text, /runs-on: ubuntu-latest/);
  assert.match(text, /git merge-base --is-ancestor/);
  assert.match(text, /test "\$SOURCE_SHA" = "\$GITHUB_SHA"/);
  assert.doesNotMatch(text, /secrets\.|npm run test|moon test/);
  assert.equal((text.match(/if: inputs.publish/g) || []).length, 2);
});

import { selectReleaseVersion } from '../tools/release-version.mjs';
test('only the reserved bootstrap CalVer is skipped', () => {
  assert.equal(selectReleaseVersion('2026.11.0'), '2026.11.1');
  for (let year = 2025; year <= 2030; year++) for (let month = 1; month <= 12; month++) for (let patch = 0; patch < 20; patch++) {
    const value = `${year}.${month}.${patch}`;
    assert.equal(selectReleaseVersion(value), value === '2026.11.0' ? '2026.11.1' : value);
  }
  for (const value of ['', 'v2026.11.0', '2026.11.0\ntag=bad', '2026.011.0', '2026.13.0']) assert.throws(() => selectReleaseVersion(value));
});
