///|
#export_name("glyph_program")
pub fn glyph_program(data : Bytes, index : Int32) -> Bytes {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return try! face.font.glyph_program()
    }
  }
  abort("missing font face")
}

///|
#export_name("sample_program")
pub fn sample_program(data : Bytes, index : Int32) -> Bytes {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return (try! face.sample_whole_program()).unwrap_or(b"")
    }
  }
  abort("missing font face")
}

///|
#export_name("pruned_program")
pub fn pruned_program(
  data : Bytes,
  index : Int32,
  glyphs : Array[Int32],
) -> Bytes {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return (try! face.sample_pruned(glyphs)).unwrap_or(b"")
    }
  }
  abort("missing font face")
}

///|
#export_name("reachable")
pub fn reachable(data : Bytes, index : Int32, text : String) -> Array[Int32] {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return face.font.specimen_reachable(text)
    }
  }
  abort("missing font face")
}

///|
#export_name("automatic_pruned")
pub fn automatic_pruned(data : Bytes, index : Int32, text : String) -> Bytes {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return (try! face.sample_program(text)).unwrap_or(b"")
    }
  }
  abort("missing font face")
}

///|
#export_name("sample_plan")
pub fn sample_plan(data : Bytes, index : Int32, text : String) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let plan = face.sample_plan(text)
      let primary = match plan.primary {
        Some(script) => script.code
        None => ""
      }
      return Json::object({
        "primary": Json::string(primary),
        "scripts": Json::array(
          plan.scripts.map(script => Json::string(script.code)),
        ),
        "specimen": Json::string(plan.specimen),
        "charset": Json::array(plan.charset.map(line => Json::string(line))),
        "waterfall": Json::string(plan.waterfall),
        "rtl": Json::boolean(plan.rtl),
        "lang": Json::string(plan.lang),
        "all": Json::string(plan.all()),
      }).stringify()
    }
  }
  abort("missing font face")
}

///|
#export_name("glyph_names")
pub fn glyph_names(data : Bytes, index : Int32) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return Json::array(
        face.font.glyph_names().map(name => Json::string(name)),
      ).stringify()
    }
  }
  abort("missing font face")
}

///|
#export_name("coverage")
pub fn coverage(data : Bytes, index : Int32) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return Json::array(
        face
        .coverage()
        .map(entry => {
          Json::object({
            "first": Json::number(entry.block.first.to_double()),
            "last": Json::number(entry.block.last.to_double()),
            "name": Json::string(entry.block.name),
            "assigned": Json::number(entry.block.assigned.to_double()),
            "mapped": Json::number(entry.mapped.to_double()),
          })
        }),
      ).stringify()
    }
  }
  abort("missing font face")
}

///|
fn name_json(name : @font.SpecimenName) -> Json {
  Json::object({
    "id": Json::number(name.id.to_double()),
    "lang": Json::string(name.lang),
    "english": Json::boolean(name.english),
    "text": Json::string(name.text),
    "rank": Json::number(name.rank.to_double()),
  })
}

///|
#export_name("specimen_names")
pub fn specimen_names(data : Bytes) -> String {
  let names = @font.parse_specimen_names(data)
  let best : Array[Json] = []
  let locals : Array[Json] = []
  for id in 0..<30 {
    best.push(Json::string(names.best(id)))
    locals.push(Json::array(names.local(id).map(name_json)))
  }
  Json::object({
    "records": Json::array(names.records.map(name_json)),
    "cut": Json::boolean(names.cut),
    "best": Json::array(best),
    "locals": Json::array(locals),
    "family": Json::string(names.family()),
    "full": Json::string(names.full()),
  }).stringify()
}

///|
#export_name("glyph_details")
pub fn glyph_details(data : Bytes, index : Int32) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let glyphs = face
        .specimen_glyphs()
        .map(g => {
          Json::object({
            "name": Json::string(g.name),
            "characters": Json::array(
              g.characters.map(c => Json::number(c.to_double())),
            ),
            "label": Json::string(g.label),
            "alternative": Json::string(g.alternative),
          })
        })
      let counts = face
        .script_counts()
        .map(c => {
          Json::object({
            "name": Json::string(c.name),
            "count": Json::number(c.count.to_double()),
          })
        })
      return Json::object({
        "glyphs": Json::array(glyphs),
        "counts": Json::array(counts),
      }).stringify()
    }
  }
  abort("missing font face")
}

///|
#export_name("variations")
pub fn variations(data : Bytes, raw_names : Bytes) -> String {
  let v = @font.parse_variations(data, @font.parse_specimen_names(raw_names))
  Json::object({
    "axes": Json::array(
      v.axes.map(a => {
        Json::object({
          "tag": Json::string(a.tag),
          "name": Json::string(a.name),
          "min": Json::number(a.minimum),
          "default": Json::number(a.default_value),
          "max": Json::number(a.maximum),
          "hidden": Json::boolean(a.hidden),
        })
      }),
    ),
    "instances": Json::array(
      v.instances.map(i => {
        Json::object({
          "name": Json::string(i.name),
          "postscript": Json::string(i.postscript),
          "coordinates": Json::array(i.coordinates.map(c => Json::number(c))),
        })
      }),
    ),
  }).stringify()
}

///|
#export_name("info_tables")
pub fn info_tables(
  cmap : Bytes,
  meta : Bytes,
  colr : Bytes,
  cpal : Bytes,
  sbix : Bytes,
  cblc : Bytes,
  svg : Bytes,
) -> String {
  let (count, more) = @font.variation_sequences(cmap)
  let (design, supported) = @font.metadata_languages(meta)
  Json::object({
    "count": Json::number(count.to_double()),
    "more": Json::boolean(more),
    "design": Json::string(design),
    "supported": Json::string(supported),
    "color": Json::string(@font.color_formats(colr, cpal, sbix, cblc, svg)),
    "palettes": Json::array(
      @font.color_palettes(cpal).map(p => {
        Json::array(p.map(c => Json::number(c.to_double())))
      }),
    ),
  }).stringify()
}

///|
#export_name("kerning_description")
pub fn kerning_description(data : Bytes, index : Int32) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return face.kerning()
    }
  }
  abort("missing font face")
}

///|
fn overview_row(row : @font.OverviewRow) -> Json {
  Json::object({
    "label": Json::string(row.label),
    "value": Json::string(row.value),
    "lang": Json::string(row.lang),
  })
}

///|
#export_name("overview")
pub fn overview(data : Bytes, index : Int32, outlines : Bool) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let sections = file
        .overview(face, outlines~)
        .map(s => {
          Json::object({
            "title": Json::string(s.title),
            "rows": Json::array(s.rows.map(overview_row)),
          })
        })
      return Json::object({
        "sections": Json::array(sections),
        "tables": Json::array(face.table_list().map(overview_row)),
      }).stringify()
    }
  }
  abort("missing font face")
}

///|
#export_name("features")
pub fn features(data : Bytes, index : Int32) -> String {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return Json::array(
        face
        .feature_groups()
        .map(g => {
          Json::object({
            "table": Json::string(g.table),
            "tag": Json::string(g.tag),
            "lookups": Json::array(
              g.lookups.map(x => Json::number(x.to_double())),
            ),
            "scripts": Json::array(g.scripts.map(Json::string)),
            "uiName": Json::string(g.ui_name),
            "displayName": Json::string(g.display_name()),
            "scriptList": Json::string(g.script_list()),
            "scriptTags": Json::string(g.script_tags()),
            "defaultNote": Json::string(g.default_note()),
            "characters": Json::array(
              g.characters.map(x => Json::number(x.to_double())),
            ),
          })
        }),
      ).stringify()
    }
  }
  abort("missing font face")
}

///|
#export_name("scroll_plan")
pub fn scroll_plan(
  kinds : Array[Int32],
  values : Array[Double],
  names : Array[String],
) -> String {
  let layout = @font.ScrollLayout::new()
  let anchors : Map[String, Bool] = Map([])
  for i in 0..<kinds.length() {
    match kinds[i] {
      0 => layout.add(values[i])
      1 => layout.add(values[i], keep=true)
      2 => layout.space(values[i])
      3 => {
        layout.anchor(names[i])
        anchors[names[i]] = true
      }
      _ => ()
    }
  }
  let plan = layout.finish()
  let pages : Array[Json] = []
  let rows : Array[Json] = []
  for i, page in plan.strips {
    pages.push(Json::number(Float::from_double(page.height).to_double()))
    for (index, y) in page.bands {
      rows.push(
        Json::object({
          "index": Json::number(index.to_double()),
          "page": Json::number((i + 1).to_double()),
          "y": Json::number(y),
        }),
      )
    }
  }
  let resolved : Map[String, Json] = Map([])
  if rows.length() > 0 {
    for name in anchors.keys() {
      match plan.anchor_page(name) {
        Some(page) => resolved[name] = Json::number(page.to_double())
        None => ()
      }
    }
  }
  Json::object({
    "pages": Json::array(pages),
    "rows": Json::array(rows),
    "anchors": Json::object(resolved),
  }).stringify()
}

///|
#export_name("prepare_outlines")
pub fn prepare_outlines(data : Bytes, index : Int32) -> @font.SpecimenOutlines {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return face.outlines()
    }
  }
  abort("missing font face")
}

///|
#export_name("specimen_path")
pub fn specimen_path(outlines : @font.SpecimenOutlines, glyph : Int32) -> Bytes {
  match outlines.path(glyph) {
    None => b""
    Some(path) => try! @core.encode_path_collection([path])
  }
}

///|
pub struct PainterFixture {
  object : @core.ObjectBuilder
  painter : @font.OutlinePainter
}

///|
#export_name("prepare_painter")
pub fn prepare_painter(data : Bytes, index : Int32) -> PainterFixture {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let object = @core.ObjectBuilder::new()
      object.set_bbox(0.0F, 0.0F, 720.0F, 1024.0F)
      return { object, painter: face.outline_painter(object), }
    }
  }
  abort("missing font face")
}

///|
#export_name("paint_glyphs")
pub fn paint_glyphs(
  f : PainterFixture,
  glyphs : Array[Int32],
  offsets : Array[Double],
  x : Double,
  y : Double,
  size : Double,
  alt : String,
) -> Unit {
  ignore(try! f.painter.draw(glyphs, offsets, x, y, size, alt))
}

///|
#export_name("painter_object")
pub fn painter_object(f : PainterFixture) -> Bytes {
  try! f.object.encode()
}

///|
pub struct GlyphPainterFixture {
  object : @core.ObjectBuilder
  painter : @font.GlyphPainter
}

///|
#export_name("prepare_glyph_painter")
pub fn prepare_glyph_painter(
  data : Bytes,
  index : Int32,
) -> GlyphPainterFixture {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let object = @core.ObjectBuilder::new()
      object.set_bbox(0.0F, 0.0F, 720.0F, 1024.0F)
      let embedded : @core.Font = {
        hash: Some("00000000000000000000000000000000"),
        family: "",
        weight: 400,
        style: 0,
      }
      return {
        object,
        painter: face.glyph_painter(object, embedded=Some(embedded)),
      }
    }
  }
  abort("missing font face")
}

///|
#export_name("paint_embedded_glyphs")
pub fn paint_embedded_glyphs(
  f : GlyphPainterFixture,
  glyphs : Array[Int32],
  offsets : Array[Double],
  x : Double,
  y : Double,
  size : Double,
  alt : String,
) -> Unit {
  ignore(try! f.painter.draw(glyphs, offsets, x, y, size, alt))
}

///|
#export_name("glyph_painter_object")
pub fn glyph_painter_object(f : GlyphPainterFixture) -> Bytes {
  try! f.object.encode()
}

///|
#export_name("prepare_sample_painter")
pub fn prepare_sample_painter(
  data : Bytes,
  index : Int32,
  mode : Int32,
  doc_language : String,
) -> GlyphPainterFixture {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let object = @core.ObjectBuilder::new()
      object.set_bbox(0.0F, 0.0F, 720.0F, 1024.0F)
      let glyph : @core.Font = {
        hash: Some("00000000000000000000000000000000"),
        family: "",
        weight: 400,
        style: 0,
      }
      let sample : @core.Font = {
        hash: Some(
          if mode == 4 {
            "00000000000000000000000000000000"
          } else {
            "01000000000000000000000000000000"
          },
        ),
        family: "",
        weight: 400,
        style: 0,
      }
      return {
        object,
        painter: face.glyph_painter(
          object,
          embedded=if mode == 1 || mode >= 3 { Some(glyph) } else { None },
          sample_font=if mode >= 2 { Some(sample) } else { None },
          doc_language~,
        ),
      }
    }
  }
  abort("missing font face")
}

///|
#export_name("paint_sample")
pub fn paint_sample(
  f : GlyphPainterFixture,
  text : String,
  x : Double,
  y : Double,
  size : Double,
  rtl : Bool,
  lang : String,
) -> Unit {
  ignore(try! f.painter.sample(text, x, y, size, rtl, lang))
}

///|
#export_name("prepare_programs")
pub fn prepare_programs(
  data : Bytes,
  selection : String,
  text : String,
  ignore_restrictions : Bool,
) -> String {
  let file = try! @font.load(data)
  let doc = @core.DocumentWriter::new()
  let result = try! file.prepare_programs(
    doc,
    selection,
    text,
    ignore_restrictions~,
  )
  Json::object({
    "faces": Json::array(
      result.faces.map(face => {
        Json::object({
          "index": Json::number(face.face_index.to_double()),
          "glyph": match face.glyph_font {
            Some(font) => Json::string(font.hash.unwrap())
            None => Json::null()
          },
          "sample": match face.sample_font {
            Some(font) => Json::string(font.hash.unwrap())
            None => Json::null()
          },
          "outlined": Json::boolean(face.outlined),
        })
      }),
    ),
    "warnings": Json::array(result.warnings.map(Json::string)),
    "fontParts": Json::number(result.font_parts.to_double()),
    "outlined": Json::number(result.outlined.to_double()),
  }).stringify()
}

///|
#export_name("document_plan")
pub fn document_plan(
  data : Bytes,
  selection : String,
  title : String,
) -> String {
  let file = try! @font.load(data)
  let plan = try! file.document_plan(selection, title)
  let meta = plan.metadata
  Json::object({
    "metadata": Json::object({
      "source": Json::string(meta.source),
      "type": Json::string(meta.type_name),
      "title": Json::string(meta.title),
      "creator": Json::string(meta.creator),
      "rights": Json::string(meta.rights),
      "description": Json::string(meta.description),
      "created": Json::string(meta.created),
      "modified": Json::string(meta.modified),
    }),
    "views": Json::array(
      plan.views.map(v => {
        Json::object({
          "id": Json::string(v.id),
          "title": Json::string(v.title),
        })
      }),
    ),
  }).stringify()
}

///|
pub struct TexterFixture {
  db : @db.Database
  texter : @font.SpecimenTexter
}

///|
#export_name("new_texter")
pub fn new_texter() -> TexterFixture {
  let db = @db.Database::new()
  { db, texter: @font.SpecimenTexter::new(db), }
}

///|
#export_name("texter_add_font")
pub fn texter_add_font(f : TexterFixture, path : String, data : Bytes) -> Unit {
  ignore(f.db.add_file(path, data))
}

///|
#export_name("measure_text")
pub fn measure_text(
  f : TexterFixture,
  text : String,
  size : Double,
  bold : Bool,
  max_width : Double,
) -> String {
  let line = f.texter.line(text, size, bold)
  let runs = line.runs.map(r => {
    let face = match r.choice.resolved.face {
      Some(id) => f.db.face(id)
      None => None
    }
    Json::object({
      "text": Json::string(r.text),
      "lang": Json::string(r.lang),
      "x": Json::number(r.x),
      "width": Json::number(r.width),
      "face": match face {
        Some(entry) => Json::string(entry.path)
        None => Json::null()
      },
      "index": Json::number(
        (match face {
          Some(entry) => entry.index
          None => -1
        }).to_double(),
      ),
      "requested": Json::string(r.choice.requested),
      "generic": Json::string(r.choice.resolved.generic),
      "bold": Json::boolean(r.choice.bold),
      "italic": Json::boolean(r.choice.italic),
      "synthBold": Json::boolean(r.choice.resolved.synth_bold),
      "synthItalic": Json::boolean(r.choice.resolved.synth_italic),
    })
  })
  Json::object({
    "width": Json::number(line.width),
    "runs": Json::array(runs),
    "fit": Json::string(f.texter.fit(text, size, bold, max_width)),
    "wrap": Json::array(
      f.texter.wrap(text, size, bold, max_width).map(Json::string),
    ),
  }).stringify()
}

///|
#export_name("texter_usage")
pub fn texter_usage(f : TexterFixture) -> String {
  let (faces, missing) = f.texter.usage()
  Json::object({
    "used": Json::array(
      faces.map(usage => {
        let face = f.db.face(usage.face).unwrap()
        Json::object({
          "path": Json::string(face.path),
          "index": Json::number(face.index.to_double()),
          "codes": Json::array(
            usage.codepoints.map(c => Json::number(c.to_double())),
          ),
        })
      }),
    ),
    "missing": Json::array(missing.map(c => Json::number(c.to_double()))),
  }).stringify()
}

///|
pub struct UIFontFixture {
  texter : TexterFixture
  fonts : @font.SpecimenUIFonts
}

///|
#export_name("finish_ui_fonts")
pub fn finish_ui_fonts(
  f : TexterFixture,
  system : Bool,
  no_subset : Bool,
  ignore_restrictions : Bool,
) -> UIFontFixture {
  let doc = @core.DocumentWriter::new()
  let fonts : @font.SpecimenUIFonts = if system {
    { hashes: Map([]), warnings: [], }
  } else {
    try! f.texter.embed(doc, no_subset~, ignore_restrictions~)
  }
  { texter: f, fonts, }
}

///|
#export_name("ui_font_summary")
pub fn ui_font_summary(f : UIFontFixture) -> String {
  Json::object({
    "parts": Json::number(f.fonts.hashes.length().to_double()),
    "warnings": Json::array(f.fonts.warnings.map(Json::string)),
  }).stringify()
}

///|
#export_name("ui_font_records")
pub fn ui_font_records(
  f : UIFontFixture,
  text : String,
  size : Double,
  bold : Bool,
) -> String {
  let line = f.texter.texter.line(text, size, bold)
  Json::array(
    line.runs.map(r => {
      let font = f.texter.texter.font_record(r.choice, f.fonts)
      Json::object({
        "hash": match font.hash {
          Some(hash) => Json::string(hash)
          None => Json::null()
        },
        "family": Json::string(font.family),
        "weight": Json::number(font.weight.to_double()),
        "style": Json::number(font.style.to_double()),
      })
    }),
  ).stringify()
}

///|
#export_name("record_ui_text")
pub fn record_ui_text(
  f : TexterFixture,
  text : String,
  size : Double,
  bold : Bool,
) -> Unit {
  ignore(f.texter.line(text, size, bold))
}

///|
pub struct UIPainterFixture {
  object : @core.ObjectBuilder
  glyphs : @font.GlyphPainter
  ui : @font.SpecimenUIPainter
  texter : @font.SpecimenTexter
}

///|
#export_name("prepare_ui_painter")
pub fn prepare_ui_painter(
  data : Bytes,
  doc_language : String,
  glyph_hash : String,
  sample_hash : String,
  font_set : UIFontFixture,
) -> UIPainterFixture {
  let file = try! @font.load(data)
  let face = file.faces()[0]
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 720.0F, 1024.0F)
  let glyph : @core.Font = {
    hash: Some(glyph_hash),
    family: "",
    weight: 400,
    style: 0,
  }
  let sample : @core.Font = {
    hash: Some(sample_hash),
    family: "",
    weight: 400,
    style: 0,
  }
  let glyphs = face.glyph_painter(
    object,
    embedded=Some(glyph),
    sample_font=Some(sample),
    doc_language~,
  )
  let texter = font_set.texter.texter
  let ui = @font.SpecimenUIPainter::new(glyphs, texter, font_set.fonts)
  { object, glyphs, ui, texter, }
}

///|
#export_name("paint_ui_label")
pub fn paint_ui_label(
  f : UIPainterFixture,
  text : String,
  x : Double,
  y : Double,
  size : Double,
  bold : Bool,
  color : UInt32,
  align : Int32,
) -> Unit {
  let line = f.texter.line(text, size, bold)
  ignore(try! f.ui.label(line, x, y, color, align))
}

///|
#export_name("paint_ui_sample")
pub fn paint_ui_sample(f : UIPainterFixture, rtl : Bool) -> Unit {
  ignore(try! f.glyphs.sample("Sample あ", 200.0, 300.0, 18.0, rtl, "ja"))
}

///|
#export_name("paint_ui_glyphs")
pub fn paint_ui_glyphs(f : UIPainterFixture, advance : Double) -> Unit {
  ignore(try! f.glyphs.draw([1, 2], [0.0, advance], 100.0, 130.0, 16.0, "alt"))
}

///|
#export_name("ui_painter_object")
pub fn ui_painter_object(f : UIPainterFixture) -> Bytes {
  try! f.object.encode()
}

///|
pub struct PageBatchFixture {
  face : @font.FileFace
  programs : @font.SpecimenFacePrograms
  texter : @font.SpecimenTexter
  fonts : @font.SpecimenUIFonts
  plan : @font.ScrollPlan
}

///|
#export_name("prepare_page_batch")
pub fn prepare_page_batch(
  data : Bytes,
  glyph_hash : String,
  sample_hash : String,
  fonts : UIFontFixture,
  heights : Array[Double],
  spaces : Array[Double],
  keep : Array[Bool],
  anchors : Array[String],
) -> PageBatchFixture {
  let face = (try! @font.load(data)).faces()[0]
  let glyph : @core.Font = {
    hash: Some(glyph_hash),
    family: "",
    weight: 400,
    style: 0,
  }
  let sample : @core.Font = {
    hash: Some(sample_hash),
    family: "",
    weight: 400,
    style: 0,
  }
  let programs : @font.SpecimenFacePrograms = {
    face_index: face.index,
    glyph_font: Some(glyph),
    sample_font: Some(sample),
    sample: face.sample_plan(""),
    outlined: false,
  }
  let scroll = @font.ScrollLayout::new()
  for i in 0..<heights.length() {
    scroll.space(spaces[i])
    if anchors[i] != "" {
      scroll.anchor(anchors[i])
    }
    scroll.add(heights[i], keep=keep[i])
  }
  {
    face,
    programs,
    texter: fonts.texter.texter,
    fonts: fonts.fonts,
    plan: scroll.finish(),
  }
}

///|
#export_name("page_batch_layout")
pub fn page_batch_layout(f : PageBatchFixture) -> String {
  Json::array(
    f.plan.strips.map(strip => {
      Json::object({
        "height": Json::number(specimen_float(strip.height)),
        "bands": Json::array(
          strip.bands.map(pair => {
            Json::array([Json::number(pair.0.to_double()), Json::number(pair.1)])
          }),
        ),
      })
    }),
  ).stringify()
}

///|
fn specimen_float(n : Double) -> Double {
  Float::from_double(n).to_double()
}

///|
#export_name("begin_specimen_page")
pub fn begin_specimen_page(
  f : PageBatchFixture,
  index : Int32,
) -> @font.SpecimenPagePainter {
  try! @font.SpecimenPagePainter::new(
    f.face,
    f.programs,
    f.texter,
    f.fonts,
    f.plan,
    f.plan.strips[index].height,
  )
}

///|
#export_name("paint_page_band")
pub fn paint_page_band(
  f : PageBatchFixture,
  page : @font.SpecimenPagePainter,
  y : Double,
  text : String,
  bold : Bool,
  color : UInt32,
  target : String,
  advance : Double,
) -> Unit {
  page.rect(36.0, y + 2.0, 200.0, 4.0, color)
  page.mark(0, "")
  let line = f.texter.line(text, 11.0, bold)
  ignore(try! page.label(line, 36.0, y + 18.0, color, 0))
  page.link_to(36.0, y, 30.0, 20.0, target)
  page.save()
  page.clip_rect(36.0, y, 300.0, 30.0)
  ignore(try! page.sample("Aあ", 40.0, y + 24.0, 12.0, false, "ja"))
  page.restore()
  ignore(
    try! page.glyph_run([1, 2], [0.0, advance], 360.0, y + 25.0, 13.0, "alt"),
  )
}

///|
#export_name("specimen_page_object")
pub fn specimen_page_object(page : @font.SpecimenPagePainter) -> Bytes {
  try! page.encode()
}

///|
pub struct GlyphViewFixture {
  pages : Array[@font.SpecimenRenderedPage]
}

///|
#export_name("render_glyph_view")
pub fn render_glyph_view(
  data : Bytes,
  index : Int32,
  ui_font : Bytes,
  system : Bool,
  outlined : Bool,
  glyph_hash : String,
) -> GlyphViewFixture {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let db = @db.Database::new()
      if ui_font.length() > 0 {
        ignore(db.add_file("stix.ttf", ui_font))
      }
      let texter = @font.SpecimenTexter::new(db)
      let view = face.glyph_view(texter)
      let ui_fonts : @font.SpecimenUIFonts = if system {
        { hashes: Map::new(), warnings: [], }
      } else {
        try! texter.embed(@core.DocumentWriter::new())
      }
      let glyph : @core.Font? = if outlined {
        None
      } else {
        Some({ hash: Some(glyph_hash), family: "", weight: 400, style: 0, })
      }
      let programs : @font.SpecimenFacePrograms = {
        face_index: face.index,
        glyph_font: glyph,
        sample_font: None,
        sample: face.sample_plan(""),
        outlined,
      }
      return { pages: try! view.render(programs, ui_fonts), }
    }
  }
  abort("missing font face")
}

///|
#export_name("glyph_view_count")
pub fn glyph_view_count(f : GlyphViewFixture) -> Int32 {
  f.pages.length()
}

///|
#export_name("glyph_view_height")
pub fn glyph_view_height(f : GlyphViewFixture, index : Int32) -> Double {
  specimen_float(f.pages[index].height)
}

///|
#export_name("glyph_view_object")
pub fn glyph_view_object(f : GlyphViewFixture, index : Int32) -> Bytes {
  f.pages[index].object
}

///|
#export_name("begin_chart_cells")
pub fn begin_chart_cells(
  data : Bytes,
  index : Int32,
  hash : String,
  outlined : Bool,
  height : Double,
) -> @font.SpecimenPagePainter {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let db = @db.Database::new()
      let texter = @font.SpecimenTexter::new(db)
      let fonts : @font.SpecimenUIFonts = { hashes: Map::new(), warnings: [], }
      let glyph : @core.Font? = if outlined {
        None
      } else {
        Some({ hash: Some(hash), family: "", weight: 400, style: 0, })
      }
      let programs : @font.SpecimenFacePrograms = {
        face_index: face.index,
        glyph_font: glyph,
        sample_font: None,
        sample: face.sample_plan(""),
        outlined,
      }
      let scroll = @font.ScrollLayout::new().finish()
      return try! @font.SpecimenPagePainter::new(
        face, programs, texter, fonts, scroll, height,
      )
    }
  }
  abort("missing font face")
}

///|
#export_name("paint_chart_cell")
pub fn paint_chart_cell(
  page : @font.SpecimenPagePainter,
  glyph : Int32,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  alt : String,
) -> Unit {
  ignore(try! page.cell_glyph(glyph, x, y, width, height, alt))
}

///|
#export_name("render_character_view")
pub fn render_character_view(
  data : Bytes,
  index : Int32,
  ui_font : Bytes,
  system : Bool,
  outlined : Bool,
  glyph_hash : String,
) -> GlyphViewFixture {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      let db = @db.Database::new()
      if ui_font.length() > 0 {
        ignore(db.add_file("stix.ttf", ui_font))
      }
      let texter = @font.SpecimenTexter::new(db)
      let view = face.character_view(texter)
      let ui_fonts : @font.SpecimenUIFonts = if system {
        { hashes: Map::new(), warnings: [], }
      } else {
        try! texter.embed(@core.DocumentWriter::new())
      }
      let glyph : @core.Font? = if outlined {
        None
      } else {
        Some({ hash: Some(glyph_hash), family: "", weight: 400, style: 0, })
      }
      let programs : @font.SpecimenFacePrograms = {
        face_index: face.index,
        glyph_font: glyph,
        sample_font: None,
        sample: face.sample_plan(""),
        outlined,
      }
      return { pages: try! view.render(programs, ui_fonts), }
    }
  }
  abort("missing font face")
}

///|
pub struct FeaturePlannerFixture {
  planner : @font.SpecimenFeaturePlanner
  groups : Array[@font.FeatureGroup]
}

///|
#export_name("new_feature_planner")
pub fn new_feature_planner(
  data : Bytes,
  index : Int32,
) -> FeaturePlannerFixture {
  let file = try! @font.load(data)
  for face in file.faces() {
    if face.index == index {
      return { planner: face.feature_planner(), groups: face.feature_groups(), }
    }
  }
  abort("missing font face")
}

///|
fn placed_json(p : @font.FeaturePlacedGlyph) -> Json {
  Json::object({
    "glyph": Json::number(p.glyph.to_double()),
    "x": Json::number(p.x),
    "y": Json::number(p.y),
  })
}

///|
#export_name("gsub_feature_examples")
pub fn gsub_feature_examples(
  f : FeaturePlannerFixture,
  index : Int32,
  limit : Int32,
) -> String {
  let examples = f.planner.gsub_examples(f.groups[index], limit)
  Json::object({
    "group": Json::number(index.to_double()),
    "total": Json::number(examples.total.to_double()),
    "items": Json::array(
      examples.items.map(it => {
        Json::object({
          "before": Json::array(it.before.map(placed_json)),
          "after": Json::array(it.after.map(placed_json)),
          "beforeWidth": Json::number(it.before_width),
          "afterWidth": Json::number(it.after_width),
          "alternatives": Json::boolean(it.alternatives),
          "boxes": Json::boolean(it.boxes),
          "beforeAdvance": Json::number(it.before_advance),
          "afterAdvance": Json::number(it.after_advance),
          "offset": Json::number(it.offset),
          "note": Json::string(it.note),
        })
      }),
    ),
  }).stringify()
}
