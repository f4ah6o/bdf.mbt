///|
/// A DocuWorks (`.xdw`) conversion failure.
pub suberror XdwError {
  /// Not a DocuWorks file.
  XdwNotFile(String)
  /// Damaged or inconsistent data.
  XdwCorrupt(String)
  /// Past one of the safety limits: too large or damaged.
  XdwTooLarge(String)
  /// The document is protected (password or certificate); its entries and
  /// properties are encrypted.
  XdwProtected
} derive(Show)

///|
fn XdwError::to_string(self : XdwError) -> String {
  match self {
    XdwNotFile(s) => "not a DocuWorks file: " + s
    XdwCorrupt(s) => "damaged file: " + s
    XdwTooLarge(s) => "too large or damaged: " + s
    XdwProtected =>
      "protected: the document is encrypted (password or certificate); remove the protection in DocuWorks first"
  }
}
