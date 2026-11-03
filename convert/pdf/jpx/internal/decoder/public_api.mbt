///|
// Spec basis (T.800-2015 Annex A/B):
// - public decode entrypoint exposes codestream parse/decode contract
//   aligned with marker and packet model.
pub fn decode_samples(data : Bytes) -> Result[@orchestrate.DecodeSamplesResult, String] {
  let decoded = @orchestrate.decode_samples_impl(data)
  if decoded is Ok(result) {
    return Ok(@orchestrate.decode_samples_from_internal(result))
  }
  if decoded is Err(msg) {
    return Err(msg)
  }
  Err("decode_samples failed")
}

///|
// Diagnostic entrypoint for packet-order/header/body audit logs.
pub fn decode_samples_audit(
  data : Bytes,
  packet_audit_limit? : Int = 300,
  force_relocated_ppt? : Bool = false,
) -> Result[@orchestrate.DecodeSamplesResult, String] {
  let decoded = @orchestrate.decode_samples_impl(
    data,
    packet_audit=true,
    packet_audit_limit~,
    force_relocated_ppt~,
  )
  if decoded is Ok(result) {
    return Ok(@orchestrate.decode_samples_from_internal(result))
  }
  if decoded is Err(msg) {
    return Err(msg)
  }
  Err("decode_samples_audit failed")
}

///|
pub fn decode_samples_all_components_debug(
  data : Bytes,
) -> Result[@orchestrate.DecodeAllComponentsResult, String] {
  let decoded = @orchestrate.decode_samples_all_components(data)
  if decoded is Ok(result) {
    return Ok(result)
  }
  if decoded is Err(msg) {
    return Err(msg)
  }
  Err("decode_samples_all_components_debug failed")
}

///|
pub fn decode_samples_all_components_audit(
  data : Bytes,
  packet_audit_limit? : Int = 300,
) -> Result[@orchestrate.DecodeAllComponentsResult, String] {
  let decoded = @orchestrate.decode_samples_all_components_impl(
    data,
    packet_audit=true,
    packet_audit_limit~,
  )
  if decoded is Ok(result) {
    return Ok(result)
  }
  if decoded is Err(msg) {
    return Err(msg)
  }
  Err("decode_samples_all_components_audit failed")
}
