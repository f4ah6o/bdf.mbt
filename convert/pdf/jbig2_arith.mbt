///|
// The MQ arithmetic decoder (T.88 Annex E), ported from upstream
// converter/internal/jbig2/arith.go. MoonBit's Int is 32-bit signed, so the
// code and interval registers C and A use UInt: the standard lets them wrap
// modulo 2^32.
priv struct PdfJbig2QeRow {
  qe : UInt
  nmps : Int
  nlps : Int
  switch_mps : Bool
}

///|
// A row of the probability estimation table (T.88 Table E.1).
let pdf_jbig2_qe_table : Array[PdfJbig2QeRow] = [
  { qe: 0x5601U, nmps: 1, nlps: 1, switch_mps: true },
  { qe: 0x3401U, nmps: 2, nlps: 6, switch_mps: false },
  { qe: 0x1801U, nmps: 3, nlps: 9, switch_mps: false },
  { qe: 0x0ac1U, nmps: 4, nlps: 12, switch_mps: false },
  { qe: 0x0521U, nmps: 5, nlps: 29, switch_mps: false },
  { qe: 0x0221U, nmps: 38, nlps: 33, switch_mps: false },
  { qe: 0x5601U, nmps: 7, nlps: 6, switch_mps: true },
  { qe: 0x5401U, nmps: 8, nlps: 14, switch_mps: false },
  { qe: 0x4801U, nmps: 9, nlps: 14, switch_mps: false },
  { qe: 0x3801U, nmps: 10, nlps: 14, switch_mps: false },
  { qe: 0x3001U, nmps: 11, nlps: 17, switch_mps: false },
  { qe: 0x2401U, nmps: 12, nlps: 18, switch_mps: false },
  { qe: 0x1c01U, nmps: 13, nlps: 20, switch_mps: false },
  { qe: 0x1601U, nmps: 29, nlps: 21, switch_mps: false },
  { qe: 0x5601U, nmps: 15, nlps: 14, switch_mps: true },
  { qe: 0x5401U, nmps: 16, nlps: 14, switch_mps: false },
  { qe: 0x5101U, nmps: 17, nlps: 15, switch_mps: false },
  { qe: 0x4801U, nmps: 18, nlps: 16, switch_mps: false },
  { qe: 0x3801U, nmps: 19, nlps: 17, switch_mps: false },
  { qe: 0x3401U, nmps: 20, nlps: 18, switch_mps: false },
  { qe: 0x3001U, nmps: 21, nlps: 19, switch_mps: false },
  { qe: 0x2801U, nmps: 22, nlps: 19, switch_mps: false },
  { qe: 0x2401U, nmps: 23, nlps: 20, switch_mps: false },
  { qe: 0x2201U, nmps: 24, nlps: 21, switch_mps: false },
  { qe: 0x1c01U, nmps: 25, nlps: 22, switch_mps: false },
  { qe: 0x1801U, nmps: 26, nlps: 23, switch_mps: false },
  { qe: 0x1601U, nmps: 27, nlps: 24, switch_mps: false },
  { qe: 0x1401U, nmps: 28, nlps: 25, switch_mps: false },
  { qe: 0x1201U, nmps: 29, nlps: 26, switch_mps: false },
  { qe: 0x1101U, nmps: 30, nlps: 27, switch_mps: false },
  { qe: 0x0ac1U, nmps: 31, nlps: 28, switch_mps: false },
  { qe: 0x09c1U, nmps: 32, nlps: 29, switch_mps: false },
  { qe: 0x08a1U, nmps: 33, nlps: 30, switch_mps: false },
  { qe: 0x0521U, nmps: 34, nlps: 31, switch_mps: false },
  { qe: 0x0441U, nmps: 35, nlps: 32, switch_mps: false },
  { qe: 0x02a1U, nmps: 36, nlps: 33, switch_mps: false },
  { qe: 0x0221U, nmps: 37, nlps: 34, switch_mps: false },
  { qe: 0x0141U, nmps: 38, nlps: 35, switch_mps: false },
  { qe: 0x0111U, nmps: 39, nlps: 36, switch_mps: false },
  { qe: 0x0085U, nmps: 40, nlps: 37, switch_mps: false },
  { qe: 0x0049U, nmps: 41, nlps: 38, switch_mps: false },
  { qe: 0x0025U, nmps: 42, nlps: 39, switch_mps: false },
  { qe: 0x0015U, nmps: 43, nlps: 40, switch_mps: false },
  { qe: 0x0009U, nmps: 44, nlps: 41, switch_mps: false },
  { qe: 0x0005U, nmps: 45, nlps: 42, switch_mps: false },
  { qe: 0x0001U, nmps: 45, nlps: 43, switch_mps: false },
  { qe: 0x5601U, nmps: 46, nlps: 46, switch_mps: false },
]

///|
// How many bytes past the end of its data, or past the marker that ends it,
// the decoder reads before the data counts as exhausted. Coded data needs no
// more than a few; reading on decodes garbage from corrupt or truncated data.
let pdf_jbig2_max_overrun : Int = 16

///|
// A context is an Int holding its state index shifted left by one and its more
// probable symbol in bit 0; the zero value is the initial state.
priv struct PdfJbig2Arith {
  data : Bytes
  mut pos : Int
  mut c : UInt
  mut a : UInt
  mut ct : Int
  mut over : Int
}

///|
fn pdf_jbig2_arith_new(data : Bytes) -> PdfJbig2Arith {
  let d : PdfJbig2Arith = {
    data,
    pos: 0,
    c: 0U,
    a: 0x8000U,
    ct: 0,
    over: 0,
  }
  d.c = pdf_jbig2_arith_byte_at(d, 0) << 16
  pdf_jbig2_arith_byte_in(d)
  d.c = d.c << 7
  d.ct -= 7
  d
}

///|
fn pdf_jbig2_arith_byte_at(d : PdfJbig2Arith, i : Int) -> UInt {
  if i >= 0 && i < d.data.length() {
    d.data[i].to_uint()
  } else {
    0xffU
  }
}

///|
// Read the next byte into the code register (BYTEIN).
fn pdf_jbig2_arith_byte_in(d : PdfJbig2Arith) -> Unit {
  if pdf_jbig2_arith_byte_at(d, d.pos) == 0xffU {
    let b = pdf_jbig2_arith_byte_at(d, d.pos + 1)
    if b > 0x8fU {
      // A marker, or the end of the data: feed 1 bits without advancing.
      d.c = d.c + 0xff00U
      d.ct = 8
      d.over += 1
    } else {
      d.pos += 1
      d.c = d.c + (b << 9)
      d.ct = 7
    }
    return
  }
  d.pos += 1
  if d.pos >= d.data.length() {
    d.over += 1
  }
  d.c = d.c + (pdf_jbig2_arith_byte_at(d, d.pos) << 8)
  d.ct = 8
}

///|
fn PdfJbig2Arith::exhausted(self : PdfJbig2Arith) -> Bool {
  self.over > pdf_jbig2_max_overrun
}

///|
// Decode a binary decision in context cx (DECODE).
fn pdf_jbig2_arith_decode(
  d : PdfJbig2Arith,
  cx : Array[Int],
  index : Int,
) -> Int {
  let st = cx[index]
  let row = pdf_jbig2_qe_table[st >> 1]
  let mut mps = st & 1
  let qe = row.qe
  d.a = d.a - qe
  let mut bit = 0
  if (d.c >> 16) < qe {
    // The lower subinterval, with conditional exchange (LPS_EXCHANGE).
    if d.a < qe {
      bit = mps
      cx[index] = (row.nmps << 1) | mps
    } else {
      bit = 1 - mps
      if row.switch_mps {
        mps = 1 - mps
      }
      cx[index] = (row.nlps << 1) | mps
    }
    d.a = qe
  } else {
    d.c = d.c - (qe << 16)
    if (d.a & 0x8000U) != 0U {
      return mps
    }
    // MPS_EXCHANGE.
    if d.a < qe {
      bit = 1 - mps
      if row.switch_mps {
        mps = 1 - mps
      }
      cx[index] = (row.nlps << 1) | mps
    } else {
      bit = mps
      cx[index] = (row.nmps << 1) | mps
    }
  }
  // RENORMD
  while (d.a & 0x8000U) == 0U {
    if d.ct == 0 {
      pdf_jbig2_arith_byte_in(d)
    }
    d.a = d.a << 1
    d.c = d.c << 1
    d.ct -= 1
  }
  bit
}

///|
// Bit reader of an integer decoding procedure (T.88 A.2): it carries the
// binary context index built from the bits decoded so far.
priv struct PdfJbig2IntBits {
  ad : PdfJbig2Arith
  cx : Array[Int]
  mut prev : Int
}

///|
fn PdfJbig2IntBits::bit(self : PdfJbig2IntBits) -> Int {
  let b = pdf_jbig2_arith_decode(self.ad, self.cx, self.prev)
  self.prev = if self.prev < 256 {
    (self.prev << 1) | b
  } else {
    (((self.prev << 1) | b) & 511) | 256
  }
  b
}

///|
fn PdfJbig2IntBits::bits(self : PdfJbig2IntBits, n : Int) -> Int64 {
  let mut v : Int64 = 0L
  for _ in 0..<n {
    v = (v << 1) | self.bit().to_int64()
  }
  v
}

///|
// Decode an integer (T.88 A.2); ok is false for the out-of-band value.
fn pdf_jbig2_arith_decode_int(
  d : PdfJbig2Arith,
  cx : Array[Int],
) -> (Int, Bool) {
  let r : PdfJbig2IntBits = { ad: d, cx, prev: 1 }
  let sign = r.bit()
  let mut value : Int64 = 0L
  if r.bit() == 0 {
    value = r.bits(2)
  } else if r.bit() == 0 {
    value = r.bits(4) + 4L
  } else if r.bit() == 0 {
    value = r.bits(6) + 20L
  } else if r.bit() == 0 {
    value = r.bits(8) + 84L
  } else if r.bit() == 0 {
    value = r.bits(12) + 340L
  } else {
    value = r.bits(32) + 4436L
  }
  if value > 2147483647L {
    value = 2147483647L
  }
  if sign == 1 {
    if value == 0L {
      return (0, false)
    }
    value = -value
  }
  (value.to_int(), true)
}

///|
// Decode a symbol ID of n bits (T.88 A.3); cx has 1<<n entries.
fn pdf_jbig2_arith_decode_iaid(
  d : PdfJbig2Arith,
  cx : Array[Int],
  n : Int,
) -> Int {
  let mut prev = 1
  for _ in 0..<n {
    prev = (prev << 1) | pdf_jbig2_arith_decode(d, cx, prev)
  }
  prev - (1 << n)
}
