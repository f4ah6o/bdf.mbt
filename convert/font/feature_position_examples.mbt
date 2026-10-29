///|
priv struct FeaturePairCandidate {
  first : Int32
  second : Int32
  v1 : @otlayout.PositionValue
  v2 : @otlayout.PositionValue
  order : Int32
}

///|
fn feature_in_ranges(code : Int32, ranges : Array[(Int32, Int32)]) -> Bool {
  let mut low = 0
  let mut high = ranges.length()
  while low < high {
    let mid = low + (high - low) / 2
    let (first, last) = ranges[mid]
    if code < first {
      high = mid
    } else if code > last {
      low = mid + 1
    } else {
      return true
    }
  }
  false
}

///|
fn feature_position_zero(v : @otlayout.PositionValue) -> Bool {
  v.x_placement == 0 &&
  v.y_placement == 0 &&
  v.x_advance == 0 &&
  v.y_advance == 0
}

///|
fn feature_position_example(
  before : Array[FeaturePlacedGlyph],
  after : Array[FeaturePlacedGlyph],
  before_width : Double,
  after_width : Double,
  boxes : Bool,
  before_advance : Double,
  after_advance : Double,
  offset : Double,
  note : String,
) -> FeatureExample {
  {
    before,
    after,
    before_width,
    after_width,
    alternatives: false,
    boxes,
    before_advance,
    after_advance,
    offset,
    note,
  }
}

///|
/// Collect positioning examples for one GPOS feature using the sample text.
/// A zero limit retains all examples; the total includes unshown pairs.
pub fn SpecimenFeaturePlanner::gpos_examples(
  self : SpecimenFeaturePlanner,
  group : FeatureGroup,
  limit : Int32,
  sample : SamplePlan,
) -> FeatureExamples {
  let items : Array[FeatureExample] = []
  let total = Ref(0L)
  guard group.table == "GPOS" &&
    self.gpos is Some(table) &&
    self.gpos_layout is Some(layout) else {
    return { items, total: 0L, }
  }
  let face = self.face
  let upem = face.font.metrics.units_per_em.to_double()
  let glyphs = face.specimen_glyphs()
  let outlines = face.outlines()
  let sample_text = sample.all()
  let add = (item : FeatureExample) => {
    total.val += 1L
    if limit == 0 || items.length() < limit {
      items.push(item)
    }
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
    match layout.lookups[index].typ {
      2 => {
        let chars : Array[Int32] = []
        let text = sample_text +
          "AVAWAYATAvAwAyLTLVLWLYPAPaTaTeToTrTuTyVaVeVoWaWeWoYaYeYoFAFaKoRoLyffrvyvwkv.y.,T.V.Y.F.P.r,y,"
        for c in text {
          let code = c.to_int()
          if feature_in_ranges(code, specimen_position_graphic_ranges) &&
            face.font.glyph(code) is Some(_) {
            chars.push(code)
          }
        }
        let found : Array[FeaturePairCandidate] = []
        let pair_seen : Map[Int64, Bool] = Map([])
        let try_pair = (a : Int32, b : Int32) => {
          let key = (a.to_int64() << 16) | b.to_int64()
          if pair_seen.contains(key) ||
            a < 0 ||
            b < 0 ||
            a >= glyphs.length() ||
            b >= glyphs.length() {
            return
          }
          pair_seen[key] = true
          match table.pair_value(index, a, b) {
            Some((v1, v2)) if !feature_position_zero(v1) ||
              !feature_position_zero(v2) =>
              found.push({ first: a, second: b, v1, v2, order: found.length(), })
            _ => ()
          }
        }
        for i in 0..<Int32::max(chars.length() - 1, 0) {
          try_pair(
            face.font.glyph(chars[i]).unwrap(),
            face.font.glyph(chars[i + 1]).unwrap(),
          )
        }
        if found.length() < 24 {
          let n = Ref(0)
          table.each_pair(index, pair => {
            if pair.first < glyphs.length() &&
              pair.second < glyphs.length() &&
              glyphs[pair.first].characters.length() > 0 &&
              glyphs[pair.second].characters.length() > 0 {
              try_pair(pair.first, pair.second)
            }
            n.val += 1
            found.length() < 48 && n.val < 200000
          })
        }
        found.sort_by((a, b) => {
          let av = a.v1.x_advance + a.v2.x_placement
          let bv = b.v1.x_advance + b.v2.x_placement
          let aa = Int32::max(av, -av)
          let bb = Int32::max(bv, -bv)
          if aa == bb {
            a.order.compare(b.order)
          } else {
            bb.compare(aa)
          }
        })
        let count = table.pair_count(index)
        let shown = Int32::min(found.length(), 48)
        for i in 0..<shown {
          let pair = found[i]
          let (before, bw) = feature_sequence(face, [pair.first, pair.second])
          let a0 = face.font.advance(pair.first)
          let after : Array[FeaturePlacedGlyph] = [
            {
              glyph: pair.first,
              x: pair.v1.x_placement.to_double() / upem,
              y: pair.v1.y_placement.to_double() / upem,
            },
            {
              glyph: pair.second,
              x: a0 +
              (pair.v1.x_advance + pair.v2.x_placement).to_double() / upem,
              y: pair.v2.y_placement.to_double() / upem,
            },
          ]
          let aw = a0 +
            (pair.v1.x_advance + pair.v2.x_advance).to_double() / upem +
            face.font.advance(pair.second)
          let v = pair.v1.x_advance + pair.v2.x_placement
          add(
            feature_position_example(
              before,
              after,
              bw,
              aw,
              false,
              0.0,
              0.0,
              0.0,
              if v == 0 {
                ""
              } else {
                v.to_string()
              },
            ),
          )
        }
        total.val += Int64::max(count - shown.to_int64(), 0L)
      }
      1 => {
        let mapped : Array[FeatureExample] = []
        let other : Array[FeatureExample] = []
        table.each_single(index, (glyph, v) => {
          if glyph < 0 || glyph >= glyphs.length() {
            return true
          }
          let a = face.font.advance(glyph)
          let adv = a + v.x_advance.to_double() / upem
          let offset = v.x_placement.to_double() / upem
          let before : Array[FeaturePlacedGlyph] = [{ glyph, x: 0.0, y: 0.0, }]
          let after : Array[FeaturePlacedGlyph] = [
            { glyph, x: offset, y: v.y_placement.to_double() / upem, },
          ]
          let example = feature_position_example(
            before,
            after,
            a,
            Double::max(adv, a),
            true,
            a,
            adv,
            offset,
            "",
          )
          if glyphs[glyph].characters.length() > 0 {
            mapped.push(example)
          } else {
            other.push(example)
          }
          true
        })
        for item in mapped {
          add(item)
        }
        for item in other {
          add(item)
        }
      }
      4 | 6 =>
        for attachment in table.attachments(index) {
          let marks = attachment.marks
            .keys()
            .collect()
            .filter(g => g >= 0 && g < glyphs.length())
          marks.sort_by((a, b) => {
            let ma = glyphs[a].characters.length() > 0
            let mb = glyphs[b].characters.length() > 0
            if ma != mb {
              if ma {
                -1
              } else {
                1
              }
            } else {
              a.compare(b)
            }
          })
          let by_class : Map[Int32, Int32] = Map([])
          let classes : Array[Int32] = []
          for mark in marks {
            let class = attachment.marks[mark].class
            if !by_class.contains(class) {
              by_class[class] = mark
              classes.push(class)
            }
          }
          classes.sort()
          let bases = attachment.bases
            .keys()
            .collect()
            .filter(g => g >= 0 && g < glyphs.length())
          let first_char = (g : Int32) => {
            glyphs[g].characters.get(0).unwrap_or(0)
          }
          let rank = (g : Int32) => {
            let code = first_char(g)
            if code == 0 {
              3
            } else if feature_in_ranges(code, specimen_letter_ranges) {
              if sample_text.contains(
                  String::from_array([code.to_char().unwrap_or('\u{fffd}')]),
                ) {
                0
              } else {
                1
              }
            } else {
              2
            }
          }
          bases.sort_by((a, b) => {
            let order = rank(a).compare(rank(b))
            if order != 0 {
              order
            } else {
              let order = first_char(a).compare(first_char(b))
              if order != 0 {
                order
              } else {
                a.compare(b)
              }
            }
          })
          for class in classes {
            let mark = by_class[class]
            let ma = attachment.marks[mark].anchor
            let mut shown = 0
            for base in bases {
              let anchors = attachment.bases[base]
              guard anchors.get(class) is Some(Some(anchor)) else { continue }
              let (before, bw) = feature_sequence(face, [base, mark])
              let ab = face.font.advance(base)
              let x = (anchor.x - ma.x).to_double() / upem
              let y = (anchor.y - ma.y).to_double() / upem
              let after : Array[FeaturePlacedGlyph] = [
                { glyph: base, x: 0.0, y: 0.0, },
                { glyph: mark, x, y, },
              ]
              let aw = match outlines.bounds(mark) {
                Some((_, _, x1, _)) => Double::max(ab, x + x1 / upem)
                None => ab
              }
              add(
                feature_position_example(
                  before, after, bw, aw, false, 0.0, 0.0, 0.0, "",
                ),
              )
              shown += 1
              if shown == 4 {
                break
              }
            }
          }
        }
      _ => ()
    }
  }
  { items, total: total.val, }
}
