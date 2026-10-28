///|
test "linear NFKC matches normalization library for scalar values" {
  for cp in 0..<0x10000 {
    if cp >= 0xd800 && cp < 0xe000 {
      continue
    }
    let s = cp.unsafe_to_char().to_string()
    assert_eq(search_nfkc(s), @normalization.nfkc(s))
  }
}

///|
test "linear NFKC preserves composition and stable ordering" {
  let parts = [
    "a", "é", "\u{301}", "\u{323}", "\u{315}", "\u{34f}", "\u{345}", "ｶ", "ﾞ",
    "\u{1100}", "\u{1161}", "\u{11a8}", "가", "㌔", "𝒜",
  ]
  for a in parts {
    for b in parts {
      for c in parts {
        let s = a + b + c
        assert_eq(search_nfkc(s), @normalization.nfkc(s))
      }
    }
  }
}

///|
test "linear NFKC handles long reverse ordered combining sequences" {
  let query = "a" + "\u{301}".repeat(100000) + "\u{323}".repeat(100000)
  let normalized = search_nfkc(query)
  assert_eq(
    normalized,
    "ạ" + "\u{323}".repeat(99999) + "\u{301}".repeat(100000),
  )
  assert_eq(normalize_query(query, case_sensitive=true), normalized)
}
