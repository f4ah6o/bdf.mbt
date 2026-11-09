///|
/// The parameters `convert/xdw` accepts.
pub(all) struct Params {
  /// Keep text that a later opaque fill covers completely in the text index.
  include_hidden : Bool
}

///|
/// Read the `include_hidden` parameter. `1`, `true`, `yes` and `on` turn it
/// on; an empty value, `0`, `false`, `no` and `off` leave it off. Anything
/// else is an error rather than a silent default, so a typo cannot quietly
/// change what the index holds.
pub fn parse_params(params : Map[String, String]) -> Params raise XdwError {
  let raw = params.get("include_hidden").unwrap_or("")
  {
    include_hidden: match raw.to_lower() {
      "" | "0" | "f" | "false" | "no" | "off" => false
      "1" | "t" | "true" | "yes" | "on" => true
      _ =>
        raise XdwInvalidParam(
          "xdw: parameter include_hidden: " + raw + " is not 0 or 1",
        )
    },
  }
}
