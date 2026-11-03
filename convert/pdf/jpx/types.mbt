///|
pub(all) struct ImageData {
  width : Int
  height : Int
  num_components : Int
  bits_per_component : Int
  is_signed : Bool
  data : Bytes
} derive(Eq, Show)

///|
pub(all) suberror DecodeError {
  InvalidCodestream(String)
  UnsupportedFeature(String)
  DecodeFailed(String)
} derive(Show)

///|
struct DecodeSamplesResult {
  width : Int
  height : Int
  num_components : Int
  bits_per_component : Int
  is_signed : Bool
  sample_layout : String
  samples : Bytes
}
