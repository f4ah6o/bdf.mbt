///|
test "pdf reads AcroForm fields" {
  let pdf =
    #|%PDF-1.7
    #|1 0 obj << /T (name) /V (Alice) /FT /Tx /Rect [10 20 100 40] >>
    #|2 0 obj << /T (note) /V (A\(B\)) /FT /Tx >>
    #|%%EOF
  let fields = read_fields(@utf8.encode(pdf))
  assert_eq(fields.length(), 2)
  assert_eq(fields[0].name, "name")
  assert_eq(fields[0].value, "Alice")
  assert_eq(fields[0].typ, "/Tx")
  assert_eq(fields[0].rect, Some((10.0, 20.0, 100.0, 40.0)))
  assert_eq(fields[1].name, "note")
  assert_eq(fields[1].value, "A(B)")
}
///|
test "pdf reads hex and name values" {
  let pdf =
    #|%PDF-1.7
    #|1 0 obj << /T (unicode) /V <FEFF0041006C006900630065> /FT /Tx >>
    #|2 0 obj << /T (ascii) /V <414243> /FT /Tx >>
    #|3 0 obj << /T (check) /V /Yes /FT /Btn >>
    #|%%EOF
  let fields = read_fields(@utf8.encode(pdf))
  assert_eq(fields.length(), 3)
  assert_eq(fields[0].value, "Alice")
  assert_eq(fields[1].value, "ABC")
  assert_eq(fields[2].value, "/Yes")
  assert_eq(fields[2].typ, "/Btn")
}

///|
test "pdf overlay draws form values" {
  let pdf =
    #|%PDF-1.7
    #|1 0 obj << /Type /Page /MediaBox [0 0 200 100] >>
    #|2 0 obj << /T (name) /V () /FT /Tx /Ff 7 /TU (Full Name) /MaxLen 20 /DV (Initial) /DA (/TiRo 8 Tf 0.5 g) /Q 1 /MK << /BG [0.9 0.9 0.9] /BC [1 0 0] >> /BS << /W 2 /S /D >> /Opt [[(Red) (R)] [<FEFF30B0> (G)]] /Rect [10 20 100 40] /P 3 0 R >>
    #|3 0 obj << /T (agree) /V () /FT /Btn /Rect [110 20 130 40] /P 4 0 R >>
    #|%%EOF
  let fields = read_fields(@utf8.encode(pdf))
  assert_true(fields[0].no_export)
  let bdf = fill_overlay(
    @utf8.encode(pdf),
    @utf8.encode("{\"name\":\"Alice\\nBob\",\"agree\":\"On\"}"),
    title="overlay",
  )
  let document = @core.open_single(bdf)
  assert_eq(document.manifest.views[0].pages[0].width, 200.0)
  assert_eq(document.manifest.views[0].pages[0].height, 100.0)
  let mut text = ""
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      for value in resources.object.strings {
        text = text + value + "\n"
      }
    }
  }
  let expected_color = fields[0].font_color.unwrap().reinterpret_as_int()
  let commands = @render.decode_commands(
    document.part(document.manifest.views[0].pages[0].layers[0].object),
  ) catch {
    _ => fail("overlay commands cannot be decoded")
  }
  assert_true(
    commands.any(fn(command) {
      match command {
        @render.FillColor(color) => color == expected_color
        _ => false
      }
    }),
  )
  assert_true(
    commands.any(fn(command) {
      match command {
        @render.Font(_, size) => size == 8.0
        _ => false
      }
    }),
  )

  assert_true(text.contains("Alice"), msg=text)
  assert_true(text.contains("Bob"), msg=text)
  assert_true(text.contains("X"), msg=text)
  let mut long = ""
  for _ in 0..<100 {
    long += "あ"
  }
  let wrap_pdf = pdf
    .replace(old="/MaxLen 20", new="")
    .replace(old="[10 20 100 40]", new="[10 20 30 40]")
  let wrapped = fill_overlay(
    @utf8.encode(wrap_pdf),
    @utf8.encode("{\"name\":\"" + long + "\"}"),
  )
  let wrapped_doc = @core.open_single(wrapped)
  let wrapped_commands = @render.decode_commands(
    wrapped_doc.part(wrapped_doc.manifest.views[0].pages[0].layers[0].object),
  ) catch {
    _ => fail("wrapped overlay commands cannot be decoded")
  }
  let mut wrapped_lines = 0
  for command in wrapped_commands {
    match command {
      @render.FillText(_, _, _, _) => wrapped_lines += 1
      _ => ()
    }
  }
  assert_true(wrapped_lines > 1, msg=wrapped_lines.to_string())
  let words = fill_overlay(
    @utf8.encode(wrap_pdf),
    @utf8.encode("{\"name\":\"Hello world again and again\"}"),
  )
  let word_doc = @core.open_single(words)
  let word_commands = @render.decode_commands(
    word_doc.part(word_doc.manifest.views[0].pages[0].layers[0].object),
  ) catch {
    _ => fail("word overlay commands cannot be decoded")
  }
  let mut word_count = 0
  for command in word_commands {
    match command {
      @render.FillText(value, _, _, _) => {
        word_count += 1
      }
      _ => ()
    }
  }
  assert_true(word_count > 1, msg=word_count.to_string())
}

///|
test "pdf reads a button field" {
  let pdf =
    #|%PDF-1.7
    #|1 0 obj << /Type /Page /MediaBox [0 0 200 100] >>
    #|2 0 obj << /T (name) /V () /FT /Tx /Ff 3 /TU (Full Name) /MaxLen 20 /DV (Initial) /DA (/TiRo 8 Tf 0.5 g) /Q 1 /MK << /BG [0.9 0.9 0.9] /BC [1 0 0] >> /BS << /W 2 /S /D >> /Opt [[(Red) (R)] [<FEFF30B0> (G)]] /Rect [10 20 100 40] /P 3 0 R >>
    #|3 0 obj << /T (agree) /V () /FT /Btn /Rect [110 20 130 40] /P 4 0 R >>
    #|%%EOF
  let fields = read_fields(@utf8.encode(pdf))
  assert_eq(fields.length(), 2)
  assert_eq(fields[1].name, "agree")
  assert_eq(fields[1].typ, "/Btn")
  assert_eq(fields[1].rect, Some((110.0, 20.0, 130.0, 40.0)))
  assert_eq(fields[0].page_object, Some(3))
  assert_eq(fields[0].flags, Some(3))
  assert_true(fields[0].read_only)
  assert_true(fields[0].required)
  assert_eq(fields[0].alternate_name, "Full Name")
  assert_eq(fields[0].max_len, Some(20))
  assert_eq(fields[0].default_value, "Initial")
  assert_eq(fields[0].font_size, Some(8.0))
  assert_eq(fields[0].font_color, Some(0x808080ff))
  assert_eq(fields[0].font_name, "Times-Roman")
  assert_eq(fields[0].quadding, Some(1))
  assert_eq(fields[0].background_color, Some(0xE6E6E6ff))
  assert_eq(fields[0].border_color, Some(0xFF0000ff))
  assert_eq(fields[0].border_width, Some(2.0))
  assert_eq(fields[0].border_style, "D")
  assert_eq(fields[0].options, ["Red", "グ"])
  assert_eq(fields[0].option_values, ["R", "G"])
  assert_eq(fields[1].page_object, Some(4))
}

///|
test "pdf overlay uses a CropBox" {
  let pdf =
    #|%PDF-1.7
    #|1 0 obj << /Type /Page /CropBox [0 0 300 150] >>
    #|2 0 obj << /T (name) /V () /FT /Tx /Rect [10 20 100 40] >>
    #|%%EOF
  let bdf = fill_overlay(
    @utf8.encode(pdf),
    @utf8.encode("{\"name\":\"Alice\"}"),
    title="crop",
  )
  let document = @core.open_single(bdf)
  assert_eq(document.manifest.views[0].pages[0].width, 300.0)
  assert_eq(document.manifest.views[0].pages[0].height, 150.0)
}
///|
test "pdf overlay can skip read-only fields" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoT2xkKSAvRmYgMSAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzQ4CiUlRU9GCg==",
  )
  let skipped = fill_overlay(
    pdf,
    @utf8.encode("{\"name\":\"New\"}"),
    skip_read_only=true,
  )
  let document = @core.open_single(skipped)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(!resources.object.strings.contains("New"))
  let filled = fill_overlay(pdf, @utf8.encode("{\"name\":\"New\"}"))
  let document2 = @core.open_single(filled)
  let resources2 = @core.decode_object_resources(
    document2.part(document2.manifest.parts[0].hash),
  )
  assert_true(resources2.object.strings.contains("New"))
}
///|
test "pdf overlay respects maximum lengths" {
  let pdf =
    #|%PDF-1.7
    #|1 0 obj << /Type /Page /MediaBox [0 0 200 100] >>
    #|2 0 obj << /T (name) /V () /FT /Tx /MaxLen 3 /Rect [10 20 100 40] >>
    #|%%EOF
  let bdf = fill_overlay(@utf8.encode(pdf), @utf8.encode("{\"name\":\"Alice\"}"))
  let document = @core.open_single(bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.strings.contains("Ali"))
  assert_true(!resources.object.strings.contains("Alice"))
}

///|
test "pdf comb fields expose the flag and separators" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChjb2RlKSAvRmYgMTY3NzcyMTYgL01heExlbiAzIC9WIChBQkMpIC9SZWN0IFsxMCAyMCAxMDAgNDBdIC9QIDMgMCBSID4+CmVuZG9iagp4cmVmCjAgNQowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwMDkgMDAwMDAgbiAKMDAwMDAwMDA5MCAwMDAwMCBuIAowMDAwMDAwMTQ3IDAwMDAwIG4gCjAwMDAwMDAyMzQgMDAwMDAgbiAKdHJhaWxlcgo8PCAvU2l6ZSA1IC9Sb290IDEgMCBSID4+CnN0YXJ0eHJlZgozNjUKJSVFT0YK",
  )
  let fields = read_fields(pdf)
  assert_true(fields[0].comb)
  assert_eq(fields[0].max_len, Some(3))
  let bdf = fill_overlay(pdf, @utf8.encode("{\"code\":\"ABC\"}"))
  let document = @core.open_single(bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.ops.length() > 10)
}

///|
test "pdf password fields are masked in overlays" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChzZWNyZXQpIC9GZiA4MTkyIC9WIChoaWRkZW4pIC9SZWN0IFsxMCAyMCAxMDAgNDBdIC9QIDMgMCBSID4+CmVuZG9iagp4cmVmCjAgNQowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwMDkgMDAwMDAgbiAKMDAwMDAwMDA5MCAwMDAwMCBuIAowMDAwMDAwMTQ3IDAwMDAwIG4gCjAwMDAwMDAyMzQgMDAwMDAgbiAKdHJhaWxlcgo8PCAvU2l6ZSA1IC9Sb290IDEgMCBSID4+CnN0YXJ0eHJlZgozNTYKJSVFT0YK",
  )
  let fields = read_fields(pdf)
  assert_true(fields[0].password)
  let bdf = fill_overlay(pdf, @utf8.encode("{\"secret\":\"hidden\"}"))
  let document = @core.open_single(bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.strings.contains("******"))
  assert_true(!resources.object.strings.contains("hidden"))
}

///|
test "pdf underline borders are drawn" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoQUJDKSAvQlMgPDwgL1cgMiAvUyAvVSA+PiAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzYzCiUlRU9GCg==",
  )
  let fields = read_fields(pdf)
  assert_eq(fields[0].border_style, "U")
  let bdf = fill_overlay(pdf, @utf8.encode("{\"name\":\"ABC\"}"))
  let document = @core.open_single(bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.ops.length() > 10)
}

///|
test "pdf multiline fields keep line breaks" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChub3RlKSAvRmYgNDA5NiAvViAoQVxuQikgL1JlY3QgWzEwIDIwIDEwMCA0MF0gL1AgMyAwIFIgPj4KZW5kb2JqCnhyZWYKMCA1CjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAwOSAwMDAwMCBuIAowMDAwMDAwMDkwIDAwMDAwIG4gCjAwMDAwMDAxNDcgMDAwMDAgbiAKMDAwMDAwMDIzNCAwMDAwMCBuIAp0cmFpbGVyCjw8IC9TaXplIDUgL1Jvb3QgMSAwIFIgPj4Kc3RhcnR4cmVmCjM1MgolJUVPRgo=",
  )
  let fields = read_fields(pdf)
  assert_true(fields[0].multiline)
  let bdf = fill_overlay(pdf, @utf8.encode("{\"note\":\"A\\nB\"}"))
  let document = @core.open_single(bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.strings.contains("A"))
  assert_true(resources.object.strings.contains("B"))
}

///|
test "pdf single-line fields collapse newlines" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChub3RlKSAvViAoQVxuQikgL1JlY3QgWzEwIDIwIDEwMCA0MF0gL1AgMyAwIFIgPj4KZW5kb2JqCnhyZWYKMCA1CjAwMDAwMDAwMDAgNjU1MzUgZiAKMDAwMDAwMDAwOSAwMDAwMCBuIAowMDAwMDAwMDkwIDAwMDAwIG4gCjAwMDAwMDAxNDcgMDAwMDAgbiAKMDAwMDAwMDIzNCAwMDAwMCBuIAp0cmFpbGVyCjw8IC9TaXplIDUgL1Jvb3QgMSAwIFIgPj4Kc3RhcnR4cmVmCjM0MwolJUVPRgo=",
  )
  let fields = read_fields(pdf)
  assert_true(!fields[0].multiline)
  let bdf = fill_overlay(pdf, @utf8.encode("{\"note\":\"A\\nB\"}"))
  let document = @core.open_single(bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.strings.contains("A B"))
}

///|
test "pdf bevel borders are drawn" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoQUJDKSAvQlMgPDwgL1cgMiAvUyAvQiA+PiAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzYzCiUlRU9GCg==",
  )
  let fields = read_fields(pdf)
  assert_eq(fields[0].border_style, "B")
  let bdf = fill_overlay(pdf, @utf8.encode("{\"name\":\"ABC\"}"))
  let document = @core.open_single(bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.ops.length() > 10)
}

///|
test "pdf inset borders are drawn" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzQgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzQgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoQUJDKSAvQlMgPDwgL1cgMiAvUyAvSSA+PiAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCAzIDAgUiA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjM0IDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzYzCiUlRU9GCg==",
  )
  let fields = read_fields(pdf)
  assert_eq(fields[0].border_style, "I")
  let bdf = fill_overlay(pdf, @utf8.encode("{\"name\":\"ABC\"}"))
  let document = @core.open_single(bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.ops.length() > 10)
}

///|
test "pdf overlay spans multiple pages" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzUgMCBSIDYgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzMgMCBSIDQgMCBSXSAvQ291bnQgMiA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzUgMCBSXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDMwMCAxNTBdIC9Bbm5vdHMgWzYgMCBSXSA+PgplbmRvYmoKNSAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChmaXJzdCkgL1YgKCkgL1JlY3QgWzEwIDIwIDEwMCA0MF0gL1AgMyAwIFIgPj4KZW5kb2JqCjYgMCBvYmoKPDwgL1R5cGUgL0Fubm90IC9TdWJ0eXBlIC9XaWRnZXQgL0ZUIC9UeCAvVCAoc2Vjb25kKSAvViAoKSAvUmVjdCBbMTAgMjAgMTAwIDQwXSAvUCA0IDAgUiA+PgplbmRvYmoKeHJlZgowIDcKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTYgMDAwMDAgbiAKMDAwMDAwMDE1OSAwMDAwMCBuIAowMDAwMDAwMjQ2IDAwMDAwIG4gCjAwMDAwMDAzMzMgMDAwMDAgbiAKMDAwMDAwMDQzOSAwMDAwMCBuIAp0cmFpbGVyCjw8IC9TaXplIDcgL1Jvb3QgMSAwIFIgPj4Kc3RhcnR4cmVmCjU0NgolJUVPRgo=",
  )
  let bdf = fill_overlay(
    pdf,
    @utf8.encode("{\"first\":\"One\",\"second\":\"Two\"}"),
  )
  let document = @core.open_single(bdf)
  let view = document.manifest.views[0]
  assert_eq(view.pages.length(), 2)
  assert_eq(view.pages[0].width, 200.0)
  assert_eq(view.pages[0].height, 100.0)
  assert_eq(view.pages[1].width, 300.0)
  assert_eq(view.pages[1].height, 150.0)
  let first = @core.decode_object_resources(
    document.part(view.pages[0].layers[0].object),
  )
  let second = @core.decode_object_resources(
    document.part(view.pages[1].layers[0].object),
  )
  assert_true(first.object.strings.contains("One"))
  assert_true(second.object.strings.contains("Two"))
}

///|
test "pdf overlay puts fields without a page on the first page" {
  let pdf = @base64.decode(
    "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgL0Fjcm9Gb3JtIDw8IC9GaWVsZHMgWzMgMCBSXSA+PiA+PgplbmRvYmoKMiAwIG9iago8PCAvVHlwZSAvUGFnZXMgL0tpZHMgWzQgMCBSXSAvQ291bnQgMSA+PgplbmRvYmoKMyAwIG9iago8PCAvVHlwZSAvQW5ub3QgL1N1YnR5cGUgL1dpZGdldCAvRlQgL1R4IC9UIChuYW1lKSAvViAoKSAvUmVjdCBbMTAgMjAgMTAwIDQwXSA+PgplbmRvYmoKNCAwIG9iago8PCAvVHlwZSAvUGFnZSAvUGFyZW50IDIgMCBSIC9NZWRpYUJveCBbMCAwIDIwMCAxMDBdIC9Bbm5vdHMgWzMgMCBSXSA+PgplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwOTAgMDAwMDAgbiAKMDAwMDAwMDE0NyAwMDAwMCBuIAowMDAwMDAwMjQzIDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMzMwCiUlRU9GCg==",
  )
  let bdf = fill_overlay(pdf, @utf8.encode("{\"name\":\"Alice\"}"))
  let document = @core.open_single(bdf)
  let view = document.manifest.views[0]
  assert_eq(view.pages.length(), 1)
  assert_eq(view.pages[0].width, 200.0)
  let resources = @core.decode_object_resources(document.part(view.pages[0].layers[0].object))
  assert_true(resources.object.strings.contains("Alice"))
}

