// A minimal valid synthetic DocuWorks container for end-to-end tests, built
// the way `convert/xdw/kind7_browser_test.mjs` builds its fixture (same
// project, same license): one page with an annotation picture and a
// header/footer picture, each a 2x2 24-bit DIB.

function concat(...parts) {
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const part of parts) {
    out.set(part, at);
    at += part.length;
  }
  return out;
}

function tlv(tag, value) {
  const n = value.length;
  const head = n < 0x80 ? [tag, n] : n < 0x100 ? [tag, 0x81, n] : [tag, 0x82, n >> 8, n & 0xff];
  return concat(Uint8Array.from(head), value);
}

function base128(n) {
  const out = [n & 0x7f];
  n >>= 7;
  while (n > 0) {
    out.unshift((n & 0x7f) | 0x80);
    n >>= 7;
  }
  return out;
}

function prop(tag, value, cls = 0x80) {
  const head = tag < 0x1f ? [cls | tag] : [cls | 0x1f, ...base128(tag)];
  const n = value.length;
  const len = n < 0x80 ? [n] : n < 0x100 ? [0x81, n] : [0x82, n >> 8, n & 0xff];
  return concat(Uint8Array.from([...head, ...len]), value);
}

function beNum(n) {
  const bytes = beRawBytes(n);
  return Uint8Array.from([bytes.length, ...bytes]);
}

function beRawBytes(n) {
  const bytes = [];
  let v = n;
  do {
    bytes.unshift(v & 0xff);
    v = Math.floor(v / 256);
  } while (v > 0);
  if (bytes[0] & 0x80) {
    bytes.unshift(0);
  }
  return bytes;
}

function beRaw(n) {
  return Uint8Array.from(beRawBytes(n));
}

function nums(values) {
  return concat(...values.map(beNum));
}

function kindBytes(kind) {
  const hi = (kind >> 8) & 0xff;
  const lo = kind & 0xff;
  return hi & 0x80 ? Uint8Array.from([0, hi, lo]) : Uint8Array.from([hi, lo]);
}

function record(depth, kind, attrs) {
  const body = concat(prop(0, Uint8Array.from([depth])), prop(2, Uint8Array.from(kind), 0x60), ...attrs);
  return prop(2, body, 0x60);
}

function u32le(n) {
  return Uint8Array.from([n & 0xff, (n >> 8) & 0xff, (n >> 16) & 0xff, (n >> 24) & 0xff]);
}

// One LZH block whose literal table has all 256 bytes at 8 bits, so every
// output byte is its own 8-bit code. Enough for a small properties block.
function lzhLiteral(data) {
  const bits = [];
  const put = (v, n) => {
    for (let i = n - 1; i >= 0; i -= 1) {
      bits.push((v >> i) & 1);
    }
  };
  put(data.length, 16);
  put(0, 5);
  put(10, 5);
  put(256, 9);
  put(0, 4);
  put(0, 4);
  for (const b of data) {
    put(b, 8);
  }
  const out = new Uint8Array(Math.ceil(bits.length / 8));
  for (let i = 0; i < bits.length; i += 1) {
    if (bits[i]) {
      out[i >> 3] |= 0x80 >> (i & 7);
    }
  }
  return out;
}

function bmi24(width, height) {
  const b = new Uint8Array(40);
  const dv = new DataView(b.buffer);
  dv.setUint32(0, 40, true);
  dv.setUint32(4, width, true);
  dv.setInt32(8, height, true);
  dv.setUint16(12, 1, true);
  dv.setUint16(14, 24, true);
  dv.setUint32(16, 0, true);
  dv.setUint32(20, width * height * 3, true);
  return b;
}

function kind7Body() {
  // 2x2 24-bit, stride 8: red/green on top, blue/yellow below, padded
  const row0 = Uint8Array.from([0, 0, 255, 0, 255, 0, 0, 0]);
  const row1 = Uint8Array.from([255, 0, 0, 0, 255, 255, 0, 0]);
  const band = bytes => concat(u32le(bytes.length), u32le(bytes.length), u32le(1), bytes);
  return concat(bmi24(2, 2), u32le(2), band(row0), band(row1));
}

function drawing(annotation) {
  return concat(tlv(0x80, Uint8Array.from([7])), ...(annotation ? [tlv(0x8d, Uint8Array.from([1]))] : []), tlv(0x86, kind7Body()));
}

///|
// One DocuWorks page: an annotation picture at 100,200 and a header/footer
// picture at 100,700, each 300x400pt on a 21000x29700 page.
export function syntheticXdw() {
  const properties = concat(
    record(0, [0x13, 0x01], [prop(5, nums([21000, 29700]))]),
    record(1, [0x13, 0x02], [prop(52, nums([100, 200]))]),
    record(2, kindBytes(0x803f), [prop(5, nums([300, 400])), prop(7, drawing(true))]),
    record(1, [0x13, 0x02], [prop(52, nums([100, 700]))]),
    record(2, kindBytes(0x802e), [prop(5, nums([300, 400])), prop(7, drawing(false))]),
  );
  const compressed = lzhLiteral(properties);
  const propsBlock = tlv(0x63, compressed);
  const fields = concat(
    tlv(0x80, Uint8Array.from([0])),
    tlv(0x82, Uint8Array.from([0])),
    tlv(0x83, beRaw(properties.length)),
    tlv(0x84, beRaw(compressed.length)),
    tlv(0x85, Uint8Array.from([0, 0, 0, 0])),
  );
  const trailerValueLen = fields.length + 6;
  const trailer = tlv(0x68, concat(fields, tlv(0x86, u32le(trailerValueLen))));
  return concat(tlv(0x60, tlv(0x82, Uint8Array.from([10]))), propsBlock, trailer);
}
