// Fail-closed tests: no Go binary is executed and no output is accepted.
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, existsSync, rmSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createHash } from 'node:crypto';
const root = mkdtempSync(join(tmpdir(), 'oracle-rejection-'));
const script = new URL('./generate-oracle.mjs', import.meta.url).pathname;
const binary = Buffer.from('not executable: rejection must precede invocation');
const identity = {
  version: 1, upstream: 'a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22', go: 'go1.27.0',
  goFlags: '', goExperiment: '', goWork: 'off', goEnv: 'off',
  goos: 'linux', goarch: 'amd64', goamd64: 'v3',
  binarySha256: createHash('sha256').update(binary).digest('hex'), adapters: {}, seeds: {},
};
const cases = [
  [{ version: 2 }, /Unexpected oracle identity/],
  [{ upstream: 'other' }, /Unexpected oracle identity/],
  [{ go: 'go1.26.0' }, /Unexpected oracle identity/],
  [{ goEnv: 'on' }, /Unpinned build environment/],
  [{ goarch: 'unknown' }, /Unsupported oracle platform/],
  [{ goarch: 'arm64', goarm64: 'v9.0' }, /Unpinned ARM64 profile/],
  [{ goamd64: 'v2' }, /Unpinned AMD64 profile/],
  [{ binarySha256: '0'.repeat(64) }, /Oracle binary integrity failure/],
  [{ adapters: { '../outside.go': '0'.repeat(64) } }, /Invalid adapter path/],
  [{ adapters: { 'generate_formatted_test.go': '0'.repeat(64) } }, /Adapter changed/],
  [{}, /Adapter inventory mismatch/],
];
try {
  writeFileSync(join(root, 'xlsx-oracle.test'), binary);
  for (const [index, [change, message]] of cases.entries()) {
    writeFileSync(join(root, 'identity.json'), JSON.stringify({ ...identity, ...change }));
    const output = join(root, `output-${index}`);
    const result = spawnSync(process.execPath, [script, '--build', root, '--output', output], { encoding: 'utf8' });
    assert.equal(result.status, 1, `case ${index}`);
    assert.match(result.stderr, message);
    assert.equal(existsSync(output), false, `case ${index} created output before rejecting identity`);
  }
  console.log(`${cases.length} oracle pre-execution identity rejection checks PASS`);
} finally {
  rmSync(root, { recursive: true, force: true });
}
