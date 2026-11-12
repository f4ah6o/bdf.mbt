///|
/// xdw_expanded_size on its own: when is stored data compressed, and to
/// what size. The kind 4 numbers are the viewer-accepted repro: an
/// expanded size of 892 for 935 stored bytes.
test "expanded size: an entry larger than stored is compressed" {
  // the flag is absent and the expanded size beats the stored size
  guard xdw_expanded_size(None, None, Some(1000L), 500) == Some(1000) else {
    abort("a larger expanded size should mean compressed")
  }
  // the flag says compressed without any gain
  guard xdw_expanded_size(None, Some(1L), Some(1000L), 500) == Some(1000) else {
    abort("flag 0x8a = 1 should expand to the given size")
  }
}

///|
test "expanded size: a kind 4 smaller than stored is compressed" {
  // the viewer-accepted repro: 892 expanded, 935 stored, no flag
  guard xdw_expanded_size(Some(4L), None, Some(892L), 935) == Some(892) else {
    abort("kind 4 smaller than stored should still expand")
  }
}

///|
test "expanded size: a size equal to stored is raw" {
  guard xdw_expanded_size(None, None, Some(500L), 500) is None else {
    abort("an equal size is not compressed")
  }
  guard xdw_expanded_size(Some(4L), None, Some(935L), 935) is None else {
    abort("an equal size is not compressed, kind 4 included")
  }
}

///|
test "expanded size: kind 7 never expands without the flag" {
  guard xdw_expanded_size(Some(7L), None, Some(892L), 935) is None else {
    abort("kind 7 sizes are not expanded sizes")
  }
  guard xdw_expanded_size(Some(7L), None, Some(2000L), 1000) is None else {
    abort("kind 7 sizes are not expanded sizes, even larger than stored")
  }
}

///|
test "expanded size: an explicit flag 0 means raw" {
  guard xdw_expanded_size(Some(4L), Some(0L), Some(892L), 935) is None else {
    abort("flag 0x8a = 0 should keep the data raw")
  }
  guard xdw_expanded_size(None, Some(0L), Some(1000L), 500) is None else {
    abort("flag 0x8a = 0 should keep the data raw")
  }
}

///|
test "expanded size: zero never decodes" {
  guard xdw_expanded_size(Some(4L), None, Some(0L), 935) is None else {
    abort("a zero size is not a compressed size")
  }
  assert_true(xdw_size_rejected(Some(1L), Some(0L)))
}

///|
test "expanded size: negative never decodes" {
  guard xdw_expanded_size(Some(4L), None, Some(-892L), 935) is None else {
    abort("a negative size is not a compressed size")
  }
  assert_true(xdw_size_rejected(Some(1L), Some(-892L)))
}

///|
test "expanded size: sizes past the Int range are rejected" {
  assert_true(xdw_size_rejected(Some(1L), Some(2147483648L)))
  assert_true(xdw_size_rejected(None, Some(4294967552L)))
}

///|
fn xdw_size_rejected(flag : Int64?, size : Int64?) -> Bool {
  try {
    ignore(xdw_expanded_size(Some(4L), flag, size, 500))
    false
  } catch {
    XdwCorrupt(_) | XdwTooLarge(_) => true
    _ => false
  }
}

///|
test "expanded size: missing compressed size is rejected and unknown flag stays raw" {
  assert_true(xdw_size_rejected(Some(1L), None))
  assert_eq(xdw_expanded_size(Some(4L), None, None, 500), None)
  assert_eq(xdw_expanded_size(Some(4L), Some(2L), Some(132L), 175), None)
}
