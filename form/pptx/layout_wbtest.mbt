///|
test "form pptx renders slide text with a layout" {
  let content_types =
    #|<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/><Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/><Override PartName="/ppt/slideLayouts/slideLayout1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideLayout+xml"/><Override PartName="/ppt/slideMasters/slideMaster1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slideMaster+xml"/></Types>
  let rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/></Relationships>
  let presentation =
    #|<?xml version="1.0"?><p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst><p:sldSz cx="12192000" cy="6858000"/></p:presentation>
  let presentation_rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="slideMasters/slideMaster1.xml"/></Relationships>
  let slide =
    #|<?xml version="1.0"?><p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree><p:sp><p:nvSpPr><p:cNvPr id="2" name="Text"/><p:cNvSpPr/><p:nvPr/></p:nvSpPr><p:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="2000000" cy="1000000"/></a:xfrm></p:spPr><p:txBody><a:p><a:r><a:t>{{name}}</a:t></a:r></a:p></p:txBody></p:sp></p:spTree></p:cSld></p:sld>
  let slide_rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>
  let layout =
    #|<?xml version="1.0"?><p:sldLayout xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><p:cSld><p:spTree/></p:cSld><p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr></p:sldLayout>
  let layout_rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideMaster" Target="../slideMasters/slideMaster1.xml"/></Relationships>
  let master =
    #|<?xml version="1.0"?><p:sldMaster xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><p:cSld><p:spTree/></p:cSld><p:clrMap accent1="accent1" accent2="accent2" accent3="accent3" accent4="accent4" accent5="accent5" accent6="accent6" bg1="lt1" bg2="lt2" folHlink="folHlink" hlink="hlink" tx1="dk1" tx2="dk2"/><p:sldLayoutIdLst><p:sldLayoutId id="2147483649" r:id="rId1"/></p:sldLayoutIdLst></p:sldMaster>
  let master_rels =
    #|<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slideLayout" Target="../slideLayouts/slideLayout1.xml"/></Relationships>
  let zipped = @ooxml.stored_zip([
    ("[Content_Types].xml", @utf8.encode(content_types)),
    ("_rels/.rels", @utf8.encode(rels)),
    ("ppt/presentation.xml", @utf8.encode(presentation)),
    ("ppt/_rels/presentation.xml.rels", @utf8.encode(presentation_rels)),
    ("ppt/slides/slide1.xml", @utf8.encode(slide)),
    ("ppt/slides/_rels/slide1.xml.rels", @utf8.encode(slide_rels)),
    ("ppt/slideLayouts/slideLayout1.xml", @utf8.encode(layout)),
    ("ppt/slideLayouts/_rels/slideLayout1.xml.rels", @utf8.encode(layout_rels)),
    ("ppt/slideMasters/slideMaster1.xml", @utf8.encode(master)),
    ("ppt/slideMasters/_rels/slideMaster1.xml.rels", @utf8.encode(master_rels)),
  ])
  let filled = fill_bytes(zipped, @utf8.encode("{\"name\":\"Alice\"}"))
  let result = @pptx.convert(filled)
  let document = @core.open_single(result.bdf)
  let mut text = ""
  for page in document.manifest.views[0].pages {
    for layer in page.layers {
      let resources = @core.decode_object_resources(document.part(layer.object))
      for value in resources.object.strings {
        text = text + value
      }
    }
  }
  assert_true(text.contains("Alice"), msg=text + " warnings=" + result.warnings.join(";"))
}

