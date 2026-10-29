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
/// stored as SFNT by default; WOFF2 can be enabled for embedded fonts.
pub fn FontFile::prepare_programs(
  self : FontFile,
  document : @core.DocumentWriter,
  selection : String,
  text : String,
  ignore_restrictions~ : Bool = false,
  no_woff2~ : Bool = true,
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
        let hash = specimen_add_font(document, data, no_woff2, warnings)
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
        let hash = specimen_add_font(document, data, no_woff2, warnings)
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

///|
fn specimen_add_font(
  document : @core.DocumentWriter,
  data : Bytes,
  no_woff2 : Bool,
  warnings : Array[String],
) -> String raise {
  let program = if no_woff2 {
    data
  } else {
    @woff2.encode(data) catch {
      @woff2.Woff2Failure(message) => {
        if message != "woff2: the font compresses more than decoders accept" {
          warnings.push("font: not stored as WOFF2: " + message)
        }
        data
      }
      error => {
        warnings.push("font: not stored as WOFF2: " + error.to_string())
        data
      }
    }
  }
  document.add_part("font", program)
}
