///|
/// A glyph placed at an em-relative position in a feature example.
pub(all) struct FeaturePlacedGlyph {
  glyph : Int32
  x : Double
  y : Double
}

///|
/// Before-and-after glyphs and their advances for an OpenType feature example.
pub(all) struct FeatureExample {
  before : Array[FeaturePlacedGlyph]
  after : Array[FeaturePlacedGlyph]
  before_width : Double
  after_width : Double
  alternatives : Bool
  boxes : Bool
  before_advance : Double
  after_advance : Double
  offset : Double
  note : String
}

///|
/// Examples retained and their total number before the display limit.
pub(all) struct FeatureExamples {
  items : Array[FeatureExample]
  total : Int64
}

///|
/// Parsed OpenType lookups and their shared work budgets for a specimen face.
pub struct SpecimenFeaturePlanner {
  priv face : FileFace
  priv gsub : @otlayout.Gsub?
  priv gsub_layout : @otlayout.Layout?
  priv gpos : @otlayout.Gpos?
  priv gpos_layout : @otlayout.Layout?
}

///|
pub fn FileFace::feature_planner(self : FileFace) -> SpecimenFeaturePlanner {
  let gsub = self.font.table("GSUB").unwrap_or(b"")
  let gpos = self.font.table("GPOS").unwrap_or(b"")
  {
    face: self,
    gsub: @otlayout.parse_gsub(gsub[:]),
    gsub_layout: @otlayout.parse_layout(gsub[:]),
    gpos: @otlayout.parse_gpos(gpos[:]),
    gpos_layout: @otlayout.parse_layout(gpos[:], gpos=true),
  }
}

///|
fn feature_sequence(
  face : FileFace,
  glyphs : Array[Int32],
) -> (Array[FeaturePlacedGlyph], Double) {
  let items : Array[FeaturePlacedGlyph] = []
  let mut x = 0.0
  for glyph in glyphs {
    items.push({ glyph, x, y: 0.0, })
    x += face.font.advance(glyph)
  }
  (items, x)
}

///|
/// Collect substitution examples for one GSUB feature, including nested
/// contextual lookups. A zero limit retains every example.
pub fn SpecimenFeaturePlanner::gsub_examples(
  self : SpecimenFeaturePlanner,
  group : FeatureGroup,
  limit : Int32,
) -> FeatureExamples {
  let items : Array[FeatureExample] = []
  let total = Ref(0L)
  guard group.table == "GSUB" &&
    self.gsub is Some(table) &&
    self.gsub_layout is Some(layout) else {
    return { items, total: 0L, }
  }
  let seen : Map[Int32, Bool] = Map([])
  let pending : Array[(Int32, Int32)] = []
  for i = group.lookups.length() - 1; i >= 0; i = i - 1 {
    pending.push((group.lookups[i], 0))
  }
  while pending.length() > 0 {
    let (index, depth) = pending.pop().unwrap()
    if depth > 8 ||
      index < 0 ||
      index >= layout.lookups.length() ||
      seen.contains(index) {
      continue
    }
    seen[index] = true
    match table.context(index) {
      Some(context) if context.nested.length() > 0 => {
        for i = context.nested.length() - 1; i >= 0; i = i - 1 {
          pending.push((context.nested[i], depth + 1))
        }
        continue
      }
      _ => ()
    }
    table.each_substitution(index, substitution => {
      let mut valid = true
      for glyph in substitution.input {
        if glyph < 0 || glyph >= self.face.font.metrics.glyph_count {
          valid = false
        }
      }
      for glyph in substitution.output {
        if glyph < 0 || glyph >= self.face.font.metrics.glyph_count {
          valid = false
        }
      }
      if !valid {
        return true
      }
      let (before, before_width) = feature_sequence(
        self.face,
        substitution.input,
      )
      let alternatives = layout.lookups[index].typ == 3
      let (after, after_width) = if alternatives {
        let after : Array[FeaturePlacedGlyph] = []
        let mut x = 0.0
        for glyph in substitution.output {
          after.push({ glyph, x, y: 0.0, })
          x += self.face.font.advance(glyph) + 0.25
        }
        (after, Double::max(x - 0.25, 0.0))
      } else {
        feature_sequence(self.face, substitution.output)
      }
      total.val += 1L
      if limit == 0 || items.length() < limit {
        items.push({
          before,
          after,
          before_width,
          after_width,
          alternatives,
          boxes: false,
          before_advance: 0.0,
          after_advance: 0.0,
          offset: 0.0,
          note: "",
        })
      }
      true
    })
  }
  { items, total: total.val, }
}

///|
/// Describe a feature lookup and consume its shared inspection budget.
pub fn SpecimenFeaturePlanner::lookup_note(
  self : SpecimenFeaturePlanner,
  group : FeatureGroup,
  index : Int32,
) -> String {
  let is_gpos = group.table == "GPOS"
  let layout = if is_gpos { self.gpos_layout } else { self.gsub_layout }
  guard layout is Some(layout) && layout.lookups.get(index) is Some(lookup) else {
    return ""
  }
  let mut text = "#" +
    index.to_string() +
    " " +
    @otlayout.lookup_type_name(lookup.typ, gpos=is_gpos)
  let context = if is_gpos {
    match self.gpos {
      Some(table) => table.context(index)
      None => None
    }
  } else {
    match self.gsub {
      Some(table) => table.context(index)
      None => None
    }
  }
  match context {
    Some(context) if context.nested.length() > 0 => {
      let references = context.nested.map(n => "#" + n.to_string()).join(" ")
      let label = if context.rules == 1 { "rule" } else { "rules" }
      return text +
        " (" +
        info_number(context.rules.to_int64()) +
        " " +
        label +
        ", applying " +
        references +
        ")"
    }
    _ => ()
  }
  let n = Ref(0L)
  if is_gpos {
    match self.gpos {
      Some(table) =>
        if lookup.typ == 2 {
          n.val = table.pair_count(index)
        } else if lookup.typ == 1 {
          table.each_single(index, (_, _) => {
            n.val += 1L
            true
          })
        } else {
          let (marks, bases) = table.mark_counts(index)
          if marks > 0 {
            return text +
              " (" +
              info_number(marks.to_int64()) +
              " marks, " +
              info_number(bases.to_int64()) +
              " bases)"
          }
          n.val = bases.to_int64()
        }
      None => ()
    }
  } else {
    match self.gsub {
      Some(table) =>
        table.each_substitution(index, _ => {
          n.val += 1L
          true
        })
      None => ()
    }
  }
  if n.val > 0L {
    text += " (" + info_number(n.val) + ")"
  }
  text
}
