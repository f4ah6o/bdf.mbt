///|
/// A mark or base anchor in font units.
pub(all) struct Anchor {
  x : Int32
  y : Int32
}

///|
/// The class and anchor associated with a mark glyph.
pub(all) struct MarkAnchor {
  class : Int32
  anchor : Anchor
}

///|
/// Mark-to-base or mark-to-mark attachment data for one subtable.
pub(all) struct Attachment {
  marks : Map[Int32, MarkAnchor]
  bases : Map[Int32, Array[Anchor?]]
}

///|
fn attachment_anchor(data : BytesView?) -> Anchor? {
  guard data is Some(data) else { return None }
  if u16(data, 0) < 1 || u16(data, 0) > 3 {
    return None
  }
  let x = u16(data, 2)
  let y = u16(data, 4)
  Some({
    x: if x >= 32768 {
      x - 65536
    } else {
      x
    },
    y: if y >= 32768 {
      y - 65536
    } else {
      y
    },
  })
}

///|
/// Read attachment anchors for mark-to-base and mark-to-mark lookups.
pub fn Gpos::attachments(self : Gpos, index : Int32) -> Array[Attachment] {
  let out : Array[Attachment] = []
  guard self.lookups.get(index) is Some(lookup) &&
    (lookup.typ == 4 || lookup.typ == 6) else {
    return out
  }
  for st in lookup.subtables {
    if u16(st, 0) != 1 {
      continue
    }
    let marks = coverage(at(st, u16(st, 2)))
    let bases = coverage(at(st, u16(st, 4)))
    let classes = u16(st, 6)
    let ma = at(st, u16(st, 8))
    let ba = at(st, u16(st, 10))
    if !self.spend(1L + marks.length().to_int64() + bases.length().to_int64()) {
      break
    }
    guard ma is Some(ma) && ba is Some(ba) && classes != 0 else { continue }
    let item : Attachment = { marks: Map([]), bases: Map([]), }
    let n = count(ma, u16(ma, 0), 2, 4)
    for k in 0..<Int32::min(marks.length(), n) {
      let class = u16(ma, 2 + k * 4)
      match attachment_anchor(at(ma, u16(ma, 4 + k * 4))) {
        Some(anchor) if class < classes =>
          item.marks[marks[k]] = { class, anchor, }
        _ => ()
      }
    }
    let n = count(ba, u16(ba, 0), 2, 2 * classes)
    let size = Int32::min(n, bases.length())
    if !self.spend(size.to_int64() * classes.to_int64()) {
      break
    }
    for k in 0..<size {
      let anchors : Array[Anchor?] = []
      let mut has = false
      for class in 0..<classes {
        let anchor = attachment_anchor(
          at(ba, u16(ba, 2 + (k * classes + class) * 2)),
        )
        if anchor is Some(_) {
          has = true
        }
        anchors.push(anchor)
      }
      if has {
        item.bases[bases[k]] = anchors
      }
    }
    out.push(item)
  }
  out
}

///|
/// Count unique marks and bases (or joined glyphs for cursive attachment).
pub fn Gpos::mark_counts(self : Gpos, index : Int32) -> (Int32, Int32) {
  guard self.lookups.get(index) is Some(lookup) else { return (0, 0) }
  let marks : Map[Int32, Bool] = Map([])
  let bases : Map[Int32, Bool] = Map([])
  for st in lookup.subtables {
    if u16(st, 0) != 1 {
      continue
    }
    let first = coverage(at(st, u16(st, 2)))
    let second = if lookup.typ == 4 || lookup.typ == 5 || lookup.typ == 6 {
      coverage(at(st, u16(st, 4)))
    } else {
      []
    }
    if !self.spend(1L + first.length().to_int64() + second.length().to_int64()) {
      break
    }
    if lookup.typ == 3 {
      for glyph in first {
        bases[glyph] = true
      }
    } else if lookup.typ == 4 || lookup.typ == 5 || lookup.typ == 6 {
      for glyph in first {
        marks[glyph] = true
      }
      for glyph in second {
        bases[glyph] = true
      }
    }
  }
  (marks.length(), bases.length())
}
