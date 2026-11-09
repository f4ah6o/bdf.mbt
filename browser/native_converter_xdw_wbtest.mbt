///|
/// A request shaped like the one the worker receives.
extern "js" fn xdw_test_request(params_json : String) -> ConverterRequest =
  #|(json) => ({ id: 1, type: "convert", options: { params: JSON.parse(json) } })

///|
/// Capture what the worker posts, in place of the real `self`.
extern "js" fn xdw_test_capture_start() -> Unit =
  #|() => { globalThis.__xdwPosted = []; globalThis.self = { postMessage: (m) => { globalThis.__xdwPosted.push(m); } }; }

///|
/// The posted messages, without the converted bytes.
extern "js" fn xdw_test_capture_take() -> String =
  #|() => JSON.stringify((globalThis.__xdwPosted ?? []).map(m => ({ ok: m.ok, format: m.result?.format, error: m.error })))

///|
extern "js" fn xdw_test_capture_stop() -> Unit =
  #|() => { delete globalThis.self; delete globalThis.__xdwPosted; }

///|
/// A real DocuWorks sample with one text annotation.
let xdw_test_sample : String = "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"

///|
fn xdw_test_bytes() -> Bytes {
  @base64.decode(xdw_test_sample) catch {
    _ => abort("the sample is not valid base64")
  }
}

///|
fn xdw_test_options(params_json : String) -> Bool {
  let options = native_xdw_options(xdw_test_request(params_json)) catch {
    e => abort("parse failed: " + e.to_string())
  }
  options.include_hidden
}

///|
fn xdw_test_options_error(params_json : String) -> String {
  try {
    ignore(native_xdw_options(xdw_test_request(params_json)))
    ""
  } catch {
    e => e.to_string()
  }
}

///|
test "a request without include_hidden keeps covered text out" {
  assert_eq(xdw_test_options("{}"), false)
  assert_eq(xdw_test_options("{\"include_hidden\":\"\"}"), false)
  assert_eq(xdw_test_options("{\"include_hidden\":\"0\"}"), false)
}

///|
test "include_hidden=1 reaches the converter options" {
  assert_eq(xdw_test_options("{\"include_hidden\":\"1\"}"), true)
  // The worker reads numbers and booleans as their string form.
  assert_eq(xdw_test_options("{\"include_hidden\":1}"), true)
  assert_eq(xdw_test_options("{\"include_hidden\":true}"), true)
}

///|
test "an invalid include_hidden is reported, not silently defaulted" {
  let message = xdw_test_options_error("{\"include_hidden\":\"bogus\"}")
  assert_true(message.contains("include_hidden"))
}

///|
test "the xdw request entry reports an invalid include_hidden" {
  xdw_test_capture_start()
  native_convert_xdw(
    xdw_test_request("{\"include_hidden\":\"bogus\"}"),
    b"",
    false,
  )
  let posted = xdw_test_capture_take()
  xdw_test_capture_stop()
  assert_true(posted.contains("\"ok\":false"))
  assert_true(posted.contains("include_hidden"))
}

///|
test "the xdw request entry converts with include_hidden=1" {
  xdw_test_capture_start()
  native_convert_xdw(
    xdw_test_request("{\"include_hidden\":\"1\"}"),
    xdw_test_bytes(),
    false,
  )
  let posted = xdw_test_capture_take()
  xdw_test_capture_stop()
  assert_true(posted.contains("\"ok\":true"))
  assert_true(posted.contains("\"format\":\"xdw\""))
}

///|
test "the xdw request entry converts with the default options" {
  xdw_test_capture_start()
  native_convert_xdw(xdw_test_request("{}"), xdw_test_bytes(), false)
  let posted = xdw_test_capture_take()
  xdw_test_capture_stop()
  assert_true(posted.contains("\"ok\":true"))
  assert_true(posted.contains("\"format\":\"xdw\""))
}
