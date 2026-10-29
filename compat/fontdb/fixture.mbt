///|
#export_name("new_database")
pub fn new_database() -> @fontdb.Database {
  @fontdb.Database::new()
}

///|
#export_name("add_file")
pub fn add_file(db : @fontdb.Database, path : String, data : Bytes) -> Int32 {
  db.add_file(path, data)
}

///|
fn describe(db : @fontdb.Database, result : @fontdb.Resolved) -> Json {
  let face = match result.face {
    Some(id) => db.face(id)
    None => None
  }
  let path = match face {
    Some(face) => face.path
    None => ""
  }
  let index = match face {
    Some(face) => face.index
    None => -1
  }
  Json::object({
    "path": Json::string(path),
    "index": Json::number(index.to_double()),
    "bold": Json::boolean(result.synth_bold),
    "italic": Json::boolean(result.synth_italic),
    "exact": Json::boolean(result.exact),
    "generic": Json::string(result.generic),
  })
}

///|
#export_name("resolve")
pub fn resolve(
  db : @fontdb.Database,
  name : String,
  bold : Bool,
  italic : Bool,
  cjk : Bool,
) -> String {
  describe(db, db.resolve(name, bold~, italic~, cjk~)).stringify()
}

///|
#export_name("fallbacks")
pub fn fallbacks(
  db : @fontdb.Database,
  generic : String,
  bold : Bool,
  italic : Bool,
) -> String {
  Json::array(db.fallbacks(generic, bold~, italic~).map(r => describe(db, r))).stringify()
}

///|
#export_name("resolve_math")
pub fn resolve_math(db : @fontdb.Database, name : String) -> String {
  match db.resolve_math(name) {
    Some(id) => db.face(id).unwrap().path
    None => ""
  }
}

///|
#export_name("face_for")
pub fn face_for(
  db : @fontdb.Database,
  latin : String,
  ea : String,
  code : Int32,
  bold : Bool,
) -> String {
  let choice = db.face_for(latin, ea, code, bold~)
  let path = match choice.resolved.face {
    Some(id) => db.face(id).unwrap().path
    None => ""
  }
  Json::object({
    "path": Json::string(path),
    "requested": Json::string(choice.requested),
    "generic": Json::string(choice.resolved.generic),
    "synthBold": Json::boolean(choice.resolved.synth_bold),
    "synthItalic": Json::boolean(choice.resolved.synth_italic),
  }).stringify()
}

///|
#export_name("normalize")
pub fn normalize(name : String) -> String {
  @fontdb.normalize(name)
}

///|
fn csv_result(
  db : @fontdb.Database,
  data : Bytes,
  scenario : Int32,
  mode : Int32,
) -> @csv.NoFontResult raise {
  @csv.convert_with_fonts(
    no_woff2=true,
    data,
    db,
    no_subset=mode == 0,
    system_fonts=mode == 2,
    header=HeaderYes,
    name="People",
    title="Report",
    table_style=if scenario == 3 { "Medium2" } else { "" },
  )
}

///|
#export_name("csv_document")
pub fn csv_document(
  db : @fontdb.Database,
  data : Bytes,
  scenario : Int32,
  mode : Int32,
) -> Bytes {
  (try! csv_result(db, data, scenario, mode)).bdf
}

///|
#export_name("csv_warnings")
pub fn csv_warnings(
  db : @fontdb.Database,
  data : Bytes,
  scenario : Int32,
  mode : Int32,
) -> String {
  Json::array(
    (try! csv_result(db, data, scenario, mode)).warnings.map(w => {
      Json::string(w)
    }),
  ).stringify()
}

///|
fn csv_compressed_result(
  db : @fontdb.Database,
  data : Bytes,
  scenario : Int32,
  mode : Int32,
) -> @csv.NoFontResult raise {
  @csv.convert_with_fonts(
    data,
    db,
    no_subset=mode == 0,
    system_fonts=mode == 2,
    header=HeaderYes,
    name="People",
    title="Report",
    table_style=if scenario == 3 { "Medium2" } else { "" },
  )
}

///|
#export_name("csv_compressed_document")
pub fn csv_compressed_document(
  db : @fontdb.Database,
  data : Bytes,
  scenario : Int32,
  mode : Int32,
) -> Bytes {
  (try! csv_compressed_result(db, data, scenario, mode)).bdf
}

///|
#export_name("csv_compressed_warnings")
pub fn csv_compressed_warnings(
  db : @fontdb.Database,
  data : Bytes,
  scenario : Int32,
  mode : Int32,
) -> String {
  Json::array(
    (try! csv_compressed_result(db, data, scenario, mode)).warnings.map(
      Json::string,
    ),
  ).stringify()
}
