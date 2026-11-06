///|
/// A response status that is not a success.
pub suberror StatusError {
  StatusError(Int, String)
}

pub const STATUS_SERVER_ERROR_OPERATION_NOT_SUPPORTED : Int = 0x0501
pub const STATUS_CLIENT_ERROR_NOT_POSSIBLE : Int = 0x040b

///|
pub fn status_is_success(status : Int) -> Bool {
  status >= 0x0000 && status <= 0x00ff
}

///|
pub fn status_is_client_error(status : Int) -> Bool {
  status >= 0x0400 && status <= 0x04ff
}

///|
pub fn status_is_server_error(status : Int) -> Bool {
  status >= 0x0500 && status <= 0x05ff
}

///|
pub fn status_name(status : Int) -> String {
  if status == STATUS_OK {
    "successful-ok"
  } else if status == STATUS_OK_IGNORED_OR_SUBSTITUTED {
    "successful-ok-ignored-or-substituted-attributes"
  } else if status == STATUS_CLIENT_ERROR_BAD_REQUEST {
    "client-error-bad-request"
  } else if status == STATUS_CLIENT_ERROR_FORBIDDEN {
    "client-error-forbidden"
  } else if status == STATUS_CLIENT_ERROR_NOT_FOUND {
    "client-error-not-found"
  } else if status == STATUS_SERVER_ERROR_INTERNAL {
    "server-error-internal-error"
  } else if status_is_client_error(status) {
    "client-error-0x" + status.to_string()
  } else if status_is_server_error(status) {
    "server-error-0x" + status.to_string()
  } else {
    "status-0x" + status.to_string()
  }
}

///|
/// The status-message of a response, or "".
pub fn message_status_text(message : Message) -> String {
  match message.attr(TAG_OPERATION, "status-message") {
    Some(attribute) => attribute.text()
    None => ""
  }
}

///|
/// Raise StatusError when a response is not a success.
pub fn check_response(message : Message) -> Unit raise StatusError {
  if !status_is_success(message.code) {
    let text = message_status_text(message)
    raise StatusError(
      message.code,
      if text == "" { status_name(message.code) } else { text },
    )
  }
}
