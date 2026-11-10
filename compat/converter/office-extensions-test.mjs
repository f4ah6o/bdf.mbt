// The converter Worker's format notification and the Office extensions
// upstream registers on the workbook, word-processing and presentation
// converters (`converter/xlsx`, `converter/docx` and `converter/pptx` at
// `a5e4d7a`).
//
//   MOON_HOME=$PWD/.moon-home moon build --target js
//   node compat/converter/office-extensions-test.mjs
//
// The Worker is a browser module. This test gives it the `self` it expects and
// drives the same message protocol a client uses, so the metadata and the
// conversions are checked without a browser. A macro-enabled or template
// package is the same OPC package as its plain counterpart: the content
// decides the format, the extension only decides it when the content is not
// recognized, and a VBA project is never executed or carried into the BDF.
import assert from 'node:assert/strict';
import { BdfDocument, BufferSource } from '@bdfkit/core';

const workerUrl = new URL(
  '../../_build/js/debug/build/native_converter_worker/native_converter_worker.js',
  import.meta.url,
);

const encoder = new TextEncoder();

/** The extensions upstream registers on each retained Office converter. */
const UPSTREAM_OFFICE = {
  xlsx: ['.xlsx', '.xlsm', '.xltx', '.xltm'],
  docx: ['.docx', '.docm', '.dotx', '.dotm'],
  pptx: ['.pptx', '.pptm', '.ppsx', '.ppsm', '.potx', '.potm'],
};

/** Formats dropped from the porting scope; they must stay unregistered. */
const DROPPED = ['epub', 'gerber', 'kicad', 'midi', 'mml', 'musicxml'];

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

const crcTable = Array.from({ length: 256 }, (_, index) => {
  let value = index;
  for (let bit = 0; bit < 8; bit++) value = value & 1 ? 0xedb88320 ^ (value >>> 1) : value >>> 1;
  return value >>> 0;
});
const crc32 = data => {
  let crc = 0xffffffff;
  for (const byte of data) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
};

/** A ZIP of stored entries, the container every OOXML package is. */
const storedZip = files => {
  const entries = files.map(([name, body]) => ({
    name: encoder.encode(name),
    body: typeof body === 'string' ? encoder.encode(body) : body,
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
    put32(out, at + 14, crc32(entry.body));
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
    put32(out, at + 16, crc32(entry.body));
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

const contentTypes = body =>
  `<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">${body}</Types>`;
const relationships = target =>
  `<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="${target}"/></Relationships>`;

const workbook = () =>
  storedZip([
    ['[Content_Types].xml', contentTypes('<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>')],
    ['_rels/.rels', relationships('xl/workbook.xml')],
    ['xl/workbook.xml', '<?xml version="1.0"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>'],
    ['xl/_rels/workbook.xml.rels', '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>'],
    ['xl/worksheets/sheet1.xml', '<?xml version="1.0"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Hello workbook</t></is></c></row></sheetData></worksheet>'],
  ]);

const document = () =>
  storedZip([
    ['[Content_Types].xml', contentTypes('<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>')],
    ['_rels/.rels', relationships('word/document.xml')],
    ['word/document.xml', '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Hello document</w:t></w:r></w:p></w:body></w:document>'],
  ]);

const presentation = () =>
  storedZip([
    ['[Content_Types].xml', contentTypes('<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>')],
    ['_rels/.rels', relationships('ppt/presentation.xml')],
    ['ppt/presentation.xml', '<?xml version="1.0"?><p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:sldIdLst><p:sldId id="256" r:id="rId2"/></p:sldIdLst><p:sldSz cx="9144000" cy="6858000"/></p:presentation>'],
    ['ppt/_rels/presentation.xml.rels', '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/></Relationships>'],
    ['ppt/slides/slide1.xml', '<?xml version="1.0"?><p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:txBody><a:p><a:r><a:t>Hello slide</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>'],
  ]);

const PACKAGES = { xlsx: workbook, docx: document, pptx: presentation };

/** The VBA project a macro-enabled document carries. */
const MACRO_MARKER = 'VBA-MACRO-MUST-NOT-RUN';

/** The document package with the VBA project part a `.docm` carries. */
const macroDocument = () =>
  storedZip([
    ['[Content_Types].xml', contentTypes('<Override PartName="/word/document.xml" ContentType="application/vnd.ms-word.document.macroEnabled.main+xml"/>')],
    ['_rels/.rels', relationships('word/document.xml')],
    ['word/document.xml', '<?xml version="1.0"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>Hello document</w:t></w:r></w:p></w:body></w:document>'],
    ['word/vbaProject.bin', MACRO_MARKER],
  ]);

const replies = [];
globalThis.self = {
  onmessage: null,
  postMessage: message => replies.push(message),
};
await import(workerUrl.href);

/** Send one request and wait for the reply the Worker posts. */
const send = async request => {
  const before = replies.length;
  self.onmessage({ data: request });
  for (let attempt = 0; attempt < 400 && replies.length === before; attempt++) {
    await new Promise(resolve => setTimeout(resolve, 5));
  }
  assert.ok(replies.length > before, `no reply to ${request.type}`);
  return replies[replies.length - 1];
};

const convert = (data, options) => send({ id: 1, type: 'convert', data: data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength), options });

/** The bytes of a converted document, read back by the upstream reader. */
const readBdf = async bdf => BdfDocument.open(new BufferSource(bdf));

const contains = (haystack, needle) => {
  const text = encoder.encode(needle);
  outer: for (let at = 0; at + text.length <= haystack.length; at++) {
    for (let index = 0; index < text.length; index++) {
      if (haystack[at + index] !== text[index]) continue outer;
    }
    return true;
  }
  return false;
};

const init = await send({ type: 'init', wasm: '' });
assert.equal(init.id, 0);
assert.equal(init.ok, true);
const formats = new Map(init.formats.map(format => [format.name, format]));

// The notification is what a client builds its file picker from, so it must
// name every extension the converters accept.
for (const [name, extensions] of Object.entries(UPSTREAM_OFFICE)) {
  assert.ok(formats.has(name), `the Worker does not advertise ${name}`);
  assert.deepEqual(formats.get(name).extensions, extensions, `${name} extensions differ from upstream`);
}

// HTML is retained but its MHTML reader is not ported: advertising `.mhtml`
// or `.mht` would promise a conversion the Worker cannot make.
assert.deepEqual(formats.get('html').extensions, ['.html', '.htm', '.xhtml'], 'HTML must not advertise the unported MHTML extensions');

for (const name of DROPPED) {
  assert.ok(!formats.has(name), `dropped format is still registered: ${name}`);
}

// Content decides the format, whatever the extension says.
for (const [format, extensions] of Object.entries(UPSTREAM_OFFICE)) {
  for (const extension of extensions) {
    const data = PACKAGES[format]();
    const reply = await convert(data, { name: 'sample' + extension });
    assert.equal(reply.ok, true, `sample${extension}: ${reply.error}`);
    assert.equal(reply.result.format, format, `sample${extension} was detected as ${reply.result.format}`);
    const doc = await readBdf(reply.result.bdf);
    assert.ok(doc.manifest.views.length > 0, `sample${extension} is not a readable BDF`);
    // A workbook has a sheet view of tiles; a document or a deck has pages.
    const view = doc.manifest.views[0];
    const drawn = view.pages?.length ?? Object.keys(view.tiles ?? {}).length;
    assert.ok(drawn > 0, `sample${extension} has no page`);
  }
}

// An explicit format converts the same bytes under any name.
for (const [format, extensions] of Object.entries(UPSTREAM_OFFICE)) {
  for (const extension of extensions) {
    const reply = await convert(PACKAGES[format](), { format, name: 'sample' + extension });
    assert.equal(reply.ok, true, `sample${extension} as ${format}: ${reply.error}`);
    assert.equal(reply.result.format, format);
  }
}

// Upstream's detectNamed falls back to the registered extension when no
// detector claims the content, so a broken package is reported as the format
// its name promises instead of as an unsupported image.
const junk = encoder.encode('not an OPC package at all\n');
for (const [format, extensions] of Object.entries(UPSTREAM_OFFICE)) {
  for (const extension of extensions) {
    const reply = await convert(junk, { name: 'sample' + extension });
    assert.equal(reply.ok, false, `sample${extension} should not convert`);
    assert.ok(reply.error.startsWith(format + ': '), `sample${extension} reported ${reply.error}`);
  }
}

// A macro-enabled document converts as its plain counterpart: the VBA project
// is never executed, its bytes are not carried into the BDF, and the input
// archive is left as it was.
{
  const plain = document();
  const macro = macroDocument();
  const before = macro.slice();
  const plainReply = await convert(plain, { name: 'sample.docm' });
  const macroReply = await convert(macro, { name: 'sample.docm' });
  assert.equal(macroReply.ok, true, macroReply.error);
  assert.equal(macroReply.result.format, 'docx');
  assert.deepEqual(macroReply.result.bdf, plainReply.result.bdf, 'the VBA project changed the converted document');
  assert.equal(contains(macroReply.result.bdf, MACRO_MARKER), false, 'the VBA project reached the BDF');
  assert.deepEqual(macro, before, 'conversion rewrote the input archive');
  assert.equal(contains(macro, MACRO_MARKER), true, 'the fixture lost its VBA project');
  const doc = await readBdf(macroReply.result.bdf);
  assert.ok(doc.manifest.views.length > 0);
}

// The unported and dropped extensions must not reach a converter by name.
for (const [name, body] of [
  ['page.mht', 'MIME-Version: 1.0\r\nContent-Type: multipart/related; boundary="x"\r\n\r\n--x\r\nContent-Type: text/html\r\n\r\n<html><body>hi</body></html>\r\n--x--\r\n'],
  ['page.mhtml', 'MIME-Version: 1.0\r\nContent-Type: multipart/related; boundary="x"\r\n\r\n--x\r\nContent-Type: text/html\r\n\r\n<html><body>hi</body></html>\r\n--x--\r\n'],
  ['bundle.zip', 'PK\u0003\u0004 not really'],
  ['book.epub', 'not a zip'],
  ['song.mid', 'not midi'],
  ['tune.mml', 'r4'],
  ['score.musicxml', 'name,value\nA,1\nB,2\n'],
  ['board.kicad_pcb', '(kicad_pcb (version 20240108))'],
  ['board.gbr', 'G04 dropped*\n%FSLAX46Y46*%\n'],
]) {
  let format;
  try {
    format = (await convert(encoder.encode(body), { name })).result.format;
  } catch (error) {
    format = 'error';
  }
  assert.ok(!['html', 'epub', 'midi', 'mml', 'musicxml', 'kicad', 'gerber'].includes(format), `${name} reached ${format}`);
}

console.log(
  `converter Worker advertises ${formats.size} formats; ${Object.values(UPSTREAM_OFFICE).flat().length} Office extensions convert by content, by explicit format and by name.`,
);
