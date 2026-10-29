///|
/// Dublin Core values taken from the first selected font face.
pub(all) struct SpecimenMetadata {
  source : String
  type_name : String
  title : String
  creator : String
  rights : String
  description : String
  created : String
  modified : String
}

///|
/// A scroll view belonging to a selected face.
pub(all) struct SpecimenView {
  id : String
  title : String
  face_index : Int32
}

///|
/// Document metadata and view identities before specimen pages are drawn.
pub(all) struct SpecimenDocumentPlan {
  metadata : SpecimenMetadata
  views : Array[SpecimenView]
  warnings : Array[String]
}

///|
fn face_has_features(face : FileFace) -> Bool {
  for tag in ["GSUB", "GPOS"] {
    guard face.font.table(tag) is Some(data) else { continue }
    match @otlayout.parse_layout(data[:], gpos=tag == "GPOS") {
      Some(table) if table.features.length() > 0 => return true
      _ => ()
    }
  }
  false
}

///|
/// Plan the upstream specimen's metadata and view names for a selection.
/// The title override is used when nonempty; selection warnings are retained.
pub fn FontFile::document_plan(
  self : FontFile,
  selection : String,
  title : String,
) -> SpecimenDocumentPlan raise {
  let (faces, warnings) = self.select(selection)
  let first = faces[0]
  let names = first.specimen_names()
  let first_title = if faces.length() > 1 {
    names.family()
  } else {
    names.full()
  }
  let creator = if names.best(9) != "" { names.best(9) } else { names.best(8) }
  let head = first.font.table("head").unwrap_or(b"")
  let created = if head.length() >= 54 {
    info_head_time(head[:], 20).1
  } else {
    ""
  }
  let modified = if head.length() >= 54 {
    info_head_time(head[:], 28).1
  } else {
    ""
  }
  let metadata : SpecimenMetadata = {
    source: "font",
    type_name: "Font",
    title: if title != "" {
      title
    } else {
      first_title
    },
    creator,
    rights: names.best(0),
    description: names.best(10),
    created,
    modified,
  }
  let views : Array[SpecimenView] = []
  let several = faces.length() > 1
  for face in faces {
    let suffix = if several { "-" + (face.index + 1).to_string() } else { "" }
    let name = face.specimen_names().full()
    let prefix = if several {
      (if name == "" { "Font " + (face.index + 1).to_string() } else { name }) +
      ": "
    } else {
      ""
    }
    views.push({
      id: "overview" + suffix,
      title: prefix + "Overview",
      face_index: face.index,
    })
    if face.font.characters().length() > 0 {
      views.push({
        id: "characters" + suffix,
        title: prefix + "Characters",
        face_index: face.index,
      })
    }
    views.push({
      id: "glyphs" + suffix,
      title: prefix + "Glyphs",
      face_index: face.index,
    })
    if face_has_features(face) {
      views.push({
        id: "features" + suffix,
        title: prefix + "Features",
        face_index: face.index,
      })
    }
  }
  { metadata, views, warnings, }
}
