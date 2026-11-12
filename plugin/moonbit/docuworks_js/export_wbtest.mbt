///|
/// The DocuWorks JS export never raises across the FFI. Detection is the
/// converter's own header check, and an unreadable input becomes an
/// `{"ok":false,"error":...}` envelope whose message is the converter's.

///|
/// 24 zero bytes after the header: long enough for the header check.
fn detectable_header() -> Bytes {
  b"\x60\x03\x80\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
}

///|
fn envelope(text : String) -> Map[String, Json] raise {
  match @json.parse(text) {
    Json::Object(object) => object
    _ => fail("the DocuWorks export did not return an object: " + text)
  }
}

///|
test "bdf_xdw_detect" {
  inspect(bdf_xdw_detect(detectable_header()), content="true")
  inspect(bdf_xdw_detect(b"not a docuworks file"), content="false")
  inspect(bdf_xdw_detect(b""), content="false")
}

///|
test "bdf_xdw_convert: error envelope" {
  let object = envelope(bdf_xdw_convert(b"garbage", false)) catch {
    error => abort("garbage convert should not raise: " + error.to_string())
  }
  match object.get("ok") {
    Some(Json::False) => ()
    _ => abort("the error envelope does not say ok:false")
  }
  match object.get("error") {
    Some(Json::String(_)) => ()
    _ => abort("the error envelope does not carry an error string")
  }
}
