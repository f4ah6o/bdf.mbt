///|
#export_name("zip_read")
pub fn zip_read(data : Bytes) -> String {
  try {
    let archive = @zip.open_zip(data)
    let entries = archive.entries.map(fn(entry) {
      let content = Some(archive.read(entry, 1048576)) catch { _ => None }
      Json::array([
        Json::string(entry.name),
        Json::number(entry.method.to_double()),
        Json::number(entry.flags.to_double()),
        Json::number(entry.compressed_size.to_double()),
        Json::number(entry.size.to_double()),
        match content {
          None => Json::null()
          Some(b) =>
            Json::array([ for v in b => Json::number(v.to_int().to_double()) ])
        },
      ])
    })
    Json::array(entries).stringify()
  } catch {
    _ => "null"
  }
}
