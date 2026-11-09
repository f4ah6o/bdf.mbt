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
test "実ファイルの PDF を BDF に変換する" {
  let data = read_fixture("pdf/fixtures/cairo-cff.pdf")
  assert_true(data.length() > 1000)
  let outcome = convert(data, name="cairo-cff.pdf") catch {
    AllFailure(message) => fail("cairo-cff.pdf: \{message}")
  }
  assert_eq(outcome.format, "pdf")
  assert_true(outcome.bdf.length() > 1000)
  assert_true(outcome.summary.length() > 0)
}

///|
test "別の生成元の PDF も実ファイルから変換する" {
  let data = read_fixture("pdf/fixtures/reportlab-master.pdf")
  let outcome = convert(data, name="reportlab-master.pdf") catch {
    AllFailure(message) => fail("reportlab-master.pdf: \{message}")
  }
  assert_eq(outcome.format, "pdf")
  assert_true(outcome.bdf.length() > 1000)
}

///|
test "実ファイルの HTML を名前から検出して変換する" {
  let data = read_fixture("html/fixtures/article.html")
  let outcome = convert(data, name="article.html") catch {
    AllFailure(message) => fail("article.html: \{message}")
  }
  assert_eq(outcome.format, "html")
  assert_true(outcome.bdf.length() > 1000)
}
