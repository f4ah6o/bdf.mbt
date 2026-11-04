import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const mime = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.wasm': 'application/wasm',
  '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
};
const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>pptx</title>');
    return;
  }
  try {
    const file = resolve(root, '.' + decodeURIComponent(new URL(request.url, 'http://x').pathname));
    if (!file.startsWith(root + '/')) {
      response.writeHead(403).end();
      return;
    }
    const data = await readFile(file);
    response.writeHead(200, { 'content-type': mime[extname(file)] ?? 'application/octet-stream' });
    response.end(data);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((resolvePromise, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolvePromise);
});
const base = 'http://127.0.0.1:' + server.address().port;
const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage();
  await page.goto(base + '/blank.html');
  const result = await page.evaluate(async base => {
    const { Converter } = await import('/node_modules/@bdfkit/convert/dist/index.js');
    const { BdfDocument, BufferSource, ByteReader, decodeObject, decodePathCollection, decodeTextIndex } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
    const upstream = new Converter(
      new Worker('/node_modules/@bdfkit/convert/dist/worker.js', { type: 'module' }),
      '/node_modules/@bdfkit/convert-all/dist/converter.wasm',
    );
    const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
    await Promise.all([upstream.ready, moon.ready]);
    const inspect = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      const view = doc.manifest.views[0];
      const text = view.textIndex
        ? decodeTextIndex(await doc.part(view.textIndex)).map(run => run.text).join(' ')
        : '';
      return {
        id: view.id,
        kind: view.kind,
        pages: view.pages.length,
        sizes: view.pages.map(p => [p.w, p.h]),
        roles: view.pages.map(p => p.layers.map(l => l.role)),
        objects: view.pages.flatMap(p => p.layers.map(l => l.obj)),
        text,
      };
    };

    // A deck that exercises the preset geometry registry, theme style
    // references and placeholder fill/outline inheritance. Its shapes use
    // lines only (no arcs), so both converters can be compared command by
    // command after applying their draw transforms.
    const encoder = new TextEncoder();
    const put16 = (bytes, at, value) => {
      bytes[at] = value & 0xff;
      bytes[at + 1] = (value >> 8) & 0xff;
    };
    const put32 = (bytes, at, value) => {
      bytes[at] = value & 0xff;
      bytes[at + 1] = (value >> 8) & 0xff;
      bytes[at + 2] = (value >> 16) & 0xff;
      bytes[at + 3] = (value >> 24) & 0xff;
    };
    const storedZip = files => {
      const entries = files.map(([name, body]) => ({
        name: encoder.encode(name),
        body: encoder.encode(body),
      }));
      let total = 22;
      for (const entry of entries) total += 30 + entry.name.length + entry.body.length + 46 + entry.name.length;
      const out = new Uint8Array(total);
      const offsets = [];
      let at = 0;
      for (const entry of entries) {
        offsets.push(at);
        put32(out, at, 0x04034b50);
        put16(out, at + 4, 20);
        put32(out, at + 18, entry.body.length);
        put32(out, at + 22, entry.body.length);
        put16(out, at + 26, entry.name.length);
        out.set(entry.name, at + 30);
        out.set(entry.body, at + 30 + entry.name.length);
        at += 30 + entry.name.length + entry.body.length;
      }
      const central = at;
      for (const [index, entry] of entries.entries()) {
        put32(out, at, 0x02014b50);
        put16(out, at + 4, 20);
        put16(out, at + 6, 20);
        put32(out, at + 20, entry.body.length);
        put32(out, at + 24, entry.body.length);
        put16(out, at + 28, entry.name.length);
        put32(out, at + 42, offsets[index]);
        out.set(entry.name, at + 46);
        at += 46 + entry.name.length;
      }
      put32(out, at, 0x06054b50);
      put16(out, at + 8, entries.length);
      put16(out, at + 10, entries.length);
      put32(out, at + 12, at - central);
      put32(out, at + 16, central);
      return out;
    };
    const relations = (targets, extra = '') =>
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
      targets.map(([id, type, target]) =>
        '<Relationship Id="' + id + '" Type="http://schemas.openxmlformats.org/' + type + '" Target="' + target + '"/>')
        .join('') + extra + '</Relationships>';
    const shape = (prst, x, y, w, h, fill, extra = '', text = '') =>
      '<p:sp><p:nvSpPr><p:cNvPr id="2" name="' + prst + '"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr>' +
      '<p:spPr><a:xfrm><a:off x="' + x + '" y="' + y + '"/><a:ext cx="' + w + '" cy="' + h + '"/></a:xfrm>' +
      '<a:prstGeom prst="' + prst + '"/>' + fill + extra + '</p:spPr>' +
      (text ? '<p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800" lang="en-US"/><a:t>' + text + '</a:t></a:r></a:p></p:txBody>' : '') +
      '</p:sp>';
    const solid = color => '<a:solidFill><a:srgbClr val="' + color + '"/></a:solidFill>';
    const line = (color, width = '12700') => '<a:ln w="' + width + '">' + solid(color) + '</a:ln>';
    const presetSlide =
      '<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">' +
      '<p:cSld><p:spTree><p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr><p:grpSpPr/>' +
      shape('triangle', 914400, 457200, 2540000, 1270000, solid('00FF00')) +
      shape('diamond', 4572000, 457200, 2540000, 1270000, solid('FF0000')) +
      shape('rightArrow', 457200, 2286000, 2540000, 1270000, solid('0000FF')) +
      shape('star5', 4572000, 2286000, 2540000, 1270000, solid('FFFF00')) +
      shape('hexagon', 914400, 4114800, 2540000, 1270000, solid('800080')) +
      shape('wedgeRectCallout', 4572000, 4114800, 2540000, 1270000, solid('FF8000'), line('000000')) +
      shape('flowChartDecision', 6858000, 457200, 1270000, 1270000, solid('00FFFF')) +
      shape('rect', 6858000, 2286000, 1270000, 1270000, '',
        '<p:style><a:lnRef idx="1"><a:schemeClr val="accent1"/></a:lnRef>' +
        '<a:fillRef idx="1"><a:schemeClr val="accent1"/></a:fillRef>' +
        '<a:effectRef idx="0"><a:schemeClr val="accent1"/></a:effectRef>' +
        '<a:fontRef idx="minor"><a:schemeClr val="lt1"/></a:fontRef></p:style>') +
      shape('notAPreset', 6858000, 4114800, 1270000, 914400, solid('999999')) +
      '<p:sp><p:nvSpPr><p:cNvPr id="3" name="Placeholder"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr>' +
      '<p:spPr><a:xfrm><a:off x="914400" y="914400"/><a:ext cx="4572000" cy="914400"/></a:xfrm></p:spPr>' +
      '<p:txBody><a:bodyPr/><a:p><a:r><a:rPr sz="1800" lang="en-US"/><a:t>Inherited body text</a:t></a:r></a:p></p:txBody></p:sp>' +
      '</p:spTree></p:cSld></p:sld>';
    const presetLayout =
      '<p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">' +
      '<p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="Layout"/><p:cNvSpPr/><p:nvPr><p:ph type="body" idx="1"/></p:nvPr></p:nvSpPr>' +
      '<p:spPr>' + solid('224466') + line('33CC33', '25400') + '</p:spPr></p:sp></p:spTree></p:cSld></p:sldLayout>';
    const presetMaster =
      '<p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">' +
      '<p:clrMap bg1="lt1" tx1="dk1" bg2="lt2" tx2="dk2" accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" hlink="hlink" folHlink="folHlink"/>' +
      '<p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="Master"/><p:cNvSpPr/><p:nvPr><p:ph type="body"/></p:nvPr></p:nvSpPr>' +
      '<p:spPr>' + solid('0000FF') + '</p:spPr></p:sp></p:spTree></p:cSld></p:sldMaster>';
    const presetTheme =
      '<a:theme xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" name="Test"><a:themeElements>' +
      '<a:clrScheme name="Test"><a:dk1><a:srgbClr val="000000"/></a:dk1><a:lt1><a:srgbClr val="FFFFFF"/></a:lt1>' +
      '<a:dk2><a:srgbClr val="333333"/></a:dk2><a:lt2><a:srgbClr val="EEEEEE"/></a:lt2>' +
      '<a:accent1><a:srgbClr val="CC0000"/></a:accent1><a:accent2><a:srgbClr val="00CC00"/></a:accent2></a:clrScheme>' +
      '<a:fmtScheme name="Test"><a:fillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:fillStyleLst>' +
      '<a:bgFillStyleLst><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:bgFillStyleLst>' +
      '<a:lnStyleLst><a:ln w="12700"><a:solidFill><a:schemeClr val="phClr"/></a:solidFill></a:ln></a:lnStyleLst>' +
      '</a:fmtScheme></a:themeElements></a:theme>';
    const presetDeck = storedZip([
      ['_rels/.rels', relations([
        ['root', 'officeDocument/2006/relationships/officeDocument', 'ppt/presentation.xml'],
        ['theme', 'officeDocument/2006/relationships/theme', 'ppt/theme/theme1.xml'],
      ])],
      ['ppt/presentation.xml', '<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst><p:sldSz cx="9144000" cy="6858000"/></p:presentation>'],
      ['ppt/_rels/presentation.xml.rels', relations([['rId1', 'slide', 'slides/slide1.xml']])],
      ['ppt/slides/slide1.xml', presetSlide],
      ['ppt/slides/_rels/slide1.xml.rels', relations([['l1', 'slideLayout', '../slideLayouts/slideLayout1.xml']])],
      ['ppt/slideLayouts/slideLayout1.xml', presetLayout],
      ['ppt/slideLayouts/_rels/slideLayout1.xml.rels', relations([['m1', 'slideMaster', '../slideMasters/slideMaster1.xml']])],
      ['ppt/slideMasters/slideMaster1.xml', presetMaster],
      ['ppt/slideMasters/_rels/slideMaster1.xml.rels', relations([['t1', 'theme', '../theme/theme1.xml']])],
      ['ppt/theme/theme1.xml', presetTheme],
    ]);
    // Compare the drawing commands of both documents after applying the
    // transform in effect: rects and polygon paths, their fills and outlines.
    const round = value => Math.round(value * 100) / 100;
    const geometryCommands = async (doc, layer) => {
      const object = decodeObject(await doc.part(layer.obj));
      const out = [];
      const reader = new ByteReader(object.ops);
      let matrix = [1, 0, 0, 1, 0, 0];
      const stack = [];
      const apply = (x, y) => [
        matrix[0] * x + matrix[2] * y + matrix[4],
        matrix[1] * x + matrix[3] * y + matrix[5],
      ];
      const concat = next => {
        matrix = [
          matrix[0] * next[0] + matrix[2] * next[1],
          matrix[1] * next[0] + matrix[3] * next[1],
          matrix[0] * next[2] + matrix[2] * next[3],
          matrix[1] * next[2] + matrix[3] * next[3],
          matrix[0] * next[4] + matrix[2] * next[5] + matrix[4],
          matrix[1] * next[4] + matrix[3] * next[5] + matrix[5],
        ];
      };
      const pathAt = async index => {
        const entry = object.paths[index];
        if (entry.inline) return entry.inline;
        const collection = decodePathCollection(await doc.part(entry.hash));
        return collection[entry.index];
      };
      const placedPath = path => {
        const verbs = Array.from(path.verbs);
        const args = Array.from(path.args);
        const points = [];
        for (let i = 0, at = 0; i < verbs.length; i++) {
          if (verbs[i] === 0 || verbs[i] === 1) {
            const point = apply(args[at], args[at + 1]);
            points.push(point);
            at += 2;
          } else if (verbs[i] === 4 || verbs[i] === 5) {
            at += verbs[i] === 5 ? 4 : 0;
          } else {
            return null;
          }
        }
        if (verbs.length === 1 && verbs[0] === 5) {
          const [x, y] = apply(args[0], args[1]);
          return ['rect', round(x), round(y), round(args[2]), round(args[3])];
        }
        if (verbs.length === 5 && verbs[4] === 4 &&
          verbs.slice(1, 4).every(verb => verb === 1) &&
          points[1][1] === points[0][1] && points[2][0] === points[1][0] &&
          points[3][1] === points[2][1] && points[0][0] === points[3][0]) {
          const x = Math.min(points[0][0], points[1][0], points[2][0], points[3][0]);
          const y = Math.min(points[0][1], points[1][1], points[2][1], points[3][1]);
          return ['rect', round(x), round(y), round(points[2][0] - x), round(points[2][1] - y)];
        }
        const coordinates = [];
        for (const point of points) {
          coordinates.push(round(point[0]), round(point[1]));
        }
        return ['path', verbs.join(''), coordinates];
      };
      const geometry = path => {
        const placed = placedPath(path);
        return placed ?? ['path', Array.from(path.verbs).join(''), Array.from(path.args).map(round)];
      };
      while (!reader.eof) {
        const op = reader.u8();
        switch (op) {
          case 0x01: stack.push(matrix.slice()); break;
          case 0x02: matrix = stack.pop() ?? [1, 0, 0, 1, 0, 0]; break;
          case 0x03: concat([reader.f32(), reader.f32(), reader.f32(), reader.f32(), reader.f32(), reader.f32()]); break;
          case 0x04: {
            const x = reader.f32(), y = reader.f32();
            concat([1, 0, 0, 1, x, y]);
            break;
          }
          case 0x05: concat([reader.f32(), 0, 0, reader.f32(), 0, 0]); break;
          case 0x06: reader.varuint(); reader.u8(); break;
          case 0x07: for (let i = 0; i < 4; i++) reader.f32(); break;
          case 0x10: out.push(['fillcolor', reader.u32()]); break;
          case 0x11: reader.varuint(); break;
          case 0x12: out.push(['strokecolor', reader.u32()]); break;
          case 0x13: reader.varuint(); break;
          case 0x14: out.push(['line', round(reader.f32()), reader.u8(), reader.u8(), round(reader.f32())]); break;
          case 0x15: {
            const count = reader.varuint();
            const segments = [];
            for (let i = 0; i < count; i++) segments.push(round(reader.f32()));
            segments.push(round(reader.f32()));
            out.push(['dash', segments]);
            break;
          }
          case 0x16: reader.f32(); break;
          case 0x17: reader.u8(); break;
          case 0x18: reader.u32(); reader.f32(); reader.f32(); reader.f32(); break;
          case 0x19: reader.varuint(); break;
          case 0x1a: reader.varuint(); reader.f32(); break;
          case 0x1b: reader.u8(); reader.u8(); reader.u8(); reader.f32(); break;
          case 0x20: {
            const [x, y] = apply(reader.f32(), reader.f32());
            out.push(['fill', ['rect', round(x), round(y), round(reader.f32()), round(reader.f32())]]);
            break;
          }
          case 0x21: {
            const [x, y] = apply(reader.f32(), reader.f32());
            out.push(['stroke', ['rect', round(x), round(y), round(reader.f32()), round(reader.f32())]]);
            break;
          }
          case 0x22: {
            const index = reader.varuint();
            reader.u8();
            out.push(['fill', geometry(await pathAt(index))]);
            break;
          }
          case 0x23: {
            const index = reader.varuint();
            out.push(['stroke', geometry(await pathAt(index))]);
            break;
          }
          case 0x24: {
            const index = reader.varuint();
            reader.u8();
            reader.f32(); reader.f32();
            out.push(['fill', geometry(await pathAt(index))]);
            break;
          }
          case 0x25: {
            reader.u8();
            const count = reader.varuint();
            for (let i = 0; i < count; i++) { reader.varuint(); reader.f32(); reader.f32(); }
            break;
          }
          case 0x26: for (let i = 0; i < 4; i++) reader.f32(); break;
          case 0x30: reader.varuint(); reader.f32(); reader.f32(); reader.f32(); break;
          case 0x31: reader.varuint(); reader.f32(); reader.f32(); reader.f32(); break;
          case 0x40: reader.varuint(); for (let i = 0; i < 4; i++) reader.f32(); break;
          case 0x41: reader.varuint(); for (let i = 0; i < 8; i++) reader.f32(); break;
          case 0x42: reader.u8(); reader.u8(); break;
          case 0x50: reader.varuint(); break;
          case 0x51: reader.varuint(); reader.f32(); reader.f32(); break;
          case 0x52: reader.f32(); reader.u8(); for (let i = 0; i < 4; i++) reader.f32(); break;
          case 0x53: break;
          case 0x54: {
            reader.u8();
            reader.u32();
            reader.bytesN(reader.varuint());
            break;
          }
          case 0x55: break;
          case 0x70: for (let i = 0; i < 4; i++) reader.f32(); reader.varuint(); break;
          case 0x71: reader.u8(); reader.varuint(); break;
          case 0xff: reader.bytesN(reader.u32()); break;
          default: throw new Error('unexpected opcode 0x' + op.toString(16) + ' of ' + object.ops.length + ' bytes in the ' + layer.role + ' layer: ' + Array.from(object.ops.slice(Math.max(0, reader.pos - 24), reader.pos + 8)).join(','));
        }
      }
      return out;
    };
    const drawing = async bdf => {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      const layers = [];
      for (const page of doc.manifest.views[0].pages) {
        for (const layer of page.layers) {
          layers.push({ role: layer.role, commands: await geometryCommands(doc, layer) });
        }
      }
      return layers;
    };
    const cases = [];
    for (const name of ['basic', 'features', 'math']) {
      const data = new Uint8Array(await (await fetch(base + '/.upstream/converter/pptx/testdata/' + name + '.pptx')).arrayBuffer());
      const a = await upstream.convert(data, { name: name + '.pptx' });
      const m = await moon.convert(data, { name: name + '.pptx' });
      cases.push({
        name,
        upstream: { summary: a.summary, warnings: a.warnings, ...(await inspect(a.bdf)) },
        moon: { summary: m.summary, warnings: m.warnings, ...(await inspect(m.bdf)) },
      });
    }
    const presetUpstream = await upstream.convert(presetDeck, { name: 'presets.pptx' });
    const presetMoon = await moon.convert(presetDeck, { name: 'presets.pptx' });
    const presets = {
      upstream: {
        summary: presetUpstream.summary,
        warnings: presetUpstream.warnings,
        drawing: await drawing(presetUpstream.bdf),
        ...(await inspect(presetUpstream.bdf)),
      },
      moon: {
        summary: presetMoon.summary,
        warnings: presetMoon.warnings,
        drawing: await drawing(presetMoon.bdf),
        ...(await inspect(presetMoon.bdf)),
      },
    };
    moon.terminate();
    return { cases, presets };
  }, base);
  const normalize = value => value.replace(/\\s+/g, '');
  const lcs = (a, b) => {
    let previous = new Array(b.length + 1).fill(0);
    for (let i = 1; i <= a.length; i++) {
      const current = new Array(b.length + 1).fill(0);
      for (let j = 1; j <= b.length; j++) {
        current[j] = a[i - 1] === b[j - 1]
          ? previous[j - 1] + 1
          : Math.max(previous[j], current[j - 1]);
      }
      previous = current;
    }
    return previous[b.length];
  };
  const similarity = (a, b) => {
    const x = normalize(a);
    const y = normalize(b);
    return 2 * lcs(x, y) / (x.length + y.length);
  };
  for (const entry of result.cases) {
    assert.equal(entry.moon.id, 'slides', entry.name + ': view id');
    assert.equal(entry.moon.kind, 'fixed', entry.name + ': view kind');
    assert.equal(entry.moon.pages, entry.upstream.pages, entry.name + ': page count');
    assert.deepEqual(entry.moon.sizes, entry.upstream.sizes, entry.name + ': page sizes');
    assert.deepEqual(entry.moon.roles, entry.upstream.roles, entry.name + ': layer roles');
    assert.equal(entry.moon.summary, entry.upstream.summary, entry.name + ': summary');
    assert.ok(entry.moon.warnings.some(w => w.includes('no fonts found')), entry.name + ': font warning');
    const ratio = similarity(entry.upstream.text, entry.moon.text);
    assert.ok(ratio >= 0.99, entry.name + ': text similarity ' + ratio.toFixed(4));
    if (entry.name === 'math') {
      assert.ok(!entry.moon.text.includes('FALLBACK PICTURE'), 'math: fallback picture text');
      assert.ok(entry.moon.text.includes('e^(iπ)+1=0'), 'math: linearized formula');
    }
    if (entry.name === 'features') {
      assert.ok(new Set(entry.moon.objects).size < entry.moon.objects.length, 'features: shared master/layout objects');
    }
  }
  const presets = result.presets;
  assert.equal(presets.moon.pages, presets.upstream.pages, 'presets: page count');
  assert.deepEqual(presets.moon.sizes, presets.upstream.sizes, 'presets: page sizes');
  assert.deepEqual(presets.moon.roles, presets.upstream.roles, 'presets: layer roles');
  assert.equal(presets.moon.summary, presets.upstream.summary, 'presets: summary');
  assert.deepEqual(presets.moon.warnings, presets.upstream.warnings, 'presets: warnings');
  assert.ok(
    presets.moon.warnings.includes('unknown preset shape "notAPreset" drawn as a rectangle'),
    'presets: unknown preset warning',
  );
  assert.deepEqual(presets.moon.drawing, presets.upstream.drawing, 'presets: drawing commands');
  assert.equal(similarity(presets.upstream.text, presets.moon.text), 1, 'presets: text');
  console.log('Phase 15 PPTX: slides view, layers, master sharing, text and OMML match upstream; preset geometry, theme fills and placeholder inheritance draw the same commands.');

} finally {
  await browser.close();
  server.close();
}
