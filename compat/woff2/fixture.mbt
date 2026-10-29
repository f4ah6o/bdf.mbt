///|
pub struct DecodeResult {
  valid : Bool
  data : Bytes
}

///|
#export_name("decode_woff2")
pub fn decode_woff2(data : Bytes) -> DecodeResult {
  { valid: true, data: @woff2.decode(data), } catch {
    _ => { valid: false, data: b"", }
  }
}

///|
#export_name("decode_valid")
pub fn decode_valid(result : DecodeResult) -> Bool {
  result.valid
}

///|
#export_name("decode_bytes")
pub fn decode_bytes(result : DecodeResult) -> Bytes {
  result.data
}
