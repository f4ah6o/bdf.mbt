///|
/// A drawing reference: which body of the object record (attribute 7) is
/// the drawing, and what kind it stores.

///|
priv struct XdwDrawing {
  kind : Int64
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
      data => Some({ kind, data })
    }
  } else {
    // the drawing's body inline: `80` kind, `86` data
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
    match tlv_find(items, 0x86) {
      Some(t) => Some({ kind, data: t.bytes(attr.value) })
      None => None
    }
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
    Some(a) => xdw_num(a.value).to_int()
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
/// A DocuWorks conversion result.
pub(all) struct XdwResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// Detect a DocuWorks file: the header tag 0x60 and an ASN.1-style long
/// length behind it.
pub fn xdw_detect(data : Bytes) -> Bool {
  data.length() >= 24 && data[0].to_int() == T_HEADER && data[1].to_int() == 0x0e && data[2].to_int() == 0x82
}

///|
/// Draw object `obj`'s drawing into the page. Kinds: 4 an EMF (with the
/// DocuWorks driver's DW comment records), 1 the WMF records of an old
/// page, 5 a picture page (a JPEG behind a 16-byte header), 7 a bitmap
/// page (a DIB).
fn XdwDocument::xdw_draw_object(
  self : XdwDocument,
  obj : XdwObject,
  object : @core.ObjectBuilder,
  writer : @core.DocumentWriter,
  warnings : Array[String],
) -> Unit raise {
  let pic = match self.drawing_of(obj.record) {
    Some(pic) => pic
    None => return
  }
  let kind_name_ = xdw_kind_name(obj.kind)
  let scale = xdw_px2pt
  let x = obj.x.to_double() * scale
  let y = obj.y.to_double() * scale
  let w = obj.w.to_double() * scale
  let h = obj.h.to_double() * scale
  let body_x = if obj.kind == K_CONTENT { 0.0 } else { x }
  let body_y = if obj.kind == K_CONTENT { 0.0 } else { y }
  let data = pic.data
  let file_kind = @metafile.kind(data)
  if file_kind != "" {
    if w <= 0.0 || h <= 0.0 {
      // a degenerate object box: nothing to draw
      warnings.push(kind_name_ + ": the object box is empty")
      return
    }
    let warns = try @metafile.draw_into(
        object,
        writer,
        data,
        body_x,
        body_y,
        w,
        h,
        pics=self.pictures(obj.record),
      ) catch {
      @metafile.MetafileInvalid(message) => {
        warnings.push(kind_name_ + ": " + message)
        []
      }
    }
    for w2 in warns {
      warnings.push(kind_name_ + ": " + w2)
    }
  } else if pic.kind == 5 ||
    (data.length() > 18 && data[16].to_int() == 0xff && data[17].to_int() == 0xd8) ||
    (data.length() > 4 && data[0].to_int() == 0xff && data[1].to_int() == 0xd8) {
    // a picture page: the body's data is a JPEG
    let jpeg = if data.length() > 18 && data[16].to_int() == 0xff && data[17].to_int() == 0xd8 {
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
      Float::from_double(body_x),
      Float::from_double(body_y),
      Float::from_double(w),
      Float::from_double(h),
    ) catch {
      error => warnings.push(kind_name_ + ": " + error.to_string())
    }
  } else if pic.kind == 7 {
    // a bitmap: a DIB
    match @metafile.dib_to_png(data, None) {
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
          Float::from_double(body_x),
          Float::from_double(body_y),
          Float::from_double(w),
          Float::from_double(h),
        ) catch {
          error => warnings.push(kind_name_ + ": " + error.to_string())
        }
      }
      None => warnings.push(kind_name_ + ": a bitmap page was not readable")
    }
  } else {
    warnings.push(kind_name_ + ": drawing kind " + pic.kind.to_string() + " is not supported")
  }
}

///|
/// Convert a whole DocuWorks document into a single-file BDF.
pub fn xdw_convert(data : Bytes, title~ : String = "") -> XdwResult raise {
  let doc = xdw_open_with(data, Limits::default())
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
  for i in 0..<doc.pages.length() {
    let page = doc.pages[i]
    let width = page.w.to_double() * xdw_px2pt
    let height = page.h.to_double() * xdw_px2pt
    let object = @core.ObjectBuilder::new()
    object.set_bbox(0.0F, 0.0F, Float::from_double(width), Float::from_double(height))
    for o in page.objects {
      doc.xdw_draw_object(o, object, writer, warnings)
    }
    let encoded = object.encode() catch {
      error => raise XdwCorrupt("a page could not be built: " + error.to_string())
    }
    let hash = writer.add_part("obj", encoded) catch {
      error => raise XdwCorrupt("a page could not be stored: " + error.to_string())
    }
    pages.push(
      Json::object({
        "w": Json::number(width, repr=width.to_string()),
        "h": Json::number(height, repr=height.to_string()),
        "layers": Json::array(
          [
            Json::object({
              "role": Json::string("body"),
              "obj": Json::string(hash),
            }),
          ],
        ),
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
