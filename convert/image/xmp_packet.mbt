///|
fn metadata_xmp(packet : Bytes) -> Map[String, Array[String]] raise {
  if packet.length() == 0 {
    return Map([])
  }
  let utf16 = packet.length() >= 2 &&
    (
      (packet[0] == 0xff && packet[1] == 0xfe) ||
      (packet[0] == 0xfe && packet[1] == 0xff)
    )
  let text = if utf16 {
    "\u{feff}" +
    metadata_utf16_raw(packet[2:].to_bytes(), packet[0] == 0xff, false)
  } else {
    @utf8.decode(packet, ignore_bom=true) catch {
      _ => raise ImageFailure("image: XMP encoding is not yet supported")
    }
  }
  let (root, complete) = xmp_tree_checked(text, utf16~)
  if !complete {
    raise ImageFailure("image: malformed XMP is not yet supported")
  }
  if root is Some(node) {
    xmp_metadata(node)
  } else {
    Map([])
  }
}
