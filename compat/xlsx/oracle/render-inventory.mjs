// Existing render IDs and four-shard ownership captured at the baseline commit.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { shardIndex } from '../shard.mjs';
import { lock, sha } from './contract.mjs';
const manifestBytes = await readFile(new URL('./render-ids.manifest', import.meta.url));
export const renderManifestSha = sha(manifestBytes);
const manifest = JSON.parse(manifestBytes);
if (manifest.version !== 1 || manifest.baseline !== lock.baseline || manifest.count !== 144298 || manifest.shards4.length !== 4) throw Error('Invalid render ID manifest');
export function validateRenderIds(raw) {
  const text = Buffer.isBuffer(raw) ? raw.toString('utf8') : raw;
  const ids = text.split('\n').filter(Boolean);
  assert.equal(ids.length, manifest.count, 'render ID count');
  assert.equal(new Set(ids).size, ids.length, 'duplicate render ID');
  assert.equal(sha(text), manifest.sha256, 'render ID order and membership');
  for (let i = 0; i < 4; i++) {
    const own = ids.filter(id => shardIndex(id, 4) === i);
    assert.equal(own.length, manifest.shards4[i].count, `shard ${i} count`);
    assert.equal(sha(own.length ? own.join('\n') + '\n' : ''), manifest.shards4[i].sha256, `shard ${i} membership`);
  }
  return ids.length;
}
