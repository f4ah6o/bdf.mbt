///|
/// The pages carried by a segment of a document.
pub(all) struct Segment {
  view : String
  from : Int32
  to : Int32
} derive(Eq, Debug)

///|
/// Read a segment declaration from a manifest, if one is present.
pub fn parse_segment(input : String) -> Segment? raise {
  let root = @json.parse(input) catch {
    _ => raise BadFormat("invalid manifest JSON")
  }
  if root is Object(fields) {
    match fields.get("segment") {
      None | Some(Null) => None
      Some(segment) => {
        let view = required_string(segment, "view")
        let from = checked_size(required_number(segment, "from"), "from")
        let to = checked_size(required_number(segment, "to"), "to")
        Some({ view, from, to, })
      }
    }
  } else {
    raise BadFormat("expected object")
  }
}
