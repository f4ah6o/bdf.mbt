///|
test "Markdown は名前から検出して変換する（内容の検出器は使わない）" {
  let outcome = convert(@utf8.encode("# 見出し\n\n本文の段落です。\n"), name="めも.md")
  assert_eq(outcome.format, "markdown")
  assert_true(outcome.bdf.length() > 100)
}

///|
test "CSV を名前と内容の両方から表にする" {
  let outcome = convert(@utf8.encode("a,b\n1,2\n3,4\n"), name="memo.csv")
  assert_eq(outcome.format, "csv")
  assert_true(outcome.bdf.length() > 100)
}

///|
test "形式の指定があれば検出を飛ばす" {
  let outcome = convert(@utf8.encode("a;b\n1;2\n"), format="csv", name="memo.csv")
  assert_eq(outcome.format, "csv")
}

///|
test "不明な形式は画像の失敗を返す" {
  let message = try {
    ignore(convert(@utf8.encode("なにかのデータ"), name="memo.zzz"))
    ""
  } catch {
    AllFailure(message) => message
  }
  assert_eq(
    message,
    "image: input is not a supported BMP, ICO, JPEG, PNG, GIF, WebP, AVIF or SVG image",
  )
}
