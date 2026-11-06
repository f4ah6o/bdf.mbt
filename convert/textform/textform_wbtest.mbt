///|
test "textform renders a fixed view" {
  let data : Map[String, Json] = { "name": Json::string("A") }
  let image = @textform.fill_image(data, "Hello {{name}}!")
  let bytes = render(image, "Greeting")
  let document = @core.open_single(bytes)
  let mut has_text = false
  let mut has_obj = false
  let mut has_idx = false
  for part in document.manifest.parts {
    if part.kind == "text" {
      has_text = true
    } else if part.kind == "obj" {
      has_obj = true
    } else if part.kind == "idx" {
      has_idx = true
    }
  }
  assert_true(has_text, msg="the text part")
  assert_true(has_obj, msg="the page object")
  assert_true(has_idx, msg="the text index")
  assert_eq(document.manifest.views.length(), 1)
  let view = document.manifest.views[0]
  assert_eq(view.id, "pages")
  assert_eq(view.kind, "fixed")
  assert_eq(view.title, "Greeting")
  assert_eq(view.pages.length(), 1)
  assert_eq(view.pages[0].width, 576.0)
  assert_eq(view.pages[0].height, 792.0)
  assert_eq(view.pages[0].layers.length(), 1)
  assert_eq(view.pages[0].layers[0].role, "body")
  let back = @textpart.from_document(bytes)
  assert_eq(back.pages.length(), 1)
  assert_eq(back.pages[0].lines[0].text, "Hello A!")
}

///|
test "textform renders paper and tall lines" {
  let data : Map[String, Json] = Map([])
  let template = "{{#preprinted}}\nrule\n{{/preprinted}}\n{{#_big}}\nbig\n{{/_big}}\n"
  let image = @textform.fill_image(data, template)
  let bytes = render(image, "")
  let document = @core.open_single(bytes)
  let view = document.manifest.views[0]
  assert_eq(view.pages[0].layers.length(), 2)
  assert_eq(view.pages[0].layers[0].role, "background")
  assert_eq(view.pages[0].layers[1].role, "body")
  let back = @textpart.from_document(bytes)
  assert_eq(back.pages[0].lines[0].text, "rule")
  assert_eq(back.pages[0].lines[1].text, "big")
  assert_eq(back.pages[0].lines[1].size[0].size, @textpart.SIZE_BIG)
}
///|
test "textform uses the front matter font" {
  let template = "---\nfont: \"Gen\"\n---\nHello\n"
  let image = @textform.fill_image(Map([]), template)
  let bytes = render(image, "")
  let document = @core.open_single(bytes)
  let page = document.manifest.views[0].pages[0]
  let resources = @core.decode_object_resources(document.part(page.layers[0].object))
  assert_eq(resources.fonts.length(), 1)
  assert_eq(resources.fonts[0].family, "Gen")
}

///|
test "textform converts from data sources" {
  let source : @data.Source = {
    name: "",
    file_name: "data.json",
    data: @utf8.encode("{\"name\":\"Alice\"}"),
  }
  let result = convert_sources("Hello {{name}}", [source], "Source")
  let document = @core.open_single(result.bdf)
  let mut text = ""
  for view in document.manifest.views {
    match view.text_index {
      Some(hash) => {
        for run in @core.decode_text_index(document.part(hash)) {
          text = text + run.text
        }
      }
      None => ()
    }
  }
  assert_true(text.contains("Hello Alice"), msg=text)
}
///|
test "textform converts from YAML sources" {
  let source : @data.Source = {
    name: "",
    file_name: "data.yaml",
    data: @utf8.encode("name: Alice\n"),
  }
  let result = convert_sources("Hello {{name}}", [source], "YAML")
  let document = @core.open_single(result.bdf)
  let mut text = ""
  for view in document.manifest.views {
    match view.text_index {
      Some(hash) => {
        for run in @core.decode_text_index(document.part(hash)) {
          text = text + run.text
        }
      }
      None => ()
    }
  }
  assert_true(text.contains("Hello Alice"), msg=text)
}

