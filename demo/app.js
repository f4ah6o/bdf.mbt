import { bdf_create_native_converter, bdf_create_viewer } from './browser.js';

const $ = selector => document.querySelector(selector);
const file = $('#file');
const status = $('#status');
const view = $('#view');
const pageNumber = $('#page-number');
const download = $('#download');
const pdfPassword = $('#pdf-password');
const pdfRetry = $('#pdf-retry');
const pdfUnlockStatus = $('#pdf-unlock-status');
const converter = bdf_create_native_converter(new URL('./native_converter_worker.js', import.meta.url).href);
const viewer = bdf_create_viewer($('#preview'), { workerUrl: new URL('./render_worker.js', import.meta.url).href, layout: 'single', find: false });
window.bdfViewer = viewer;
let currentPage = 0;
let downloadUrl;
let busy = false;
let selection = 0;
let scrollFrame = 0;
let lastOpen = null;

function say(message, error = false) {
  status.textContent = message;
  status.classList.toggle('error', error);
}
function setBusy(value) {
  busy = value;
  file.disabled = value;
  $('#open-file').disabled = value;
  $('#sample').disabled = value;
  $('#csv-sample').disabled = value;
  if (pdfPassword) pdfPassword.disabled = value;
  if (pdfRetry) pdfRetry.disabled = value || !lastOpen;
  for (const link of document.querySelectorAll('[data-sample]')) link.setAttribute('aria-disabled', String(value));
  view.disabled = value || !viewer.document;
}
function pageCount() { return viewer.view?.pages?.length ?? 0; }
function updatePage() {
  const count = pageCount();
  currentPage = Math.max(0, Math.min(currentPage, Math.max(0, count - 1)));
  pageNumber.textContent = count ? `${currentPage + 1} / ${count}` : '–';
  $('#previous').disabled = busy || count === 0 || currentPage === 0;
  $('#next').disabled = busy || count === 0 || currentPage + 1 >= count;
}
function setDownload(bytes, name) {
  if (downloadUrl) URL.revokeObjectURL(downloadUrl);
  downloadUrl = URL.createObjectURL(new Blob([bytes], { type: 'application/octet-stream' }));
  download.href = downloadUrl;
  download.download = name.replace(/\.[^.]+$/, '') + '.bdf';
  download.hidden = false;
}
function showViews(manifest) {
  view.replaceChildren(...manifest.views.map(item => {
    const option = document.createElement('option'); option.value = item.id; option.textContent = item.title || item.id; return option;
  }));
  view.value = viewer.view?.id ?? manifest.views[0]?.id ?? '';
  currentPage = 0;
  updatePage();
}
async function openBytes(name, input, retry = false) {
  if (busy) return;
  if (!retry) {
    lastOpen = null;
    if (pdfRetry) pdfRetry.disabled = true;
    if (pdfUnlockStatus) {
      pdfUnlockStatus.textContent = '暗号化 PDF はここに入力してください。サンプルのパスワードは demo です。';
      pdfUnlockStatus.classList.remove('error');
    }
  }
  setBusy(true);
  updatePage();
  say(`${name} を開いています…`);
  const isPdf = name.toLowerCase().endsWith('.pdf');
  try {
    let bytes = input;
    let summary = '';
    let warnings = [];
    if (!name.toLowerCase().endsWith('.bdf')) {
      await converter.ready;
      const options = { name };
      const password = isPdf && pdfPassword ? pdfPassword.value : '';
      if (password) options.params = { password };
      const result = await converter.convert(input, options);
      bytes = result.bdf;
      summary = result.summary ?? '';
      warnings = result.warnings ?? [];
    }
    const manifest = await viewer.open({ kind: 'buffer', buffer: bytes.slice().buffer });
    viewer.stage.scrollTop = 0;
    viewer.stage.scrollLeft = 0;
    $('#document-name').textContent = name;
    $('#document-meta').textContent = summary;
    $('#search').value = '';
    $('#search-status').textContent = '';
    showViews(manifest);
    setDownload(bytes, name);
    window.bdfDemo = {
      name,
      bytes: bytes.slice(),
      viewer,
      goToPage(page) { currentPage = page; updatePage(); viewer.scrollToPage(page); },
    };
    document.dispatchEvent(new CustomEvent('bdf:document', { detail: { name } }));
    say(warnings.length ? warnings.join(' · ') : `${name} を表示しています。`);
    if (isPdf) {
      lastOpen = null;
      if (pdfRetry) pdfRetry.disabled = true;
      if (pdfPassword) pdfPassword.value = '';
      if (pdfUnlockStatus) {
        pdfUnlockStatus.textContent = 'PDF を開きました。';
        pdfUnlockStatus.classList.remove('error');
      }
    }
  } catch (error) {
    const message = String(error.message ?? error);
    if (isPdf && /password|encrypted/i.test(message)) {
      lastOpen = { name, input };
      if (pdfRetry) pdfRetry.disabled = false;
      if (pdfPassword) pdfPassword.focus();
      if (pdfUnlockStatus) {
        pdfUnlockStatus.textContent = /incorrect/i.test(message)
          ? 'パスワードが正しくありません。確認して再変換してください。'
          : 'この PDF は暗号化されています。パスワードを入力して再変換してください。';
        pdfUnlockStatus.classList.add('error');
      }
      say(pdfUnlockStatus?.textContent ?? 'PDF のパスワードを入力してください。', true);
    } else {
      say(`${name} を開けませんでした: ${message}`, true);
    }
  } finally {
    setBusy(false);
    updatePage();
  }
}
async function openSample(path, name, password = '') {
  if (busy) return;
  const token = ++selection;
  try {
    const response = await fetch(new URL(path, import.meta.url));
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (pdfPassword) pdfPassword.value = password;
    if (pdfUnlockStatus) {
      pdfUnlockStatus.textContent = password
        ? `サンプルのパスワード ${password} を使用します。`
        : '暗号化 PDF はここに入力してください。サンプルのパスワードは demo です。';
      pdfUnlockStatus.classList.remove('error');
    }
    if (token === selection) await openBytes(name, bytes);
  } catch (error) { if (token === selection) say(`サンプルを読み込めませんでした: ${error.message ?? error}`, true); }
}
$('#open-file').addEventListener('click', () => file.click());
async function openLocal(selected) {
  if (!selected || busy) return;
  const token = ++selection;
  try {
    const bytes = new Uint8Array(await selected.arrayBuffer());
    if (token === selection) await openBytes(selected.name, bytes);
  } catch (error) { if (token === selection) say(`${selected.name} を読み込めませんでした: ${error.message ?? error}`, true); }
}
const preview = $('#preview');
preview.addEventListener('dragover', event => { if ([...event.dataTransfer.types].includes('Files')) { event.preventDefault(); preview.classList.add('dragging'); } });
preview.addEventListener('dragleave', event => { if (!preview.contains(event.relatedTarget)) preview.classList.remove('dragging'); });
preview.addEventListener('drop', event => { event.preventDefault(); preview.classList.remove('dragging'); void openLocal(event.dataTransfer.files[0]); });
file.addEventListener('change', async () => {
  const selected = file.files?.[0];
  file.value = '';
  await openLocal(selected);
});
const samples = {
  bdf: ['./samples/upstream-demo.bdf', 'upstream-demo.bdf'],
  csv: ['./samples/people.csv', 'people.csv'],
  xlsx: ['./samples/sales.xlsx', 'sales.xlsx'],
  'xlsx-picture': ['./samples/field-guide.xlsx', 'field-guide.xlsx'],
  image: ['./samples/illustration.svg', 'illustration.svg'],
  font: ['./samples/stix.ttf', 'stix.ttf'],
  pdf: ['./samples/simple.pdf', 'simple.pdf'],
  'pdf-features': ['./samples/pdf-features.pdf', 'pdf-features.pdf'],
  'pdf-encrypted': ['./samples/pdf-encrypted.pdf', 'pdf-encrypted.pdf'],
  docx: ['./samples/simple.docx', 'simple.docx'],
  pptx: ['./samples/simple.pptx', 'simple.pptx'],
  drawio: ['./samples/labels.drawio', 'labels.drawio'],
  parquet: ['./samples/table.parquet', 'table.parquet'],
};
for (const link of document.querySelectorAll('[data-sample]')) {
  link.addEventListener('click', event => {
    if (busy) { event.preventDefault(); return; }
    const sample = samples[link.dataset.sample];
    if (sample) void openSample(...sample, link.dataset.password ?? '');
  });
}
$('#pdf-unlock').addEventListener('submit', event => {
  event.preventDefault();
  if (lastOpen && !busy) void openBytes(lastOpen.name, lastOpen.input, true);
});
if (pdfPassword) {
  pdfPassword.addEventListener('input', () => pdfUnlockStatus?.classList.remove('error'));
}
$('#sample').addEventListener('click', () => openSample('./samples/upstream-demo.bdf', 'upstream-demo.bdf'));
$('#csv-sample').addEventListener('click', () => openSample('./samples/people.csv', 'people.csv'));
view.addEventListener('change', () => { $('#search-status').textContent = ''; viewer.setView(view.value); viewer.stage.scrollTop = 0; viewer.stage.scrollLeft = 0; currentPage = 0; updatePage(); });
$('#layout').addEventListener('change', event => { viewer.setLayout(event.target.value); viewer.scrollToPage(currentPage); updatePage(); });
$('#zoom').addEventListener('change', event => { viewer.setZoom(Number(event.target.value)); viewer.scrollToPage(currentPage); });
$('#previous').addEventListener('click', () => { currentPage--; updatePage(); viewer.scrollToPage(currentPage); });
$('#next').addEventListener('click', () => { currentPage++; updatePage(); viewer.scrollToPage(currentPage); });
$('#search-form').addEventListener('submit', async event => {
  event.preventDefault();
  try {
    const result = await viewer.find($('#search').value);
    $('#search-status').textContent = result.total ? `${result.index + 1} / ${result.total}${result.more ? '+' : ''}` : '0 件';
  } catch (error) { say(`検索できませんでした: ${error.message ?? error}`, true); }
});
viewer.stage.addEventListener('scroll', () => {
  if (scrollFrame || !pageCount()) return;
  scrollFrame = requestAnimationFrame(() => {
    scrollFrame = 0;
    const top = viewer.stage.getBoundingClientRect().top;
    const visible = [...viewer.stage.querySelectorAll('[data-bdf-page]')].find(frame => frame.getBoundingClientRect().bottom > top + 2);
    if (visible) { currentPage = Number(visible.dataset.bdfPage); updatePage(); }
  });
});
viewer.addEventListener('error', event => { event.preventDefault(); say(`表示できませんでした: ${event.detail?.message ?? event.detail}`, true); });
window.addEventListener('pagehide', event => { if (!event.persisted) { viewer.destroy(); converter.terminate(); if (downloadUrl) URL.revokeObjectURL(downloadUrl); } });
if (document.body.dataset.startSample === 'csv') openSample(...samples.csv);
else openSample(...samples.bdf);
