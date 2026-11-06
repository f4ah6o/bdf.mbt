///|
test "parse printer attributes" {
  let message = new_response(STATUS_OK, 1, "", "")
  message.add(TAG_PRINTER, [
    attr("printer-name", [name("office")]),
    attr("printer-make-and-model", [text("BDF Printer")]),
    attr("printer-info", [text("third floor")]),
    attr("printer-state", [enum_value(PRINTER_IDLE)]),
    attr("queued-job-count", [integer(2)]),
    attr("printer-state-reasons", [keyword("none")]),
    attr("printer-is-accepting-jobs", [boolean(true)]),
    attr("ipp-versions-supported", [keyword("2.0")]),
    attr("operations-supported", [enum_value(OP_PRINT_JOB), enum_value(OP_CREATE_JOB)]),
    attr("document-format-supported", [mime_type("application/pdf"), mime_type("image/pwg-raster")]),
    attr("media-supported", [keyword("iso_a4_210x297mm")]),
    attr("sides-supported", [keyword("one-sided"), keyword("two-sided-long-edge")]),
    attr("print-quality-supported", [enum_value(4), enum_value(5)]),
    attr("printer-resolution-supported", [resolution(300, 300, 3), resolution(600, 600, 3)]),
    attr("copies-supported", [range(1, 99)]),
    attr("page-ranges-supported", [boolean(true)]),
    attr("pwg-raster-document-type-supported", [keyword("sgray_8"), keyword("srgb_8")]),
    attr("pwg-raster-document-sheet-back", [keyword("normal")]),
    attr("urf-supported", [keyword("W8"), keyword("SRGB24")]),
    attr("pclm-strip-height-preferred", [integer(16)]),
    attr("pclm-source-resolution-supported", [resolution(300, 300, 3)]),
    attr("pclm-compression-method-preferred", [keyword("flate")]),
    attr("job-account-id-supported", [boolean(true)]),
    attr("media-col-database", [
      collection([
        attr("media-size-name", [keyword("iso_a4_210x297mm")]),
        attr("media-size", [
          collection([
            attr("x-dimension", [integer(21000)]),
            attr("y-dimension", [integer(29700)]),
          ]),
        ]),
        attr("media-source", [keyword("tray-1")]),
      ]),
    ]),
  ])
  let printer = parse_printer(message)
  assert_eq(printer.name, "office")
  assert_eq(printer.make_model, "BDF Printer")
  assert_eq(printer.info, "third floor")
  assert_eq(printer.state, PRINTER_IDLE)
  assert_eq(printer.queued, 2)
  assert_true(printer.accepting_jobs)
  assert_true(printer.supports("APPLICATION/PDF"))
  assert_true(printer.supports("image/pwg-raster"))
  assert_true(!printer.supports("image/urf"))
  assert_true(printer.supports_op(OP_CREATE_JOB))
  assert_true(!printer.supports_op(OP_CANCEL_JOB))
  assert_eq(printer.copies, (1, 99))
  assert_true(printer.page_ranges)
  assert_eq(printer.qualities, [4, 5])
  assert_eq(printer.resolutions.length(), 2)
  assert_eq(printer.pwg_raster_types, ["sgray_8", "srgb_8"])
  assert_eq(printer.pwg_raster_sheet_back, "normal")
  assert_true(printer.pclm)
  assert_eq(printer.pclm_strip_height, 16)
  assert_eq(printer.pclm_compression, ["flate"])
  assert_eq(printer.media_col_db.length(), 1)
  let media = printer.media_col_db[0]
  assert_eq(media.size_name, "iso_a4_210x297mm")
  assert_eq(media.x, 21000)
  assert_eq(media.y, 29700)
  assert_eq(media.source, "tray-1")
  assert_true(printer.has("printer-name") is Some(_))
  assert_true(printer.has("missing") is None)
  let summary = printer.summary()
  assert_true(summary.contains("name: office"))
  assert_true(summary.contains("formats: application/pdf, image/pwg-raster"))
  assert_eq(printer.sorted_formats(), ["application/pdf", "image/pwg-raster"])
}

///|
test "empty printer" {
  let printer = parse_printer(new_request(OP_GET_PRINTER_ATTRIBUTES, 1, "", ""))
  assert_eq(printer.name, "")
  assert_eq(printer.copies, (1, 1))
  assert_true(!printer.supports("application/pdf"))
}
