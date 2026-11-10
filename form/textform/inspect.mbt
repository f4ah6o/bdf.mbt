///|
// The fields of the tags of a text template, with the line and column of
// each tag (converter/textform of upstream).

///|
/// The fields of the tags of a text template, with the line and column of
/// each tag.
pub fn inspect(data : Bytes) -> Array[@tag.Field] raise TextFormError {
  parse_template(data).fields()
}
