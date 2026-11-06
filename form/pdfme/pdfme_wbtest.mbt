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
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"sig","type":"signature","position":{"x":5,"y":5},"width":50,"height":10}]]}
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
    #|{"basePdf":{"width":120,"height":80},"schemas":[[{"name":"lines","type":"table","position":{"x":10,"y":10},"width":100,"height":40,"head":["item","qty"],"fontSize":9,"rowHeight":8}]]}
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
    #|{"basePdf":{"width":100,"height":50},"schemas":[[{"name":"logo","type":"image","position":{"x":10,"y":10},"width":20,"height":20}]]}
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
    #|{"basePdf":{"width":120,"height":80},"schemas":[[{"name":"lines","type":"table","position":{"x":10,"y":10},"width":100,"height":40,"head":["item","qty","note"],"headWidthPercentages":[50,20,30],"fontSize":9,"rowHeight":8}]]}
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
    #|{"basePdf":{"width":120,"height":80},"schemas":[[{"name":"lines","type":"table","position":{"x":10,"y":10},"width":100,"height":40,"head":["item","qty"],"headStyles":{"alignment":"center","fontSize":12,"height":10,"backgroundColor":"#E6E6E6","fontColor":"#333333"},"columnStyles":[{"alignment":"center","fontColor":"#FF0000"},{"alignment":"right"}],"fontSize":9,"rowHeight":8}]]}
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

