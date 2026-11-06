///|
fn pdfme_text(bdf : Bytes) -> String raise {
  let document = @core.open_single(bdf)
  let out = StringBuilder()
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let raw = document.part(part.hash)
      let resources = @core.decode_object_resources(raw)
      for text in resources.object.strings {
        out.write_string(text)
        out.write_char('\n')
      }
    }
  }
  out.to_string()
}

///|
test "pdfme fills text fields" {
  let template =
    #|{"basePdf":{"width":100,"height":50,"staticSchema":[{"name":"brand","type":"text","readOnly":true,"content":"BDF STUDIO","position":{"x":10,"y":5},"width":60,"height":7,"fontSize":12}]},"schemas":[[{"name":"title","type":"text","readOnly":true,"content":"Invoice","position":{"x":10,"y":20},"width":60,"height":8,"fontSize":14},{"name":"customer","type":"text","content":"","position":{"x":10,"y":32},"width":60,"height":6,"fontSize":10}]]}
  let data = #|{"customer":"Alice"}
  let result = fill(@utf8.encode(template), @utf8.encode(data))
  assert_eq(result.pages, 1)
  assert_true(result.bdf.length() > 0)
  let text = pdfme_text(result.bdf)
  assert_true(text.contains("BDF STUDIO"), msg=text)
  assert_true(text.contains("Invoice"), msg=text)
  assert_true(text.contains("Alice"), msg=text)
  assert_eq(result.warnings.length(), 0)
  let unsupported =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"sig","type":"unsupported","position":{"x":5,"y":5},"width":50,"height":10}]]}
  let warned = fill(@utf8.encode(unsupported), @utf8.encode("{}"))
  assert_eq(warned.warnings.length(), 1)
  let bad = try {
    ignore(fill(b"not json", b"{}"))
    false
  } catch {
    PdfmeError(_) => true
  }
  assert_true(bad, msg="a broken template")
}

///|
test "pdfme fills a table" {
  let template =
    #|{"basePdf":{"width":120,"height":80},"schemas":[[{"name":"lines","type":"table","position":{"x":10,"y":10},"width":100,"height":40,"head":["item","qty"],"fontSize":9,"rowHeight":8,"cellPadding":2,"borderColor":"#CC0000","borderWidth":0.8,"borderStyle":"dashed"}]]}
  let data = #|{"lines":[{"item":"Pen","qty":2},{"item":"Ink","qty":1}]}
  let result = fill(@utf8.encode(template), @utf8.encode(data))
  let text = pdfme_text(result.bdf)
  assert_true(text.contains("item"), msg=text)
  assert_true(text.contains("Pen"), msg=text)
  assert_true(text.contains("Ink"), msg=text)
  assert_eq(result.warnings.length(), 0)
}

///|
test "pdfme fills an image" {
  let template =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"logo","type":"image","position":{"x":10,"y":10},"width":20,"height":20,"opacity":0.5}]]}
  let png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l8ZkAAAAAElFTkSuQmCC"
  let data = "{\"logo\":\"data:image/png;base64," + png + "\"}"
  let result = fill(@utf8.encode(template), @utf8.encode(data))
  let document = @core.open_single(result.bdf)
  let mut images = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      images += resources.object.images.length()
    }
  }
  assert_eq(images, 1)
  assert_eq(result.warnings.length(), 0)
  let commands = @render.decode_commands(
    document.part(document.manifest.views[0].pages[0].layers[0].object),
  ) catch {
    _ => fail("image commands cannot be decoded")
  }
  assert_true(
    commands.any(fn(command) {
      match command {
        @render.Alpha(value) => (value - 0.5).abs() < 0.001
        _ => false
      }
    }),
  )
}


///|
test "pdfme fills variables" {
  let template =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"customer","type":"multiVariableText","position":{"x":10,"y":10},"width":80,"height":20,"fontSize":10,"text":"{company}\n{person}","variables":["company","person"]}]]}
  let data = #|{"customer":{"company":"ACME","person":"Sales"}}
  let result = fill(@utf8.encode(template), @utf8.encode(data))
  let text = pdfme_text(result.bdf)
  assert_true(text.contains("ACME"), msg=text)
  assert_true(text.contains("Sales"), msg=text)
}


///|
test "pdfme draws text boxes" {
  let template =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"box","type":"text","content":"Boxed","position":{"x":10,"y":10},"width":50,"height":10,"fontSize":10,"backgroundColor":"#eeeeee","borderColor":"#000000","borderWidth":0.5}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  let text = pdfme_text(result.bdf)
  assert_true(text.contains("Boxed"), msg=text)
  assert_eq(result.warnings.length(), 0)
}


///|
test "pdfme reads a base PDF page size" {
  let base = "JVBERi0xLjQKMSAwIG9iajw8L1R5cGUvUGFnZS9NZWRpYUJveFswIDAgNzIwIDM2MF0+PgplbmRvYmoKJSVFT0YK"
  let template = "{\"basePdf\":\"data:application/pdf;base64," + base + "\",\"schemas\":[[{\"name\":\"title\",\"type\":\"text\",\"content\":\"Base\",\"position\":{\"x\":10,\"y\":10},\"width\":50,\"height\":10}]]}"
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.pages, 1)
  let document = @core.open_single(result.bdf)
  assert_eq(document.manifest.views[0].pages[0].width, 720.0)
  assert_eq(document.manifest.views[0].pages[0].height, 360.0)
  assert_eq(result.warnings.length(), 1)
  assert_true(result.warnings[0].contains("base PDF"))
}


///|
test "pdfme draws a QR code" {
  let template =
    #|{"basePdf":{"width":80,"height":80},"schemas":[[{"name":"code","type":"qrcode","readOnly":true,"content":"HELLO","position":{"x":10,"y":10},"width":30,"height":30}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut ops = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      ops += resources.object.ops.length()
    }
  }
  assert_true(ops > 100)
}


///|
test "pdfme draws a Code 39 barcode" {
  let template =
    #|{"basePdf":{"width":80,"height":50},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"ABC123","format":"code39","position":{"x":10,"y":10},"width":60,"height":20}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut ops = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      ops += resources.object.ops.length()
    }
  }
  assert_true(ops > 100)
  let gs1 =
    #|{"basePdf":{"width":80,"height":50},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"(01)04912345678904(10)ABC","format":"gs1","position":{"x":10,"y":10},"width":60,"height":20}]]}
  let encoded = fill(@utf8.encode(gs1), @utf8.encode("{}"))
  assert_eq(encoded.warnings.length(), 0)
  let encodedDoc = @core.open_single(encoded.bdf)
  let mut gs1Ops = 0
  for part in encodedDoc.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(encodedDoc.part(part.hash))
      gs1Ops += resources.object.ops.length()
    }
  }
  assert_true(gs1Ops > 100)
}


///|
test "pdfme draws an EAN-13 barcode" {
  let template =
    #|{"basePdf":{"width":80,"height":50},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"490123456789","format":"ean13","position":{"x":10,"y":10},"width":60,"height":20}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut ops = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      ops += resources.object.ops.length()
    }
  }
  assert_true(ops > 100)
  let bad =
    #|{"basePdf":{"width":80,"height":50},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"abc","format":"ean13","position":{"x":10,"y":10},"width":60,"height":20}]]}
  let failed = try {
    ignore(fill(@utf8.encode(bad), @utf8.encode("{}")))
    false
  } catch {
    _ => true
  }
  assert_true(failed, msg="bad EAN-13")
}


///|
test "pdfme draws an EAN-8 barcode" {
  let template =
    #|{"basePdf":{"width":60,"height":40},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"1234567","format":"ean8","position":{"x":5,"y":5},"width":50,"height":20}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut ops = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      ops += resources.object.ops.length()
    }
  }
  assert_true(ops > 100)
}


///|
test "pdfme draws a Code 128 barcode" {
  let template =
    #|{"basePdf":{"width":80,"height":50},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"HELLO","format":"code128","position":{"x":10,"y":10},"width":60,"height":20}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut ops = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      ops += resources.object.ops.length()
    }
  }
  assert_true(ops > 100)
}


///|
test "pdfme evaluates expressions" {
  let template =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"totals","type":"multiVariableText","position":{"x":10,"y":10},"width":80,"height":20,"fontSize":10,"text":"{total * 1.1}","variables":["total"]}]]}
  let data = #|{"totals":{"total":100}}
  let result = fill(@utf8.encode(template), @utf8.encode(data))
  let text = pdfme_text(result.bdf)
  assert_true(text.contains("110"), msg=text)
  let data2 = #|{"totals":{"total":100,"tax":10}}
  let template2 =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"totals","type":"multiVariableText","position":{"x":10,"y":10},"width":80,"height":20,"fontSize":10,"text":"{(total + tax) / 2}","variables":["total","tax"]}]]}
  let result2 = fill(@utf8.encode(template2), @utf8.encode(data2))
  assert_true(pdfme_text(result2.bdf).contains("55"))
}


///|
test "pdfme draws an ITF barcode" {
  let template =
    #|{"basePdf":{"width":80,"height":50},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"123456","format":"itf","position":{"x":10,"y":10},"width":60,"height":20}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut ops = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      ops += resources.object.ops.length()
    }
  }
  assert_true(ops > 100)
}


///|
test "pdfme draws an NW-7 barcode" {
  let template =
    #|{"basePdf":{"width":80,"height":50},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"1234","format":"nw7","position":{"x":10,"y":10},"width":60,"height":20}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut ops = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      ops += resources.object.ops.length()
    }
  }
  assert_true(ops > 100)
}


///|
test "pdfme draws a UPC-A barcode" {
  let template =
    #|{"basePdf":{"width":80,"height":50},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"036000291452","format":"upca","position":{"x":10,"y":10},"width":60,"height":20}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut ops = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      ops += resources.object.ops.length()
    }
  }
  assert_true(ops > 100)
}

///|
test "pdfme draws a UPC-E barcode" {
  let template =
    #|{"basePdf":{"width":80,"height":50},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"0123456","format":"upce","position":{"x":10,"y":10},"width":60,"height":20}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut ops = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      ops += resources.object.ops.length()
    }
  }
  assert_true(ops > 50)
}

///|
test "pdfme draws an MSI barcode" {
  let template =
    #|{"basePdf":{"width":80,"height":50},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"1234567","format":"msi","position":{"x":10,"y":10},"width":60,"height":20}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut ops = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      ops += resources.object.ops.length()
    }
  }
  assert_true(ops > 50)
}

///|
test "pdfme draws a Code 93 barcode" {
  let template =
    #|{"basePdf":{"width":80,"height":50},"schemas":[[{"name":"code","type":"barcode","readOnly":true,"content":"ABC-123","format":"code93","position":{"x":10,"y":10},"width":60,"height":20}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut ops = 0
  for part in document.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(document.part(part.hash))
      ops += resources.object.ops.length()
    }
  }
  assert_true(ops > 50)
}

///|
test "pdfme uses table column widths" {
  let template =
    #|{"basePdf":{"width":120,"height":80},"schemas":[[{"name":"lines","type":"table","position":{"x":10,"y":10},"width":100,"height":40,"head":["item","qty","note"],"headWidthPercentages":[50,20,30],"fontSize":9,"rowHeight":8,"cellPadding":2,"borderColor":"#CC0000","borderWidth":0.8,"borderStyle":"dashed"}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.strings.contains("item"))
  assert_true(resources.object.ops.length() > 10)
}

///|
test "pdfme evaluates expression functions" {
  let template =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"totals","type":"multiVariableText","position":{"x":10,"y":10},"width":80,"height":20,"fontSize":10,"text":"{max(round(total / 3), 10)}","variables":["total"]}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{\"totals\":{\"total\":100}}"))
  let text = pdfme_text(result.bdf)
  assert_true(text.contains("33"), msg=text)
  let template2 =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"totals","type":"multiVariableText","position":{"x":10,"y":10},"width":80,"height":20,"fontSize":10,"text":"{abs(total - 120)}","variables":["total"]}]]}
  let result2 = fill(@utf8.encode(template2), @utf8.encode("{\"totals\":{\"total\":100}}"))
  assert_true(pdfme_text(result2.bdf).contains("20"))
}

///|
test "pdfme aligns table columns" {
  let template =
    #|{"basePdf":{"width":120,"height":80},"schemas":[[{"name":"lines","type":"table","position":{"x":10,"y":10},"width":100,"height":40,"head":["item","qty"],"headStyles":{"alignment":"center","fontSize":12,"height":10,"backgroundColor":"#E6E6E6","fontColor":"#333333","cellPadding":4},"alternateBackgroundColor":"#F5F5F5","columnStyles":[{"alignment":"center","fontColor":"#FF0000","backgroundColor":"#EEEEEE","fontSize":7,"fontName":"Courier","verticalAlign":"middle"},{"alignment":"right"}],"fontSize":9,"rowHeight":8,"cellPadding":2,"borderColor":"#CC0000","borderWidth":0.8,"borderStyle":"dashed"}]]}
  let result = fill(
    @utf8.encode(template),
    @utf8.encode("{\"lines\":[{\"item\":\"apple\",\"qty\":\"2\"}]}"),
  )
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.strings.contains("apple"))
  assert_true(resources.object.ops.length() > 10)
}

///|
test "pdfme reads a base PDF CropBox" {
  let base = "JVBERi0xLjQKMSAwIG9iajw8L1R5cGUvUGFnZS9Dcm9wQm94WzAgMCA0MDAgMjAwXT4+CmVuZG9iagolJUVPRgo="
  let template = "{\"basePdf\":\"data:application/pdf;base64," + base + "\",\"schemas\":[[{\"name\":\"title\",\"type\":\"text\",\"content\":\"Base\",\"position\":{\"x\":10,\"y\":10},\"width\":50,\"height\":10}]]}"
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  let document = @core.open_single(result.bdf)
  assert_eq(document.manifest.views[0].pages[0].width, 400.0)
  assert_eq(document.manifest.views[0].pages[0].height, 200.0)
}

///|
test "pdfme rotates a base PDF page" {
  let base = "JVBERi0xLjQKMSAwIG9iajw8L1R5cGUvUGFnZS9Dcm9wQm94WzAgMCA0MDAgMjAwXS9Sb3RhdGUgOTA+PgplbmRvYmoKJSVFT0YK"
  let template = "{\"basePdf\":\"data:application/pdf;base64," + base + "\",\"schemas\":[[{\"name\":\"title\",\"type\":\"text\",\"content\":\"Base\",\"position\":{\"x\":10,\"y\":10},\"width\":50,\"height\":10}]]}"
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  let document = @core.open_single(result.bdf)
  assert_eq(document.manifest.views[0].pages[0].width, 200.0)
  assert_eq(document.manifest.views[0].pages[0].height, 400.0)
}

///|
test "pdfme draws base PDF content" {
  let base = "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUl0gL0NvdW50IDEgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAyMDAgMTAwXSAvQ29udGVudHMgNCAwIFIgPj4KZW5kb2JqCjQgMCBvYmoKPDwgL0xlbmd0aCAxOCA+PgpzdHJlYW0KMC41IDAuNSAxMCAxMCByZSBmCmVuZHN0cmVhbQplbmRvYmoKeHJlZgowIDUKMDAwMDAwMDAwMCA2NTUzNSBmIAowMDAwMDAwMDA5IDAwMDAwIG4gCjAwMDAwMDAwNTggMDAwMDAgbiAKMDAwMDAwMDExNSAwMDAwMCBuIAowMDAwMDAwMjAyIDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNSAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKMjcwCiUlRU9GCg=="
  let template = "{\"basePdf\":\"data:application/pdf;base64," + base + "\",\"schemas\":[[{\"name\":\"title\",\"type\":\"text\",\"content\":\"Base\",\"position\":{\"x\":10,\"y\":10},\"width\":50,\"height\":10}]]}"
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  assert_eq(document.manifest.views[0].pages[0].layers.length(), 2)
  assert_eq(document.manifest.views[0].pages[0].width, 200.0)
  assert_true(pdfme_text(result.bdf).contains("Base"))
}

///|
test "pdfme keeps base PDF pages" {
  let base = "JVBERi0xLjQKMSAwIG9iago8PCAvVHlwZSAvQ2F0YWxvZyAvUGFnZXMgMiAwIFIgPj4KZW5kb2JqCjIgMCBvYmoKPDwgL1R5cGUgL1BhZ2VzIC9LaWRzIFszIDAgUiA0IDAgUl0gL0NvdW50IDIgPj4KZW5kb2JqCjMgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAyMDAgMTAwXSAvQ29udGVudHMgNSAwIFIgPj4KZW5kb2JqCjQgMCBvYmoKPDwgL1R5cGUgL1BhZ2UgL1BhcmVudCAyIDAgUiAvTWVkaWFCb3ggWzAgMCAzMDAgMTUwXSAvQ29udGVudHMgNiAwIFIgPj4KZW5kb2JqCjUgMCBvYmoKPDwgL0xlbmd0aCAxOCA+PgpzdHJlYW0KMC41IDAuNSAxMCAxMCByZSBmCmVuZHN0cmVhbQplbmRvYmoKNiAwIG9iago8PCAvTGVuZ3RoIDE4ID4+CnN0cmVhbQowLjIgMC4yIDIwIDIwIHJlIGYKZW5kc3RyZWFtCmVuZG9iagp4cmVmCjAgNwowMDAwMDAwMDAwIDY1NTM1IGYgCjAwMDAwMDAwMDkgMDAwMDAgbiAKMDAwMDAwMDA1OCAwMDAwMCBuIAowMDAwMDAwMTIxIDAwMDAwIG4gCjAwMDAwMDAyMDggMDAwMDAgbiAKMDAwMDAwMDI5NSAwMDAwMCBuIAowMDAwMDAwMzYzIDAwMDAwIG4gCnRyYWlsZXIKPDwgL1NpemUgNyAvUm9vdCAxIDAgUiA+PgpzdGFydHhyZWYKNDMxCiUlRU9GCg=="
  let template = "{\"basePdf\":\"data:application/pdf;base64," + base + "\",\"schemas\":[[{\"name\":\"a\",\"type\":\"text\",\"content\":\"One\",\"position\":{\"x\":1,\"y\":1},\"width\":20,\"height\":5}],[{\"name\":\"b\",\"type\":\"text\",\"content\":\"Two\",\"position\":{\"x\":1,\"y\":1},\"width\":20,\"height\":5}]]}"
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.pages, 2)
  let document = @core.open_single(result.bdf)
  assert_eq(document.manifest.views[0].pages.length(), 2)
  assert_eq(document.manifest.views[0].pages[0].width, 200.0)
  assert_eq(document.manifest.views[0].pages[1].width, 300.0)
  assert_eq(document.manifest.views[0].pages[0].layers.length(), 2)
  assert_eq(document.manifest.views[0].pages[1].layers.length(), 2)
  let text = pdfme_text(result.bdf)
  assert_true(text.contains("One"), msg=text)
  assert_true(text.contains("Two"), msg=text)
}

///|
test "pdfme places JPEG images" {
  let data = "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDi6KKK+ZP3E//Z"
  let template = "{\"basePdf\":{\"width\":40,\"height\":40},\"schemas\":[[{\"name\":\"logo\",\"type\":\"image\",\"readOnly\":true,\"content\":\"data:image/jpeg;base64," + data + "\",\"position\":{\"x\":5,\"y\":5},\"width\":20,\"height\":20}]]}"
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let mut images = 0
  for part in document.manifest.parts {
    if part.kind == "img" {
      images += 1
    }
  }
  assert_eq(images, 1)
  let native = template.replace(old="\"objectFit\":\"cover\"", new="\"objectFit\":\"none\"")
  let native_result = fill(@utf8.encode(native), @utf8.encode("{}"))
  assert_eq(native_result.warnings.length(), 0)
}

///|
test "pdfme draws a signature box" {
  let template =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"sig","type":"signature","position":{"x":5,"y":5},"width":50,"height":10,"opacity":0.5}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.ops.length() > 5)
  let commands = @render.decode_commands(
    document.part(document.manifest.parts[0].hash),
  ) catch {
    _ => fail("signature commands cannot be decoded")
  }
  assert_true(
    commands.any(fn(command) {
      match command {
        @render.Alpha(value) => (value - 0.5).abs() < 0.001
        _ => false
      }
    }),
  )
}

///|
test "pdfme draws radio groups" {
  let template =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"choice","type":"radioGroup","direction":"row","options":["One","Two"],"position":{"x":10,"y":10},"width":60,"height":20}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{\"choice\":\"Two\"}"))
  assert_eq(result.warnings.length(), 0)
  let text = pdfme_text(result.bdf)
  assert_true(text.contains("One"), msg=text)
  assert_true(text.contains("Two"), msg=text)
}

///|
test "pdfme draws dashed rectangles" {
  let template =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"box","type":"rectangle","position":{"x":10,"y":10},"width":50,"height":20,"borderColor":"#000000","borderWidth":0.5,"borderStyle":"dashed","opacity":0.5}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.ops.length() > 5)
  let commands = @render.decode_commands(
    document.part(document.manifest.parts[0].hash),
  ) catch {
    _ => fail("rectangle commands cannot be decoded")
  }
  assert_true(
    commands.any(fn(command) {
      match command {
        @render.Alpha(value) => (value - 0.5).abs() < 0.001
        _ => false
      }
    }),
  )
}

///|
test "pdfme draws dashed lines" {
  let template =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"line","type":"line","position":{"x":10,"y":10},"width":50,"height":1,"color":"#000000","borderStyle":"dashed"}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.ops.length() > 2)
}

///|
test "pdfme falls back from a non-positive font size" {
  let template =
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"text","type":"text","position":{"x":10,"y":10},"width":60,"height":10,"fontSize":0,"opacity":0.5}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{\"text\":\"Alice\"}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let resources = @core.decode_object_resources(
    document.part(document.manifest.parts[0].hash),
  )
  assert_true(resources.object.strings.contains("Alice"))
  let commands = @render.decode_commands(
    document.part(document.manifest.parts[0].hash),
  ) catch {
    _ => fail("text commands cannot be decoded")
  }
  assert_true(
    commands.any(fn(command) {
      match command {
        @render.Alpha(value) => (value - 0.5).abs() < 0.001
        _ => false
      }
    }),
  )
}

///|
test "pdfme falls back from non-positive table fonts" {
  let template =
    #|{"basePdf":{"width":120,"height":80},"schemas":[[{"name":"lines","type":"table","position":{"x":10,"y":10},"width":100,"height":40,"head":["item"],"fontSize":0,"columnStyles":[{"fontSize":0}],"rowHeight":0,"cellPadding":-2,"opacity":0.5}]]}
  let data = #|{"lines":[{"item":"Pen"}]}
  let result = fill(@utf8.encode(template), @utf8.encode(data))
  assert_eq(result.warnings.length(), 0)
  let text = pdfme_text(result.bdf)
  assert_true(text.contains("Pen"), msg=text)
  let document = @core.open_single(result.bdf)
  let commands = @render.decode_commands(
    document.part(document.manifest.parts[0].hash),
  ) catch {
    _ => fail("table commands cannot be decoded")
  }
  assert_true(
    commands.any(fn(command) {
      match command {
        @render.Alpha(value) => (value - 0.5).abs() < 0.001
        _ => false
      }
    }),
  )
}

///|
test "pdfme falls back from non-positive table widths" {
  let template =
    #|{"basePdf":{"width":120,"height":80},"schemas":[[{"name":"lines","type":"table","position":{"x":10,"y":10},"width":100,"height":40,"head":["item","qty"],"headWidthPercentages":[-1,0],"fontSize":9,"rowHeight":8,"cellPadding":2,"borderWidth":-1}]]}
  let data = #|{"lines":[{"item":"Pen","qty":2}]}
  let result = fill(@utf8.encode(template), @utf8.encode(data))
  assert_eq(result.warnings.length(), 0)
  let text = pdfme_text(result.bdf)
  assert_true(text.contains("Pen"), msg=text)
  assert_true(text.contains("2"), msg=text)
}

///|
test "pdfme honors the QR error correction level" {
  let template =
    #|{"basePdf":{"width":80,"height":80},"schemas":[[{"name":"code","type":"qrcode","readOnly":true,"content":"HELLO","errorCorrectionLevel":"H","minVersion":5,"maxVersion":5,"mask":3,"mode":"Byte","opacity":0.5,"position":{"x":10,"y":10},"width":30,"height":30}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  assert_true(document.manifest.parts.length() > 0)
  let commands = @render.decode_commands(
    document.part(document.manifest.parts[0].hash),
  ) catch {
    _ => fail("QR commands cannot be decoded")
  }
  assert_true(
    commands.any(fn(command) {
      match command {
        @render.Alpha(value) => (value - 0.5).abs() < 0.001
        _ => false
      }
    }),
  )
}

///|
test "pdfme applies checkbox opacity" {
  let template =
    #|{"basePdf":{"width":60,"height":40},"schemas":[[{"name":"check","type":"checkbox","position":{"x":10,"y":10},"width":8,"height":8,"opacity":0.5}]]}
  let result = fill(@utf8.encode(template), @utf8.encode("{\"check\":true}"))
  assert_eq(result.warnings.length(), 0)
  let document = @core.open_single(result.bdf)
  let commands = @render.decode_commands(
    document.part(document.manifest.parts[0].hash),
  ) catch {
    _ => fail("checkbox commands cannot be decoded")
  }
  assert_true(
    commands.any(fn(command) {
      match command {
        @render.Alpha(value) => (value - 0.5).abs() < 0.001
        _ => false
      }
    }),
  )
}

