import assert from 'node:assert/strict';
import { createReadStream, readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { chromium } from 'playwright';

const root = process.cwd();
const requests = [];
const server = createServer((request, response) => {
  const url = new URL(request.url, 'http://localhost');
  requests.push(url.pathname);
  if (url.pathname === '/') {
    response.setHeader('Content-Type', 'text/html');
    response.end('<!doctype html><meta charset="utf-8"><title>fontFiles</title><script type="importmap">{"imports":{"@bdfkit/core":"/node_modules/@bdfkit/core/dist/index.js"}}</script>');
    return;
  }
  if (url.pathname === '/fonts/index.json') {
    const size = readFileSync('compat/font/fixtures/stix.ttf').length;
    response.setHeader('Content-Type', 'application/json');
    response.end(JSON.stringify([{ name: 'stix.ttf', size, url: '/fonts/stix.ttf' }]));
    return;
  }
  if (url.pathname === '/fonts/stix.ttf') {
    response.setHeader('Content-Type', 'font/ttf');
    createReadStream('compat/font/fixtures/stix.ttf').pipe(response);
    return;
  }
  if (!url.pathname.startsWith('/_build/js/debug/build/') && !url.pathname.startsWith('/node_modules/@bdfkit/') && !url.pathname.startsWith('/compat/font/fixtures/') && !url.pathname.startsWith('/compat/converter/xlsx-fixtures/')) {
    response.writeHead(404).end();
    return;
  }
  const file = path.resolve(root, '.' + decodeURIComponent(url.pathname));
  const stream = createReadStream(file);
  stream.once('error', () => { if (!response.headersSent) response.writeHead(404); response.end(); });
  response.setHeader('Content-Type', url.pathname.endsWith('.json') ? 'application/json' : 'text/javascript');
  stream.pipe(response);
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}`;
const browser = await chromium.launch();
try {
  const page = await browser.newPage();
  await page.goto(base + '/', { waitUntil: 'networkidle' });
  const result = await page.evaluate(async () => {
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const { BdfDocument, BufferSource } = await import('@bdfkit/core');
    const load = async name => new Uint8Array(await (await fetch('/compat/font/fixtures/' + name)).arrayBuffer());
    const ttf = await load('stix.ttf');
    const otf = await load('stix.otf');
    const ttc = await load('bold.ttc');
    // A valid SFNT whose name table has no records: it parses, but the
    // database cannot register a family name for it.
    const noFamily = (() => {
      const copy = ttf.slice();
      const view = new DataView(copy.buffer);
      for (let index = 0; index < view.getUint16(4); index++) {
        const record = 12 + index * 16;
        if (String.fromCharCode(copy[record], copy[record + 1], copy[record + 2], copy[record + 3]) === 'name') {
          view.setUint16(view.getUint32(record + 8) + 2, 0);
          break;
        }
      }
      return copy;
    })();
    // A TTC header claiming two faces but containing only one offset.
    const truncatedTtc = (() => {
      const out = new Uint8Array(16);
      const view = new DataView(out.buffer);
      out.set([0x74, 0x74, 0x63, 0x66], 0);
      view.setUint32(4, 0x00010000);
      view.setUint32(8, 2);
      view.setUint32(12, 16);
      return out;
    })();
    // A TTC header claiming 257 faces, all pointing at the same valid SFNT.
    const manyFaces = (() => {
      const count = 257, header = 12 + count * 4;
      const out = new Uint8Array(header + ttf.length);
      const view = new DataView(out.buffer);
      out.set([0x74, 0x74, 0x63, 0x66], 0);
      view.setUint32(4, 0x00010000);
      view.setUint32(8, count);
      for (let index = 0; index < count; index++) view.setUint32(12 + index * 4, header);
      out.set(ttf, header);
      return out;
    })();
    const csv = new TextEncoder().encode('name,value\nAlpha,42\nBeta,7\n');
    const postscriptNames = data => {
      const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
      const collection = data[0] === 0x74 && data[1] === 0x74 && data[2] === 0x63 && data[3] === 0x66;
      const count = collection ? view.getUint32(8) : 1;
      const names = [];
      for (let face = 0; face < count; face++) {
        const base = collection ? view.getUint32(12 + face * 4) : 0;
        let nameOffset = -1;
        for (let index = 0; index < view.getUint16(base + 4); index++) {
          const record = base + 12 + index * 16;
          if (String.fromCharCode(data[record], data[record + 1], data[record + 2], data[record + 3]) === 'name') {
            nameOffset = view.getUint32(record + 8);
            break;
          }
        }
        let name = '';
        if (nameOffset >= 0) {
          const countNames = view.getUint16(nameOffset + 2), stringOffset = view.getUint16(nameOffset + 4);
          for (let index = 0; index < countNames; index++) {
            const record = nameOffset + 6 + index * 12;
            const platform = view.getUint16(record), encoding = view.getUint16(record + 2), id = view.getUint16(record + 6);
            if (id !== 6) continue;
            const size = view.getUint16(record + 8), start = nameOffset + stringOffset + view.getUint16(record + 10);
            if (start + size > data.length) continue;
            let text = '';
            if (platform === 3 || platform === 0) for (let i = 0; i < size; i += 2) text += String.fromCharCode(view.getUint16(start + i));
            else if (platform === 1 && encoding === 0) for (let i = 0; i < size; i++) text += String.fromCharCode(data[start + i]);
            else continue;
            if (text) { name = text; break; }
          }
        }
        names.push(name);
      }
      return names;
    };
    const noFonts = 'no fonts found; text is laid out with estimated metrics and not embedded';
    const tableDirectory = (data, base) => {
      const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
      const tables = new Map();
      for (let index = 0; index < view.getUint16(base + 4); index++) {
        const record = base + 12 + index * 16;
        const tag = String.fromCharCode(data[record], data[record + 1], data[record + 2], data[record + 3]);
        tables.set(tag, { offset: view.getUint32(record + 8), length: view.getUint32(record + 12), checksum: view.getUint32(record + 4) });
      }
      return tables;
    };
    const faceBase = (data, faceIndex) => data[0] === 0x74 && data[1] === 0x74 && data[2] === 0x63 && data[3] === 0x66
      ? new DataView(data.buffer, data.byteOffset, data.byteLength).getUint32(12 + faceIndex * 4) : 0;
    const tableBytes = (data, table) => data.slice(table.offset, table.offset + table.length);
    const checksum = bytes => {
      let sum = 0;
      for (let index = 0; index < bytes.length; index += 4) {
        let word = 0;
        for (let offset = 0; offset < 4; offset++) word = (word << 8) | (index + offset < bytes.length ? bytes[index + offset] : 0);
        sum = (sum + word) >>> 0;
      }
      return sum >>> 0;
    };
    const validateStandalone = async (standalone, source, faceIndex) => {
      if (standalone[0] === 0x74 && standalone[1] === 0x74 && standalone[2] === 0x63 && standalone[3] === 0x66) throw new Error('standalone is still a TTC');
      const sourceTables = tableDirectory(source, faceBase(source, faceIndex));
      const standaloneTables = tableDirectory(standalone, 0);
      if (sourceTables.size !== standaloneTables.size) throw new Error('standalone table count differs');
      for (const [tag, table] of standaloneTables) {
        const sourceTable = sourceTables.get(tag);
        if (!sourceTable) throw new Error('standalone has an unselected table ' + tag);
        const actual = tableBytes(standalone, table);
        const expected = tableBytes(source, sourceTable);
        if (actual.length !== expected.length) throw new Error('table length differs: ' + tag);
        for (let index = 0; index < actual.length; index++) {
          if (tag === 'head' && index >= 8 && index < 12) continue;
          if (actual[index] !== expected[index]) throw new Error('table differs: ' + tag);
        }
        const checkBytes = actual.slice();
        if (tag === 'head') checkBytes.fill(0, 8, 12);
        if (checksum(checkBytes) !== table.checksum) throw new Error('table checksum differs: ' + tag);
      }
      if (checksum(standalone) !== 0xB1B0AFBA) throw new Error('global checksum differs');
      await new FontFace('bdf-standalone-' + faceIndex, standalone).load();
    };
    const fontParts = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      return doc.manifest.parts.filter(part => part.t === 'font').map(part => part.h);
    };
    const fontPartBytes = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      const part = doc.manifest.parts.find(part => part.t === 'font');
      return part ? new Uint8Array(await doc.part(part.h)) : null;
    };
    const fontPartNames = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      const names = [];
      for (const part of doc.manifest.parts.filter(part => part.t === 'font')) {
        names.push(postscriptNames(new Uint8Array(await doc.part(part.h)))[0]);
      }
      return names;
    };
    const client = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    const out = { errors: [], hashes: {}, requests: [] };
    try {
      await client.ready;
      const plain = await client.convert(csv, { format: 'csv' });
      if (!plain.warnings.includes(noFonts)) throw new Error('CSV without fonts must warn');
      if ((await fontParts(plain.bdf)).length !== 0) throw new Error('CSV without fonts must not embed a font');
      for (const fontFiles of [null, []]) {
        const absent = await client.convert(csv, { format: 'csv', fontFiles });
        if (!absent.warnings.includes(noFonts) || (await fontParts(absent.bdf)).length !== 0) throw new Error('null/empty fontFiles must behave as absent');
      }
      const withTtf = await client.convert(csv, { format: 'csv', fontFiles: [{ name: 'stix.ttf', bytes: ttf }] });
      const nonStringUrl = await client.convert(csv, { format: 'csv', fonts: 123, fontFiles: [{ name: 'stix.ttf', bytes: ttf }] });
      if ((await fontParts(nonStringUrl.bdf))[0] !== (await fontParts(withTtf.bdf))[0]) throw new Error('non-string fonts must stay absent in byte mode');
      if (withTtf.warnings.includes(noFonts)) throw new Error('CSV with fontFiles must not warn about missing fonts');
      const ttfParts = await fontParts(withTtf.bdf);
      if (ttfParts.length !== 1) throw new Error('CSV with fontFiles must embed one font, got ' + ttfParts.length);
      out.hashes.ttf = ttfParts[0];
      const withOtf = await client.convert(csv, { format: 'csv', fontFiles: [{ name: 'stix.otf', bytes: otf }] });
      const otfParts = await fontParts(withOtf.bdf);
      if (otfParts.length !== 1 || otfParts[0] === ttfParts[0]) throw new Error('OTF byte input must embed a different font');
      out.hashes.otf = otfParts[0];
      const withTtc = await client.convert(csv, { format: 'csv', fontFiles: [{ name: 'bold.ttc', bytes: ttc }] });
      const ttcParts = await fontParts(withTtc.bdf);
      if (ttcParts.length !== 2 || new Set(ttcParts).size !== 2) throw new Error('TTC byte input must load both collection faces: ' + JSON.stringify(ttcParts));
      out.hashes.ttc = ttcParts;
      const ttcNames = postscriptNames(ttc);
      if (ttcNames.length !== 2 || ttcNames.some(name => !name) || ttcNames[0] === ttcNames[1]) throw new Error('bold.ttc must expose two distinct PostScript names');
      const mutatedTtc = ttc.slice();
      for (let faceIndex = 0; faceIndex < 2; faceIndex++) {
        const head = tableDirectory(mutatedTtc, faceBase(mutatedTtc, faceIndex)).get('head');
        new DataView(mutatedTtc.buffer).setUint32(head.offset + 8, 0xDEADBEEF);
      }
      const selectedHashes = [];
      for (const postscriptName of ttcNames) {
        const selected = await client.convert(csv, { format: 'csv', fontFiles: [{ name: 'bold.ttc', bytes: mutatedTtc, postscriptName }] });
        const parts = await fontParts(selected.bdf);
        const names = await fontPartNames(selected.bdf);
        if (parts.length !== 1 || names.length !== 1 || names[0] !== postscriptName) throw new Error('selected TTC face must embed exactly that face');
        selectedHashes.push(parts[0]);
      }
      if (new Set(selectedHashes).size !== 2) throw new Error('each TTC selector must select a different face');
      const ttfName = postscriptNames(ttf)[0];
      const selectedTtf = await client.convert(csv, { format: 'csv', fontFiles: [{ name: 'stix.ttf', bytes: ttf, postscriptName: ttfName }] });
      if ((await fontPartNames(selectedTtf.bdf))[0] !== ttfName) throw new Error('selected single-face font must embed that face');
      const xlsx = new Uint8Array(await (await fetch('/compat/converter/xlsx-fixtures/basic.xlsx')).arrayBuffer());
      const xlsxAll = await client.convert(xlsx, { format: 'xlsx', fontFiles: [{ name: 'bold.ttc', bytes: ttc }] });
      const allBytes = await fontPartBytes(xlsxAll.bdf);
      if (!allBytes || allBytes[0] !== 0x74 || allBytes[1] !== 0x74 || allBytes[2] !== 0x63 || allBytes[3] !== 0x66) throw new Error('unselected TTC must keep the existing whole-collection XLSX behaviour');
      const standaloneByFace = [];
      for (let faceIndex = 0; faceIndex < 2; faceIndex++) {
        const xlsxSelected = await client.convert(xlsx, { format: 'xlsx', fontFiles: [{ name: 'bold.ttc', bytes: mutatedTtc, postscriptName: ttcNames[faceIndex] }] });
        const selectedBytes = await fontPartBytes(xlsxSelected.bdf);
        if (!selectedBytes) throw new Error('selected TTC XLSX must embed a font');
        if (selectedBytes.length >= mutatedTtc.length) throw new Error('XLSX selected face must be a standalone SFNT');
        if (postscriptNames(selectedBytes)[0] !== ttcNames[faceIndex]) throw new Error('XLSX selected face must be the requested face');
        await validateStandalone(selectedBytes, mutatedTtc, faceIndex);
        standaloneByFace.push(selectedBytes);
      }
      if (standaloneByFace[0].length === standaloneByFace[1].length && standaloneByFace[0].every((value, index) => value === standaloneByFace[1][index])) throw new Error('both selected faces produced the same standalone font');
      const xlsxTtf = await client.convert(xlsx, { format: 'xlsx', fontFiles: [{ name: 'stix.ttf', bytes: ttf, postscriptName: ttfName }] });
      const ttfBytes = await fontPartBytes(xlsxTtf.bdf);
      if (!ttfBytes || ttfBytes.length !== ttf.length || ttfBytes.some((value, index) => value !== ttf[index])) throw new Error('XLSX selected single-face font must embed that face');
      const arrayBuffer = await client.convert(csv, { format: 'csv', fontFiles: [{ name: 'stix.ttf', bytes: ttf.buffer.slice(0) }] });
      if ((await fontParts(arrayBuffer.bdf))[0] !== ttfParts[0]) throw new Error('ArrayBuffer bytes must match Uint8Array bytes');
      const wrapped = new Uint8Array(ttf.length + 6);
      wrapped.set(ttf, 3);
      const view = wrapped.subarray(3, 3 + ttf.length);
      const sliced = await client.convert(csv, { format: 'csv', fontFiles: [{ name: 'stix.ttf', bytes: view }] });
      if ((await fontParts(sliced.bdf))[0] !== ttfParts[0]) throw new Error('typed-array slice must match its bytes');
      if (wrapped.length !== ttf.length + 6 || wrapped[0] !== 0 || wrapped[3] !== ttf[0]) throw new Error('caller buffer was detached or modified');
      const opened = await client.open(csv, { format: 'csv', fontFiles: [{ name: 'stix.ttf', bytes: ttf }] });
      if (opened.pages !== 0 || opened.stream !== undefined || (await fontParts(opened.bdf))[0] !== ttfParts[0]) throw new Error('open must accept fontFiles');
      const isolated = await client.convert(csv, { format: 'csv' });
      if (!isolated.warnings.includes(noFonts) || (await fontParts(isolated.bdf)).length !== 0) throw new Error('fontFiles leaked into a later request');
      const urlMode = await client.convert(csv, { format: 'csv', fonts: '/fonts/' });
      if ((await fontParts(urlMode.bdf))[0] !== ttfParts[0]) throw new Error('URL font mode must keep working');
      const cases = [
        [{ fontFiles: 'x' }, 'fontFiles: expected an array of {name, bytes}'],
        [{ fontFiles: [null] }, 'fontFiles[0]: expected an object with name and bytes'],
        [{ fontFiles: [{}] }, 'fontFiles[0]: name must be a non-empty string'],
        [{ fontFiles: [{ name: '', bytes: ttf }] }, 'fontFiles[0]: name must be a non-empty string'],
        [{ fontFiles: [{ name: 'a.ttf', bytes: 'x' }] }, 'fontFiles[0]: bytes must be a Uint8Array or ArrayBuffer'],
        [{ fontFiles: [{ name: 'a.ttf', bytes: new Uint8Array() }] }, 'fontFiles[0]: bytes must not be empty'],
        [{ fontFiles: [{ name: 'a.ttf', bytes: new Uint8Array([1, 2, 3]) }] }, 'fontFiles[0]: no usable font face'],
        [{ fontFiles: [{ name: 'dup.ttf', bytes: ttf }, { name: 'dup.ttf', bytes: ttf }] }, 'fontFiles[1]: duplicate name'],
        [{ fontFiles: [{ name: 'dup.ttf', bytes: ttf }, { name: 'dup.ttf', bytes: otf }] }, 'fontFiles[1]: duplicate name'],
        [{ fontFiles: [{ name: 'nofamily.ttf', bytes: noFamily }] }, 'fontFiles[0]: no usable font face'],
        [{ fontFiles: [{ name: 'stix.ttf', bytes: ttf }, { name: 'nofamily.ttf', bytes: noFamily }] }, 'fontFiles[1]: no usable font face'],
        [{ fontFiles: [{ name: 'many.ttc', bytes: manyFaces }] }, 'fontFiles[0]: collection has more than 256 faces'],
        [{ fontFiles: [{ name: 'bold.ttc', bytes: ttc, postscriptName: '' }] }, 'fontFiles[0]: postscriptName must be a non-empty string'],
        [{ fontFiles: [{ name: 'bold.ttc', bytes: ttc, postscriptName: 5 }] }, 'fontFiles[0]: postscriptName must be a non-empty string'],
        [{ fontFiles: [{ name: 'bold.ttc', bytes: ttc, postscriptName: 'NoSuchFace' }] }, 'fontFiles[0]: postscriptName matches no face'],
        [{ fontFiles: [{ name: 'a.ttc', bytes: ttc, postscriptName: ttcNames[0] }, { name: 'b.ttc', bytes: ttc, postscriptName: ttcNames[0] }] }, 'fontFiles[1]: duplicate postscriptName'],
        [{ fontFiles: [{ name: 'whole.ttc', bytes: ttc }, { name: 'selected.ttc', bytes: ttc, postscriptName: ttcNames[0] }] }, 'fontFiles[1]: face already added'],
        [{ fontFiles: [{ name: 'selected.ttc', bytes: ttc, postscriptName: ttcNames[0] }, { name: 'whole.ttc', bytes: ttc }] }, 'fontFiles[1]: face already added'],
        [{ fontFiles: [{ name: 'truncated.ttc', bytes: truncatedTtc }] }, 'fontFiles[0]: malformed font collection'],
        [{ fontFiles: [{ name: 'secret-name.ttf', bytes: new Uint8Array([1, 2, 3]) }] }, 'fontFiles[0]: no usable font face'],
        [{ fontFiles: [{ name: 'a.ttf', bytes: new Uint8Array(32 * 1024 * 1024 + 1) }] }, 'fontFiles[0]: bytes exceed the 33554432 byte per-file limit'],
        [{ fonts: '/fonts/', fontFiles: [{ name: 'stix.ttf', bytes: ttf }] }, 'fonts: options.fonts and options.fontFiles cannot both be set'],
      ];
      for (const [options, expected] of cases) {
        let message;
        try { await client.convert(csv, { format: 'csv', ...options }); } catch (error) { message = error.message; }
        if (message !== expected) throw new Error('wrong error for ' + JSON.stringify(options.fontFiles?.map(file => ({ name: file.name, postscriptName: file.postscriptName }))) + ': ' + message);
        if (message.includes('secret-name')) throw new Error('error leaked a supplied name');
        out.errors.push(message);
      }
      const pdf = () => {
        const stream = 'BT /F1 24 Tf 20 40 Td (Hello PDF) Tj ET';
        const objects = ['<< /Type /Catalog /Pages 2 0 R >>', '<< /Type /Pages /Kids [3 0 R] /Count 1 >>', '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 100] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>', `<< /Length ${stream.length} >>\nstream\n${stream}\nendstream`, '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'];
        let body = '%PDF-1.4\n';
        const offsets = [];
        for (let index = 0; index < objects.length; index++) { offsets.push(body.length); body += `${index + 1} 0 obj\n${objects[index]}\nendobj\n`; }
        const xref = body.length;
        body += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
        for (const offset of offsets) body += `${String(offset).padStart(10, '0')} 00000 n \n`;
        body += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
        return new TextEncoder().encode(body);
      };
      const pdfPlain = await client.convert(pdf(), { format: 'pdf' });
      const pdfWithFonts = await client.convert(pdf(), { format: 'pdf', fontFiles: [{ name: 'stix.ttf', bytes: ttf }] });
      if (pdfPlain.bdf.length !== pdfWithFonts.bdf.length || pdfPlain.bdf.some((value, index) => value !== pdfWithFonts.bdf[index])) throw new Error('PDF must not receive the font database');
      out.pdfBytes = pdfPlain.bdf.length;
      return out;
    } finally { client.terminate(); }
  });
  assert.equal(result.hashes.ttf.length > 0, true);
  assert.notEqual(result.hashes.ttf, result.hashes.otf);
  assert.equal(result.hashes.ttc.length, 2);
  assert.ok(!result.hashes.ttc.includes(result.hashes.ttf));
  assert.equal(result.errors.length, 22);
  assert.ok(result.pdfBytes > 0);
  assert.ok(requests.includes('/fonts/index.json'), 'URL mode must fetch the directory');
  const byteModeRequests = requests.filter(name => name.startsWith('/fonts/'));
  assert.deepEqual(byteModeRequests, ['/fonts/index.json', '/fonts/stix.ttf'], 'only URL mode may fetch fonts: ' + JSON.stringify(byteModeRequests));
  console.log(JSON.stringify({ hashes: result.hashes, pdfBytes: result.pdfBytes, errors: result.errors }, null, 2));
} finally {
  await browser.close();
  await new Promise(resolve => server.close(resolve));
}
