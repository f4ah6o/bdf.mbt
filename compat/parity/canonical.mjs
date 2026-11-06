// Canonical form of a BDF document for upstream parity tests.
//
// The Go and MoonBit converters may embed fonts with different WOFF2 bytes,
// so the font part hash of a FONT record is replaced by its family, weight
// and style. Image parts are keyed by decoded PNG pixels and object image
// references are rewritten to those keys. Everything else is kept, including
// object child order, path and paint resources, MARK/LINK/ALT instructions
// and the text index.

import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import {
  BdfDocument,
  BufferSource,
  decodeTextIndex,
  walk,
  NoopSink,
} from '@bdfkit/core';

const require = createRequire(import.meta.url);
const { PNG } = require('pngjs');

const OP_NAMES = Object.getOwnPropertyNames(NoopSink.prototype)
  .filter(name => name !== 'constructor');

function numbers(value) {
  return Array.from(value, n => number(n));
}

function number(value) {
  if (typeof value !== 'number') return value;
  if (Number.isNaN(value)) return 'NaN';
  if (value === Infinity) return 'Infinity';
  if (value === -Infinity) return '-Infinity';
  return value;
}

function rect(value) {
  if (!value) return value;
  return { x: number(value.x), y: number(value.y), w: number(value.w), h: number(value.h) };
}

function pathData(paths) {
  return paths.map(path => ({ verbs: Array.from(path.verbs), args: numbers(path.args) }));
}

function stable(value) {
  if (value === null || typeof value !== 'object') return value;
  if (Array.isArray(value)) return value.map(stable);
  if (ArrayBuffer.isView(value)) return Array.from(value);
  const keys = Object.keys(value).sort();
  const out = {};
  for (const key of keys) out[key] = stable(value[key]);
  return out;
}

export function digest(value) {
  return createHash('sha256').update(JSON.stringify(stable(value))).digest('hex');
}

function recordOps(object, imageKeys) {
  const calls = [];
  const sink = {};
  for (const name of OP_NAMES) {
    sink[name] = (...args) => {
      const values = args.map(normalizeArg);
      if ((name === 'image' || name === 'imageSub') && typeof values[0] === 'number') {
        values[0] = imageKeys[values[0]] ?? 'image:' + values[0];
      }
      calls.push([name, ...values]);
    };
  }
  walk(object, sink);
  return calls;
}

async function imageKey(doc, hash, cache) {
  if (cache.has(hash)) return cache.get(hash);
  const data = await doc.part(hash);
  let key;
  if (data.length >= 8 &&
    data[0] === 0x89 && data[1] === 0x50 && data[2] === 0x4e && data[3] === 0x47) {
    try {
      const png = PNG.sync.read(Buffer.from(data));
      const pixels = createHash('sha256').update(png.data).digest('hex');
      key = 'png:' + png.width + 'x' + png.height + ':' + pixels;
    } catch {
      key = 'bytes:' + createHash('sha256').update(data).digest('hex');
    }
  } else {
    key = 'bytes:' + createHash('sha256').update(data).digest('hex');
  }
  cache.set(hash, key);
  return key;
}

function normalizeArg(value) {
  if (typeof value === 'number') return number(value);
  if (Array.isArray(value)) {
    if (value.length && typeof value[0] === 'object' && value[0] && 'path' in value[0]) {
      return value.map(g => ({ path: g.path, x: number(g.x), y: number(g.y) }));
    }
    return value.map(normalizeArg);
  }
  if (ArrayBuffer.isView(value)) return Array.from(value);
  return value;
}

async function canonicalObject(doc, hash, cache, stack, imageCache) {
  if (cache.has(hash)) return cache.get(hash);
  if (stack.has(hash)) return { cycle: hash };
  const object = await doc.object(hash);
  stack.add(hash);
  const objects = [];
  for (const child of object.objects) {
    objects.push(await canonicalObject(doc, child, cache, stack, imageCache));
  }
  const paths = [];
  for (const path of object.paths) {
    if (path.inline) {
      paths.push({ inline: pathData([path.inline])[0] });
    } else {
      const collection = await doc.pathCollection(path.hash);
      paths.push({ collection: pathData(collection), index: path.index });
    }
  }
  stack.delete(hash);
  const imageKeys = [];
  for (const image of object.images) {
    imageKeys.push(await imageKey(doc, image, imageCache));
  }
  const canon = {
    opset: object.opset,
    bbox: rect(object.bbox),
    strings: object.strings,
    paths,
    paints: object.paints.map(paint => ({
      kind: paint.kind,
      coords: numbers(paint.coords),
      stops: paint.stops.map(stop => ({ offset: number(stop.offset), color: stop.color })),
      image: paint.image >= 0 ? imageKeys[paint.image] ?? 'image:' + paint.image : paint.image,
      repeat: paint.repeat,
      matrix: numbers(paint.matrix),
    })),
    // A font part's bytes differ between the encoders; its face does not.
    fonts: object.fonts.map(font => ({
      kind: font.kind,
      family: font.family,
      weight: font.weight,
      style: font.style,
    })),
    images: imageKeys.slice().sort(),
    objects,
    ops: recordOps(object, imageKeys),
  };
  cache.set(hash, canon);
  return canon;
}

export async function canonicalize(bytes) {
  const doc = await BdfDocument.open(new BufferSource(bytes));
  const manifest = doc.manifest;
  const objectCache = new Map();
  const imageCache = new Map();
  const views = [];
  for (const view of manifest.views) {
    const runs = view.textIndex
      ? decodeTextIndex(await doc.part(view.textIndex))
      : null;
    const pages = [];
    for (const page of view.pages ?? []) {
      const layers = [];
      for (const layer of page.layers) {
        layers.push({
          role: layer.role,
          obj: await canonicalObject(doc, layer.obj, objectCache, new Set(), imageCache),
        });
      }
      pages.push({ w: number(page.w), h: number(page.h), body: rect(page.body), layers });
    }
    const tiles = {};
    for (const [key, hash] of Object.entries(view.tiles ?? {})) {
      tiles[key] = await canonicalObject(doc, hash, objectCache, new Set(), imageCache);
    }
    views.push({
      id: view.id,
      kind: view.kind,
      title: view.title ?? null,
      textIndex: runs,
      pages,
      continuous: view.continuous ?? null,
      direction: view.direction ?? null,
      tile: view.tile ?? null,
      cols: view.cols ?? null,
      rows: view.rows ?? null,
      freeze: view.freeze ?? null,
      gridlines: view.gridlines ?? null,
      tiles,
      play: view.play ?? null,
    });
  }
  // Object and path parts are compared through the decoded instructions and
  // paths; their hashes merely follow the content. Font parts differ in their
  // WOFF2 bytes between the encoders, so only their count is compared. The
  // remaining resources (images, indexes, tables, sequences) are compared by
  // content hash: compression choices do not matter.
  const resources = [];
  for (const part of manifest.parts) {
    if (['obj', 'path', 'font'].includes(part.t)) continue;
    const hash = part.t === 'img'
      ? await imageKey(doc, part.h, imageCache)
      : part.h;
    resources.push({ t: part.t, h: hash });
  }
  resources.sort((a, b) => JSON.stringify(a).localeCompare(JSON.stringify(b)));
  const fontCount = manifest.parts.filter(part => part.t === 'font').length;
  return {
    bdf: manifest.bdf,
    opset: manifest.opset,
    unit: manifest.unit,
    meta: manifest.meta ?? null,
    views,
    parts: { fontCount, resources },
    tables: manifest.tables ?? null,
  };
}

function equalNumber(a, b, tolerance) {
  if (a === 'NaN' && b === 'NaN') return true;
  if (typeof a !== 'number' || typeof b !== 'number') return a === b;
  if (a === b) return true;
  return Math.abs(a - b) <= tolerance;
}

function compareValue(a, b, path, tolerance, out, limit) {
  if (out.length >= limit) return;
  if (a === b) return;
  if (typeof a === 'number' || typeof b === 'number') {
    if (!equalNumber(a, b, tolerance)) out.push({ path, upstream: a, moon: b });
    return;
  }
  if (a === null || b === null || typeof a !== 'object' || typeof b !== 'object') {
    out.push({ path, upstream: a, moon: b });
    return;
  }
  if (Array.isArray(a) !== Array.isArray(b)) {
    out.push({ path, upstream: Array.isArray(a) ? 'array' : typeof a, moon: Array.isArray(b) ? 'array' : typeof b });
    return;
  }
  if (Array.isArray(a)) {
    if (a.length !== b.length) {
      out.push({ path: path + '.length', upstream: a.length, moon: b.length });
      if (out.length >= limit) return;
    }
    const end = Math.min(a.length, b.length);
    for (let i = 0; i < end && out.length < limit; i++) {
      compareValue(a[i], b[i], path + '[' + i + ']', tolerance, out, limit);
    }
    return;
  }
  const keys = new Set([...Object.keys(a), ...Object.keys(b)]);
  for (const key of [...keys].sort()) {
    if (out.length >= limit) return;
    if (!(key in a) || !(key in b)) {
      out.push({ path: path + '.' + key, upstream: key in a ? a[key] : '<missing>', moon: key in b ? b[key] : '<missing>' });
      continue;
    }
    compareValue(a[key], b[key], path + '.' + key, tolerance, out, limit);
  }
}

export function compareCanonical(upstream, moon, options = {}) {
  const tolerance = options.tolerance ?? 0.01;
  const limit = options.limit ?? 80;
  const diffs = [];
  compareValue(upstream, moon, '$', tolerance, diffs, limit);
  return diffs;
}
