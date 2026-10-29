///|
fn sample_writer() -> @core.DocumentWriter {
  let writer = @core.DocumentWriter::new(
    meta=Json::object({ "source": Json::string("test") }),
  )
  let hash = try! writer.add_part("table", b"abc")
  ignore(try! writer.add_part("obj", Bytes::make(1000, b'a')))
  writer.add_table(
    Json::object({
      "id": Json::string("data"),
      "part": Json::string(hash),
      "rows": Json::number(1.0),
      "columns": Json::array([]),
    }),
  )
  for i in 0..<30 {
    writer.add_view(
      Json::object({
        "id": Json::string("view\{i}"),
        "kind": Json::string("fixed"),
      }),
    )
  }
  writer
}

///|
#export_name("fixture")
pub fn fixture() -> Bytes {
  try! sample_writer().write_single()
}

///|
#export_name("fixture_for_part")
pub fn fixture_for_part(data : Bytes) -> Bytes {
  let writer = @core.DocumentWriter::new()
  ignore(try! writer.add_part("obj", data))
  try! writer.write_single()
}

///|
#export_name("split_manifest")
pub fn split_manifest(data : Bytes) -> Bytes {
  (try! @core.single_to_split(data)).manifest
}

///|
#export_name("split_part")
pub fn split_part(data : Bytes, index : Int32) -> Bytes {
  (try! @core.single_to_split(data)).parts[index].data
}

///|
#export_name("writer_split_manifest")
pub fn writer_split_manifest() -> Bytes {
  (try! sample_writer().write_split()).manifest
}

///|
#export_name("writer_split_part")
pub fn writer_split_part(index : Int32) -> Bytes {
  (try! sample_writer().write_split()).parts[index].data
}

///|
#export_name("join_split")
pub fn join_split(manifest : Bytes, parts : Array[Bytes]) -> Bytes {
  let mut index = 0
  try! @core.split_to_single(manifest, (_, _) => {
    let part = parts[index]
    index += 1
    part
  })
}
