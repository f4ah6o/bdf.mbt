///|
#export_name("fixture")
pub fn fixture() -> Bytes {
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
  try! writer.write_single()
}

///|
#export_name("fixture_for_part")
pub fn fixture_for_part(data : Bytes) -> Bytes {
  let writer = @core.DocumentWriter::new()
  ignore(try! writer.add_part("obj", data))
  try! writer.write_single()
}
