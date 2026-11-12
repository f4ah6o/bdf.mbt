import assert from 'node:assert/strict';
import { test } from 'node:test';
import { mkdtempSync, mkdirSync, cpSync, symlinkSync, readFileSync, writeFileSync, rmSync, readdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

test('custom output cannot bypass fixed staging scratch symlink checks', () => {
  const owned = mkdtempSync(join(tmpdir(), 'bdf-pack-scratch-'));
  try {
    for (const [tool, scratch] of [['pack.mjs', 'plugin-pack'], ['library-pack.mjs', 'library-pack']]) {
      const root = join(owned, scratch);
      mkdirSync(join(root, 'plugin/tools'), {recursive: true});
      mkdirSync(join(root, '_scratch'));
      mkdirSync(join(root, 'safe-output'));
      const target = join(owned, `sentinel-${scratch}`);
      mkdirSync(target); writeFileSync(join(target, 'keep.txt'), 'unchanged');
      symlinkSync(target, join(root, '_scratch', scratch));
      for (const file of [tool, 'staging-path.mjs']) cpSync(resolve(import.meta.dirname, '../tools', file), join(root, 'plugin/tools', file));
      const run = spawnSync(process.execPath, [join(root, 'plugin/tools', tool), '--out', 'safe-output'], {cwd: root, encoding: 'utf8'});
      assert.notEqual(run.status, 0);
      assert.match(run.stderr, /staging scratch.*symbolic link|symbolic link/);
      assert.equal(readFileSync(join(target, 'keep.txt'), 'utf8'), 'unchanged');
      assert.deepEqual(readdirSync(target), ['keep.txt']);
      assert.deepEqual(readdirSync(join(root, 'safe-output')), []);
    }
  } finally { rmSync(owned, {recursive: true, force: true}); }
});
