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

///|
pub struct EncodeResult {
  data : Bytes
  error : String
}

///|
#export_name("encode_woff2")
pub fn encode_woff2(data : Bytes) -> EncodeResult {
  { data: @woff2.encode(data), error: "", } catch {
    @woff2.Woff2Failure(message) => { data: b"", error: message, }
    error => { data: b"", error: error.to_string(), }
  }
}

///|
#export_name("encode_bytes")
pub fn encode_bytes(result : EncodeResult) -> Bytes {
  result.data
}

///|
#export_name("encode_error")
pub fn encode_error(result : EncodeResult) -> String {
  result.error
}
