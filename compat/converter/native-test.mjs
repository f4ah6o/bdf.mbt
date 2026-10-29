import assert from 'node:assert/strict';

export async function verifyNativeConverter(browser, base) {
  const page = await browser.newPage();
  try {
    await page.goto(`${base}moon.html`, { waitUntil: 'networkidle' });
    const outcomes = await page.evaluate(async () => {
      const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
      const { Converter } = await import('/node_modules/@bdfkit/convert/dist/index.js');
      const { BdfDocument, BufferSource } = await import('@bdfkit/core');
      const fixtures = await (await fetch('/compat/image/upstream.json')).json();
      const toBytes = encoded => Uint8Array.from(atob(encoded), c => c.charCodeAt(0));
      {
        const worker = new Worker('/_build/js/debug/build/native_converter_worker/native_converter_worker.js', { type: 'module' });
        const reply = new Promise(resolve => worker.onmessage = event => resolve(event.data));
        worker.postMessage({ id: 7, type: 'convert', data: new Uint8Array().buffer });
        const value = await reply;
        if (value.id !== 7 || value.ok || value.error !== 'converter is not ready') throw new Error('Worker must reject requests before init');
        worker.terminate();
      }
      const result = [];
      for (const kind of ['upstream-client', 'native-client']) {
        const client = kind === 'upstream-client'
          ? new Converter(new Worker('/_build/js/debug/build/native_converter_worker/native_converter_worker.js', { type: 'module' }), '')
          : bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
        try {
          const formats = await client.ready;
          if (!formats.some(f => f.name === 'image' && f.extensions.includes('.bmp') && f.extensions.includes('.ico') && f.extensions.includes('.jpg') && f.extensions.includes('.png') && f.extensions.includes('.gif') && f.extensions.includes('.webp') && f.extensions.includes('.avif'))) throw new Error(`${kind}: missing image formats ${JSON.stringify(formats)}`);
          const converted = [];
          for (const fixture of [fixtures[0], fixtures[1], fixtures[4], fixtures[5], fixtures[6], fixtures[7], fixtures[9], fixtures[10], fixtures[11], fixtures[12], fixtures[13], fixtures[14], fixtures.find(f => f.name === 'anim.gif'), fixtures.find(f => f.name === 'xmp.gif'), fixtures.find(f => f.name === 'scene.webp'), fixtures.find(f => f.name === 'rotated.avif'), ...fixtures.filter(f => f.name.startsWith('synthetic-') && (f.format === 'webp' || f.format === 'avif'))]) {
            const input = toBytes(fixture.input);
            const wrapped = new Uint8Array(input.length + 6); wrapped.set(input, 3);
            const source = wrapped.subarray(3, 3 + input.length);
            const output = await client.convert(source, { name: fixture.name });
            const opened = await client.open(source, { format: 'image', name: fixture.name });
            const doc = await BdfDocument.open(new BufferSource(output.bdf));
            const doc2 = await BdfDocument.open(new BufferSource(opened.bdf));
            const actualDc = Object.entries(doc.manifest.meta.dc ?? {}).sort(([a], [b]) => a.localeCompare(b));
            const expectedDc = Object.entries(fixture.dc).sort(([a], [b]) => a.localeCompare(b));
            if (JSON.stringify(actualDc) !== JSON.stringify(expectedDc)) throw new Error(`${kind}: metadata differs for ${fixture.name}`);
            const view = doc.manifest.views[0];
            const object = await doc.part(view.pages[0].layers[0].obj);
            const media = await doc.part(doc.manifest.parts[0].h);
            const expectedObject = toBytes(fixture.object);
            if (JSON.stringify(output.warnings) !== JSON.stringify(fixture.warnings)) throw new Error(`${kind}: warnings differ for ${fixture.name}`);
            if (output.format !== fixture.format || output.summary !== fixture.summary ||
                opened.pages !== 0 || opened.stream !== undefined ||
                doc.manifest.parts[0].h !== fixture.imageHash ||
                object.length !== expectedObject.length ||
                !object.every((v, i) => v === expectedObject[i]) ||
                media.length !== input.length ||
                !media.every((v, i) => v === input[i])) throw new Error(`${kind}: differs from upstream ${fixture.name}`);
            converted.push({ format: output.format, summary: output.summary, warnings: output.warnings, protected: output.protected,
              opened: { format: opened.format, pages: opened.pages, summary: opened.summary, warnings: opened.warnings, protected: opened.protected, stream: opened.stream ?? null },
              page: [view.pages[0].w, view.pages[0].h], openedPage: [doc2.manifest.views[0].pages[0].w, doc2.manifest.views[0].pages[0].h],
              media: [...media], object: [...object], inputIntact: source.every((v, i) => v === input[i]) });
          }
          let unknown;
          try { await client.convert(new Uint8Array([1, 2, 3])); } catch (e) { unknown = { name: e.name, code: e.code }; }
          if (unknown?.name !== 'ConvertError' || unknown.code !== 'unknown-format') throw new Error('unsupported format must fail');
          const closed = await client.close(123);
          let missing;
          try { await client.page(123, 0); } catch (e) { missing = { name: e.name, message: e.message }; }
          if (closed !== null || missing?.name !== 'ConvertError' || missing.message !== 'no conversion 123') throw new Error('invalid stream lifecycle');
          result.push({ converted, closed, missing });
        } finally { client.terminate(); }
      }
      for (const fixture of [fixtures[0], fixtures[6], fixtures[10], fixtures[12], fixtures[14], fixtures.find(f => f.name === 'anim.gif'), fixtures.find(f => f.name === 'scene.webp'), fixtures.find(f => f.name === 'rotated.avif')]) {
        const { bdf_create_viewer } = await import('/_build/js/debug/build/browser/browser.js');
        const client = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
        const host = document.createElement('div'); host.style.cssText = 'width:200px;height:200px'; document.body.append(host);
        const viewer = bdf_create_viewer(host, { workerUrl: '/_build/js/debug/build/render_worker/render_worker.js', find: false });
        try {
          const manifest = await viewer.openFile(client, toBytes(fixture.input), { name: fixture.name });
          if (manifest.views[0].pages[0].w !== fixture.width * 0.75) throw new Error('viewer opened the wrong page');
          const start = performance.now();
          while (!host.querySelector('canvas[data-loaded="ready"]')) {
            if (performance.now() - start > 7000) throw new Error('viewer did not render native conversion');
            await new Promise(resolve => setTimeout(resolve, 20));
          }
        } finally { viewer.destroy(); client.terminate(); host.remove(); }
      }
      return result;
    });
    assert.deepEqual(outcomes[1], outcomes[0], 'native Worker supports both converter clients');
    assert.ok(outcomes[1].converted.every(result => result.inputIntact));
  } finally { await page.close(); }
}
