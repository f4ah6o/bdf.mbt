///|
#export_name("roundtrip_object")
pub fn roundtrip_object(data : Bytes) -> Bytes {
  try! @core.encode_object_resources(@core.decode_object_resources(data))
}

///|
#export_name("roundtrip_paths")
pub fn roundtrip_paths(data : Bytes) -> Bytes {
  try! @core.encode_path_collection(@core.decode_path_collection(data))
}

///|
#export_name("build_object")
pub fn build_object() -> Bytes {
  let object = @core.ObjectBuilder::new()
  let font = object.add_font({
    hash: None,
    family: "\u{feff}Example",
    weight: 700,
    style: 1,
  })
  let image = object.add_image("0123456789abcdef0123456789abcdef")
  object.save()
  object.translate(2.0F, 3.0F)
  object.clip_rect(1.0F, 2.0F, 3.0F, 4.0F)
  object.fill_color(0x12345678U)
  try! object.font(font, 11.0F)
  object.text_style(0, 0, 1, 0.5F)
  object.mark(1, "\u{feff}cell")
  object.fill_text("\u{feff}hello", 10.0F, 20.0F, 30.0F)
  object.stroke_text("hello", -5.0F, 4.0F, -2.0F)
  object.fill_rect(2.0F, 3.0F, -4.0F, 6.0F)
  object.stroke_rect(1.0F, 2.0F, 3.0F, 4.0F)
  object.clear_rect(-100.0F, -100.0F, 1.0F, 1.0F)
  try! object.image(image, 5.0F, 6.0F, 7.0F, 8.0F)
  object.restore()
  try! object.encode()
}

///|
#export_name("build_complete_object")
pub fn build_complete_object() -> Bytes {
  let hash = "0123456789abcdef0123456789abcdef"
  let object = @core.ObjectBuilder::new()
  object.set_bbox(-20.0F, -10.0F, 300.0F, 200.0F)
  let path : @core.Path = {
    verbs: b"\x00\x01\x02\x03\x04\x05\x06\x07\x08",
    coordinates: [
      1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, -1.0,
      -2.0, 3.0, 4.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 1.0, 1.0, 2.0, 3.0, 4.0,
      5.0, 1.0, 2.0, 3.0, 4.0, 5.0,
    ],
  }
  let p = object.add_path(Inline(path))
  let ext = object.add_path(External(hash, 128))
  let linear = object.add_paint(
    Gradient(0, [1.0, 2.0, 3.0, 4.0], [
      { offset: 0.0, color: 0xff0000ffU.reinterpret_as_int(), },
      { offset: 1.0, color: 0x00123456, },
    ]),
  )
  ignore(object.add_paint(Gradient(1, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0], [])))
  ignore(object.add_paint(Gradient(2, [1.0, 2.0, 3.0], [])))
  ignore(object.add_paint(Pattern(0, 2, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0])))
  let font = object.add_font({
    hash: None,
    family: "\u{feff}Example sans",
    weight: 700,
    style: 1,
  })
  ignore(
    object.add_font({ hash: Some(hash), family: "", weight: 400, style: 0, }),
  )
  let image = object.add_image(hash)
  let child = object.add_object(hash, (1.0F, 2.0F, 3.0F, 4.0F))
  object.save()
  object.transform(1.0F, 2.0F, 3.0F, 4.0F, 5.0F, 6.0F)
  object.translate(10.0F, 11.0F)
  object.scale(2.0F, 3.0F)
  try! object.clip_path(p, 1)
  object.clip_rect(1.0F, 2.0F, 3.0F, 4.0F)
  object.fill_color(0x12345678U)
  try! object.fill_paint(linear)
  object.stroke_color(0xabcdefffU)
  try! object.stroke_paint(linear)
  object.line(2.0F, 1, 2, 4.0F)
  object.dash([1.0F, 2.0F, 3.0F], 0.5F)
  object.alpha(0.5F)
  object.blend(2)
  object.shadow(0xff0000ffU, 1.0F, 2.0F, 3.0F)
  object.filter("blur(2px)")
  try! object.font(font, 12.0F)
  object.text_style(0, 0, 1, 0.0F)
  object.fill_rect(1.0F, 2.0F, 3.0F, 4.0F)
  object.stroke_rect(2.0F, 3.0F, 4.0F, 5.0F)
  try! object.fill_path(p, 0)
  try! object.stroke_path(ext)
  try! object.fill_path_at(p, 1, 2.0F, 3.0F)
  try! object.fill_path_run(0, [
    { path: p, x: 1.0F, y: 2.0F, },
    { path: ext, x: 3.0F, y: 4.0F, },
  ])
  object.clear_rect(1.0F, 2.0F, 3.0F, 4.0F)
  object.fill_text("\u{feff}日本語", 10.0F, 20.0F, 30.0F)
  object.stroke_text("ABC", 4.0F, 5.0F, 6.0F)
  try! object.image(image, 1.0F, 2.0F, 3.0F, 4.0F)
  try! object.image_sub(image, 1.0F, 2.0F, 3.0F, 4.0F, 5.0F, 6.0F, 7.0F, 8.0F)
  object.smoothing(true, 2)
  try! object.use_object(child)
  try! object.use_object_at(child, 10.0F, 20.0F)
  object.group_begin(0.8F, 1, 1.0F, 2.0F, 3.0F, 4.0F)
  object.mask_begin(0, 0xffU, b"\x00\x01\x02")
  object.mask_end()
  object.group_end()
  object.link(1.0F, 2.0F, 3.0F, 4.0F, "https://example.com")
  object.mark(1, "x")
  object.ext(b"\x01\x02\x03")
  object.restore()
  try! object.encode()
}

///|
#export_name("build_auto_object")
pub fn build_auto_object() -> Bytes {
  let hash = "0123456789abcdef0123456789abcdef"
  let object = @core.ObjectBuilder::new()
  let path = object.add_path(
    Inline({
      verbs: b"\x00\x03\x06",
      coordinates: [
        -4.0, 2.0, 5.0, 6.0, 8.0, -10.0, 12.0, 15.0, 3.0, 4.0, 2.0, 6.0, 0.0, 0.0,
        1.0, 0.0,
      ],
    }),
  )
  let empty = object.add_path(Inline({ verbs: b"", coordinates: [], }))
  let external = object.add_path(External(hash, 0))
  try! object.fill_path(path, 0)
  try! object.fill_path_at(empty, 0, 50.0F, 60.0F)
  try! object.stroke_path(external)
  try! object.fill_path_run(0, [{ path, x: -20.0F, y: 10.0F, }])
  let child = object.add_object(hash, (-1.0F, -2.0F, 5.0F, 10.0F))
  try! object.use_object_at(child, 100.0F, -10.0F)
  try! object.encode()
}
