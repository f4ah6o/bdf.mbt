import { bdf_create_native_converter, bdf_create_viewer } from './browser.js';

const $ = selector => document.querySelector(selector);
const file = $('#file');
const status = $('#status');
const view = $('#view');
const pageNumber = $('#page-number');
const download = $('#download');
const converter = bdf_create_native_converter(new URL('./native_converter_worker.js', import.meta.url).href);
const viewer = bdf_create_viewer($('#preview'), { workerUrl: new URL('./render_worker.js', import.meta.url).href, layout: 'single', find: false });
let currentPage = 0;
let downloadUrl;
let busy = false;
let selection = 0;
let scrollFrame = 0;

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
async function openBytes(name, input) {
  if (busy) return;
  setBusy(true);
  updatePage();
  say(`${name} を開いています…`);
  try {
    let bytes = input;
    let summary = '';
    let warnings = [];
    if (!name.toLowerCase().endsWith('.bdf')) {
      await converter.ready;
      const result = await converter.convert(input, { name });
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
    say(warnings.length ? warnings.join(' · ') : `${name} を表示しています。`);
  } catch (error) {
    say(`${name} を開けませんでした: ${error.message ?? error}`, true);
  } finally {
    setBusy(false);
    updatePage();
  }
}
async function openSample(path, name) {
  if (busy) return;
  const token = ++selection;
  try {
    const response = await fetch(new URL(path, import.meta.url));
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const bytes = new Uint8Array(await response.arrayBuffer());
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
  docx: ['./samples/simple.docx', 'simple.docx'],
};
for (const link of document.querySelectorAll('[data-sample]')) {
  link.addEventListener('click', event => {
    if (busy) { event.preventDefault(); return; }
    const sample = samples[link.dataset.sample];
    if (sample) void openSample(...sample);
  });
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
