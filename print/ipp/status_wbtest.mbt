///|
test "ipp status" {
  assert_true(status_is_success(STATUS_OK))
  assert_true(status_is_success(0x00ff))
  assert_true(!status_is_success(STATUS_CLIENT_ERROR_BAD_REQUEST))
  assert_true(status_is_client_error(STATUS_CLIENT_ERROR_FORBIDDEN))
  assert_true(status_is_server_error(STATUS_SERVER_ERROR_INTERNAL))
  assert_eq(status_name(STATUS_OK), "successful-ok")
  assert_eq(status_name(STATUS_CLIENT_ERROR_NOT_FOUND), "client-error-not-found")
  assert_eq(status_name(STATUS_SERVER_ERROR_INTERNAL), "server-error-internal-error")
  let ok = new_response(STATUS_OK, 1, "", "")
  ignore(check_response(ok))
  let bad = new_response(STATUS_CLIENT_ERROR_BAD_REQUEST, 2, "", "")
  bad.add(TAG_OPERATION, [attr("status-message", [text("bad copies")])])
  assert_eq(message_status_text(bad), "bad copies")
  let failed = try {
    check_response(bad)
    false
  } catch {
    StatusError(status, message) => status == STATUS_CLIENT_ERROR_BAD_REQUEST && message == "bad copies"
    _ => false
  }
  assert_true(failed)
  let no_message = new_response(STATUS_SERVER_ERROR_INTERNAL, 3, "", "")
  let failed = try {
    check_response(no_message)
    false
  } catch {
    StatusError(_, message) => message == "server-error-internal-error"
    _ => false
  }
  assert_true(failed)
}
