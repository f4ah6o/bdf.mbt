const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];

function toBase64(bytes) {
  let text = '';
  const chunk = 0x8000;
  for (let index = 0; index < bytes.length; index += chunk) {
    text += String.fromCharCode(...bytes.subarray(index, index + chunk));
  }
  return btoa(text);
}

function fromBase64(value) {
  const binary = atob(value);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes;
}

function fileStem(name) {
  return name.replace(/\.[^./\\]+$/, '');
}

function normalize(text) {
  return text
    .normalize('NFKC')
    .toLowerCase()
    .replace(/[\u3041-\u3096]/g, char => String.fromCharCode(char.charCodeAt(0) + 0x60));
}

function tokenize(text) {
  const tokens = [];
  for (const part of normalize(text).split(/[^\p{L}\p{N}]+/u)) {
    if (!part) continue;
    if (/^[\p{Script=Latin}\p{N}]+$/u.test(part)) {
      tokens.push(part);
    } else if (/[\u3040-\u30ff\u3400-\u9fff]/u.test(part)) {
      const chars = [...part];
      if (chars.length === 1) tokens.push(part);
      else for (let index = 0; index + 1 < chars.length; index += 1) tokens.push(chars[index] + chars[index + 1]);
    } else {
      tokens.push(part);
    }
  }
  return tokens;
}

function recordsOf(text) {
  const records = [];
  for (const view of text.views ?? []) {
    const pages = Array.isArray(view.pages) ? view.pages : [];
    if (pages.length === 0 && typeof view.text === 'string') {
      records.push({ id: view.id, page: 1, view: view.id, title: view.title ?? view.id, text: view.text });
      continue;
    }
    for (const page of pages) {
      if (typeof page?.text !== 'string' || page.text === '') continue;
      const number = Number.isFinite(page.page) ? page.page : 1;
      records.push({
        id: view.id + ':' + number,
        page: number,
        view: view.id,
        title: view.title ?? view.id,
        text: page.text,
      });
    }
  }
  return records;
}

function snippet(text, query, length = 180) {
  const normalized = normalize(text);
  const needle = normalize(query);
  let at = needle ? normalized.indexOf(needle) : -1;
  if (at < 0) at = 0;
  const start = Math.max(0, at - 55);
  const end = Math.min(text.length, start + length);
  return (start > 0 ? '…' : '') + text.slice(start, end).replace(/\s+/g, ' ') + (end < text.length ? '…' : '');
}

const crcTable = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function zipFiles(files) {
  const encoder = new TextEncoder();
  const local = [];
  const central = [];
  let offset = 0;
  for (const file of files) {
    const name = encoder.encode(file.name);
    const data = file.bytes instanceof Uint8Array ? file.bytes : new Uint8Array(file.bytes);
    const crc = crc32(data);
    const header = new Uint8Array(30 + name.length);
    const view = new DataView(header.buffer);
    view.setUint32(0, 0x04034b50, true);
    view.setUint16(4, 20, true);
    view.setUint16(6, 0x0800, true);
    view.setUint16(8, 0, true);
    view.setUint16(10, 0, true);
    view.setUint16(12, 0x21, true);
    view.setUint32(14, crc, true);
    view.setUint32(18, data.length, true);
    view.setUint32(22, data.length, true);
    view.setUint16(26, name.length, true);
    view.setUint16(28, 0, true);
    header.set(name, 30);
    local.push(header, data);

    const entry = new Uint8Array(46 + name.length);
    const entryView = new DataView(entry.buffer);
    entryView.setUint32(0, 0x02014b50, true);
    entryView.setUint16(4, 20, true);
    entryView.setUint16(6, 20, true);
    entryView.setUint16(8, 0x0800, true);
    entryView.setUint16(10, 0, true);
    entryView.setUint16(12, 0, true);
    entryView.setUint16(14, 0x21, true);
    entryView.setUint32(16, crc, true);
    entryView.setUint32(20, data.length, true);
    entryView.setUint32(24, data.length, true);
    entryView.setUint16(28, name.length, true);
    entryView.setUint16(30, 0, true);
    entryView.setUint16(32, 0, true);
    entryView.setUint16(34, 0, true);
    entryView.setUint16(36, 0, true);
    entryView.setUint32(38, 0, true);
    entryView.setUint32(42, offset, true);
    entry.set(name, 46);
    central.push(entry);
    offset += header.length + data.length;
  }
  const centralSize = central.reduce((sum, part) => sum + part.length, 0);
  const end = new Uint8Array(22);
  const endView = new DataView(end.buffer);
  endView.setUint32(0, 0x06054b50, true);
  endView.setUint16(4, 0, true);
  endView.setUint16(6, 0, true);
  endView.setUint16(8, files.length, true);
  endView.setUint16(10, files.length, true);
  endView.setUint32(12, centralSize, true);
  endView.setUint32(16, offset, true);
  endView.setUint16(20, 0, true);

  const out = new Uint8Array(offset + centralSize + end.length);
  let at = 0;
  for (const part of [...local, ...central, end]) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}

export function createExportUI({ root, getDocument, getViewer, loadApi, api: suppliedApi }) {
  if (!root) return null;
  const tabs = $$('[role="tab"]', root);
  const panels = $$('[role="tabpanel"]', root);
  const documentName = $('[data-export-document]');
  let api = suppliedApi ?? null;
  let currentText = null;
  let currentSearch = null;
  let index = null;
  let pdfUrl = null;
  let pdfBytes = null;
  let markdownUrl = null;
  let textUrl = null;
  const timings = new Map();

  function status(panel, message, error = false) {
    const node = panel.querySelector('[data-export-status]');
    if (!node) return;
    node.textContent = message;
    node.classList.toggle('error', error);
  }

  function setBusy(panel, busy) {
    for (const button of panel.querySelectorAll('button, select, input')) {
      if (button.dataset.exportKeepEnabled !== undefined) continue;
      button.disabled = busy;
    }
    panel.setAttribute('aria-busy', String(busy));
  }

  function currentDocument() {
    const document = getDocument?.();
    if (!document?.bytes) return null;
    return document;
  }

  function refreshDocument() {
    const document = currentDocument();
    if (documentName) documentName.textContent = document?.name ?? '文書を開いてください';
    for (const panel of panels) {
      const run = panel.querySelector('[data-export-run]');
      if (run) run.disabled = !document || panel.getAttribute('aria-busy') === 'true';
    }
    return document;
  }

  async function resolveApi() {
    if (api) return api;
    if (!loadApi) throw new Error('書き出し API がありません');
    api = await loadApi();
    return api;
  }

  async function duration(panel, label, work) {
    const started = performance.now();
    const value = await work();
    const milliseconds = performance.now() - started;
    timings.set(label, milliseconds);
    const live = document.querySelector('[data-benchmark-live]');
    if (live) {
      live.textContent = [...timings.entries()]
        .map(([name, time]) => name + ' ' + Math.round(time) + ' ms')
        .join(' · ');
    }
    return value;
  }

  function activate(id, focus = false) {
    const target = tabs.find(tab => tab.id === id)?.getAttribute('aria-controls') ?? id;
    for (const tab of tabs) {
      const selected = tab.id === id;
      tab.setAttribute('aria-selected', String(selected));
      tab.tabIndex = selected ? 0 : -1;
      if (selected && focus) tab.focus();
    }
    for (const panel of panels) panel.hidden = panel.id !== target;
    refreshDocument();
  }

  for (const tab of tabs) {
    tab.addEventListener('click', () => activate(tab.id));
    tab.addEventListener('keydown', event => {
      if (event.key !== 'ArrowLeft' && event.key !== 'ArrowRight') return;
      event.preventDefault();
      const index = tabs.indexOf(tab);
      const next = tabs[(index + (event.key === 'ArrowRight' ? 1 : -1) + tabs.length) % tabs.length];
      activate(next.id, true);
    });
  }

  const pdfPanel = $('#panel-pdf', root);
  if (pdfPanel) {
    const warningsNode = $('[data-export-warnings]', pdfPanel);
    const run = $('[data-export-run="pdf"]', pdfPanel);
    run?.addEventListener('click', async () => {
      const document = currentDocument();
      if (!document) return status(pdfPanel, '先にビューアで文書を開いてください', true);
      setBusy(pdfPanel, true);
      status(pdfPanel, 'PDF を書き出しています…');
      try {
        const bridge = await resolveApi();
        const tagged = $('[data-export-tagged]', pdfPanel)?.checked ?? false;
        const result = await duration(pdfPanel, 'PDF', () => bridge.exportPdf(toBase64(document.bytes), tagged));
        if (!result.ok) throw new Error(result.error ?? 'PDF を書き出せませんでした');
        if (pdfUrl) URL.revokeObjectURL(pdfUrl);
        pdfBytes = fromBase64(result.pdf);
        pdfUrl = URL.createObjectURL(new Blob([pdfBytes], { type: 'application/pdf' }));
        const frame = $('[data-export-frame]', pdfPanel);
        if (frame) {
          frame.src = pdfUrl;
          frame.hidden = false;
        }
        const open = $('[data-export-pdf-open]', pdfPanel);
        if (open) open.href = pdfUrl;
        const save = $('[data-export-pdf-save]', pdfPanel);
        if (save) {
          save.href = pdfUrl;
          save.download = fileStem(document.name) + '.pdf';
        }
        const links = $('[data-export-links]', pdfPanel);
        if (links) links.hidden = false;
        const warnings = result.warnings?.length ? '（' + result.warnings.length + ' 件の注意）' : '';
        status(pdfPanel, result.pages + ' ページ、' + result.fonts + ' フォント' + warnings);
        if (warningsNode) warningsNode.textContent = [...new Set(result.warnings ?? [])].join(' / ');
      } catch (error) {
        status(pdfPanel, String(error.message ?? error), true);
      } finally {
        setBusy(pdfPanel, false);
      }
    });
  }

  const mdPanel = $('#panel-md', root);
  if (mdPanel) {
    const run = $('[data-export-run="md"]', mdPanel);
    run?.addEventListener('click', async () => {
      const document = currentDocument();
      if (!document) return status(mdPanel, '先にビューアで文書を開いてください', true);
      setBusy(mdPanel, true);
      status(mdPanel, 'Markdown を書き出しています…');
      try {
        const bridge = await resolveApi();
        const images = $('[data-export-images]', mdPanel)?.value ?? 'zip';
        const result = await duration(mdPanel, 'Markdown', () => bridge.markdown(toBase64(document.bytes), images));
        if (!result.ok) throw new Error(result.error ?? 'Markdown を書き出せませんでした');
        const output = $('[data-export-markdown]', mdPanel);
        if (output) output.value = result.markdown;
        if (markdownUrl) URL.revokeObjectURL(markdownUrl);
        const save = $('[data-export-md-save]', mdPanel);
        const files = result.files ?? [];
        if (images === 'zip' && files.length > 0) {
          const archive = zipFiles([
            { name: fileStem(document.name) + '.md', bytes: new TextEncoder().encode(result.markdown) },
            ...files.map(file => ({ name: file.name, bytes: fromBase64(file.bytes) })),
          ]);
          markdownUrl = URL.createObjectURL(new Blob([archive], { type: 'application/zip' }));
          if (save) {
            save.href = markdownUrl;
            save.download = fileStem(document.name) + '.zip';
            save.textContent = 'Markdown と画像を zip で保存';
            save.hidden = false;
          }
        } else {
          markdownUrl = URL.createObjectURL(new Blob([result.markdown], { type: 'text/markdown;charset=utf-8' }));
          if (save) {
            save.href = markdownUrl;
            save.download = fileStem(document.name) + '.md';
            save.textContent = '保存';
            save.hidden = false;
          }
        }
        status(mdPanel, result.markdown.length + ' 文字、' + result.views + ' ビュー' + (files.length ? '、' + files.length + ' ファイル' : ''));
      } catch (error) {
        status(mdPanel, String(error.message ?? error), true);
      } finally {
        setBusy(mdPanel, false);
      }
    });
  }

  const textPanel = $('#panel-text', root);
  const findPanel = $('#panel-find', root);
  let textPromise = null;

  async function ensureText() {
    if (currentText) return currentText;
    if (textPromise) return textPromise;
    const document = currentDocument();
    if (!document) throw new Error('先にビューアで文書を開いてください');
    textPromise = (async () => {
      const bridge = await resolveApi();
      const result = await duration(textPanel ?? findPanel, 'Text', () => bridge.searchText(toBase64(document.bytes)));
      if (!result.ok) throw new Error(result.error ?? 'テキストを取り出せませんでした');
      currentText = JSON.parse(result.text);
      currentSearch = result;
      const output = $('[data-export-text]', textPanel);
      if (output) output.textContent = JSON.stringify(currentText, null, 2);
      if (textUrl) URL.revokeObjectURL(textUrl);
      textUrl = URL.createObjectURL(new Blob([result.text], { type: 'application/json' }));
      const save = $('[data-export-text-save]', textPanel);
      if (save) {
        save.href = textUrl;
        save.download = fileStem(document.name) + '.json';
        save.hidden = false;
      }
      return currentText;
    })();
    try {
      return await textPromise;
    } finally {
      textPromise = null;
    }
  }

  if (textPanel) {
    const run = $('[data-export-run="text"]', textPanel);
    run?.addEventListener('click', async () => {
      setBusy(textPanel, true);
      status(textPanel, 'ページごとのテキストを取り出しています…');
      try {
        const text = await ensureText();
        status(textPanel, text.views.length + ' ビュー、' + (currentSearch?.pages ?? '?') + ' ページ');
      } catch (error) {
        status(textPanel, String(error.message ?? error), true);
      } finally {
        setBusy(textPanel, false);
      }
    });
  }

  if (findPanel) {
    const input = $('[data-export-find]', findPanel);
    const hits = $('[data-export-hits]', findPanel);
    const run = $('[data-export-find-run]', findPanel);
    let MiniSearch = null;

    async function ensureIndex() {
      if (index) return index;
      const text = await ensureText();
      const module = await import('./minisearch/index.js');
      MiniSearch = module.default;
      index = new MiniSearch({
        fields: ['text', 'title'],
        storeFields: ['page', 'view', 'title'],
        tokenize,
        processTerm: term => term.normalize('NFKC').toLowerCase(),
        searchOptions: { prefix: true, fuzzy: 0.2 },
      });
      index.addAll(recordsOf(text));
      return index;
    }

    function showHits(query) {
      const search = index.search(query);
      if (!hits) return;
      hits.replaceChildren();
      if (search.length === 0) {
        const empty = document.createElement('p');
        empty.className = 'empty';
        empty.textContent = '該当するページはありません。';
        hits.append(empty);
        return;
      }
      for (const hit of search.slice(0, 30)) {
        const record = recordsOf(currentText).find(item => item.id === hit.id);
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'hit';
        const page = Number(hit.page) || 1;
        const title = document.createElement('span');
        title.className = 'hit-page';
        title.textContent = 'p. ' + page;
        const body = document.createElement('span');
        body.className = 'hit-text';
        body.textContent = snippet(record?.text ?? hit.text ?? '', query);
        button.append(title, body);
        button.addEventListener('click', () => {
          const viewer = getViewer?.();
          viewer?.scrollToPage?.(page - 1);
        });
        hits.append(button);
      }
    }

    async function runFind() {
      const query = input?.value.trim() ?? '';
      if (!query) {
        if (hits) hits.replaceChildren();
        return status(findPanel, '検索語を入力してください', true);
      }
      setBusy(findPanel, true);
      status(findPanel, '索引を作っています…');
      try {
        await ensureIndex();
        showHits(query);
        status(findPanel, index.search(query).length + ' 件');
      } catch (error) {
        status(findPanel, String(error.message ?? error), true);
      } finally {
        setBusy(findPanel, false);
      }
    }

    run?.addEventListener('click', runFind);
    input?.addEventListener('keydown', event => {
      if (event.key === 'Enter') {
        event.preventDefault();
        void runFind();
      }
    });
    findPanel.querySelector('[role="tab"]')?.addEventListener('click', () => {
      if (input) input.focus();
    });
  }

  document.addEventListener('bdf:document', () => {
    refreshDocument();
    currentText = null;
    currentSearch = null;
    index = null;
    textPromise = null;
    for (const panel of panels) status(panel, '');
    for (const node of root.querySelectorAll('[data-export-warnings]')) node.textContent = '';
  });
  refreshDocument();
  let lastDocument = null;
  setInterval(() => {
    const document = currentDocument();
    if (document?.bytes !== lastDocument) {
      lastDocument = document?.bytes ?? null;
      refreshDocument();
    }
  }, 400);
  const firstSelected = tabs.find(tab => tab.getAttribute('aria-selected') === 'true') ?? tabs[0];
  if (firstSelected) activate(firstSelected.id);
  return { refresh: refreshDocument };
}
