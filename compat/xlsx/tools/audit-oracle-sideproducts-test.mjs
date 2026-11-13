import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { auditSideproducts } from './audit-oracle-sideproducts.mjs';
const hash = x => createHash('sha256').update(JSON.stringify(x)).digest('hex');
const outputs = new Map([['single.json', 'input'], ['three.json', ['a', 'b', 'c']], ['empty.json', []]]);
const inventory = [['single.json', 'single-input', 1, hash('input')], ['three.json', 'input-array', 3, hash(['a', 'b', 'c'])], ['empty.json', 'input-array', 0, hash([])]];
const names = inventory.map(x => x[0]);
assert.equal(auditSideproducts(names, outputs, inventory).length, 3);
assert.throws(() => auditSideproducts([...names, 'new.json'], outputs, inventory), /inventory changed/);
assert.throws(() => auditSideproducts([names[0], names[1], names[1]], outputs, inventory), /inventory changed/);
for (const [name, altered] of [['single.json', 'other'], ['three.json', ['a', 'c', 'b']], ['empty.json', ['new']]]) {
  const changed = new Map(outputs); changed.set(name, altered);
  assert.throws(() => auditSideproducts(names, changed, inventory), /content changed/);
}
console.log('Sideproduct inventory, content and order checks PASS');
