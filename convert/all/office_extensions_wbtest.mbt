///|
/// The Office extensions upstream registers on the workbook, word-processing
/// and presentation converters (`converter/xlsx`, `converter/docx` and
/// `converter/pptx` at `a5e4d7a`). A macro-enabled or template package is the
/// same OPC package as its plain counterpart, so the content decides the
/// format and the extension only decides it when the content is not
/// recognized.
let office_extension_cases : Array[(String, String)] = [
  ("xlsx", ".xlsx"),
  ("xlsx", ".xlsm"),
  ("xlsx", ".xltx"),
  ("xlsx", ".xltm"),
  ("docx", ".docx"),
  ("docx", ".docm"),
  ("docx", ".dotx"),
  ("docx", ".dotm"),
  ("pptx", ".pptx"),
  ("pptx", ".pptm"),
  ("pptx", ".ppsx"),
  ("pptx", ".ppsm"),
  ("pptx", ".potx"),
  ("pptx", ".potm"),
]

///|
/// A real package of the format, so the content detection is exercised on
/// bytes a producer wrote rather than on a hand-built stub.
fn office_fixture(format : String) -> Bytes raise {
  match format {
    "xlsx" => read_fixture("converter/xlsx-fixtures/basic.xlsx")
    "docx" => read_fixture("converter/docx-fixtures/basic.docx")
    "pptx" => read_fixture("converter/pptx-fixtures/basic.pptx")
    _ => fail("no fixture for " + format)
  }
}

///|
test "Office の拡張子はすべて内容から形式を決める" {
  for (format, extension) in office_extension_cases {
    let data = office_fixture(format)
    let outcome = convert(data, name="sample" + extension) catch {
      AllFailure(message) => fail("sample\{extension}: \{message}")
    }
    assert_eq(outcome.format, format, msg="sample" + extension)
    assert_true(outcome.bdf.length() > 100, msg="sample" + extension)
  }
}

///|
test "Office の形式を明示すれば拡張子に関係なく変換する" {
  for (format, extension) in office_extension_cases {
    let data = office_fixture(format)
    let outcome = convert(data, format~, name="sample" + extension) catch {
      AllFailure(message) => fail("sample\{extension} as \{format}: \{message}")
    }
    assert_eq(outcome.format, format, msg="sample" + extension)
  }
}

///|
/// Upstream's `detectNamed` falls back to the registered extension when no
/// detector claims the content, so a broken package is reported as the format
/// its name promises instead of as an unsupported image.
test "Office の拡張子は内容を読めなくても名前から形式を決める" {
  let junk = @utf8.encode("not an OPC package at all\n")
  for (format, extension) in office_extension_cases {
    let message = try {
      ignore(convert(junk, name="sample" + extension))
      ""
    } catch {
      AllFailure(message) => message
    }
    assert_true(
      message.has_prefix(format + ": "),
      msg="sample" + extension + " reported " + message,
    )
  }
}

///|
/// The VBA project a macro-enabled document carries. The bytes are a marker
/// so a test can tell whether they reached the output.
let office_macro_marker : String = "VBA-MACRO-MUST-NOT-RUN"

///|
/// A minimal WordprocessingML package. `macro` adds the VBA project part a
/// macro-enabled document (`.docm`) carries; everything else is the same, so
/// the two packages differ only in that part.
fn office_docx_package(with_macro : Bool) -> Bytes raise @ooxml.OoxmlError {
  let entries : Array[(String, Bytes)] = [
    (
      "[Content_Types].xml",
      @utf8.encode(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.ms-word.document.macroEnabled.main+xml\"/></Types>",
      ),
    ),
    (
      "_rels/.rels",
      @utf8.encode(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>",
      ),
    ),
    (
      "word/document.xml",
      @utf8.encode(
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?><w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>Macro document body</w:t></w:r></w:p></w:body></w:document>",
      ),
    ),
  ]
  if with_macro {
    entries.push(("word/vbaProject.bin", @utf8.encode(office_macro_marker)))
  }
  @ooxml.stored_zip(entries)
}

///|
/// A macro-enabled document converts as its plain counterpart: the VBA
/// project is never executed, its bytes are not carried into the BDF, and the
/// input archive is left as it was.
test "マクロ有効の文書はマクロを実行せず本文だけを変換する" {
  let plain = office_docx_package(false) catch {
    @ooxml.OoxmlError(message) => fail("plain package: " + message)
  }
  let with_macro = office_docx_package(true) catch {
    @ooxml.OoxmlError(message) => fail("macro package: " + message)
  }
  let plain_outcome = convert(plain, name="sample.docm") catch {
    AllFailure(message) => fail("plain package: " + message)
  }
  let macro_outcome = convert(with_macro, name="sample.docm") catch {
    AllFailure(message) => fail("macro package: " + message)
  }
  assert_eq(macro_outcome.format, "docx")
  // The macro part changes nothing: the same document comes out.
  assert_eq(macro_outcome.bdf, plain_outcome.bdf)
  // The VBA project is not embedded in the converted document.
  assert_false(
    @utf8.decode_lossy(macro_outcome.bdf).contains(office_macro_marker),
  )
  // The input archive still holds the part, so conversion did not rewrite it.
  assert_true(@utf8.decode_lossy(with_macro).contains(office_macro_marker))
  assert_true(@utf8.decode_lossy(with_macro).contains("Macro document body"))
}

///|
/// The extensions of the formats dropped from the porting scope stay out of
/// the name fallback: a `.epub`, `.mml`, `.mid` or `.kicad_pcb` name must not
/// reach a converter.
test "落とした形式の拡張子は名前からも変換しない" {
  for name in [
    "book.epub", "song.mml", "song.mid", "score.musicxml", "board.kicad_pcb",
    "board.gbr",
  ] {
    let format = try {
      Some(convert(@utf8.encode("dropped\n"), name~).format)
    } catch {
      AllFailure(_) => None
    }
    match format {
      Some(format) =>
        assert_false(
          ["epub", "mml", "midi", "musicxml", "kicad", "gerber"].contains(
            format,
          ),
          msg=name + " reached " + format,
        )
      None => ()
    }
  }
}
