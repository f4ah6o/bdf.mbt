///|
// Symbol dictionary decoding (T.88 6.5), ported from upstream
// converter/internal/jbig2/symbol.go.
priv struct PdfJbig2SymbolDict {
  exported : Array[PdfJbig2Bitmap]
  // Contexts retained for a later dictionary (7.4.2.1.1), or none.
  gb : Array[Int]?
  gr : Array[Int]?
}

///|
// Decode a symbol dictionary segment (7.4.2, 6.5).
fn PdfJbig2Decoder::symbol_dict_segment(
  self : PdfJbig2Decoder,
  s : PdfJbig2Segment,
  data : Bytes,
) -> Unit raise PdfStreamError {
  let r = pdf_jbig2_reader_new(data)
  let flags = r.u16()
  let huff = (flags & 1) != 0
  let refagg = (flags & 2) != 0
  let template = (flags >> 10) & 3
  let rtemplate = (flags >> 12) & 1
  let mut at : Array[PdfJbig2Point] = []
  if !huff {
    at = r.at(pdf_jbig2_generic_templates[template].nominal.length())
  }
  let mut rat : Array[PdfJbig2Point] = []
  if refagg && rtemplate == 0 {
    rat = r.at(2)
  }
  let num_ex = r.u32()
  let num_new = r.u32()
  if r.err {
    raise InvalidStream("truncated JBIG2 symbol dictionary segment")
  }
  if num_ex < 0 || num_new < 0 {
    raise InvalidStream("invalid JBIG2 symbol count")
  }
  let num_ex = num_ex.to_int64()
  let num_new = num_new.to_int64()
  let in_syms : Array[PdfJbig2Bitmap] = []
  let mut last : PdfJbig2SymbolDict? = None
  let selector : PdfJbig2TableSelector = { custom: [], next: 0 }
  for value in self.referred(s) {
    match value {
      PdfJbig2ResultSymbolDict(dict) => {
        for symbol in dict.exported {
          in_syms.push(symbol)
        }
        last = Some(dict)
      }
      PdfJbig2ResultHuffTable(table) => selector.custom.push(table)
      _ => ()
    }
  }
  let total = in_syms.length().to_int64() + num_new
  if total > pdf_jbig2_max_symbols.to_int64() || num_ex > total {
    raise InvalidStream("too many JBIG2 symbols")
  }
  self.spend(64L * total)
  let mut tdh : PdfJbig2HuffTable? = None
  let mut tdw : PdfJbig2HuffTable? = None
  let mut tbm : PdfJbig2HuffTable? = None
  let mut tai : PdfJbig2HuffTable? = None
  if huff {
    tdh = Some(pdf_jbig2_table_pick(selector, (flags >> 2) & 3, 3, [4, 5]))
    tdw = Some(pdf_jbig2_table_pick(selector, (flags >> 4) & 3, 3, [2, 3]))
    tbm = Some(pdf_jbig2_table_pick(selector, (flags >> 6) & 1, 1, [1]))
    tai = Some(pdf_jbig2_table_pick(selector, (flags >> 7) & 1, 1, [1]))
  }
  let code_len = pdf_jbig2_ceil_log2(total.to_int())
  let t : PdfJbig2TextDecoder = {
    ad: None,
    br: None,
    cx: pdf_jbig2_new_text_contexts(code_len),
    gr: None,
  }
  let iadh : Array[Int] = Array::make(512, 0)
  let iadw : Array[Int] = Array::make(512, 0)
  let iaex : Array[Int] = Array::make(512, 0)
  let iaai : Array[Int] = Array::make(512, 0)
  let mut gb : Array[Int]? = None
  if huff {
    t.br = Some({ data: r.rest(), pos: 0 })
  } else {
    t.ad = Some(pdf_jbig2_arith_new(r.rest()))
    gb = Some(pdf_jbig2_new_generic_stats(template))
  }
  if refagg {
    t.gr = Some(pdf_jbig2_new_refinement_stats(rtemplate))
  }
  if (flags & 0x100) != 0 { // bitmap coding context used
    let previous = match last {
      Some(previous) => previous
      None =>
        raise InvalidStream(
          "JBIG2 symbol dictionary \{s.header.number}: no matching retained contexts",
        )
    }
    match gb {
      Some(contexts) => {
        let retained = match previous.gb {
          Some(retained) => retained
          None =>
            raise InvalidStream(
              "JBIG2 symbol dictionary \{s.header.number}: no matching retained contexts",
            )
        }
        if retained.length() != contexts.length() {
          raise InvalidStream(
            "JBIG2 symbol dictionary \{s.header.number}: no matching retained contexts",
          )
        }
        for i in 0..<contexts.length() {
          contexts[i] = retained[i]
        }
      }
      None => ()
    }
    match t.gr {
      Some(contexts) => {
        let retained = match previous.gr {
          Some(retained) => retained
          None =>
            raise InvalidStream(
              "JBIG2 symbol dictionary \{s.header.number}: no matching retained contexts",
            )
        }
        if retained.length() != contexts.length() {
          raise InvalidStream(
            "JBIG2 symbol dictionary \{s.header.number}: no matching retained contexts",
          )
        }
        for i in 0..<contexts.length() {
          contexts[i] = retained[i]
        }
      }
      None => ()
    }
  }
  let syms : Array[PdfJbig2Bitmap] = []
  for symbol in in_syms {
    syms.push(symbol)
  }
  let generic : PdfJbig2GenericParams = {
    template,
    tpgdon: false,
    at,
    skip: None,
  }
  let mut height : Int64 = 0L
  let mut empty = 0
  while syms.length().to_int64() < total {
    let dh = pdf_jbig2_text_value(t, tdh, Some(iadh))
    height += dh.to_int64()
    if height < 0L || height > pdf_jbig2_max_dimension.to_int64() {
      raise InvalidStream("JBIG2 symbol height out of range")
    }
    let first = syms.length()
    let mut width : Int64 = 0L
    let mut tot_width : Int64 = 0L
    while true {
      let (dw, ok) = pdf_jbig2_text_int(t, tdw, Some(iadw))
      if !ok {
        break // the end of the height class
      }
      if syms.length().to_int64() >= total {
        raise InvalidStream("too many JBIG2 symbols")
      }
      let exhausted = match t.ad {
        Some(ad) => ad.exhausted()
        None => false
      }
      if exhausted {
        raise InvalidStream(
          "JBIG2 symbol dictionary \{s.header.number}: coded data ends early",
        )
      }
      width += dw.to_int64()
      tot_width += width
      if width < 0L ||
        width > pdf_jbig2_max_dimension.to_int64() ||
        tot_width > pdf_jbig2_max_dimension.to_int64() {
        raise InvalidStream("JBIG2 symbol width out of range")
      }
      let bm = if huff && !refagg {
        // Collected into the height class bitmap below; keep the width.
        pdf_jbig2_bitmap_new(width.to_int(), 0)
      } else if !refagg {
        let ad = match t.ad {
          Some(ad) => ad
          None => raise InvalidStream("missing JBIG2 arithmetic decoder")
        }
        let contexts = match gb {
          Some(contexts) => contexts
          None => raise InvalidStream("missing JBIG2 generic contexts")
        }
        pdf_jbig2_decode_generic(
          self,
          ad,
          contexts,
          width.to_int(),
          height.to_int(),
          generic,
        )
      } else {
        pdf_jbig2_aggregate_symbol(
          self,
          t,
          syms,
          width.to_int(),
          height.to_int(),
          code_len,
          rtemplate,
          rat,
          tai,
          iaai,
        )
      }
      syms.push(bm)
    }
    if huff && !refagg {
      let table = match tbm {
        Some(table) => table
        None => raise InvalidStream("missing JBIG2 height class table")
      }
      pdf_jbig2_height_class_bitmap(
        self,
        t,
        table,
        syms,
        first,
        tot_width.to_int(),
        height.to_int(),
      )
    }
    if syms.length() == first {
      empty += 1
      let exhausted = match t.ad {
        Some(ad) => ad.exhausted()
        None => false
      }
      if empty > 65536 || exhausted {
        raise InvalidStream(
          "JBIG2 symbol dictionary \{s.header.number}: no symbols decoded",
        )
      }
    }
  }
  // Export flags (6.5.10).
  let exported : Array[PdfJbig2Bitmap] = []
  let mut i : Int64 = 0L
  let mut runs = 0
  let mut exporting = false
  while i < total {
    let n = if huff {
      pdf_jbig2_text_value(t, Some(pdf_jbig2_standard_table(1)), None)
    } else {
      pdf_jbig2_text_value(t, None, Some(iaex))
    }
    let exhausted = match t.ad {
      Some(ad) => ad.exhausted()
      None => false
    }
    if n < 0 ||
      n.to_int64() > total - i ||
      (n == 0 && runs > total.to_int() + 2) ||
      exhausted {
      raise InvalidStream("invalid JBIG2 symbol export flags")
    }
    if exporting {
      if (exported.length() + n).to_int64() > num_ex {
        raise InvalidStream("too many exported JBIG2 symbols")
      }
      for k in 0..<n {
        exported.push(syms[(i + k.to_int64()).to_int()])
      }
    }
    i += n.to_int64()
    runs += 1
    exporting = !exporting
  }
  let sd : PdfJbig2SymbolDict = {
    exported,
    gb: if (flags & 0x200) != 0 { gb } else { None },
    gr: if (flags & 0x200) != 0 { t.gr } else { None },
  }
  s.result = PdfJbig2ResultSymbolDict(sd)
}

///|
// Decode a refinement/aggregate coded symbol (6.5.8.2).
fn pdf_jbig2_aggregate_symbol(
  d : PdfJbig2Decoder,
  t : PdfJbig2TextDecoder,
  syms : Array[PdfJbig2Bitmap],
  w : Int,
  h : Int,
  code_len : Int,
  rtemplate : Int,
  rat : Array[PdfJbig2Point],
  tai : PdfJbig2HuffTable?,
  iaai : Array[Int],
) -> PdfJbig2Bitmap raise PdfStreamError {
  let n = pdf_jbig2_text_value(t, tai, Some(iaai))
  if n < 1 {
    raise InvalidStream("invalid JBIG2 aggregate instance count \{n}")
  }
  if n > 1 {
    // Several symbols, drawn by the text region decoding procedure.
    let p : PdfJbig2TextParams = {
      huff: t.br is Some(_),
      refine: true,
      w,
      h,
      instances: n,
      log_strips: 0,
      syms,
      code_len,
      codes: None,
      def_pixel: 0,
      op: 0,
      transposed: false,
      corner: pdf_jbig2_corner_top_left,
      ds_offset: 0,
      fs: Some(pdf_jbig2_standard_table(6)),
      ds: Some(pdf_jbig2_standard_table(8)),
      dt: Some(pdf_jbig2_standard_table(11)),
      rdw: Some(pdf_jbig2_standard_table(15)),
      rdh: Some(pdf_jbig2_standard_table(15)),
      rdx: Some(pdf_jbig2_standard_table(15)),
      rdy: Some(pdf_jbig2_standard_table(15)),
      rsize: Some(pdf_jbig2_standard_table(1)),
      rtemplate,
      rat,
    }
    return pdf_jbig2_decode_text(d, p, t)
  }
  // One symbol, refined.
  let mut id = 0
  let mut rdx = 0
  let mut rdy = 0
  let mut ad = match t.ad {
    Some(ad) => ad
    None => pdf_jbig2_arith_new(b"")
  }
  match t.br {
    Some(br) => {
      id = br.read_bits(code_len)
      rdx = pdf_jbig2_text_value(t, Some(pdf_jbig2_standard_table(15)), None)
      rdy = pdf_jbig2_text_value(t, Some(pdf_jbig2_standard_table(15)), None)
      let size = pdf_jbig2_text_value(t, Some(pdf_jbig2_standard_table(1)), None)
      br.align()
      let data = br.bytes(size)
      ad = pdf_jbig2_arith_new(data)
    }
    None => {
      let a = match t.ad {
        Some(ad) => ad
        None => raise InvalidStream("missing JBIG2 arithmetic decoder")
      }
      id = pdf_jbig2_arith_decode_iaid(a, t.cx.iaid, code_len)
      rdx = pdf_jbig2_text_value(t, None, Some(t.cx.iardx))
      rdy = pdf_jbig2_text_value(t, None, Some(t.cx.iardy))
    }
  }
  if id < 0 || id >= syms.length() {
    raise InvalidStream("invalid JBIG2 symbol ID \{id}")
  }
  let gr = match t.gr {
    Some(gr) => gr
    None => raise InvalidStream("missing JBIG2 refinement contexts")
  }
  pdf_jbig2_decode_refinement(ad, gr, w, h, {
    template: rtemplate,
    at: rat,
    reference: syms[id],
    dx: rdx,
    dy: rdy,
    tpgron: false,
  })
}

///|
// Decode the collective bitmap of a Huffman coded height class, uncompressed
// or MMR coded, and cut it into the symbols (6.5.9).
fn pdf_jbig2_height_class_bitmap(
  d : PdfJbig2Decoder,
  t : PdfJbig2TextDecoder,
  tbm : PdfJbig2HuffTable,
  syms : Array[PdfJbig2Bitmap],
  first : Int,
  w : Int,
  h : Int,
) -> Unit raise PdfStreamError {
  let br = match t.br {
    Some(br) => br
    None => raise InvalidStream("missing JBIG2 symbol dictionary bit reader")
  }
  let size = pdf_jbig2_text_value(t, Some(tbm), None)
  br.align()
  let bm = if size == 0 {
    let bm = d.new_bitmap(w, h)
    let data = br.bytes(bm.data.length())
    for i in 0..<bm.data.length() {
      bm.data[i] = data[i]
    }
    bm.clear_padding()
    bm
  } else {
    let data = br.bytes(size)
    let (bm, _) = d.decode_mmr(data, w, h)
    bm
  }
  let mut x = 0
  for i in first..<syms.length() {
    let symbol = syms[i]
    syms[i] = bm.sub(x, 0, symbol.width, h)
    x += symbol.width
  }
}
