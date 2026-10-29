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
      const csvFixtures = await (await fetch('/compat/csv/conversion.json')).json();
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
          if (!formats.some(f => f.name === 'image' && ['.bmp', '.ico', '.jpg', '.png', '.gif', '.webp', '.avif', '.svg'].every(ext => f.extensions.includes(ext)))) throw new Error(`${kind}: missing image formats ${JSON.stringify(formats)}`);
          const csvFormat = formats.find(f => f.name === 'csv');
          if (csvFormat?.description !== 'CSV or TSV (comma-, tab-, semicolon- or bar-separated values)' || JSON.stringify(csvFormat.extensions) !== JSON.stringify(['.csv', '.tsv', '.tab'])) throw new Error(kind + ': missing CSV format');
          const imageFormat = formats.find(f => f.name === 'image');
          if (imageFormat.description !== 'Image stored as it is: PNG, JPEG, GIF, WebP, AVIF, BMP, ICO or SVG' || JSON.stringify(imageFormat.extensions) !== JSON.stringify(['.png', '.apng', '.jpg', '.jpeg', '.jpe', '.jfif', '.gif', '.webp', '.avif', '.bmp', '.ico', '.svg'])) throw new Error(`${kind}: image format descriptor differs from upstream`);
          for (const [method, pages, expected] of [
            ['convert', '0', 'convert: pages: bad page "0" in "0": pages are numbered from 1'],
            ['open', '1-x', 'open: pages: bad page "x" in "1-x": pages are numbered from 1'],
            ['convert', '5-3', 'convert: pages: bad page range "5-3": it ends before it starts'],
            ['open', '2--3', 'open: pages: bad page "-3" in "2--3": pages are numbered from 1'],
            ['convert', '\x07', 'convert: pages: bad page "\\a" in "\\a": pages are numbered from 1'],
            ['convert', '\u200b', 'convert: pages: bad page "\\u200b" in "\\u200b": pages are numbered from 1'],
          ]) {
            let message;
            try { await client[method](toBytes(fixtures[0].input), { pages }); } catch (error) { message = error.message; }
            if (message !== expected) throw new Error(`${kind}: incorrect page selection error: ${message}`);
          }
          await client.convert(toBytes(fixtures[0].input), { pages: ' 3 , 1-1 , -3, 7-, - ' });
          const converted = [];
          for (const fixture of [fixtures[0], fixtures[1], fixtures[4], fixtures[5], fixtures[6], fixtures[7], fixtures[9], fixtures[10], fixtures[11], fixtures[12], fixtures[13], fixtures[14], fixtures.find(f => f.name === 'anim.gif'), fixtures.find(f => f.name === 'xmp.gif'), fixtures.find(f => f.name === 'scene.webp'), fixtures.find(f => f.name === 'rotated.avif'), ...fixtures.filter(f => f.format === 'svg' && f.pageW <= 2 ** 24 && f.pageH <= 2 ** 24), ...fixtures.filter(f => f.name.startsWith('synthetic-') && (f.format === 'webp' || f.format === 'avif'))]) {
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
          const oversized = fixtures.find(f => f.name === 'large.svg');
          const large = await client.convert(toBytes(oversized.input), { name: oversized.name });
          if (large.summary !== oversized.summary) throw new Error(`${kind}: large SVG summary differs from upstream`);
          let oversizedError;
          try { await BdfDocument.open(new BufferSource(large.bdf)); } catch (error) { oversizedError = error.message; }
          if (!/page width.*out of range/.test(oversizedError ?? '')) throw new Error(`${kind}: oversized page should be refused by upstream reader`);
          let unknown;
          try { await client.convert(new Uint8Array([1, 2, 3])); } catch (e) { unknown = { name: e.name, code: e.code }; }
          if (unknown?.name !== 'ConvertError' || unknown.code !== 'unknown-format') throw new Error('unsupported format must fail');
          const closed = await client.close(123);
          let missing;
          try { await client.page(123, 0); } catch (e) { missing = { name: e.name, message: e.message }; }
          if (closed !== null || missing?.name !== 'ConvertError' || missing.message !== 'no conversion 123') throw new Error('invalid stream lifecycle');
          const csvOutcomes = [];
          const sorted = value => Array.isArray(value) ? value.map(sorted) : value && typeof value === 'object'
            ? Object.fromEntries(Object.keys(value).sort().map(key => [key, sorted(value[key])])) : value;
          for (const sample of csvFixtures.filter(f => !f.input.NoTextIndex && f.input.Name && !f.input.Title).slice(0, 4)) {
            const input = sample.input, params = {};
            if (input.Delimiter) params.delimiter = String.fromCharCode(input.Delimiter);
            if (input.Quote === -1) params.quote = 'none';
            else if (input.Quote) params.quote = String.fromCharCode(input.Quote);
            if (input.Header === 1) params.header = 'true';
            if (input.Header === 2) params.header = 'false';
            if (input.Mode) params.data = input.Mode;
            if (input.Charset) params.charset = input.Charset;
            const expected = await BdfDocument.open(new BufferSource(toBytes(sample.bdf)));
            for (const method of ['convert', 'open']) {
              const output = await client[method](toBytes(input.Data), { format: 'csv', name: input.Name + '.csv', params });
              const doc = await BdfDocument.open(new BufferSource(output.bdf));
              for (const field of ['views', 'tables', 'meta']) {
                if (JSON.stringify(sorted(doc.manifest[field] ?? [])) !== JSON.stringify(sorted(expected.manifest[field] ?? []))) throw new Error(kind + ': CSV ' + field + ' differs');
              }
              if (output.summary !== sample.summary || JSON.stringify(output.warnings) !== JSON.stringify(sample.warnings) || output.format !== 'csv') throw new Error(kind + ': CSV result differs');
              if (method === 'open' && output.pages !== 0) throw new Error(kind + ': CSV open should return a whole document');
              for (const part of doc.manifest.parts) {
                const other = expected.manifest.parts.find(p => p.h === part.h);
                if (!other || other.t !== part.t) throw new Error(kind + ': CSV part differs');
              }
              csvOutcomes.push({ summary: output.summary, warnings: output.warnings, views: doc.manifest.views });
            }
            const named = await client.convert(toBytes(input.Data), { name: input.Name + '.csv', params });
            if (named.format !== 'csv' || named.summary !== sample.summary) throw new Error(kind + ': CSV extension detection differs');
          }
          for (const [params, expected] of [
            [{ header: 'maybe' }, 'csv: parameter header: "maybe" is not true, false or auto'],
            [{ quote: 'bad' }, 'csv: parameter quote: "bad" is not double, single or none'],
            [{ data: 'bad' }, 'csv: parameter data: "bad" is not none, all or default'],
            [{ table: 'Medium2' }, 'native CSV converter does not yet support table styles'],
          ]) {
            let error;
            try { await client.convert(new TextEncoder().encode('a,b\n1,2'), { format: 'csv', params }); } catch (e) { error = e.message; }
            if (error !== expected) throw new Error(kind + ': CSV parameter error ' + error);
          }
          const guessed = await client.convert(new TextEncoder().encode('name,value\nAlice,1\nBob,2\n'));
          if (guessed.format !== 'csv' || !guessed.summary.includes('header row')) throw new Error(kind + ': CSV content detection failed');
          const boolOptions = await client.convert(new TextEncoder().encode('a,b\n1,2'), { format: 'csv', params: { header: true, data: 'none' } });
          const boolDoc = await BdfDocument.open(new BufferSource(boolOptions.bdf));
          if (boolDoc.manifest.tables?.length || boolDoc.manifest.views[0].freeze?.rows !== 1) throw new Error(kind + ': CSV boolean option failed');
          let plotterError;
          try { await client.convert(new TextEncoder().encode('IN;SP1;PA0,0;PD100,200;')); } catch (e) { plotterError = e.code; }
          if (plotterError !== 'unknown-format') throw new Error(kind + ': plotter data was mistaken for CSV');
          for (const [input, name] of [
            ['IN;SP1;PA0,0;PD100,200;', 'plot.csv'],
            ['%PDF-1.7\nname,value\nA,1\n', 'document.csv'],
            ['name,value\nA,1\nB,2\n', 'score.mml'],
          ]) {
            let code;
            try { await client.convert(new TextEncoder().encode(input), { name }); } catch (e) { code = e.code; }
            if (code !== 'unknown-format') throw new Error(kind + ': unsupported format was mistaken for CSV');
          }
          const imageNamedCsv = await client.convert(toBytes(fixtures[0].input), { name: 'picture.csv' });
          if (imageNamedCsv.format !== fixtures[0].format) throw new Error(kind + ': image signature must precede the CSV filename');
          result.push({ converted, closed, missing, csvOutcomes });
        } finally { client.terminate(); }
      }
      for (const fixture of [fixtures[0], fixtures[6], fixtures[10], fixtures[12], fixtures[14], fixtures.find(f => f.name === 'anim.gif'), fixtures.find(f => f.name === 'scene.webp'), fixtures.find(f => f.name === 'rotated.avif'), fixtures.find(f => f.name === 'drawing.svg'), fixtures.find(f => f.name === 'units.svg')]) {
        const { bdf_create_viewer } = await import('/_build/js/debug/build/browser/browser.js');
        const client = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
        const host = document.createElement('div'); host.style.cssText = 'width:200px;height:200px'; document.body.append(host);
        const viewer = bdf_create_viewer(host, { workerUrl: '/_build/js/debug/build/render_worker/render_worker.js', find: false });
        try {
          const manifest = await viewer.openFile(client, toBytes(fixture.input), { name: fixture.name });
          if (manifest.views[0].pages[0].w !== fixture.pageW) throw new Error('viewer opened the wrong page');
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
