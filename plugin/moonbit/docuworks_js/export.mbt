///|
/// The JavaScript export of the DocuWorks converter, for the file format
/// plugin API (`plugin/src/bindings/moonbit.js`).
///
/// The exported functions never raise across the FFI. `bdf_xdw_convert`
/// returns a JSON envelope, following the `form_page` export convention:
/// an `{"ok":false,"error":"..."}` envelope carries the converter's error,
/// and a successful envelope holds the BDF (base64), the page count, the
/// summary and the warnings. The error strings are the converter's own, so
/// the caller sees what `convert/xdw` failed on.

///|
fn json_warnings(values : Array[String]) -> Json {
  Json::array(values.map(Json::string))
}

///|
#export_name("bdf_xdw_detect")
pub fn bdf_xdw_detect(data : Bytes) -> Bool {
  @xdw.xdw_detect(data)
}

///|
#export_name("bdf_xdw_convert")
pub fn bdf_xdw_convert(data : Bytes, include_hidden : Bool) -> String {
  let result = @xdw.xdw_convert(data, include_hidden~) catch {
    error =>
      return Json::object({
        "ok": Json::boolean(false),
        "error": Json::string(error.to_string()),
      }).stringify()
  }
  Json::object({
    "ok": Json::boolean(true),
    "bdf": Json::string(@base64.encode(result.bdf)),
    "pages": Json::number(result.pages.to_double()),
    "summary": Json::string(result.summary),
    "warnings": json_warnings(result.warnings),
  }).stringify()
}
