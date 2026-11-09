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

///|
/// A real DocuWorks sample (ezpzfile/ezpzfile-xdw `corpus/manifest.tsv`),
/// small enough to keep here. It carries one text annotation.
let all_xdw_sample : String = "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";

///|
fn all_xdw_bytes() -> Bytes {
  @base64.decode(all_xdw_sample) catch {
    _ => abort("the sample is not valid base64")
  }
}

///|
/// The plain text of the converted document's index.
fn all_xdw_index_text(bdf : Bytes) -> String {
  let doc = @core.open_single(bdf) catch {
    _ => return ""
  }
  let hash = match doc.manifest.views[0].text_index {
    Some(h) => h
    None => return ""
  }
  let runs = @core.decode_text_index(doc.part(hash)) catch {
    _ => return ""
  }
  @core.index_plain_text(runs)
}

///|
test "xdw は既定で注釈テキストを索引に載せる" {
  let outcome = convert(all_xdw_bytes(), format="xdw")
  assert_eq(outcome.format, "xdw")
  assert_true(all_xdw_index_text(outcome.bdf).contains("Lorem ipsum. 吾輩は猫である。"))
}

///|
test "xdw の include_hidden=1 が公開入口から変換器に届く" {
  let plain = convert(all_xdw_bytes(), format="xdw")
  let hidden = convert(
    all_xdw_bytes(),
    format="xdw",
    params={ "include_hidden": "1" },
  )
  // このサンプルに覆われた文字は無いので索引は同じ。値が届いていることは
  // 下の不正値テストで確かめる。
  assert_eq(all_xdw_index_text(plain.bdf), all_xdw_index_text(hidden.bdf))
  assert_true(all_xdw_index_text(hidden.bdf).contains("Lorem ipsum. 吾輩は猫である。"))
}

///|
test "xdw の include_hidden の不正値は黙って既定に落ちない" {
  let message = try {
    ignore(convert(all_xdw_bytes(), format="xdw", params={ "include_hidden": "bogus" }))
    ""
  } catch {
    AllFailure(message) => message
  }
  assert_true(message.contains("include_hidden"))
}

///|
test "xdw 以外の形式は include_hidden の影響を受けない" {
  let plain = convert(@utf8.encode("# 見出し\n\n本文です。\n"), name="めも.md")
  let with_param = convert(
    @utf8.encode("# 見出し\n\n本文です。\n"),
    name="めも.md",
    params={ "include_hidden": "1" },
  )
  assert_eq(plain.format, "markdown")
  assert_eq(with_param.format, "markdown")
  assert_eq(plain.bdf.length(), with_param.bdf.length())
}
