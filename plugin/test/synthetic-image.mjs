// Synthetic raster fixtures for the diagram-document tests: genuinely
// decodable raster images — a solid-color truecolor PNG per the PNG
// specification (real signature, IHDR, IDAT, IEND, correct CRCs), an
// optional ancillary-chunk padding variant for size-boundary cases, a
// header-only PNG for dimension-validation cases, and a minimal baseline
// JPEG that browsers decode. Everything is generated in-process; no
// samples of any real file, private format or organization are involved.

import { deflateSync } from "node:zlib";

const CRC_TABLE = (() => {
  const table = new Uint32Array(256);
  for (let n = 0; n < 256; n += 1) {
    let c = n;
    for (let k = 0; k < 8; k += 1) {
      c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    }
    table[n] = c >>> 0;
  }
  return table;
})();

function crc32(bytes) {
  let c = 0xffffffff;
  for (const byte of bytes) {
    c = CRC_TABLE[(c ^ byte) & 0xff] ^ (c >>> 8);
  }
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, payload) {
  const out = new Uint8Array(12 + payload.length);
  const view = new DataView(out.buffer);
  view.setUint32(0, payload.length);
  out.set([...type].map(c => c.charCodeAt(0)), 4);
  out.set(payload, 8);
  view.setUint32(8 + payload.length, crc32(out.subarray(4, 8 + payload.length)));
  return out;
}

///|
// A valid 8-bit truecolor PNG of one solid color, the way the PNG
// specification lays it out (filter byte 0 per scanline). Browsers decode
// these files, so the Chromium renderer test can draw them for real.
export function syntheticPng(width, height, [r, g, b] = [200, 30, 30]) {
  const header = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = new Uint8Array(13);
  const ihdrView = new DataView(ihdr.buffer);
  ihdrView.setUint32(0, width);
  ihdrView.setUint32(4, height);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 2; // truecolor
  ihdr[10] = 0; // deflate
  ihdr[11] = 0; // adaptive filtering
  ihdr[12] = 0; // no interlace
  const stride = width * 3;
  const raw = new Uint8Array(height * (stride + 1));
  for (let y = 0; y < height; y += 1) {
    const at = y * (stride + 1);
    raw[at] = 0; // filter: none
    for (let x = 0; x < stride; x += 3) {
      raw[at + 1 + x] = r;
      raw[at + 1 + x + 1] = g;
      raw[at + 1 + x + 2] = b;
    }
  }
  const idat = deflateSync(raw, { level: 9 });
  const parts = [header, chunk("IHDR", ihdr), chunk("IDAT", idat), chunk("IEND", new Uint8Array(0))];
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const out = new Uint8Array(total);
  let at = 0;
  for (const part of parts) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}

///|
// A structurally valid PNG of one solid color whose file size is padded to
// the requested length by one ancillary `prVt` chunk (ancillary chunks are
// legal in any PNG and the encoder skips them structurally). Used for
// per-image and total image-byte caps without generating huge rasters.
export function syntheticPngPadded(totalBytes, tag = 0, [r, g, b] = [210, 40, 130]) {
  const raw = new Uint8Array(8 * (8 * 3 + 1));
  for (let at = 0; at < raw.length; at += 1) {
    const inRow = at % (8 * 3 + 1);
    raw[at] = inRow === 0
      ? 0 // filter: none
      : inRow % 3 === 1 ? r : inRow % 3 === 2 ? g : b;
  }
  const idat = deflateSync(raw, { level: 9 });
  // 8 signature + (12+13) IHDR + (12+payload) pad + (12+idat) IDAT + 12 IEND
  const fixed = 8 + 25 + 12 + 12 + idat.length + 12;
  if (totalBytes < fixed) {
    throw new Error(`syntheticPngPadded needs at least ${fixed} bytes`);
  }
  const payload = new Uint8Array(totalBytes - fixed);
  payload[payload.length - 1] = tag & 0xff;
  const parts = [
    new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", (() => { const ihdr = new Uint8Array(13); const view = new DataView(ihdr.buffer); view.setUint32(0, 8); view.setUint32(4, 8); ihdr[8] = 8; ihdr[9] = 2; return ihdr; })()),
    chunk("prVt", payload),
    chunk("IDAT", idat),
    chunk("IEND", new Uint8Array(0)),
  ];
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  if (total !== totalBytes) {
    throw new Error(`syntheticPngPadded sizing is off by ${totalBytes - total}`);
  }
  const out = new Uint8Array(total);
  let at = 0;
  for (const part of parts) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}

///|
// A PNG signature block with caller-chosen IHDR dimensions but no IDAT:
// accepted by nothing that decodes PNG, and only useful for dimension
// validation cases.
export function syntheticPngHeader(width, height, { bytes = 33 } = {}) {
  const header = new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const ihdr = new Uint8Array(13);
  const ihdrView = new DataView(ihdr.buffer);
  ihdrView.setUint32(0, width);
  ihdrView.setUint32(4, height);
  ihdr[8] = 8;
  ihdr[9] = 2;
  const rest = new Uint8Array(Math.max(0, bytes - 33));
  const out = new Uint8Array(header.length + 12 + ihdr.length + rest.length);
  let at = 0;
  for (const part of [header, chunk("IHDR", ihdr), rest]) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}

///|
// A minimal but genuinely decodable baseline JPEG: SOI, one 8-bit quant
// table, a grayscale SOF0 frame, DC/AC Huffman tables whose single 2-bit
// code encodes "difference zero" and "end of block", one SOS, and one
// entropy block per MCU (all-zero coefficients, so every pixel decodes to
// mid-gray 128), byte-aligned and 1-padded per the JPEG specification,
// then EOI. Layout and bit coding follow the published JPEG specification;
// no real file, camera or organizational output is involved.
export function syntheticJpeg(width, height) {
  const mcus = Math.ceil(width / 8) * Math.ceil(height / 8);
  const parts = [new Uint8Array([0xff, 0xd8])]; // SOI
  const segment = (marker, payload) => {
    const out = new Uint8Array(4 + payload.length);
    out[0] = 0xff;
    out[1] = marker;
    new DataView(out.buffer).setUint16(2, payload.length + 2);
    out.set(payload, 4);
    parts.push(out);
  };
  // DQT: table 0, all quantization values 16.
  const dqt = new Uint8Array(65);
  dqt[0] = 0x00;
  dqt.fill(16, 1);
  segment(0xdb, dqt);
  // SOF0: baseline, 8-bit, grayscale, single component.
  // Payload is 9 bytes: precision, height, width, component count,
  // then one 3-byte component entry (id, sampling, quant table).
  const sof = new Uint8Array(9);
  sof[0] = 8;
  new DataView(sof.buffer).setUint16(1, height);
  new DataView(sof.buffer).setUint16(3, width);
  sof[5] = 1; // one component
  sof[6] = 1; // component id
  sof[7] = 0x11; // sampling 1x1
  sof[8] = 0; // quant table 0
  segment(0xc0, sof);
  // DHT: one 2-bit code (00) per table, for DC category 0 and AC EOB.
  const bits = new Uint8Array(17);
  bits[2] = 1;
  for (const [tableClass, symbol] of [[0x00, 0x00], [0x10, 0x00]]) {
    const dht = new Uint8Array(1 + 16 + 1);
    dht[0] = tableClass;
    dht.set(bits.subarray(1), 1);
    dht[17] = symbol;
    segment(0xc4, dht);
  }
  // SOS: one component, both table ids 0, full spectral range.
  segment(0xda, new Uint8Array([1, 1, 0x00, 0, 63, 0]));
  // Entropy: per MCU the bits 00 (DC difference zero) + 00 (EOB), padded
  // with 1s to the byte boundary, with any 0xFF byte stuffed as FF 00.
  let bitCount = 0;
  const bitsOut = [];
  const pushByte = byte => {
    if (byte === 0xff) {
      bitsOut.push(0xff, 0x00);
    } else {
      bitsOut.push(byte);
    }
  };
  let buffer = 0;
  let buffered = 0;
  for (let mcu = 0; mcu < mcus; mcu += 1) {
    bitCount += 4;
    buffer = (buffer << 4) | 0b0000;
    buffered += 4;
    if (buffered === 8) {
      pushByte(buffer & 0xff);
      buffer = 0;
      buffered = 0;
    }
  }
  if (buffered > 0) {
    buffer = (buffer << (8 - buffered)) | (0xff >>> buffered);
    pushByte(buffer & 0xff);
  }
  parts.push(new Uint8Array(bitsOut));
  parts.push(new Uint8Array([0xff, 0xd9])); // EOI
  const total = parts.reduce((sum, part) => sum + part.length, 0);
  const out = new Uint8Array(total);
  let at = 0;
  for (const part of parts) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}
