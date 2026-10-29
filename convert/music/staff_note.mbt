///|
pub(all) struct NoteHeadLayout {
  note : Int32
  position : Int32
  glyph : String
  mut x : Double
}

///|
/// Placement of a chord, its noteheads, and its stem.
pub(all) struct NoteLayout {
  heads : Array[NoteHeadLayout]
  up : Bool
  stem : Bool
  stem_x : Double
  stem_y0 : Double
  mut stem_y1 : Double
  top : Double
  bottom : Double
  right : Double
  flags : Int32
}

///|
fn head_name(kind : Int32, head : Int32) -> String {
  if head == 1 {
    if kind <= 1 {
      "noteheadXWhole"
    } else if kind == 2 {
      "noteheadXHalf"
    } else {
      "noteheadXBlack"
    }
  } else if kind == 0 {
    "noteheadDoubleWhole"
  } else if kind == 1 {
    "noteheadWhole"
  } else if kind == 2 {
    "noteheadHalf"
  } else {
    "noteheadBlack"
  }
}

///|
fn glyph_anchor(name : String, anchor : String) -> (Double, Double) {
  match music_glyph(name) {
    Some(g) => g.anchors.get(anchor).unwrap_or((0.0, 0.0))
    None => (0.0, 0.0)
  }
}

///|
/// Draw noteheads, ledger lines and accidentals, then determine the stem.
/// Pass a beam direction to override the isolated-note stem direction.
pub fn arrange_staff_note(
  drawing : MusicDrawing,
  staff : PreparedStaffMeasure,
  event : ScoreEvent,
  signs : Array[Int32?],
  x : Double,
  scale : Double,
  beam_direction~ : Bool? = None,
  beamed~ : Bool = false,
) -> NoteLayout {
  let heads : Array[NoteHeadLayout] = []
  for i, note in event.notes {
    heads.push({
      note: i,
      position: staff_position(staff.clef, note.pitch),
      glyph: head_name(event.kind, note.head),
      x,
    })
  }
  heads.sort_by((a, b) => {
    let c = b.position.compare(a.position)
    if c != 0 {
      c
    } else {
      a.note.compare(b.note)
    }
  })
  let up = match beam_direction {
    Some(v) => v
    None =>
      if staff.voices > 1 {
        event.voice % 2 == 1
      } else if heads.is_empty() {
        true
      } else {
        heads[0].position - 4 > 4 - heads[heads.length() - 1].position
      }
  }
  let stem = event.kind >= 2
  if heads.is_empty() {
    return {
      heads,
      up,
      stem,
      stem_x: 0.0,
      stem_y0: 0.0,
      stem_y1: 0.0,
      top: 0.0,
      bottom: 0.0,
      right: 0.0,
      flags: 0,
    }
  }
  let width = glyph_advance(heads[0].glyph) * scale
  let mut displaced_before = false
  let mut previous : Int32? = None
  for j in 0..<heads.length() {
    let i = if up { j } else { heads.length() - 1 - j }
    let h = heads[i]
    let displaced = match previous {
      Some(pos) => Int32::abs(h.position - pos) == 1 && !displaced_before
      None => false
    }
    if displaced {
      h.x = if up { x + width - 0.12 * scale } else { x - width + 0.12 * scale }
    }
    displaced_before = displaced
    previous = Some(h.position)
  }
  let mut top = 1.0e9
  let mut bottom = -1.0e9
  let mut right = -1.0e9
  let mut min_x = 1.0e9
  for h in heads {
    let y = h.position.to_double() / 2.0
    drawing.glyph(h.glyph, h.x, y, scale)
    top = Double::min(top, y - 0.5 * scale)
    bottom = Double::max(bottom, y + 0.5 * scale)
    right = Double::max(right, h.x + glyph_advance(h.glyph) * scale)
    min_x = Double::min(min_x, h.x)
  }
  let ext = 0.4 * scale
  let hi = heads[heads.length() - 1].position
  let lo = heads[0].position
  let mut p = -2
  while p >= hi {
    let mut x0 = 1.0e9
    let mut x1 = -1.0e9
    for h in heads {
      if h.position <= p + 1 {
        x0 = Double::min(x0, h.x)
        x1 = Double::max(x1, h.x + glyph_advance(h.glyph) * scale)
      }
    }
    drawing.rect(
      x0 - ext,
      p.to_double() / 2.0 - 0.16 / 2.0,
      x1 - x0 + 2.0 * ext,
      0.16,
    )
    p -= 2
  }
  p = 10
  while p <= lo {
    let mut x0 = 1.0e9
    let mut x1 = -1.0e9
    for h in heads {
      if h.position >= p - 1 {
        x0 = Double::min(x0, h.x)
        x1 = Double::max(x1, h.x + glyph_advance(h.glyph) * scale)
      }
    }
    drawing.rect(
      x0 - ext,
      p.to_double() / 2.0 - 0.16 / 2.0,
      x1 - x0 + 2.0 * ext,
      0.16,
    )
    p += 2
  }
  let engraving : Array[EngravingNote] = []
  for note in event.notes {
    engraving.push({
      pitch: note.pitch,
      accidental: 0,
      cautionary: false,
      tie_stop: note.tie_stop,
    })
  }
  let placed = place_accidentals(staff.clef, engraving, signs)
  let columns : Array[Double] = []
  for acc in placed {
    while columns.length() <= acc.column {
      columns.push(0.0)
    }
    columns[acc.column] = Double::max(
      columns[acc.column],
      (glyph_advance(accidental_name(acc.accidental)) + 0.2) * scale,
    )
  }
  let left : Array[Double] = []
  let mut cursor = min_x
  for value in columns {
    cursor -= value
    left.push(cursor)
  }
  for acc in placed {
    drawing.glyph(
      accidental_name(acc.accidental),
      left[acc.column],
      acc.position.to_double() / 2.0,
      scale,
    )
  }
  let first = heads[0]
  let last = heads[heads.length() - 1]
  let thick = 0.12 * scale
  let (anchor_x, anchor_y) = glyph_anchor(
    first.glyph,
    if up {
      "stemUpSE"
    } else {
      "stemDownNW"
    },
  )
  let stem_x = if up {
    x + anchor_x * scale - thick
  } else {
    x + anchor_x * scale
  }
  let stem_y0 = if up {
    first.position.to_double() / 2.0 + anchor_y * scale
  } else {
    last.position.to_double() / 2.0 + anchor_y * scale
  }
  let mut stem_y1 = if up {
    last.position.to_double() / 2.0 - 3.5 * scale
  } else {
    first.position.to_double() / 2.0 + 3.5 * scale
  }
  if scale == 1.0 {
    stem_y1 = if up {
      Double::min(stem_y1, 2.0)
    } else {
      Double::max(stem_y1, 2.0)
    }
  }
  let flags = if beamed || event.kind < 4 { 0 } else { event.kind - 3 }
  if flags > 2 {
    let extension = (flags - 2).to_double() * 0.5 * scale
    stem_y1 += if up { -extension } else { extension }
  }
  { heads, up, stem, stem_x, stem_y0, stem_y1, top, bottom, right, flags, }
}

///|
/// Draw an isolated stem and flag after arranging its noteheads.
pub fn draw_isolated_stem(
  drawing : MusicDrawing,
  layout : NoteLayout,
  scale : Double,
) -> Unit {
  if !layout.stem || layout.heads.is_empty() {
    return
  }
  drawing.rect(
    layout.stem_x,
    Double::min(layout.stem_y0, layout.stem_y1),
    0.12 * scale,
    (layout.stem_y1 - layout.stem_y0).abs(),
  )
  if layout.flags > 0 {
    let suffix = ["8th", "16th", "32nd", "64th", "128th"][Int32::min(
        layout.flags,
        5,
      ) -
      1]
    let name = "flag" + suffix + (if layout.up { "Up" } else { "Down" })
    let (ax, ay) = glyph_anchor(
      name,
      if layout.up {
        "stemUpNW"
      } else {
        "stemDownSW"
      },
    )
    drawing.glyph(
      name,
      layout.stem_x - ax * scale,
      layout.stem_y1 - ay * scale,
      scale,
    )
  }
}
