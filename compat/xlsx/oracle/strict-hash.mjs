// Type-framed digest equivalent to deep equality for JSON values. Arrays keep
// their order; object keys are sorted because deep equality ignores key order.
// In particular, IEEE -0 and +0 must remain distinguishable.
import { createHash } from 'node:crypto';
export function strictSha(value) {
  const hash = createHash('sha256');
  function visit(item) {
    if (item === null) { hash.update('n;'); return; }
    if (typeof item === 'boolean') { hash.update(item ? 'b1;' : 'b0;'); return; }
    if (typeof item === 'number') { hash.update('d' + (Object.is(item, -0) ? '-0' : String(item)) + ';'); return; }
    if (typeof item === 'string') { const encoded = JSON.stringify(item); hash.update(`s${encoded.length}:`); hash.update(encoded); return; }
    if (Array.isArray(item)) { hash.update(`a${item.length}[`); for (const child of item) visit(child); hash.update(']'); return; }
    if (typeof item === 'object' && Object.getPrototypeOf(item) === Object.prototype) {
      const keys = Object.keys(item).sort(); hash.update(`o${keys.length}{`);
      for (const key of keys) { visit(key); visit(item[key]); } hash.update('}'); return;
    }
    throw Error('Strict hash accepts JSON values only');
  }
  visit(value); return hash.digest('hex');
}
