///|
/// A drawing reference: which body of the object record (attribute 7) is
/// the drawing, and what kind it stores.

///|
priv struct XdwDrawing {
  kind : Int64
  /// Entry field 0x8d = 1: an annotation drawing, whose EMF window (not
  /// its frame) is fitted to the object box.
  annotation : Bool
  data : Bytes
}

///|
fn XdwDocument::drawing_of(self : XdwDocument, record : Int) -> XdwDrawing? raise {
  if record < 0 || record >= self.records.length() {
    return None
  }
  let attr = match self.records[record].get(7) {
    Some(attr) => attr
    None => return None
  }
  if (attr.class & 0xc0) == 0xc0 {
    // a reference: `81` entry index, `82` stored length
    let found : (Int, Int)? = try Some(xdw_read_ref(attr.value)) catch {
      _ => None
    }
    let (n, _) = match found {
      Some(pair) => pair
      None => return None
    }
    if n < 0 || n >= self.entries.length() {
      return None
    }
    let e = self.entries[n]
    let kind = match e.kind() {
      Some(k) => k
      None => return None
    }
    match e.expanded(self.b, self.limits) {
      data => Some({ kind, data, annotation: e.field(0x8d) == Some(1L) })
    }
  } else {
    // the drawing's body inline: `80` kind, `81` expanded size, `86` data,
    // `8a` compression flag
    let items = tlv_list(attr.value, 0, attr.value.length()) catch {
      e => {
        ignore(e)
        return None
      }
    }
    let kind = match tlv_find_uint(items, attr.value, 0x80) {
      Some(k) => k
      None => return None
    }
    let raw = match tlv_find(items, 0x86) {
      Some(t) => t.bytes(attr.value)
      None => return None
    }
    let expanded = xdw_expanded_size(
      Some(kind),
      tlv_find_uint(items, attr.value, 0x8a),
      tlv_find_uint(items, attr.value, 0x81),
      raw.length(),
    )
    let data = match expanded {
      Some(n) => lzh_decompress(raw, n, self.limits)
      None => raw
    }
    Some({
      kind,
      data,
      annotation: tlv_find_uint(items, attr.value, 0x8d) == Some(1L),
    })
  }
}

///|
/// A reference: `81` entry index, `82` stored (or expanded) length.
fn xdw_read_ref(v : Bytes) -> (Int, Int) raise {
  let items = tlv_list(v, 0, v.length())
  let idx = match tlv_find_uint(items, v, 0x81) {
    Some(k) => k.to_int()
    None => raise XdwCorrupt("a reference without an index")
  }
  let len = match tlv_find_uint(items, v, 0x82) {
    Some(k) => k.to_int()
    None => 0
  }
  (idx, len)
}

///|
/// The pictures (attributes 301…) an object's drawing uses, as stored:
/// a 16-byte header (size, 0, width, height) then JPEG data, or a DIB.
fn XdwDocument::pictures(self : XdwDocument, record : Int) -> Array[Bytes] {
  let out : Array[Bytes] = []
  if record < 0 || record >= self.records.length() {
    return out
  }
  let rec = self.records[record]
  let n = match rec.get(300) {
    Some(a) => xdw_le_num(a.value).to_int()
    None => return out
  }
  let defs = self.defs(record)
  for k in 1..<=n.min(100000) {
    let a : PropAttr? = if k <= 100 {
      rec.get(300 + k)
    } else {
      let mut d : PropAttrDef? = None
      for def in defs {
        if def.name == "#pd" && def.index == k.to_int64() {
          d = Some(def)
          break
        }
      }
      let found2 : PropAttr? = match d {
        Some(def) => rec.get(def.tag)
        None => {
          continue
        }
      }
      found2
    }
    let attr = match a {
      Some(attr) => attr
      None => continue
    }
    let found : (Int, Int)? = try Some(xdw_read_ref(attr.value)) catch {
      _ => None
    }
    let (i, _) = match found {
      Some(pair) => pair
      None => continue
    }
    match self.entry_data(i) {
      Some(body) => if out.length() < 1000 {
        out.push(body)
      }
      None => ()
    }
  }
  out
}

///|
/// 1/100 mm to points.
let xdw_px2pt : Double = 72.0 / 2540.0
///|
/// The transform that turns an object's drawing clockwise by `rotation`
/// degrees inside its box, and the drawing's natural size. The box is the
/// rotated size, so a quarter turn swaps width and height.
fn xdw_rotation(
  rotation : Int64,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> (Double, Double, Double, Double, Double, Double, Double, Double) {
  let r = (rotation % 360L + 360L) % 360L
  match r {
    90L => (h, w, 0.0, 1.0, -1.0, 0.0, x + w, y)
    180L => (w, h, -1.0, 0.0, 0.0, -1.0, x + w, y + h)
    270L => (h, w, 0.0, -1.0, 1.0, 0.0, x, y + h)
    _ => (w, h, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
  }
}

///|
/// A DocuWorks conversion result.
pub(all) struct XdwResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect a DocuWorks file: the header tag 0x60, its length, and the
/// first field of the header behind them (the 0x80 context class that
/// carries the generation and its friends). Only the tag classes are
/// checked, so the header may grow behind them without breaking the
/// detection.
pub fn xdw_detect(data : Bytes) -> Bool {
  data.length() >= 24 && data[0].to_int() == T_HEADER &&
  data[1].to_int() < 0x80 && (data[2].to_int() & 0xc0) == 0x80
}

///|
/// Whether `b` starts with a JPEG SOI marker.
fn xdw_is_jpeg(b : Bytes) -> Bool {
  b.length() > 2 && b[0].to_int() == 0xff && b[1].to_int() == 0xd8
}

///|
/// Whether `b` carries a JPEG SOI marker at `at`.
fn xdw_is_jpeg_at(b : Bytes, at : Int) -> Bool {
  b.length() > at + 2 && b[at].to_int() == 0xff && b[at + 1].to_int() == 0xd8
}

///|
/// The advance of a fallback text, estimated from its characters: half a size
/// for ASCII, a full size for everything else.
fn xdw_fallback_text_advance(text : String, size : Double) -> Double {
  let mut advance = 0.0
  for ch in text {
    advance += if ch.to_int() < 0x80 { size * 0.5 } else { size }
  }
  advance
}

///|
/// Draw a stored annotation text that the annotation's own drawing does not
/// carry.
///
/// The text is transparent: it is there for the text layer, the index, and
/// copy, but it does not change what the page looks like. It is drawn after
/// the annotation's own drawing, so the drawing's own fills do not hide it
/// from the index.
fn xdw_draw_fallback_text(
  object : @core.ObjectBuilder,
  text : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit {
  let size = (h * 0.2).max(4.0).min(24.0)
  let font = object.add_font({
    hash: None,
    family: "sans-serif",
    weight: 400,
    style: 0,
  })
  object.fill_color(0x00000000U)
  object.font(font, Float::from_double(size)) catch {
    _ => return
  }
  let advance = xdw_fallback_text_advance(text, size).min(w).max(size)
  object.fill_text(
    text,
    Float::from_double(x),
    Float::from_double(y + size),
    Float::from_double(advance),
  )
}

///|
/// Draw object `obj`'s drawing into the page. Kinds: 4 an EMF (with the
/// DocuWorks driver's DW comment records), 1 the WMF records of an old
/// page, 5 a picture page (a JPEG behind a 16-byte header), 7 a bitmap
/// page (a DIB).
///
/// `fallback_text` is a stored annotation text that the drawing does not
/// carry; it is drawn transparently so the text layer and the index have a
/// real run to point at. It is drawn even when the object has no drawing at
/// all, as long as its box is non-empty.
fn XdwDocument::xdw_draw_object(
  self : XdwDocument,
  obj : XdwObject,
  object : @core.ObjectBuilder,
  writer : @core.DocumentWriter,
  warnings : Array[String],
  fallback_text~ : String? = None,
) -> Unit raise {
  let pic = self.drawing_of(obj.record)
  if pic is None && fallback_text is None {
    return
  }
  let kind_name_ = xdw_kind_name(obj.kind)
  let scale = xdw_px2pt
  let x = obj.x.to_double() * scale
  let y = obj.y.to_double() * scale
  let w = obj.w.to_double() * scale
  let h = obj.h.to_double() * scale
  if w <= 0.0 || h <= 0.0 {
    // a degenerate object box: nothing to draw
    warnings.push(kind_name_ + ": the object box is empty")
    return
  }
  // attribute 61 turns the drawing clockwise inside its box; the box is
  // the rotated size, so the drawing's own width and height swap
  let (nw, nh, ta, tb, tc, td, te, tf) = xdw_rotation(obj.rotation, x, y, w, h)
  let rotated = ta != 1.0 || tb != 0.0 || tc != 0.0 || td != 1.0
  if rotated {
    object.save()
    object.transform(
      Float::from_double(ta),
      Float::from_double(tb),
      Float::from_double(tc),
      Float::from_double(td),
      Float::from_double(te),
      Float::from_double(tf),
    )
  }
  let body_x = if rotated || obj.kind == K_CONTENT { 0.0 } else { x }
  let body_y = if rotated || obj.kind == K_CONTENT { 0.0 } else { y }
  let body_w = if rotated { nw } else { w }
  let body_h = if rotated { nh } else { h }
  match pic {
    Some(pic) =>
      self.xdw_draw_body(
        obj, pic, kind_name_, body_x, body_y, body_w, body_h, object, writer, warnings,
      )
    None => ()
  }
  match fallback_text {
    Some(text) =>
      if text != "" {
        xdw_draw_fallback_text(object, text, body_x, body_y, body_w, body_h)
      }
    None => ()
  }
  if rotated {
    object.restore()
  }
}

///|
/// Draw one drawing into the box `x,y,w,h` (page points).
fn XdwDocument::xdw_draw_body(
  self : XdwDocument,
  obj : XdwObject,
  pic : XdwDrawing,
  kind_name_ : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  object : @core.ObjectBuilder,
  writer : @core.DocumentWriter,
  warnings : Array[String],
) -> Unit raise {
  let data = pic.data
  let file_kind = @metafile.kind(data)
  if file_kind != "" {
    let warns = try @metafile.draw_into(
        object,
        writer,
        data,
        x,
        y,
        w,
        h,
        pics=self.pictures(obj.record),
        annotation=pic.annotation,
      ) catch {
      @metafile.MetafileInvalid(message) => {
        warnings.push(kind_name_ + ": " + message)
        []
      }
    }
    for w2 in warns {
      warnings.push(kind_name_ + ": " + w2)
    }
  } else if pic.kind == 5 || xdw_is_jpeg(data) || xdw_is_jpeg_at(data, 16) {
    // a picture page: the body's data is a JPEG, behind a 16-byte header
    // (size, 0, width, height) when the entry stores one
    let jpeg = if xdw_is_jpeg(data) {
      data
    } else if xdw_is_jpeg_at(data, 16) {
      data[16:].to_owned()
    } else {
      data
    }
    let hash = writer.add_part("img", jpeg) catch {
      error => {
        warnings.push(kind_name_ + ": " + error.to_string())
        return
      }
    }
    let index = object.add_image(hash)
    object.image(
      index,
      Float::from_double(x),
      Float::from_double(y),
      Float::from_double(w),
      Float::from_double(h),
    ) catch {
      error => warnings.push(kind_name_ + ": " + error.to_string())
    }
  } else if pic.kind == 7 {
    // a bitmap: a DIB behind a band count and one or more band headers,
    // each band's bits LZH-compressed
    match @metafile.dib_body_bands(data) {
      Some((bmi, bands)) => {
        let bits = @buffer.Buffer()
        let mut readable = true
        for band in bands {
          let (stored, expanded_len) = band
          let part = if expanded_len > 0 && expanded_len != stored.length() {
            lzh_decompress(stored, expanded_len, self.limits) catch {
              _ => {
                readable = false
                stored
              }
            }
          } else {
            stored
          }
          bits.write_bytes(part)
        }
        if !readable {
          warnings.push(kind_name_ + ": a bitmap page was not readable")
          return
        }
        match @metafile.dib_to_png(bmi, Some(bits.to_bytes())) {
          Some(png) => {
            let hash = writer.add_part("img", png) catch {
              error => {
                warnings.push(kind_name_ + ": " + error.to_string())
                return
              }
            }
            let index = object.add_image(hash)
            object.image(
              index,
              Float::from_double(x),
              Float::from_double(y),
              Float::from_double(w),
              Float::from_double(h),
            ) catch {
              error => warnings.push(kind_name_ + ": " + error.to_string())
            }
          }
          None => warnings.push(kind_name_ + ": a bitmap page was not readable")
        }
      }
      None => warnings.push(kind_name_ + ": a bitmap page was not readable")
    }
  } else {
    warnings.push(kind_name_ + ": drawing kind " + pic.kind.to_string() + " is not supported")
  }
}

///|
/// One page's layers and the index runs they carry.
priv struct XdwPageLayers {
  layers : Array[Json]
  runs : Array[@core.IndexRun]
  /// Whether the page drew text or carries annotation text, so the index part
  /// has to be written even when every run was filtered away.
  saw_text : Bool
  /// Whether a layer's text could not be read back.
  index_failed : Bool
}

///|
/// Index one layer, reporting a failure instead of aborting the page.
fn xdw_index_layer(
  encoded : Bytes,
  page : Int,
  layer : Int,
  include_hidden : Bool,
  covers_from : Bytes?,
  warnings : Array[String],
) -> (Array[@core.IndexRun], Int32, Bool) {
  try {
    let (runs, drawn) = xdw_page_index_runs(
      encoded, page, layer, include_hidden, covers_from,
    )
    (runs, drawn, false)
  } catch {
    error => {
      warnings.push(
        "page \{page + 1}: the text index was not readable: " + error.to_string(),
      )
      ([], 0, true)
    }
  }
}

///|
/// Build a page's body and annotation layers and index each one.
///
/// The body is the page content; annotations are drawn on a layer of their
/// own, so a viewer can show or hide them. The body is indexed with the
/// annotation layer's fills as covers: the viewer draws the annotation layer
/// after the body, so a fill there still hides the body text it covers. That
/// matches the default view, where annotations are visible. A viewer that
/// hides the annotation layer reveals body text the static index leaves out;
/// the index cannot represent both views.
fn XdwDocument::xdw_page_layers(
  self : XdwDocument,
  page : XdwPage,
  index : Int,
  writer : @core.DocumentWriter,
  warnings : Array[String],
) -> XdwPageLayers raise {
  let width = page.w.to_double() * xdw_px2pt
  let height = page.h.to_double() * xdw_px2pt
  let body = @core.ObjectBuilder::new()
  body.set_bbox(0.0F, 0.0F, Float::from_double(width), Float::from_double(height))
  let annotation = @core.ObjectBuilder::new()
  annotation.set_bbox(
    0.0F, 0.0F, Float::from_double(width), Float::from_double(height),
  )
  let mut has_annotation = false
  for obj in page.objects {
    if xdw_is_annotation(obj.kind) {
      has_annotation = true
      let fallback = match obj.text {
        Some(text) => {
          let text = xdw_annotation_text(text)
          if text == "" {
            None
          } else {
            // A drawing that cannot be read back is treated as carrying no
            // text, so the stored text is drawn rather than lost.
            let drawn = try self.xdw_annotation_drawn_text(obj) catch {
              _ => ""
            }
            if drawn == "" {
              Some(text)
            } else {
              None
            }
          }
        }
        None => None
      }
      self.xdw_draw_object(
        obj, annotation, writer, warnings, fallback_text=fallback,
      )
    } else {
      self.xdw_draw_object(obj, body, writer, warnings)
    }
  }
  let body_encoded = body.encode() catch {
    error => raise XdwCorrupt("a page could not be built: " + error.to_string())
  }
  let body_hash = writer.add_part("obj", body_encoded) catch {
    error => raise XdwCorrupt("a page could not be stored: " + error.to_string())
  }
  let annotation_encoded : Bytes? = if has_annotation {
    Some(
      annotation.encode() catch {
        error => raise XdwCorrupt("a page could not be built: " + error.to_string())
      },
    )
  } else {
    None
  }
  let annotation_hash : String? = match annotation_encoded {
    Some(encoded) =>
      Some(
        writer.add_part("obj", encoded) catch {
          error => raise XdwCorrupt("a page could not be stored: " + error.to_string())
        },
      )
    None => None
  }
  let (body_runs, body_drawn, body_failed) = xdw_index_layer(
    body_encoded, index, 0, self.include_hidden, annotation_encoded, warnings,
  )
  let annotation_index : (Array[@core.IndexRun], Int32, Bool) = match annotation_encoded {
    Some(encoded) =>
      xdw_index_layer(encoded, index, 1, self.include_hidden, None, warnings)
    None => ([], 0, false)
  }
  let (annotation_runs, annotation_drawn, annotation_failed) = annotation_index
  let runs : Array[@core.IndexRun] = []
  runs.append(body_runs)
  runs.append(annotation_runs)
  let layers : Array[Json] = [
    Json::object({ "role": Json::string("body"), "obj": Json::string(body_hash) }),
  ]
  match annotation_hash {
    Some(hash) =>
      layers.push(
        Json::object({
          "role": Json::string("annotation"),
          "obj": Json::string(hash),
        }),
      )
    None => ()
  }
  {
    layers,
    runs,
    saw_text: body_drawn > 0 || annotation_drawn > 0,
    index_failed: body_failed || annotation_failed,
  }
}

///|
/// Convert a whole DocuWorks document into a single-file BDF.
///
/// `include_hidden` keeps text that a later opaque fill covers completely in
/// the text index; by default such text is left out.
pub fn xdw_convert(
  data : Bytes,
  title~ : String = "",
  include_hidden~ : Bool = false,
) -> XdwResult raise {
  let doc = xdw_open_with(data, Limits::default())
  doc.include_hidden = include_hidden
  let meta : Map[String, Json] = {
    "source": Json::string("xdw"),
    "generator": Json::string("bdf-moonbit/0.1"),
  }
  let final_title = if title != "" { title } else { xdw_document_title(doc) }
  if final_title != "" {
    meta["dc"] = Json::object({ "title": Json::string(final_title) })
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let warnings : Array[String] = []
  let pages : Array[Json] = []
  let index_runs : Array[@core.IndexRun] = []
  // Whether any page drew text or carries annotation text, and whether a
  // page's text could not be read back. An index that is present but empty
  // must still be written: the reader rebuilds a missing index from the object
  // stream, which would bring back exactly the text this index leaves out.
  let mut saw_text = false
  let mut index_failed = false
  for i in 0..<doc.pages.length() {
    let page = doc.pages[i]
    let width = page.w.to_double() * xdw_px2pt
    let height = page.h.to_double() * xdw_px2pt
    let built = doc.xdw_page_layers(page, i, writer, warnings)
    if built.saw_text {
      saw_text = true
    }
    if built.index_failed {
      index_failed = true
    }
    index_runs.append(built.runs)
    pages.push(
      Json::object({
        "w": Json::number(width, repr=width.to_string()),
        "h": Json::number(height, repr=height.to_string()),
        "layers": Json::array(built.layers),
      }),
    )
  }
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
    "pages": Json::array(pages),
  }
  if final_title != "" {
    view["title"] = Json::string(final_title)
  }
  if xdw_index_part_needed(saw_text, index_failed) {
    let index_hash = writer.add_part("idx", @core.encode_text_index(index_runs)) catch {
      error => raise XdwCorrupt("the text index could not be stored: " + error.to_string())
    }
    view["textIndex"] = Json::string(index_hash)
  }
  writer.add_view(Json::object(view))
  let bdf = writer.write_single() catch {
    error => raise XdwCorrupt("the document could not be written: " + error.to_string())
  }
  let summary = match doc.container.generation {
    Some(g) => "\{doc.pages.length()} page(s), generation \{g}, \{warnings.length()} warning(s)"
    None => "\{doc.pages.length()} page(s), \{warnings.length()} warning(s)"
  }
  {
    bdf,
    pages: doc.pages.length(),
    summary,
    warnings,
  }
}

///|
/// The document title: the name of a single document (attribute 4 or 70),
/// or a binder's own name.
fn xdw_document_title(doc : XdwDocument) -> String {
  match doc.binder_name() {
    Some(n) => if n != "" { n } else { "Binder" }
    None => {
      if doc.records.length() > 1 {
        xdw_doc_name(doc.records[1])
      } else {
        ""
      }
    }
  }
}
