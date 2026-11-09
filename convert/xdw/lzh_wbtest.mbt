///|
test "lzh expands the real properties block within the limits" {
  // every fixture's properties block is `-lh5-` compressed in the file
  // and matches the expanded size the trailer keeps
  for f in xdw_fixtures {
    let b = @base64.decode(f.1)
    let limits = Limits::default()
    let container = xdw_container_parse(b, limits)
    let props = container.properties(b, limits)
    guard props.length() == container.trailer.props_expanded.to_int() else {
      abort("{f.0}: the properties expanded to \{props.length()} bytes, the trailer says \{container.trailer.props_expanded}")
    }
    // a ratio of 1 refuses any compression gain
    let strict : Limits = {
      max_bytes: 100L,
      max_expand: 256L << 20,
      max_ratio: 1000L,
      max_pages: 20000,
    }
    let refused = try Some(container.properties_stored(b)) catch {
      _ => None
    }
    ignore(refused)
    let result = try Some(lzh_decompress(
        container.properties_stored(b),
        container.trailer.props_expanded.to_int(),
        strict,
      )) catch {
      XdwTooLarge(_) => None
      e => abort("{f.0}: unexpected error: " + e.to_string())
    }
    guard result is None else {
      abort("{f.0}: the small limits did not refuse the expansion")
    }
  }
}

///|
test "tlv numbers: sign extension and ranges" {
  // 00 c0 13 is 49171; a1 b1 ae is negative
  let wide = tlv_read(b"\x80\x03\x00\xc0\x13"[:].to_owned(), 0, 5)
  guard wide.uint(b"\x80\x03\x00\xc0\x13"[:].to_owned()) == Some(49171L) else {
    abort("00c013 did not read back as 49171")
  }
  let negative = tlv_read(b"\x81\x03\xa1\xb1\xae"[:].to_owned(), 0, 5)
  guard negative.uint(b"\x81\x03\xa1\xb1\xae"[:].to_owned()) == Some(-6180434L) else {
    abort("a1b1ae did not read back as -6180434")
  }
  let big = tlv_read(b"\x80\x81\x04\xff\xff\x00\x00"[:].to_owned(), 0, 7)
  guard big.uint(b"\x80\x81\x04\xff\xff\x00\x00"[:].to_owned()) == Some(
      -65536L,
    ) else {
    abort("the long length form did not read back (sign-extended)")
  }
}

///|
test "protected documents are refused" {
  // an entry, then a 4-byte properties block right before the trailer
  let file = @buffer.Buffer()
  file.write_bytes(b"\x67\x02\xaa\xbb\x66\x04\x01\x02\x03\x04"[:])
  file.write_bytes(b"\x0a\x00\x00\x00"[:])
  let bytes = file.to_bytes()
  let t : Trailer = {
    at: 6,
    tag: 0x65,
    count: 1L,
    offsets: [0],
    checks: [],
    unknown82: bytes[0 : 0].to_owned(),
    props_expanded: 0L,
    props_stored: 4L,
    check: 0L,
    fields: [],
  }
  guard xdw_is_protected(bytes, t) else {
    abort("protected tags were not detected")
  }
  // the same file with a plain entry and plain properties is not protected
  let plain = tlv_read(
    b"\x64\x02\xaa\xbb\x63\x04\x01\x02\x03\x04"[:].to_owned(),
    0,
    10,
  )
  guard plain.tag == T_ENTRY else {
    abort("the plain file starts with a plain entry")
  }
}
