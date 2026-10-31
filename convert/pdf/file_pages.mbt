///|
// Page attributes are copied at each tree node so sibling pages inherit
// independently. The first malformed attribute is retained on each leaf.
priv struct PdfPageAttrs {
  mut media : (Double, Double, Double, Double)?
  mut crop : (Double, Double, Double, Double)?
  mut rotate : Int32
  mut resources : PdfObject?
}

///|
priv struct PdfPageLeaf {
  dict : PdfObject
  reference : PdfObject?
  attrs : PdfPageAttrs
  error : String?
}

///|
priv struct PdfPageWalk {
  leaves : Array[PdfPageLeaf]
  seen : Map[Int64, Bool]
  listed : Map[Int64, Bool]
  mut repeated : Int32
  mut left : Int32
}

///|
fn PdfPageAttrs::copy(self : PdfPageAttrs) -> PdfPageAttrs {
  {
    media: self.media,
    crop: self.crop,
    rotate: self.rotate,
    resources: self.resources,
  }
}

///|
// Like the upstream converter's helpers, an unresolved reference is null.
fn PdfFile::page_deref(self : PdfFile, object : PdfObject?) -> PdfObject {
  match object {
    Some(PdfRef(number, _)) => self.load(number, 0).value catch { _ => PdfNull }
    Some(value) => value
    None => PdfNull
  }
}

///|
fn PdfFile::page_num(self : PdfFile, object : PdfObject?) -> Double? {
  match self.page_deref(object) {
    PdfInt(value) => Some(value.to_double())
    PdfReal(value) => Some(value)
    _ => None
  }
}

///|
fn PdfFile::page_rect(
  self : PdfFile,
  object : PdfObject,
) -> (Double, Double, Double, Double)? {
  match self.page_deref(Some(object)) {
    PdfArray(values) if values.length() >= 4 =>
      match
        (
          self.page_num(Some(values[0])),
          self.page_num(Some(values[1])),
          self.page_num(Some(values[2])),
          self.page_num(Some(values[3])),
        ) {
        (Some(a), Some(b), Some(c), Some(d)) => Some((a, b, c, d))
        _ => None
      }
    _ => None
  }
}

///|
fn PdfFile::page_inherit(
  self : PdfFile,
  dict : PdfObject,
  attrs : PdfPageAttrs,
) -> String? {
  match pdf_dict_get(dict, b"MediaBox") {
    Some(value) =>
      match self.page_rect(value) {
        Some(rect) => attrs.media = Some(rect)
        None => return Some("/MediaBox is not a rectangle")
      }
    None => ()
  }
  match pdf_dict_get(dict, b"CropBox") {
    Some(value) =>
      match self.page_rect(value) {
        Some(rect) => attrs.crop = Some(rect)
        None => return Some("/CropBox is not a rectangle")
      }
    None => ()
  }
  match pdf_dict_get(dict, b"Rotate") {
    Some(value) =>
      match self.page_num(Some(value)) {
        Some(number) =>
          attrs.rotate = if number < 0.0 {
            -(-number).round().to_int()
          } else {
            number.round().to_int()
          }
        None => return Some("/Rotate is not a number")
      }
    None => ()
  }
  match pdf_dict_get(dict, b"Resources") {
    Some(value) =>
      match self.page_deref(Some(value)) {
        PdfNull => attrs.resources = None
        PdfDict(_) as resources => attrs.resources = Some(resources)
        _ => return Some("/Resources is not a dictionary")
      }
    None => ()
  }
  None
}

///|
fn PdfFile::page_walk(
  self : PdfFile,
  walk : PdfPageWalk,
  object : PdfObject,
  inherited : PdfPageAttrs,
  inherited_error : String?,
  depth : Int32,
) -> Unit {
  let dict = self.page_deref(Some(object))
  if !(dict is PdfDict(_)) {
    return
  }
  let typ = self.page_deref(pdf_dict_get(dict, b"Type"))
  let has_kids = pdf_dict_get(dict, b"Kids") is Some(_)
  let is_tree = typ == PdfName(b"Pages") ||
    (!(typ is PdfName(_)) && has_kids) ||
    (typ == PdfName(b"") && has_kids)
  let is_page = typ == PdfName(b"Page") ||
    !(typ is PdfName(_)) ||
    typ == PdfName(b"")
  if is_tree {
    if depth > 64 {
      return
    }
    if object is PdfRef(number, _) {
      if walk.seen.contains(number) {
        return
      }
      walk.seen[number] = true
    }
    let attrs = inherited.copy()
    let err = self.page_inherit(dict, attrs)
    let err = match inherited_error {
      Some(_) => inherited_error
      None => err
    }
    match self.page_deref(pdf_dict_get(dict, b"Kids")) {
      PdfArray(kids) =>
        for kid in kids {
          self.page_walk(walk, kid, attrs, err, depth + 1)
        }
      _ => ()
    }
  } else if is_page {
    if object is PdfRef(number, _) {
      if !walk.listed.contains(number) {
        walk.listed[number] = true
      } else {
        walk.repeated += 1
        if walk.repeated > 16 {
          walk.left += 1
          return
        }
      }
    }
    let attrs = inherited.copy()
    let err = self.page_inherit(dict, attrs)
    let err = match inherited_error {
      Some(_) => inherited_error
      None => err
    }
    let reference = match object {
      PdfRef(_, _) => Some(object)
      _ => None
    }
    walk.leaves.push({ dict, reference, attrs, error: err, })
  }
}

///|
fn PdfFile::page_leaves(
  self : PdfFile,
) -> (Array[PdfPageLeaf], Int32) raise PdfStreamError {
  let catalog = self.page_deref(self.trailer_entry(b"Root"))
  let root = pdf_dict_get(catalog, b"Pages")
  let tree = self.page_deref(root)
  if !(tree is PdfDict(_)) {
    raise InvalidStream("no page tree")
  }
  let walk : PdfPageWalk = {
    leaves: [],
    seen: {},
    listed: {},
    repeated: 0,
    left: 0,
  }
  let attrs : PdfPageAttrs = {
    media: None,
    crop: None,
    rotate: 0,
    resources: None,
  }
  match root {
    Some(value) => self.page_walk(walk, value, attrs, None, 0)
    None => ()
  }
  (walk.leaves, walk.left)
}
