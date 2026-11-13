import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { cpSync, mkdtempSync, mkdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

const root = process.cwd();
const gitDir = execFileSync('git', ['rev-parse', '--absolute-git-dir'], { encoding: 'utf8' }).trim();
function fixture(fn) {
  const dir = mkdtempSync(join(tmpdir(), 'bdf-roadmap-test-'));
  try {
    for (const part of ['docs', 'issues']) cpSync(join(root, part), join(dir, part), { recursive: true });
    const run = () => spawnSync(process.execPath, [join(root, '.github/local/validate-roadmap.mjs')], {
      cwd: dir, encoding: 'utf8',
      env: { ...process.env, GIT_DIR: gitDir, GIT_WORK_TREE: dir, ROADMAP_BASE: 'HEAD' },
    });
    fn(dir, run);
  } finally { rmSync(dir, { recursive: true, force: true }); }
}
test('roadmap covers open, polished and done issue directories', () => fixture((dir, run) => {
  const result = run();
  assert.equal(result.status, 0, result.stdout + result.stderr);
}));
test('done issue acceptance remains enforced after state-directory migration', () => fixture((dir, run) => {
  const file = join(dir, 'issues/done/20261109-native-recon.md');
  writeFileSync(file, readFileSync(file, 'utf8').replace('- [x]', '- [ ]'));
  const result = run();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /done but has 1 unchecked acceptance item/);
}));
test('duplicate filenames across state directories are rejected', () => fixture((dir, run) => {
  const name = '20261109-native-recon.md';
  mkdirSync(join(dir, 'issues/doing'), { recursive: true });
  cpSync(join(dir, 'issues/done', name), join(dir, 'issues/doing', name));
  const result = run();
  assert.equal(result.status, 1);
  assert.match(result.stderr, /duplicate issue filename/);
}));
