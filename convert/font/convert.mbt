///|
/// Options for font specimen conversion. Font programs are stored as SFNT.
pub(all) struct SpecimenOptions {
  selection : String
  title : String
  text : String
  examples : Int32
  system_fonts : Bool
  no_subset : Bool
  ignore_restrictions : Bool
  no_text_index : Bool
}

///|
pub fn SpecimenOptions::new() -> SpecimenOptions {
  {
    selection: "",
    title: "",
    text: "",
    examples: 200,
    system_fonts: false,
    no_subset: false,
    ignore_restrictions: false,
    no_text_index: false,
  }
}

///|
/// The BDF document, converter summary, and nonfatal warnings.
pub(all) struct SpecimenResult {
  bdf : Bytes
  summary : String
  warnings : Array[String]
}

///|
priv enum PendingSpecimenView {
  PendingOverview(SpecimenOverviewView)
  PendingCharacters(SpecimenCharacterView)
  PendingGlyphs(SpecimenGlyphView)
  PendingFeatures(SpecimenFeatureView)
}

///|
priv struct PendingSpecimen {
  view : SpecimenView
  program : SpecimenFacePrograms
  content : PendingSpecimenView
}

///|
priv struct RenderedSpecimen {
  view : SpecimenView
  pages : Array[SpecimenRenderedPage]
  objects : Array[String]
}

///|
/// Convert a font or collection into BDF scroll views. Font discovery is
/// host-controlled through `database`; font programs are stored as SFNT.
pub fn convert(
  data : Bytes,
  database : @db.Database,
  options~ : SpecimenOptions = SpecimenOptions::new(),
) -> SpecimenResult raise {
  if options.examples < 0 {
    raise InvalidFontInput("font: examples must be nonnegative")
  }
  let file = load(data)
  let (faces, _) = file.select(options.selection)
  let plan = file.document_plan(options.selection, options.title)
  let dc : Map[String, Json] = { "type": Json::string("Font") }
  for
    (key, value) in [
      ("title", plan.metadata.title),
      ("creator", plan.metadata.creator),
      ("rights", plan.metadata.rights),
      ("description", plan.metadata.description),
      ("created", plan.metadata.created),
      ("modified", plan.metadata.modified),
    ] {
    if value != "" {
      dc[key] = Json::string(value)
    }
  }
  let writer = @core.DocumentWriter::new(
    meta=Json::object({ "source": Json::string("font"), "dc": Json::object(dc) }),
  )
  let programs = file.prepare_programs(
    writer,
    options.selection,
    options.text,
    ignore_restrictions=options.ignore_restrictions,
  )
  let texter = SpecimenTexter::new(database)
  let pending : Array[PendingSpecimen] = []
  let mut view_index = 0
  for i, face in faces {
    let program = programs.faces[i]
    let overview = file.overview_view(
      face,
      texter,
      program.sample,
      program.outlined,
    )
    pending.push({
      view: plan.views[view_index],
      program,
      content: PendingOverview(overview),
    })
    view_index += 1
    if face.font.characters().length() > 0 {
      pending.push({
        view: plan.views[view_index],
        program,
        content: PendingCharacters(face.character_view(texter)),
      })
      view_index += 1
    }
    pending.push({
      view: plan.views[view_index],
      program,
      content: PendingGlyphs(face.glyph_view(texter)),
    })
    view_index += 1
    if face_has_features(face) {
      pending.push({
        view: plan.views[view_index],
        program,
        content: PendingFeatures(
          face.feature_view(
            texter,
            program.sample,
            example_limit=options.examples,
          ),
        ),
      })
      view_index += 1
    }
  }
  let fonts : SpecimenUIFonts = if options.system_fonts {
    { hashes: Map([]), warnings: [], }
  } else {
    texter.embed(
      writer,
      no_subset=options.no_subset,
      ignore_restrictions=options.ignore_restrictions,
    )
  }
  let rendered : Array[RenderedSpecimen] = []
  for item in pending {
    let pages = match item.content {
      PendingOverview(v) => v.render(item.program, fonts)
      PendingCharacters(v) => v.render(item.program, fonts)
      PendingGlyphs(v) => v.render(item.program, fonts)
      PendingFeatures(v) => v.render(item.program, fonts)
    }
    let objects : Array[String] = []
    for page in pages {
      objects.push(writer.add_part("obj", page.object))
    }
    rendered.push({ view: item.view, pages, objects, })
  }
  for item in rendered {
    let pages = [
      for i, page in item.pages => {
        Json::object({
          "w": Json::number(720.0),
          "h": Json::number(
            Float::from_double(page.height).to_double(),
            repr=Float::from_double(page.height).to_string(),
          ),
          "layers": Json::array([
            Json::object({
              "role": Json::string("body"),
              "obj": Json::string(item.objects[i]),
            }),
          ]),
        })
      }
    ]
    let view : Map[String, Json] = {
      "id": Json::string(item.view.id),
      "kind": Json::string("scroll"),
      "title": Json::string(item.view.title),
      "pages": Json::array(pages),
    }
    if !options.no_text_index {
      let runs : Array[@core.IndexRun] = []
      for i, page in item.pages {
        let object = @core.decode_object_resources(page.object)
        let text = @render.extract_text(object, _ => None)
        for j, run in text.runs {
          runs.push({
            a: i,
            b: 0,
            ordinal: run.ordinal,
            separator: if j == 0 {
              2
            } else {
              run.separator
            },
            text: run.text,
          })
        }
      }
      view["textIndex"] = Json::string(
        writer.add_part("idx", @core.encode_text_index(runs)),
      )
    }
    writer.add_view(Json::object(view))
  }
  let warnings = programs.warnings.copy()
  for warning in fonts.warnings {
    warnings.push(warning)
  }
  let (_, missing) = texter.usage()
  if missing.length() > 0 {
    let msg = StringBuilder()
    for i, code in missing {
      if i == 20 {
        msg.write_string(
          " … (" + (missing.length() - 20).to_string() + " more)",
        )
        break
      }
      msg.write_string(
        " " +
        String::from_array([code.to_char().unwrap_or('\u{fffd}')]) +
        " U+" +
        chart_hex(code),
      )
    }
    warnings.push(
      "no available font has glyphs for:" +
      msg.to_string() +
      "; viewers draw them with their own fonts",
    )
  }
  let summary : Array[String] = []
  if faces.length() > 1 {
    summary.push(faces.length().to_string() + " fonts")
  }
  let first = faces[0]
  summary.push(
    info_number(first.font.metrics.glyph_count.to_int64()) +
    " glyphs, " +
    info_number(first.font.characters().length().to_int64()) +
    " characters",
  )
  if programs.outlined > 0 {
    summary.push("drawn as outlines")
  }
  summary.push(
    plan.views.length().to_string() +
    " view(s), " +
    (programs.font_parts + fonts.hashes.length()).to_string() +
    " embedded font(s)",
  )
  { bdf: writer.write_single(), summary: summary.join(", "), warnings, }
}
