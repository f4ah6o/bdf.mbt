///|
#export_name("ooxml_package")
pub fn ooxml_package(data : Bytes) -> String {
  try {
    let pkg = @ooxml.open_ooxml(data)
    let files : Array[Json] = []
    for
      name in [
        "xl/workbook.xml", "/XL/WORKBOOK.XML", "xl\\workbook.xml", "xl/worksheets/sheet1.xml",
        "hello.txt", "_rels/.rels", "missing",
      ] {
      let size = pkg.part_size(name)
      let (content, error) = match size {
        None => (Json::null(), "")
        Some(_) =>
          try {
            let b = pkg.read(name)
            (
              Json::array(
                [
                  for c in b => Json::number(c.to_int().to_double())
                ],
              ),
              "",
            )
          } catch {
            @ooxml.InvalidOoxml(message) => (Json::null(), message)
          }
      }
      files.push(
        Json::array([
          Json::boolean(pkg.has(name)),
          Json::number(size.unwrap_or(0).to_double()),
          content,
          Json::string(error),
        ]),
      )
    }
    let relationships : Array[Json] = []
    for source in ["", "xl/workbook.xml", "/xl/workbook.xml"] {
      let values = pkg.relationships(source)
      values.sort_by((a, b) => a.id.compare(b.id))
      relationships.push(
        Json::array(
          values.map(r => {
            Json::array([
              Json::string(r.id),
              Json::string(r.kind),
              Json::string(r.target),
              Json::boolean(r.external),
            ])
          }),
        ),
      )
    }
    let selected = [
      for source in ["", "xl/workbook.xml", "/xl/workbook.xml"] => {
        match pkg.relationship_of_type(source, "/theme") {
          None => Json::null()
          Some(r) =>
            Json::array([
              Json::string(r.id),
              Json::string(r.kind),
              Json::string(r.target),
              Json::boolean(r.external),
            ])
        }
      }
    ]
    Json::array([
      Json::array(files),
      Json::array(relationships),
      Json::array(selected),
      Json::boolean(
        @xlsx.detect_xlsx(
          data[:Int32::min(data.length(), 1024)].to_owned(),
          data,
        ),
      ),
    ]).stringify()
  } catch {
    _ => "null"
  }
}
