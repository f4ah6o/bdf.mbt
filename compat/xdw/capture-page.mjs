import { BdfDocument, BufferSource } from '@bdfkit/core';
import { PageRenderer } from '@bdfkit/render';

const WORKER_URL = '/_build/js/debug/build/native_converter_worker/native_converter_worker.js';
const state = {
  doc: null,
  renderer: null,
  views: [],
  pages: [],
  textIndexes: new Map(),
};

function convert(bytes, name, timeoutMs) {
  return new Promise((resolve, reject) => {
    const worker = new Worker(WORKER_URL, { type: 'module' });
    const timer = setTimeout(() => {
      worker.terminate();
      reject(new Error(`converter worker timed out after ${timeoutMs} ms`));
    }, timeoutMs);
    const finish = (fn, value) => {
      clearTimeout(timer);
      worker.terminate();
      fn(value);
    };
    worker.onmessage = event => {
      const data = event.data;
      if (data?.id === 0) {
        worker.postMessage({ id: 1, type: 'convert', data: bytes, options: { format: 'xdw', name } });
        return;
      }
      if (data?.ok) finish(resolve, data.result);
      else finish(reject, new Error(data?.error ?? 'conversion failed'));
    };
    worker.onerror = event => finish(reject, new Error(event.message ?? 'converter worker error'));
    worker.postMessage({ id: 0, type: 'init' });
  });
}

async function open(inputUrl, name, timeoutMs) {
  const response = await fetch(inputUrl, { cache: 'no-store' });
  if (!response.ok) throw new Error(`input fetch failed: ${response.status}`);
  const bytes = new Uint8Array(await response.arrayBuffer());
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  const inputSha256 = [...new Uint8Array(digest)].map(byte => byte.toString(16).padStart(2, '0')).join('');
  const result = await convert(bytes, name, timeoutMs);
  const doc = await BdfDocument.open(new BufferSource(new Uint8Array(result.bdf)));
  const renderer = new PageRenderer(doc);
  const views = [];
  const pages = [];
  for (const view of doc.manifest.views) {
    if (!Array.isArray(view.pages)) continue;
    views.push(view);
    for (const [pageIndex, page] of view.pages.entries()) {
      pages.push({ viewIndex: views.length - 1, pageIndex, width: page.w, height: page.h });
    }
  }
  state.doc = doc;
  state.renderer = renderer;
  state.views = views;
  state.pages = pages;
  state.textIndexes = new Map();
  return {
    inputSha256,
    format: typeof result.format === 'string' ? result.format : '',
    summary: typeof result.summary === 'string' ? result.summary : '',
    warnings: Array.isArray(result.warnings) ? result.warnings : [],
    views: doc.manifest.views.map(view => ({ id: view.id, kind: view.kind, pages: Array.isArray(view.pages) ? view.pages.length : 0 })),
    pages: pages.map(page => ({ width: page.width, height: page.height })),
  };
}

async function textRuns(viewIndex, pageIndex) {
  const view = state.views[viewIndex];
  if (!view) throw new Error(`unknown view ${viewIndex}`);
  let index = state.textIndexes.get(viewIndex);
  if (!index) {
    index = await state.doc.textIndex(view);
    state.textIndexes.set(viewIndex, index);
  }
  return index
    .filter(run => run.a === pageIndex)
    .map(({ b, ordinal, sep, text }) => ({ b, ordinal, sep, text }));
}

async function renderPage(index, dpi) {
  const entry = state.pages[index];
  if (!entry) throw new Error(`unknown page ${index}`);
  const view = state.views[entry.viewIndex];
  const page = view.pages[entry.pageIndex];
  const scale = dpi / 72;
  const width = Math.ceil(page.w * scale);
  const height = Math.ceil(page.h * scale);
  if (!Number.isSafeInteger(width) || !Number.isSafeInteger(height) || width <= 0 || height <= 0) {
    throw new Error(`invalid page size ${page.w}x${page.h} at ${dpi} dpi`);
  }
  if (width * height > 20_000_000) throw new Error(`page ${index + 1} is ${width}x${height}, over the 20 million pixel limit`);
  const canvas = document.createElement('canvas');
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext('2d');
  if (!ctx) throw new Error('2d canvas context unavailable');
  ctx.fillStyle = '#ffffff';
  ctx.fillRect(0, 0, width, height);
  await state.renderer.preparePage(page);
  await document.fonts.ready;
  await state.renderer.renderPage(ctx, page, { scale, background: '#ffffff' });
  await document.fonts.ready;
  const png = canvas.toDataURL('image/png');
  const runs = await textRuns(entry.viewIndex, entry.pageIndex);
  const fonts = [...document.fonts].map(face => ({ family: face.family, weight: face.weight, style: face.style, status: face.status }));
  return { png, width, height, pageWidth: page.w, pageHeight: page.h, runs, fonts };
}

function close() {
  state.renderer?.dispose();
  state.doc = null;
  state.renderer = null;
  state.views = [];
  state.pages = [];
  state.textIndexes = new Map();
}

window.__xdwCapture = { open, renderPage, close };
window.__xdwCaptureReady = true;
