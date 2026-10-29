///|
pub suberror MusicPaintError {
  MissingMusicGlyph(String)
}

///|
fn music_f32(value : Double) -> Float {
  if value.is_nan() || value.is_inf() {
    0.0F
  } else {
    Float::from_double(value)
  }
}

///|
// Go may fuse a multiplication and addition. Recover their rounding error
// so translated paths agree with the upstream fused result near cancellation.
fn music_mul_add(a : Double, b : Double, c : Double) -> Double {
  let product = a * b
  let split = 134217729.0
  let ah_tmp = a * split
  let ah = ah_tmp - (ah_tmp - a)
  let al = a - ah
  let bh_tmp = b * split
  let bh = bh_tmp - (bh_tmp - b)
  let bl = b - bh
  let product_error = ah * bh - product + ah * bl + al * bh + al * bl
  let sum = product + c
  let z = sum - product
  let sum_error = product - (sum - z) + (c - z)
  sum + (product_error + sum_error)
}

///|
fn music_glyph_key(p : MusicPrimitive, sp : Double) -> String {
  p.glyph +
  "|" +
  (p.scale * p.scale_x * sp).to_string() +
  "|" +
  (p.scale * p.scale_y * sp).to_string()
}

///|
/// Shared glyph paths for the score, in first-use order.
pub struct MusicGlyphPaths {
  paths : Array[@core.Path]
  indices : Map[String, Int32]
  staff_space : Double
}

///|
/// Collect and scale glyph outlines in drawing order. For upstream-compatible
/// ordering, provide each system's staff drawings followed by its spanning drawing.
pub fn music_glyph_paths(
  drawings : Array[MusicDrawing],
  staff_space : Double,
) -> MusicGlyphPaths {
  let paths : Array[@core.Path] = []
  let indices : Map[String, Int32] = Map([])
  for drawing in drawings {
    for p in drawing.primitives() {
      if p.kind != 0 {
        continue
      }
      let key = music_glyph_key(p, staff_space)
      if indices.contains(key) {
        continue
      }
      match music_glyph(p.glyph) {
        None => ()
        Some(glyph) => {
          let sx = p.scale * p.scale_x * staff_space
          let sy = p.scale * p.scale_y * staff_space
          let coordinates : Array[Double] = []
          for i, value in glyph.coordinates {
            coordinates.push(
              music_f32(value * (if i % 2 == 0 { sx } else { sy })).to_double(),
            )
          }
          indices[key] = paths.length()
          paths.push({ verbs: glyph.verbs, coordinates, })
        }
      }
    }
  }
  { paths, indices, staff_space, }
}

///|
/// Encode this collection as a BDF path part.
pub fn MusicGlyphPaths::encode(self : MusicGlyphPaths) -> Bytes raise {
  @core.encode_path_collection(self.paths)
}

///|
/// Paint staff-space music primitives into a BDF object.
pub struct MusicPainter {
  object : @core.ObjectBuilder
  glyphs : MusicGlyphPaths
  hash : String
  refs : Map[Int32, Int32]
  mut line_width : Double
  mut dashed : Bool
}

///|
/// The hash identifies the path collection returned by `MusicGlyphPaths::encode`.
pub fn MusicPainter::new(
  object : @core.ObjectBuilder,
  glyphs : MusicGlyphPaths,
  hash : String,
) -> MusicPainter {
  { object, glyphs, hash, refs: Map([]), line_width: 0.0, dashed: false, }
}

///|
/// Draw graphics and marks. Text is delegated to the caller so the same
/// font resolution, embedding and language handling can be used for titles.
pub fn MusicPainter::draw(
  self : MusicPainter,
  drawing : MusicDrawing,
  ox : Double,
  oy : Double,
  text : (MusicPrimitive, Double, Double) -> Unit raise,
) -> Unit raise {
  let object = self.object
  let sp = self.glyphs.staff_space
  for p in drawing.primitives() {
    match p.kind {
      0 => {
        let key = music_glyph_key(p, sp)
        let index = match self.glyphs.indices.get(key) {
          Some(index) => index
          None => raise MissingMusicGlyph(p.glyph)
        }
        let reference = match self.refs.get(index) {
          Some(reference) => reference
          None => {
            let reference = object.add_path(@core.External(self.hash, index))
            self.refs[index] = reference
            reference
          }
        }
        object.fill_path_at(
          reference,
          0,
          music_f32(music_mul_add(p.x, sp, ox)),
          music_f32(music_mul_add(p.y, sp, oy)),
        )
      }
      1 =>
        object.fill_rect(
          music_f32(music_mul_add(p.x, sp, ox)),
          music_f32(music_mul_add(p.y, sp, oy)),
          music_f32(p.w * sp),
          music_f32(p.h * sp),
        )
      2 =>
        match p.outline {
          None => ()
          Some(outline) => {
            let coordinates : Array[Double] = []
            for i, value in outline.coordinates {
              coordinates.push(
                music_f32(
                  music_mul_add(value, sp, if i % 2 == 0 { ox } else { oy }),
                ).to_double(),
              )
            }
            let reference = object.add_path(
              @core.Inline({ verbs: outline.verbs, coordinates, }),
            )
            object.fill_path(reference, 0)
          }
        }
      3 => {
        let width = p.width * sp
        if width != self.line_width {
          object.line(music_f32(width), 0, 0, 10.0F)
          self.line_width = width
        }
        if p.dash > 0.0 {
          object.dash(
            [music_f32(p.dash * sp), music_f32(p.dash * sp * 0.6)],
            0.0F,
          )
          self.dashed = true
        } else if self.dashed {
          object.dash([], 0.0F)
          self.dashed = false
        }
        let path : @core.Path = {
          verbs: b"\x00\x01",
          coordinates: [
            music_f32(music_mul_add(p.x, sp, ox)).to_double(),
            music_f32(music_mul_add(p.y, sp, oy)).to_double(),
            music_f32(music_mul_add(p.w, sp, ox)).to_double(),
            music_f32(music_mul_add(p.h, sp, oy)).to_double(),
          ],
        }
        let reference = object.add_path(@core.Inline(path))
        object.stroke_path(reference)
      }
      4 => text(p, music_mul_add(p.x, sp, ox), music_mul_add(p.y, sp, oy))
      5 => object.mark(p.mark.to_byte(), p.text)
      _ => ()
    }
  }
}
