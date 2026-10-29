///|
// Tables that change shaping are omitted from the glyph-by-glyph font.
fn specimen_drop(tag : String) -> Bool {
  match tag {
    "GSUB"
    | "GPOS"
    | "GDEF"
    | "BASE"
    | "JSTF"
    | "MATH"
    | "kern"
    | "morx"
    | "mort"
    | "kerx"
    | "feat"
    | "trak"
    | "ankr"
    | "prop"
    | "lcar"
    | "opbd"
    | "just"
    | "bsln"
    | "Silf"
    | "Glat"
    | "Gloc"
    | "Sill"
    | "Feat" => true
    _ => false
  }
}

///|
fn specimen_other(tag : String) -> Bool {
  match tag {
    "vhea" | "vmtx" | "VORG" | "DSIG" | "PCLT" | "meta" | "STAT" => true
    _ => false
  }
}

///|
fn specimen_variation(tag : String) -> Bool {
  match tag {
    "fvar" | "gvar" | "avar" | "cvar" | "HVAR" | "VVAR" | "MVAR" => true
    _ => false
  }
}

///|
/// Build the upstream font specimen's glyph program. Each nonzero glyph is
/// mapped to a private-use character and shaping tables are removed. The
/// caller must check whether embedding is permitted before using the program.
pub fn Font::glyph_program(self : Font) -> Bytes raise {
  let tables = self.specimen_tables(drop_layout=true)
  let cmap : Map[Int32, Int32] = Map([])
  for glyph in 1..<self.metrics.glyph_count {
    let code = if glyph < 0xfffe {
      0xf0000 + glyph
    } else {
      0x100000 + glyph - 0xfffe
    }
    cmap[code] = glyph
  }
  tables["cmap"] = build_cmap(cmap)
  match tables.get("sbix") {
    Some(sbix) =>
      match
        specimen_one_strike(
          Bytes::from_array(sbix)[:],
          self.metrics.glyph_count,
        ) {
        Some(strike) => tables["sbix"] = strike.to_array()
        None => ()
      }
    None => ()
  }
  match tables.get("post") {
    Some(post) if post.length() >= 32 => {
      let trimmed = post[:32].to_array()
      put32(trimmed, 0, 0x00030000U)
      tables["post"] = trimmed
    }
    _ => ()
  }
  build_tables(tables, self.metrics.is_cff)
}

///|
fn Font::specimen_tables(
  self : Font,
  drop_layout~ : Bool,
) -> Map[String, Array[Byte]] {
  let tables : Map[String, Array[Byte]] = Map([])
  let cff2 = self.tables.contains("CFF2")
  for tag, _ in self.tables {
    if specimen_other(tag) ||
      (drop_layout && specimen_drop(tag)) ||
      (specimen_variation(tag) && !(cff2 && (tag == "fvar" || tag == "avar"))) {
      continue
    }
    tables[tag] = sfnt_table(self.source, self.tables, tag)
      .to_owned()
      .to_array()
  }
  tables
}

///|
/// Build a whole specimen sample font, preserving shaping tables. `size` is
/// the face's standalone SFNT size; return None when upstream would omit a
/// large whole font or large color bitmap tables. The caller checks licensing.
pub fn Font::specimen_whole_sample(self : Font, size : Int64) -> Bytes? raise {
  let mut bitmap_size = 0L
  for tag in ["sbix", "CBDT", "SVG "] {
    bitmap_size += sfnt_table(self.source, self.tables, tag).length().to_int64()
  }
  if bitmap_size > 1048576L || size > 4194304L {
    return None
  }
  Some(
    build_tables(self.specimen_tables(drop_layout=false), self.metrics.is_cff),
  )
}

///|
fn specimen_one_strike(data : BytesView, glyphs : Int32) -> Bytes? {
  if data.length() < 8 {
    return None
  }
  let count = u32(data, 4)
  if count < 2U || count > ((data.length() - 8) / 4).reinterpret_as_uint() {
    return None
  }
  let mut best = -1
  let mut best_ppem = 0
  let header = 4 + (glyphs + 1) * 4
  for i in 0..<count.reinterpret_as_int() {
    let raw = u32(data, 8 + i * 4)
    if raw > data.length().reinterpret_as_uint() {
      return None
    }
    let offset = raw.reinterpret_as_int()
    if header > data.length() - offset {
      return None
    }
    let ppem = u16(data, offset)
    if best < 0 ||
      (best_ppem < 64 && ppem > best_ppem) ||
      (ppem >= 64 && ppem < best_ppem) {
      best = offset
      best_ppem = ppem
    }
  }
  let end_offset = u32(data, best + 4 + glyphs * 4)
  if end_offset == 0U ||
    end_offset > (data.length() - best).reinterpret_as_uint() {
    return None
  }
  let end = best + end_offset.reinterpret_as_int()
  let out = data[:4].to_owned().to_array()
  out.push(0)
  out.push(0)
  out.push(0)
  out.push(1)
  out.push(0)
  out.push(0)
  out.push(0)
  out.push(12)
  for byte in data[best:end] {
    out.push(byte)
  }
  Some(Bytes::from_array(out))
}

///|
/// Build a TrueType specimen sample with only the supplied reachable glyphs
/// and their composite dependencies. Glyph IDs and shaping tables are kept.
/// Returns None for non-TrueType outlines or an oversized color bitmap font.
/// The caller supplies the OpenType substitution closure and checks licensing.
pub fn Font::specimen_pruned_truetype(
  self : Font,
  glyphs : Array[Int32],
  size : Int64,
) -> Bytes? raise {
  let mut bitmap_size = 0L
  for tag in ["sbix", "CBDT", "SVG "] {
    bitmap_size += sfnt_table(self.source, self.tables, tag).length().to_int64()
  }
  if bitmap_size > 1048576L {
    return None
  }
  let whole = self.tables.contains("morx") ||
    self.tables.contains("mort") ||
    self.tables.contains("Silf")
  if whole && size > 4194304L {
    return None
  }
  if !whole && !self.tables.contains("glyf") {
    return None
  }
  let tables = self.specimen_tables(drop_layout=false)
  if whole {
    return Some(build_tables(tables, self.metrics.is_cff))
  }
  self.prune_specimen_glyf(tables, glyphs)
  Some(build_tables(tables, self.metrics.is_cff))
}

///|
fn Font::prune_specimen_glyf(
  self : Font,
  tables : Map[String, Array[Byte]],
  glyphs : Array[Int32],
) -> Unit {
  guard tables is { "glyf": _, "loca": _, "head": head, .. } &&
    head.length() >= 54 &&
    self.metrics.glyph_count > 0 else {
    return
  }
  let count = self.metrics.glyph_count
  let needed : Map[Int32, Bool] = { 0: true }
  let pending : Array[Int32] = []
  for glyph in glyphs {
    if glyph > 0 && glyph < count && !needed.contains(glyph) {
      needed[glyph] = true
      pending.push(glyph)
    }
  }
  let mut i = 0
  while i < pending.length() {
    let glyph = pending[i]
    i += 1
    for (_, child) in glyph_components(subset_glyph_data(self, glyph)) {
      if child < count && !needed.contains(child) {
        needed[child] = true
        pending.push(child)
      }
    }
  }
  let outlines : Array[Byte] = []
  let offsets : Array[Int32] = []
  for glyph in 0..<count {
    offsets.push(outlines.length())
    if needed.contains(glyph) {
      for byte in subset_glyph_data(self, glyph) {
        outlines.push(byte)
      }
      while outlines.length() % 4 != 0 {
        outlines.push(0)
      }
    }
  }
  offsets.push(outlines.length())
  let old_long = u16(Bytes::from_array(head)[:], 50) != 0
  let use_long = old_long || outlines.length() >= 0x20000
  let loca : Array[Byte] = []
  for offset in offsets {
    if use_long {
      push32(loca, offset.reinterpret_as_uint())
    } else {
      push16(loca, offset / 2)
    }
  }
  match (tables.get("hmtx"), tables.get("hhea")) {
    (Some(hmtx), Some(hhea)) if hhea.length() >= 36 => {
      let nhm = u16(Bytes::from_array(hhea)[:], 34)
      let mut shared = false
      for glyph, _ in needed {
        if glyph >= nhm {
          shared = true
        }
      }
      for glyph in 0..<count {
        if needed.contains(glyph) {
          continue
        }
        let (pos, length) = if glyph >= nhm {
          (nhm * 4 + (glyph - nhm) * 2, 2)
        } else if glyph == nhm - 1 && shared {
          (glyph * 4 + 2, 2)
        } else {
          (glyph * 4, 4)
        }
        if pos <= hmtx.length() - length {
          for j in 0..<length {
            hmtx[pos + j] = 0
          }
        }
      }
    }
    _ => ()
  }
  put16(head, 50, if use_long { 1 } else { 0 })
  tables["glyf"] = outlines
  tables["loca"] = loca
  tables["head"] = head
}
