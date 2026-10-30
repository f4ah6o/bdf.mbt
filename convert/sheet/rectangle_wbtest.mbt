///|
test "solid rectangle bytes match the upstream drawing" {
  let context : GridDrawContext = {
    tiles: [],
    indexes: Map([]),
    width: 21.0,
    height: 28.5,
    document_language: "",
  }
  let picture : GridPicture = {
    kind: 0,
    from_row: 0,
    from_column: 0,
    to_row: 2,
    to_column: 2,
    from_x_offset: 0.0,
    from_y_offset: 0.0,
    to_x_offset: 0.0,
    to_y_offset: 0.0,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    description: "example",
    image: b"",
    alpha: None,
    fill_left: 0.0,
    fill_top: 0.0,
    fill_right: 0.0,
    fill_bottom: 0.0,
    crop_left: 0.0,
    crop_top: 0.0,
    crop_right: 0.0,
    crop_bottom: 0.0,
    image_width: 0.0,
    image_height: 0.0,
    flip_horizontal: false,
    flip_vertical: false,
    rotation: 0,
    frame_width: 0.0,
    frame_height: 0.0,
  }
  let pending : Array[(Int32, Int32, Bytes)] = []
  let count = context.paint_picture(
    @core.DocumentWriter::new(),
    picture,
    [0.0, 14.25, 28.5, 42.75],
    [0.0, 10.5, 21.0, 31.5],
    21.0,
    Some(pending),
    16384,
    shape_fill=Some(0xff0000ffU),
  )
  assert_eq(count, 1)
  assert_eq(pending.length(), 1)
  let (_, _, bytes) = pending[0]
  assert_eq(
    bytes, b"\x42\x4f\x42\x4a\x01\x00\x00\x00\x00\x00\xb2\xc1\x00\x00\xb2\xc1\x00\x00\x83\x42\x00\x00\x92\x42\x02\x07\x65\x78\x61\x6d\x70\x6c\x65\x00\x01\x00\x05\x00\x01\x01\x01\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xa8\x41\x00\x00\x00\x00\x00\x00\xa8\x41\x00\x00\xe4\x41\x00\x00\x00\x00\x00\x00\xe4\x41\x00\x00\x00\x00\x10\x71\x0a\x00\x01\x10\xff\x00\x00\xff\x22\x00\x00\x02\x71\x0b\x01",
  )
}

///|
test "rotated rectangle bytes match the upstream drawing" {
  let context : GridDrawContext = {
    tiles: [],
    indexes: Map([]),
    width: 96.0,
    height: 42.75,
    document_language: "",
  }
  let picture : GridPicture = {
    kind: 0,
    from_row: 0,
    from_column: 0,
    to_row: 3,
    to_column: 2,
    from_x_offset: 0.0,
    from_y_offset: 0.0,
    to_x_offset: 0.0,
    to_y_offset: 0.0,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    description: "example",
    image: b"",
    alpha: None,
    fill_left: 0.0,
    fill_top: 0.0,
    fill_right: 0.0,
    fill_bottom: 0.0,
    crop_left: 0.0,
    crop_top: 0.0,
    crop_right: 0.0,
    crop_bottom: 0.0,
    image_width: 0.0,
    image_height: 0.0,
    flip_horizontal: false,
    flip_vertical: false,
    rotation: 12345,
    frame_width: 0.0,
    frame_height: 0.0,
  }
  let pending : Array[(Int32, Int32, Bytes)] = []
  let count = context.paint_picture(
    @core.DocumentWriter::new(),
    picture,
    [0.0, 14.25, 28.5, 42.75, 57.0],
    [0.0, 48.0, 96.0, 144.0],
    96.0,
    Some(pending),
    16384,
    shape_fill=Some(0xff0000ffU),
  )
  assert_eq(count, 1)
  assert_eq(pending.length(), 1)
  let (_, _, bytes) = pending[0]
  assert_eq(
    bytes, b"\x42\x4f\x42\x4a\x01\x00\x00\x00\x00\x00\x60\xc2\x00\x00\x60\xc2\x00\x00\x50\x43\x00\xc0\x1a\x43\x02\x07\x65\x78\x61\x6d\x70\x6c\x65\x00\x01\x00\x05\x00\x01\x01\x01\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x42\x00\x00\x00\x00\x00\x00\xc0\x42\x00\x00\x2b\x42\x00\x00\x00\x00\x00\x00\x2b\x42\x00\x00\x00\x00\x29\x71\x0a\x00\x01\x03\x94\xff\x7f\x3f\x1b\x57\x6b\x3b\x1b\x57\x6b\xbb\x94\xff\x7f\x3f\x72\xd5\x9d\x3d\x33\x5d\x30\xbe\x10\xff\x00\x00\xff\x22\x00\x00\x02\x71\x0b\x01",
  )
}

///|
test "stroked rectangle bytes match the upstream drawing" {
  let context : GridDrawContext = {
    tiles: [],
    indexes: Map([]),
    width: 96.0,
    height: 42.75,
    document_language: "",
  }
  let picture : GridPicture = {
    kind: 0,
    from_row: 0,
    from_column: 0,
    to_row: 3,
    to_column: 2,
    from_x_offset: 0.0,
    from_y_offset: 0.0,
    to_x_offset: 0.0,
    to_y_offset: 0.0,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    description: "example",
    image: b"",
    alpha: None,
    fill_left: 0.0,
    fill_top: 0.0,
    fill_right: 0.0,
    fill_bottom: 0.0,
    crop_left: 0.0,
    crop_top: 0.0,
    crop_right: 0.0,
    crop_bottom: 0.0,
    image_width: 0.0,
    image_height: 0.0,
    flip_horizontal: false,
    flip_vertical: false,
    rotation: 12345,
    frame_width: 0.0,
    frame_height: 0.0,
  }
  let pending : Array[(Int32, Int32, Bytes)] = []
  let count = context.paint_picture(
    @core.DocumentWriter::new(),
    picture,
    [0.0, 14.25, 28.5, 42.75, 57.0],
    [0.0, 48.0, 96.0, 144.0],
    96.0,
    Some(pending),
    16384,
    shape_fill=Some(0xff0000ffU),
    shape_stroke=Some((0x000000ffU, 0.5)),
  )
  assert_eq(count, 1)
  assert_eq(pending.length(), 1)
  let (_, _, bytes) = pending[0]
  assert_eq(
    bytes, b"\x42\x4f\x42\x4a\x01\x00\x00\x00\x00\x00\x60\xc2\x00\x00\x60\xc2\x00\x00\x50\x43\x00\xc0\x1a\x43\x02\x07\x65\x78\x61\x6d\x70\x6c\x65\x00\x01\x00\x05\x00\x01\x01\x01\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x42\x00\x00\x00\x00\x00\x00\xc0\x42\x00\x00\x2b\x42\x00\x00\x00\x00\x00\x00\x2b\x42\x00\x00\x00\x00\x3d\x71\x0a\x00\x01\x03\x94\xff\x7f\x3f\x1b\x57\x6b\x3b\x1b\x57\x6b\xbb\x94\xff\x7f\x3f\x72\xd5\x9d\x3d\x33\x5d\x30\xbe\x10\xff\x00\x00\xff\x22\x00\x00\x01\x14\x00\x00\x00\x3f\x00\x00\x00\x00\x00\x41\x12\xff\x00\x00\x00\x23\x00\x02\x02\x71\x0b\x01",
  )
}

///|
test "transparent rectangle bytes match the upstream drawing" {
  let context : GridDrawContext = {
    tiles: [],
    indexes: Map([]),
    width: 96.0,
    height: 42.75,
    document_language: "",
  }
  let picture : GridPicture = {
    kind: 0,
    from_row: 0,
    from_column: 0,
    to_row: 3,
    to_column: 2,
    from_x_offset: 0.0,
    from_y_offset: 0.0,
    to_x_offset: 0.0,
    to_y_offset: 0.0,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    description: "example",
    image: b"",
    alpha: None,
    fill_left: 0.0,
    fill_top: 0.0,
    fill_right: 0.0,
    fill_bottom: 0.0,
    crop_left: 0.0,
    crop_top: 0.0,
    crop_right: 0.0,
    crop_bottom: 0.0,
    image_width: 0.0,
    image_height: 0.0,
    flip_horizontal: false,
    flip_vertical: false,
    rotation: 12345,
    frame_width: 0.0,
    frame_height: 0.0,
  }
  let pending : Array[(Int32, Int32, Bytes)] = []
  let count = context.paint_picture(
    @core.DocumentWriter::new(),
    picture,
    [0.0, 14.25, 28.5, 42.75, 57.0],
    [0.0, 48.0, 96.0, 144.0],
    96.0,
    Some(pending),
    16384,
    shape_fill=Some(0xff000000U),
  )
  assert_eq(count, 1)
  assert_eq(pending.length(), 1)
  let (_, _, bytes) = pending[0]
  assert_eq(
    bytes, b"\x42\x4f\x42\x4a\x01\x00\x00\x00\x00\x00\x60\xc2\x00\x00\x60\xc2\x00\x00\x50\x43\x00\xc0\x1a\x43\x02\x07\x65\x78\x61\x6d\x70\x6c\x65\x00\x01\x00\x05\x00\x01\x01\x01\x04\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xc0\x42\x00\x00\x00\x00\x00\x00\xc0\x42\x00\x00\x2b\x42\x00\x00\x00\x00\x00\x00\x2b\x42\x00\x00\x00\x00\x29\x71\x0a\x00\x01\x03\x94\xff\x7f\x3f\x1b\x57\x6b\x3b\x1b\x57\x6b\xbb\x94\xff\x7f\x3f\x72\xd5\x9d\x3d\x33\x5d\x30\xbe\x10\x00\x00\x00\xff\x22\x00\x00\x02\x71\x0b\x01",
  )
}
