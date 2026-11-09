///|
/// `moon test` runs the test binary from the module root, so the fixtures
/// that live beside the compat packages are reachable from there.
fn fixture_path(relative : String) -> String {
  "compat/" + relative
}

///|
/// Read a checked-in fixture. A missing file fails the test instead of
/// skipping it, so an empty run cannot pass for a green one.
fn read_fixture(relative : String) -> Bytes raise {
  let path = fixture_path(relative)
  if !@fs.path_exists(path) {
    fail("fixture is missing: \{path}")
  }
  @fs.read_file_to_bytes(path) catch {
    @fs.IOError(message) => fail("cannot read \{path}: \{message}")
  }
}

///|
/// The page count and the plain text of the first view of a BDF document.
/// Reading the output back proves the bytes are a document, not just a blob.
fn document_pages_and_text(bdf : Bytes) -> (Int, String) raise {
  let document = @core.open_single(bdf)
  let view = document.manifest.views[0]
  let text = match view.text_index {
    Some(hash) => @core.index_plain_text(@core.decode_text_index(document.part(hash)))
    None => ""
  }
  (view.pages.length(), text)
}

///|
fn expect_contains(haystack : String, needle : String, label : String) -> Unit raise {
  match haystack.find(needle) {
    Some(_) => ()
    None =>
      fail("\{label}: expected \"\{needle}\" in the extracted text, got: \{haystack}")
  }
}

///|
test "実ファイルの PDF を BDF に変換する" {
  let data = read_fixture("pdf/fixtures/cairo-cff.pdf")
  assert_true(data.length() > 1000)
  let outcome = convert(data, name="cairo-cff.pdf") catch {
    AllFailure(message) => fail("cairo-cff.pdf: \{message}")
  }
  assert_eq(outcome.format, "pdf")
  assert_true(outcome.bdf.length() > 1000)
  assert_true(outcome.summary.length() > 0)
  let (pages, text) = document_pages_and_text(outcome.bdf) catch {
    _ => fail("cairo-cff.pdf: the output is not a readable BDF")
  }
  assert_eq(pages, 1)
  expect_contains(text, "Hello, world", "cairo-cff.pdf")
  expect_contains(text, "café", "cairo-cff.pdf")
}

///|
test "別の生成元の PDF も実ファイルから変換する" {
  let data = read_fixture("pdf/fixtures/reportlab-master.pdf")
  let outcome = convert(data, name="reportlab-master.pdf") catch {
    AllFailure(message) => fail("reportlab-master.pdf: \{message}")
  }
  assert_eq(outcome.format, "pdf")
  let (pages, text) = document_pages_and_text(outcome.bdf) catch {
    _ => fail("reportlab-master.pdf: the output is not a readable BDF")
  }
  assert_eq(pages, 3)
  expect_contains(text, "Quarterly report", "reportlab-master.pdf")
  expect_contains(text, "Headcount: 120", "reportlab-master.pdf")
  expect_contains(text, "page 1 of 3", "reportlab-master.pdf")
}

///|
test "実ファイルの HTML を名前から検出して変換する" {
  let data = read_fixture("html/fixtures/article.html")
  let outcome = convert(data, name="article.html") catch {
    AllFailure(message) => fail("article.html: \{message}")
  }
  assert_eq(outcome.format, "html")
  let (pages, text) = document_pages_and_text(outcome.bdf) catch {
    _ => fail("article.html: the output is not a readable BDF")
  }
  assert_eq(pages, 2)
  assert_true(text.length() > 1000)
  expect_contains(text, "Tech", "article.html")
}
