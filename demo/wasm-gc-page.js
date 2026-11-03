import { bdf_create_viewer } from './browser.js';
import { createExportUI } from './export-ui.js';
import { base64ToBytes, bytesToBase64, createWasm } from './wasm-gc.js';

const $ = selector => document.querySelector(selector);
const viewer = bdf_create_viewer($('#preview'), {
  workerUrl: new URL('./render_worker.js', import.meta.url).href,
  layout: 'single',
  find: false,
});
let currentPage = 0;
let sampleBytes = null;
let wasmPromise = null;
let exportUI = null;

function say(message, error = false) {
  const status = $('#wasm-status');
  status.textContent = message;
  status.classList.toggle('error', error);
}

function pageCount() {
  return viewer.view?.pages?.length ?? 0;
}

function updatePage() {
  const count = pageCount();
  currentPage = Math.max(0, Math.min(currentPage, Math.max(0, count - 1)));
  $('#page-number').textContent = count ? `${currentPage + 1} / ${count}` : '–';
  $('#previous').disabled = count === 0 || currentPage === 0;
  $('#next').disabled = count === 0 || currentPage + 1 >= count;
}

function setDownload(bytes, name) {
  const link = $('#download');
  if (link.href) URL.revokeObjectURL(link.href);
  link.href = URL.createObjectURL(new Blob([bytes], { type: 'application/octet-stream' }));
  link.download = name;
  link.hidden = false;
}

async function openBdf(name, bytes) {
  $('#status').textContent = name + ' を表示しています…';
  const manifest = await viewer.open({ kind: 'buffer', buffer: bytes.slice().buffer });
  viewer.stage.scrollTop = 0;
  viewer.stage.scrollLeft = 0;
  currentPage = 0;
  $('#document-name').textContent = name;
  $('#document-meta').textContent = 'wasm-gc';
  setDownload(bytes, name);
  window.bdfDemo = {
    name,
    bytes: bytes.slice(),
    viewer,
    goToPage(page) {
      currentPage = page;
      updatePage();
      viewer.scrollToPage(page);
    },
  };
  document.dispatchEvent(new CustomEvent('bdf:document', { detail: { name } }));
  updatePage();
  $('#status').textContent = `${name} を表示しています（${manifest.views.length} ビュー）`;
}

async function loadSample() {
  if (sampleBytes) return openBdf('upstream-demo.bdf', sampleBytes);
  const response = await fetch('./samples/upstream-demo.bdf');
  if (!response.ok) throw new Error('サンプルを読み込めませんでした: HTTP ' + response.status);
  sampleBytes = new Uint8Array(await response.arrayBuffer());
  return openBdf('upstream-demo.bdf', sampleBytes);
}

function getWasm() {
  if (!wasmPromise) {
    wasmPromise = createWasm('./wasm-gc.wasm').then(wasm => {
      say('wasm-gc の準備ができました');
      $('#pdf-convert').disabled = !$('#pdf-file').files?.length;
      return wasm;
    }).catch(error => {
      wasmPromise = null;
      say(String(error.message ?? error), true);
      throw error;
    });
  }
  return wasmPromise;
}

$('#sample-bdf').addEventListener('click', () => { void loadSample().catch(error => say(String(error.message ?? error), true)); });
$('#pdf-file').addEventListener('change', () => {
  const file = $('#pdf-file').files?.[0];
  $('#pdf-convert').disabled = !file;
  if (file) say(file.name + ' を変換できます');
});
$('#pdf-convert').addEventListener('click', async () => {
  const file = $('#pdf-file').files?.[0];
  if (!file) return say('PDF ファイルを選んでください', true);
  $('#pdf-convert').disabled = true;
  say('PDF を wasm-gc で変換しています…');
  try {
    const bytes = new Uint8Array(await file.arrayBuffer());
    const wasm = await getWasm();
    const result = wasm.convertPdf(bytesToBase64(bytes), $('#pdf-password').value);
    if (!result.ok) throw new Error(result.error ?? 'PDF を変換できませんでした');
    await openBdf(file.name.replace(/\.pdf$/i, '.bdf'), base64ToBytes(result.bdf));
    say(file.name + ' → BDF（' + result.pages + ' ページ）');
  } catch (error) {
    say(String(error.message ?? error), true);
  } finally {
    $('#pdf-convert').disabled = !$('#pdf-file').files?.length;
  }
});

$('#previous').addEventListener('click', () => { currentPage -= 1; updatePage(); viewer.scrollToPage(currentPage); });
$('#next').addEventListener('click', () => { currentPage += 1; updatePage(); viewer.scrollToPage(currentPage); });
viewer.stage.addEventListener('scroll', () => {
  requestAnimationFrame(() => {
    const top = viewer.stage.getBoundingClientRect().top;
    const visible = [...viewer.stage.querySelectorAll('[data-bdf-page]')].find(frame => frame.getBoundingClientRect().bottom > top + 2);
    if (visible) {
      currentPage = Number(visible.dataset.bdfPage);
      updatePage();
    }
  });
});
viewer.addEventListener('error', event => {
  event.preventDefault();
  say('表示できませんでした: ' + (event.detail?.message ?? event.detail), true);
});
window.addEventListener('pagehide', event => {
  if (!event.persisted) {
    viewer.destroy();
    if ($('#download').href) URL.revokeObjectURL($('#download').href);
  }
});

const root = $('#exports');
if (root) {
  exportUI = createExportUI({
    root,
    getDocument: () => window.bdfDemo,
    getViewer: () => window.bdfDemo?.viewer,
    loadApi: () => getWasm(),
  });
}

void loadSample().catch(error => say(String(error.message ?? error), true));
getWasm().catch(() => {});
