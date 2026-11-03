///|
fn sample_codestream_minimal() -> Array[Int] {
  @core.sample_codestream_minimal()
}

///|
fn sample_codestream_with_com() -> Array[Int] {
  @core.sample_codestream_with_com()
}

///|
fn sample_codestream_with_coc_qcc() -> Array[Int] {
  @core.sample_codestream_with_coc_qcc()
}

///|
fn sample_codestream_with_poc() -> Array[Int] {
  @core.sample_codestream_with_poc()
}

///|
fn sample_codestream_with_ppt_sop_eph() -> Array[Int] {
  @core.sample_codestream_with_ppt_sop_eph()
}

///|
fn sample_codestream_two_tileparts() -> Array[Int] {
  @core.sample_codestream_two_tileparts()
}

///|
fn sample_codestream_with_plm_plt() -> Array[Int] {
  @core.sample_codestream_with_plm_plt()
}

///|
fn sample_codestream_with_tlm() -> Array[Int] {
  @core.sample_codestream_with_tlm()
}

///|
fn sample_codestream_with_ppm() -> Array[Int] {
  @core.sample_codestream_with_ppm()
}

///|
fn sample_codestream_by_name(name : String) -> Array[Int]? {
  @core.sample_codestream_by_name(name)
}

///|
fn sample_codestream_bytes_by_name(name : String) -> Bytes? {
  match @core.sample_codestream_by_name(name) {
    Some(data) => Some(@bytes.int_array_to_bytes(data))
    None => None
  }
}

///|
fn sample_codestream_names() -> Array[String] {
  @core.sample_codestream_names()
}
