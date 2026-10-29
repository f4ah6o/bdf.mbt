///|
/// Fonts and sample plan used to draw one face of a specimen.
pub(all) struct SpecimenFacePrograms {
  face_index : Int32
  glyph_font : @core.Font?
  sample_font : @core.Font?
  sample : SamplePlan
  outlined : Bool
}

///|
/// Prepared specimen font resources and warnings for a selected collection.
pub(all) struct SpecimenPrograms {
  faces : Array[SpecimenFacePrograms]
  warnings : Array[String]
  font_parts : Int32
  outlined : Int32
}

///|
/// Prepare specimen glyph and sample fonts and store them in a document. The
/// collection selection and license policy follow upstream. Programs are
/// stored as SFNT; WOFF2 encoding is not yet available in this port.
pub fn FontFile::prepare_programs(
  self : FontFile,
  document : @core.DocumentWriter,
  selection : String,
  text : String,
  ignore_restrictions~ : Bool = false,
) -> SpecimenPrograms raise {
  let (faces, warnings) = self.select(selection)
  let glyph_fonts : Map[String, @core.Font] = Map([])
  let result : Array[SpecimenFacePrograms] = []
  let mut font_parts = 0
  let mut outlined = 0
  for face in faces {
    let sample = face.sample_plan(text)
    if !face.font.metrics.embeddable && !ignore_restrictions {
      outlined += 1
      warnings.push(
        face.specimen_names().full() +
        ": the font's license (OS/2 fsType) does not allow embedding it; its glyphs are drawn as outlines",
      )
      result.push({
        face_index: face.index,
        glyph_font: None,
        sample_font: None,
        sample,
        outlined: true,
      })
      continue
    }
    let key = face.font.specimen_glyph_key()
    let glyph_font = match glyph_fonts.get(key) {
      Some(font) => font
      None => {
        let data = face.font.glyph_program()
        let hash = document.add_part("font", data)
        font_parts += 1
        let font : @core.Font = {
          hash: Some(hash),
          family: "",
          weight: 400,
          style: 0,
        }
        glyph_fonts[key] = font
        font
      }
    }
    let program = if face.font.metrics.subsettable || ignore_restrictions {
      face.sample_program(sample.all())
    } else {
      face.sample_whole_program()
    }
    let sample_font : @core.Font? = match program {
      Some(data) => {
        let hash = document.add_part("font", data)
        font_parts += 1
        Some({ hash: Some(hash), family: "", weight: 400, style: 0, })
      }
      None => None
    }
    result.push({
      face_index: face.index,
      glyph_font: Some(glyph_font),
      sample_font,
      sample,
      outlined: false,
    })
  }
  { faces: result, warnings, font_parts, outlined, }
}
