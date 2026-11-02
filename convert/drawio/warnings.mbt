///|
/// Warnings collected while converting a document. Each key is reported
/// once per document, like draw.io's `mxLog` and the upstream converter's
/// `warnOnce`.
priv struct DrawioWarn {
  items : Array[String]
  seen : Map[String, Bool]
}

///|
fn DrawioWarn::new() -> DrawioWarn {
  { items: [], seen: Map([]) }
}

///|
fn DrawioWarn::once(self : DrawioWarn, key : String, message : String) -> Unit {
  if self.seen.contains(key) {
    return
  }
  self.seen[key] = true
  self.items.push(message)
}
