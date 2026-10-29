///|
test "normalize family names using NFKC and Unicode lowercase" {
  inspect(@db.normalize("Ａｌｐｈａ－Ｆａｃｅ"), content="alphaface")
  inspect(@db.normalize("İstanbul"), content="istanbul")
  inspect(@db.normalize("ＭＳ　ゴシック"), content="msゴシック")
}

///|
test "empty font database has no resolved faces" {
  let db = @db.Database::new()
  assert_eq(db.faces().length(), 0)
  assert_eq(db.resolve("Arial").face, None)
  assert_eq(db.resolve_math("Cambria Math"), None)
  assert_eq(db.fallbacks("sans-serif").length(), 0)
  assert_eq(db.face_for("Arial", "", 'A'.to_int()).resolved.face, None)
}
