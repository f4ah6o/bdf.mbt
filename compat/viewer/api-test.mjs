import assert from 'node:assert/strict';
import { createReadStream, existsSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const localBuild = path.join(root, '_build/js/debug/build/browser/browser.js');
if (!existsSync(localBuild)) {
  throw new Error('missing local browser build; run: MOON_HOME=$PWD/.moon-home moon build --target js');
}

// The comparison needs the upstream viewer, its dependencies, the local build,
// and the BDF fixtures the scenarios read. Everything else is refused.
const allowed = [
  '/compat/viewer/',
  '/compat/continuous/',
  '/compat/sheet/',
  '/node_modules/@bdfkit/',
  '/_build/js/debug/build/browser/',
];
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.bdf': 'application/octet-stream',
  '.json': 'application/json',
};
const server = createServer((request, response) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  const file = path.resolve(root, '.' + pathname);
  if (!allowed.some((prefix) => file.startsWith(path.resolve(root, '.' + prefix) + path.sep))) {
    response.writeHead(403).end(); return;
  }
  const stream = createReadStream(file);
  stream.once('error', () => { if (!response.headersSent) response.writeHead(404); response.end(); });
  response.setHeader('Content-Type', types[path.extname(file)] ?? 'application/octet-stream');
  stream.pipe(response);
});
await new Promise((resolve, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolve);
});
const base = 'http://127.0.0.1:' + server.address().port;

const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 900, height: 700 } });
  const browserErrors = [];
  page.on('pageerror', (error) => browserErrors.push(String(error)));
  await page.goto(base + '/compat/viewer/api-test.html', { waitUntil: 'networkidle' });
  const result = await page.evaluate(async () => {
    const { BdfDocument, BufferSource } = await import('@bdfkit/core');
    const { Viewer: UpstreamViewer } = await import('@bdfkit/viewer');
    const moon = await import('/_build/js/debug/build/browser/browser.js');

    const bytes = async (path) => new Uint8Array(await (await fetch(path)).arrayBuffer());
    const [scrollBytes, flowBytes] = await Promise.all([
      bytes('/compat/continuous/scroll.bdf'),
      bytes('/compat/continuous/flow.bdf'),
    ]);
    const scrollDoc = await BdfDocument.open(new BufferSource(scrollBytes));
    const flowDoc = await BdfDocument.open(new BufferSource(flowBytes));

    const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
    const wait = async (check, what) => {
      const start = performance.now();
      while (!check()) {
        if (performance.now() - start > 8000) throw new Error('viewer timed out: ' + what);
        await sleep(10);
      }
    };
    const host = () => {
      const element = document.createElement('div');
      element.style.cssText = 'width:300px;height:240px;position:relative';
      document.body.append(element);
      return element;
    };
    const frames = (viewer) => [...viewer.stage.querySelectorAll('[data-bdf-page]')];
    const ready = (viewer) => frames(viewer).length > 0 &&
      frames(viewer).every((frame) => frame.querySelector('canvas')?.dataset.loaded === 'ready');
    const frameSnapshot = (viewer) => frames(viewer).map((frame) => {
      const canvas = frame.querySelector('canvas');
      return {
        index: frame.dataset.bdfPage,
        style: frame.style.cssText,
        canvas: canvas ? { width: canvas.width, height: canvas.height, loaded: canvas.dataset.loaded } : null,
      };
    });
    const rows = (viewer) => [...viewer.stage.children].map((row) => ({
      children: row.childElementCount,
      style: row.style.cssText,
    }));
    const bar = (hostElement) => hostElement.querySelector('[role=search]');
    const status = (hostElement) => hostElement.querySelector('[role=status]')?.textContent ?? '';
    const marks = (viewer) => [...viewer.stage.querySelectorAll('[data-bdf-hits]')]
      .flatMap((layer) => [...layer.children].map((box) => box.style.cssText));
    const markCount = (viewer) => [...viewer.stage.querySelectorAll('[data-bdf-hits] div')].length;
    const step = (value) => JSON.parse(JSON.stringify(value));

    const eventTypes = ['documentchange', 'viewchange', 'findchange', 'conversionprogress', 'conversiondone', 'error'];
    const summarize = (type, detail) => {
      if (type === 'documentchange' || type === 'conversiondone') return [type, detail.views.map((view) => view.id)];
      if (type === 'viewchange') return [type, detail.id];
      if (type === 'findchange') return [type, step(detail)];
      if (type === 'conversionprogress') return [type, detail.page, detail.pages];
      if (type === 'error') return [type, { name: detail?.name, message: detail?.message }];
      return [type];
    };
    const record = (viewer, events) => {
      for (const type of eventTypes) {
        viewer.addEventListener(type, (event) => events.push(summarize(type, event.detail)));
      }
    };

    // A renderer and its manifest are supplied by the test, so page drawing,
    // search, and location are deterministic and identical for both viewers.
    const makeRenderer = (manifest, log) => {
      const findView = (id) => manifest.views.find((view) => view.id === id);
      const hits = (id, query) => {
        if (query === 'alpha') {
          const count = id === 'second' ? 2 : 3;
          return Array.from({ length: count }, (_, index) => ({
            segments: [{ a: index, b: 0, ordinal: 0, start: index * 10 }],
            context: 'alpha ' + id + ' ' + index,
          }));
        }
        if (query === 'many') {
          return Array.from({ length: 1001 }, (_, index) => ({
            segments: [{ a: 99, b: index, ordinal: 0, start: index }],
            context: 'many ' + index,
          }));
        }
        return [];
      };
      return {
        close: async () => { log.push('close'); },
        open: async (source, password) => { log.push('open:' + (source?.kind ?? '') + ':' + (password ?? '')); return structuredClone(manifest); },
        page: async (id, index, scale) => {
          log.push('page:' + id + ':' + index);
          const page = findView(id)?.pages?.[index];
          if (!page) throw new Error('no page ' + id + ':' + index);
          const canvas = document.createElement('canvas');
          canvas.width = Math.max(1, Math.ceil(page.w * scale));
          canvas.height = Math.max(1, Math.ceil(page.h * scale));
          const context = canvas.getContext('2d');
          context.fillStyle = '#fff';
          context.fillRect(0, 0, canvas.width, canvas.height);
          return createImageBitmap(canvas);
        },
        search: async (id, query, options) => {
          log.push('search:' + id + ':' + query);
          const found = hits(id, query);
          return found.slice(0, options?.limit ?? found.length);
        },
        locate: async (id, list) => {
          log.push('locate:' + id + ':' + list.length);
          return list.map((hit) => {
            const segment = hit.segments[0];
            return [{ a: segment.a, b: 0, x: 5 + (segment.start % 50), y: 7 + (segment.ordinal % 10), w: 20, h: 10 }];
          });
        },
        addPage: async (id, index, buffer) => {
          log.push('addPage:' + id + ':' + index + ':' + new Uint8Array(buffer)[0]);
        },
        replace: async () => { log.push('replace'); return structuredClone(manifest); },
        sheet: async (id, viewport, scale) => {
          log.push('sheet:' + id);
          const canvas = document.createElement('canvas');
          canvas.width = Math.max(1, Math.ceil(viewport.w * scale));
          canvas.height = Math.max(1, Math.ceil(viewport.h * scale));
          return createImageBitmap(canvas);
        },
        terminate: () => { log.push('terminate'); },
      };
    };

    const methodNames = ['show', 'hide', 'open', 'openFile', 'setView', 'setLayout', 'setMusicMode', 'setZoom', 'scrollToPage', 'find', 'openFind', 'clearFind', 'destroy'];
    const getterNames = ['document', 'view', 'pageLayout'];
    const describePrototype = (Viewer) => ({
      name: Viewer.name,
      length: Viewer.length,
      parent: Object.getPrototypeOf(Viewer.prototype) === EventTarget.prototype,
      constructor: Viewer.prototype.constructor === Viewer,
      methods: Object.fromEntries(methodNames.map((name) => {
        const descriptor = Object.getOwnPropertyDescriptor(Viewer.prototype, name);
        return [name, descriptor ? {
          type: typeof descriptor.value,
          name: descriptor.value?.name,
          length: descriptor.value?.length,
          writable: descriptor.writable,
          enumerable: descriptor.enumerable,
          configurable: descriptor.configurable,
        } : null];
      })),
      getters: Object.fromEntries(getterNames.map((name) => {
        const descriptor = Object.getOwnPropertyDescriptor(Viewer.prototype, name);
        return [name, descriptor ? {
          getter: typeof descriptor.get === 'function',
          setter: typeof descriptor.set === 'function',
          enumerable: descriptor.enumerable,
          configurable: descriptor.configurable,
        } : null];
      })),
    });
    const describeElement = (element) => element ? {
      tag: element.tagName,
      role: element.getAttribute('role'),
      label: element.getAttribute('aria-label'),
      tabIndex: element.tabIndex,
      style: element.style.cssText,
    } : null;

    async function run(Viewer) {
      const observations = {};
      const events = [];
      const log = [];
      const hostElement = host();
      const manifest = structuredClone(scrollDoc.manifest);
      const renderer = makeRenderer(manifest, log);
      const viewer = new Viewer(hostElement, { renderer });
      record(viewer, events);
      let lastFindDetail;
      let lastDocumentDetail;
      let lastViewDetail;
      viewer.addEventListener('documentchange', (event) => { lastDocumentDetail = event.detail; });
      viewer.addEventListener('viewchange', (event) => { lastViewDetail = event.detail; });

      observations.shape = {
        prototype: describePrototype(Viewer),
        host: viewer.host === hostElement,
        renderer: viewer.renderer === renderer,
        eventTarget: viewer instanceof EventTarget,
        instance: viewer instanceof Viewer,
        ownMethods: Object.hasOwn(viewer, 'open') || Object.hasOwn(viewer, 'setZoom'),
        ownGetters: Object.hasOwn(viewer, 'document') || Object.hasOwn(viewer, 'view'),
        surface: describeElement(viewer.surface),
        stage: describeElement(viewer.stage),
        stageParent: viewer.stage.parentElement === viewer.surface.firstElementChild,
        stageChild: viewer.surface.firstElementChild?.tagName,
        embeddedDisplay: viewer.surface.style.display,
        initial: {
          document: viewer.document,
          view: viewer.view,
          pageLayout: viewer.pageLayout,
          status: status(hostElement),
          bar: describeElement(bar(hostElement)),
          input: hostElement.querySelector('input') ? {
            type: hostElement.querySelector('input').type,
            placeholder: hostElement.querySelector('input').placeholder,
            aria: hostElement.querySelector('input').getAttribute('aria-label'),
          } : null,
          buttons: [...hostElement.querySelectorAll('[role=search] button')].map((button) => ({
            text: button.textContent,
            title: button.title,
            aria: button.getAttribute('aria-label'),
          })),
        },
      };

      const optionHost = host();
      const optionViewer = new Viewer(optionHost, {
        renderer: makeRenderer(structuredClone(scrollDoc.manifest), []),
        layout: 'spread',
        zoom: 1.5,
        find: false,
      });
      try {
        await optionViewer.open({ kind: 'buffer', buffer: scrollBytes.slice().buffer });
        await wait(() => ready(optionViewer), 'options open');
        observations.options = {
          layout: optionViewer.pageLayout,
          findBar: bar(optionHost) === null,
          frames: frameSnapshot(optionViewer),
          rows: rows(optionViewer),
        };
      } finally {
        optionViewer.destroy();
        optionHost.remove();
      }

      let musicModeError;
      try { viewer.setMusicMode('piano-roll'); }
      catch (error) { musicModeError = { name: error.name, message: error.message }; }
      observations.musicModeError = musicModeError;
      const constructHost = host();
      try {
        try { new Viewer(constructHost, { renderer: makeRenderer(structuredClone(scrollDoc.manifest), []), musicMode: 'piano-roll' }); }
        catch (error) { observations.constructorMusicModeError = { name: error.name, message: error.message }; }
      } finally {
        constructHost.remove();
      }
      observations.constructorMusicModeError ??= null;

      const opened = await viewer.open({ kind: 'buffer', buffer: scrollBytes.slice().buffer }, 'secret');
      await wait(() => ready(viewer), 'open');
      observations.open = {
        manifest: opened.views.map((view) => view.id),
        returnedDocument: opened === viewer.document,
        eventDocument: lastDocumentDetail === viewer.document,
        eventView: lastViewDetail === viewer.view,
        view: viewer.view?.id,
        viewDetail: viewer.view ? { id: viewer.view.id, kind: viewer.view.kind, pages: viewer.view.pages?.length } : null,
        layout: viewer.pageLayout,
        frames: frameSnapshot(viewer),
        rows: rows(viewer),
        scroll: [viewer.stage.scrollWidth, viewer.stage.scrollHeight, viewer.stage.clientWidth, viewer.stage.clientHeight],
        events: step(events),
        log: [...log].sort(),
      };

      const beforeScroll = viewer.stage.scrollTop;
      viewer.scrollToPage(1);
      await sleep(100);
      const scrolled = {
        before: beforeScroll,
        after: viewer.stage.scrollTop,
        frameTop: Math.round(frames(viewer)[1].getBoundingClientRect().top - viewer.stage.getBoundingClientRect().top),
      };
      viewer.scrollToPage(99);
      await sleep(50);
      observations.scrollToPage = { ...scrolled, invalid: viewer.stage.scrollTop };

      viewer.setView('missing');
      await sleep(20);
      observations.missingView = {
        view: viewer.view,
        document: viewer.document?.views.map((view) => view.id),
        children: viewer.stage.childElementCount,
        events: step(events.slice(-1)),
      };
      viewer.setView('scroll');
      await wait(() => ready(viewer), 'restore view');
      observations.restoredView = {
        view: viewer.view?.id,
        eventView: lastViewDetail === viewer.view,
        frames: frameSnapshot(viewer),
        events: step(events.slice(-2)),
      };

      viewer.setLayout('spread');
      await wait(() => ready(viewer), 'spread');
      observations.spread = { layout: viewer.pageLayout, rows: rows(viewer), frames: frameSnapshot(viewer) };
      viewer.setZoom(1.5);
      await wait(() => ready(viewer), 'zoom');
      observations.zoom = { layout: viewer.pageLayout, rows: rows(viewer), frames: frameSnapshot(viewer) };
      const zoomErrors = [];
      for (const value of [0, -1, 9, NaN, Infinity, '2']) {
        try { viewer.setZoom(value); }
        catch (error) { zoomErrors.push({ value: String(value), name: error.name, message: error.message }); }
      }
      observations.zoomErrors = zoomErrors;
      viewer.setLayout('continuous');
      await wait(() => ready(viewer), 'continuous');
      observations.continuous = { layout: viewer.pageLayout, rows: rows(viewer), frames: frameSnapshot(viewer) };
      viewer.setLayout('single');
      viewer.setZoom(1);
      await wait(() => ready(viewer), 'single');

      const outsideShortcut = new KeyboardEvent('keydown', { key: 'f', code: 'KeyF', ctrlKey: true, bubbles: true, cancelable: true });
      document.body.dispatchEvent(outsideShortcut);
      observations.focusKey = { outside: outsideShortcut.defaultPrevented, display: bar(hostElement).style.display };
      viewer.addEventListener('findchange', (event) => { lastFindDetail = event.detail; });
      const first = await viewer.find('alpha');
      await wait(() => markCount(viewer) >= 3, 'alpha marks');
      observations.findFirst = {
        state: first,
        identity: lastFindDetail === first,
        status: status(hostElement),
        marks: marks(viewer),
        scrollTop: viewer.stage.scrollTop,
        events: step(events.filter((event) => event[0] === 'findchange')),
      };
      const next = await viewer.find('alpha');
      await sleep(50);
      const previous = await viewer.find('alpha', -1);
      await sleep(50);
      const same = await viewer.find('alpha', 0);
      await sleep(50);
      observations.findNavigation = { next, previous, same, status: status(hostElement) };
      const none = await viewer.find('no such text');
      await sleep(50);
      observations.findNone = { state: none, status: status(hostElement), marks: markCount(viewer) };
      const many = await viewer.find('many');
      await sleep(100);
      observations.findMany = { state: many, status: status(hostElement), marks: markCount(viewer) };
      viewer.openFind();
      await sleep(20);
      observations.openFind = {
        display: bar(hostElement).style.display,
        focused: document.activeElement === hostElement.querySelector('input'),
        value: hostElement.querySelector('input').value,
      };
      viewer.clearFind();
      await sleep(20);
      observations.clearFind = {
        display: bar(hostElement).style.display,
        status: status(hostElement),
        value: hostElement.querySelector('input').value,
        marks: markCount(viewer),
      };
      const shortcut = new KeyboardEvent('keydown', { key: 'f', code: 'KeyF', ctrlKey: true, bubbles: true, cancelable: true });
      viewer.stage.dispatchEvent(shortcut);
      await sleep(20);
      const input = hostElement.querySelector('input');
      observations.shortcutOpen = {
        prevented: shortcut.defaultPrevented,
        display: bar(hostElement).style.display,
        focused: document.activeElement === input,
      };
      input.value = 'alpha';
      input.dispatchEvent(new InputEvent('input', { bubbles: true }));
      await wait(() => status(hostElement).startsWith('1 / 3'), 'typed search');
      observations.typed = { status: status(hostElement), marks: markCount(viewer) };
      input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
      await wait(() => status(hostElement).startsWith('2 / 3'), 'Enter next');
      observations.enter = { status: status(hostElement) };
      input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', shiftKey: true, bubbles: true, cancelable: true }));
      await wait(() => status(hostElement).startsWith('1 / 3'), 'Shift+Enter previous');
      observations.shiftEnter = { status: status(hostElement) };
      const ctrlG = new KeyboardEvent('keydown', { key: 'g', code: 'KeyG', ctrlKey: true, bubbles: true, cancelable: true });
      input.dispatchEvent(ctrlG);
      await wait(() => status(hostElement).startsWith('2 / 3'), 'Ctrl+G next');
      const f3 = new KeyboardEvent('keydown', { key: 'F3', bubbles: true, cancelable: true });
      input.dispatchEvent(f3);
      await wait(() => status(hostElement).startsWith('3 / 3'), 'F3 next');
      const shiftF3 = new KeyboardEvent('keydown', { key: 'F3', shiftKey: true, bubbles: true, cancelable: true });
      input.dispatchEvent(shiftF3);
      await wait(() => status(hostElement).startsWith('2 / 3'), 'Shift+F3 previous');
      observations.keys = { ctrlG: ctrlG.defaultPrevented, f3: f3.defaultPrevented, shiftF3: shiftF3.defaultPrevented, status: status(hostElement) };
      input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true }));
      await sleep(20);
      observations.escape = {
        display: bar(hostElement).style.display,
        status: status(hostElement),
        focusedStage: document.activeElement === viewer.stage,
        marks: markCount(viewer),
      };
      const returns = {};
      for (const [name, call] of Object.entries({
        setView: () => viewer.setView(viewer.view.id),
        setLayout: () => viewer.setLayout('single'),
        setZoom: () => viewer.setZoom(1),
        setMusicMode: () => viewer.setMusicMode('score'),
        scrollToPage: () => viewer.scrollToPage(0),
        openFind: () => viewer.openFind(),
        clearFind: () => viewer.clearFind(),
        show: () => viewer.show(),
        hide: () => viewer.hide(),
      })) {
        const value = call();
        returns[name] = value === undefined ? 'undefined' : String(value);
      }
      const destroyValue = viewer.destroy();
      returns.destroy = destroyValue === undefined ? 'undefined' : String(destroyValue);
      observations.returns = returns;
      hostElement.remove();

      // Switching views while the find bar is open keeps searching the query in
      // the view that came.
      const viewChangeEvents = [];
      const viewChangeLog = [];
      const viewChangeHost = host();
      const twoViews = structuredClone(scrollDoc.manifest);
      twoViews.views.push({ ...structuredClone(twoViews.views[0]), id: 'second' });
      const viewChangeViewer = new Viewer(viewChangeHost, { renderer: makeRenderer(twoViews, viewChangeLog) });
      record(viewChangeViewer, viewChangeEvents);
      try {
        await viewChangeViewer.open({ kind: 'buffer', buffer: scrollBytes.slice().buffer });
        await wait(() => ready(viewChangeViewer), 'view change open');
        viewChangeViewer.openFind();
        const viewChangeInput = viewChangeHost.querySelector('input');
        viewChangeInput.value = 'alpha';
        viewChangeInput.dispatchEvent(new InputEvent('input', { bubbles: true }));
        await wait(() => status(viewChangeHost).startsWith('1 / 3'), 'view change first search');
        const before = viewChangeEvents.length;
        viewChangeViewer.setView('second');
        await wait(() => status(viewChangeHost).startsWith('1 / 2'), 'view change search');
        await sleep(50);
        observations.viewChangeFind = {
          view: viewChangeViewer.view?.id,
          status: status(viewChangeHost),
          marks: markCount(viewChangeViewer),
          events: step(viewChangeEvents.slice(before)),
          searches: viewChangeLog.filter((item) => item.startsWith('search:')),
        };
      } finally {
        viewChangeViewer.destroy();
        viewChangeHost.remove();
      }

      return observations;
    }

    async function runFile(Viewer, streaming) {
      const events = [];
      const log = [];
      const calls = [];
      const hostElement = host();
      const manifest = structuredClone(flowDoc.manifest);
      const viewer = new Viewer(hostElement, { renderer: makeRenderer(manifest, log), find: false });
      record(viewer, events);
      try {
        const converter = streaming ? {
          open: async () => { calls.push('open'); return { bdf: new Uint8Array([1]), pages: 3, stream: 7 }; },
          page: async (stream, index) => { calls.push('page:' + stream + ':' + index); return { bdf: new Uint8Array([index + 2]) }; },
          finish: async (stream) => { calls.push('finish:' + stream); return { bdf: new Uint8Array([8]) }; },
          close: async (stream) => { calls.push('close:' + stream); },
        } : {
          convert: async (data, options) => { calls.push('convert:' + data.byteLength + ':' + (options?.name ?? '')); return { bdf: new Uint8Array([9]) }; },
        };
        const returned = await viewer.openFile(converter, new Uint8Array([1, 2, 3]), { name: 'sample' });
        if (streaming) await wait(() => events.some((event) => event[0] === 'conversiondone') && calls.includes('close:7'), 'stream conversion');
        else await wait(() => ready(viewer), 'fallback conversion');
        await sleep(100);
        return {
          calls: [...calls],
          log: [...log],
          events: step(events),
          manifest: returned.views.map((view) => view.id),
          returnedDocument: returned === viewer.document,
          view: viewer.view?.id,
          frames: frameSnapshot(viewer),
        };
      } finally {
        viewer.destroy();
        hostElement.remove();
      }
    }

    async function runLightbox(Viewer) {
      const log = [];
      const hostElement = host();
      const viewer = new Viewer(hostElement, { renderer: makeRenderer(structuredClone(flowDoc.manifest), log), mode: 'lightbox' });
      const embeddedHost = host();
      const embedded = new Viewer(embeddedHost, { renderer: makeRenderer(structuredClone(flowDoc.manifest), []), find: false });
      const noFindHost = host();
      const noFindViewer = new Viewer(noFindHost, { renderer: makeRenderer(structuredClone(flowDoc.manifest), []), find: false });
      const shortcut = () => new KeyboardEvent('keydown', { key: 'f', code: 'KeyF', ctrlKey: true, bubbles: true, cancelable: true });
      try {
        const barInitial = { exists: bar(hostElement) !== null, display: bar(hostElement)?.style.display };
        const initial = viewer.surface.style.display;
        const hiddenShortcut = shortcut();
        viewer.stage.dispatchEvent(hiddenShortcut);
        await sleep(20);
        const hiddenKey = {
          prevented: hiddenShortcut.defaultPrevented,
          display: bar(hostElement).style.display,
          focused: document.activeElement === hostElement.querySelector('input'),
        };
        viewer.show();
        const shown = viewer.surface.style.display;
        const shownShortcut = shortcut();
        viewer.stage.dispatchEvent(shownShortcut);
        await sleep(20);
        const shownKey = {
          prevented: shownShortcut.defaultPrevented,
          display: bar(hostElement).style.display,
          focused: document.activeElement === hostElement.querySelector('input'),
        };
        hostElement.querySelector('input').dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape', bubbles: true, cancelable: true }));
        await sleep(20);
        const escapeKey = { display: bar(hostElement).style.display, focusedStage: document.activeElement === viewer.stage };
        viewer.hide();
        const hidden = viewer.surface.style.display;
        const embeddedInitial = embedded.surface.style.display;
        embedded.show();
        const embeddedShown = embedded.surface.style.display;
        embedded.hide();
        const embeddedHidden = embedded.surface.style.display;
        const surfaceConnected = viewer.surface.isConnected;
        viewer.destroy();
        const afterDestroyShortcut = shortcut();
        document.dispatchEvent(afterDestroyShortcut);
        const destroyed = {
          removed: !viewer.surface.isConnected,
          hostChildren: hostElement.childElementCount,
          terminated: log.includes('terminate'),
          keyAfterDestroy: afterDestroyShortcut.defaultPrevented,
        };
        const noFindShortcut = shortcut();
        noFindViewer.stage.dispatchEvent(noFindShortcut);
        await sleep(20);
        const noFind = {
          bar: bar(noFindHost) === null,
          openFind: (() => { try { noFindViewer.openFind(); return 'ok'; } catch (error) { return error.name; } })(),
          prevented: noFindShortcut.defaultPrevented,
        };
        embedded.destroy();
        embeddedHost.remove();
        noFindViewer.destroy();
        noFindHost.remove();
        return { barInitial, initial, hiddenKey, shown, shownKey, escapeKey, hidden, embeddedInitial, embeddedShown, embeddedHidden, surfaceConnected, destroyed, noFind };
      } finally {
        hostElement.remove();
      }
    }

    async function runFactory() {
      const log = [];
      const hostElement = host();
      const viewer = moon.bdf_create_viewer(hostElement, { renderer: makeRenderer(structuredClone(scrollDoc.manifest), log), find: false });
      try {
        const shape = {
          host: viewer.host === hostElement,
          eventTarget: viewer instanceof EventTarget,
          ownMethods: Object.hasOwn(viewer, 'open') && Object.hasOwn(viewer, 'destroy'),
          methods: methodNames.every((name) => typeof viewer[name] === 'function'),
          getters: getterNames.every((name) => name in viewer),
          instanceOfClass: viewer instanceof moon.Viewer,
          surface: describeElement(viewer.surface),
          stage: describeElement(viewer.stage),
        };
        const opened = await viewer.open({ kind: 'buffer', buffer: scrollBytes.slice().buffer });
        await wait(() => ready(viewer), 'factory open');
        const outsideShortcut = new KeyboardEvent('keydown', { key: 'f', code: 'KeyF', ctrlKey: true, bubbles: true, cancelable: true });
        document.body.dispatchEvent(outsideShortcut);
        viewer.setLayout('spread');
        await wait(() => ready(viewer), 'factory spread');
        const found = await viewer.find('alpha');
        return {
          shape,
          manifest: opened.views.map((view) => view.id),
          returnedDocument: opened === viewer.document,
          view: viewer.view?.id,
          layout: viewer.pageLayout,
          found,
          outsideKey: outsideShortcut.defaultPrevented,
          frames: frameSnapshot(viewer),
        };
      } finally {
        viewer.destroy();
        hostElement.remove();
      }
    }

    const upstream = await run(UpstreamViewer);
    const local = await run(moon.Viewer);
    const files = {
      upstreamFallback: await runFile(UpstreamViewer, false),
      localFallback: await runFile(moon.Viewer, false),
      upstreamStream: await runFile(UpstreamViewer, true),
      localStream: await runFile(moon.Viewer, true),
    };
    const lightbox = {
      upstream: await runLightbox(UpstreamViewer),
      local: await runLightbox(moon.Viewer),
    };
    const factory = await runFactory();
    return { upstream, local, files, lightbox, factory };
  });

  assert.deepEqual(browserErrors, [], 'browser errors');

  for (const key of Object.keys(result.upstream)) {
    assert.deepEqual(result.local[key], result.upstream[key], 'viewer ' + key);
  }
  assert.deepEqual(result.files.localFallback, result.files.upstreamFallback, 'openFile fallback');
  assert.deepEqual(result.files.localStream, result.files.upstreamStream, 'openFile stream');
  assert.deepEqual(result.lightbox.local, result.lightbox.upstream, 'lightbox show/hide/destroy');

  assert.equal(result.factory.shape.host, true, 'factory host');
  assert.equal(result.factory.shape.eventTarget, true, 'factory is an EventTarget');
  assert.equal(result.factory.shape.ownMethods, true, 'factory methods are own properties');
  assert.equal(result.factory.shape.methods, true, 'factory methods');
  assert.equal(result.factory.shape.getters, true, 'factory getters');
  assert.equal(result.factory.shape.instanceOfClass, false, 'factory is not a class instance');
  assert.equal(result.factory.returnedDocument, true, 'factory open return');
  assert.deepEqual(result.factory.view, result.local.open.view, 'factory view');
  assert.deepEqual(result.factory.layout, 'spread', 'factory layout');
  assert.equal(result.factory.found.total, 3, 'factory find');

  console.log('viewer API compatibility: ok');
} finally {
  await browser.close();
  await new Promise((resolve) => server.close(resolve));
}
