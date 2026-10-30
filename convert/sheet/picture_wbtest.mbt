///|
test "invalid picture geometry reports an error instead of indexing outside the sheet" {
  let context : GridDrawContext = {
    tiles: [],
    indexes: Map([]),
    width: 10.0,
    height: 10.0,
    document_language: "",
  }
  let writer = @core.DocumentWriter::new()
  let picture : GridPicture = {
    kind: 0,
    from_row: 0,
    from_column: 0,
    to_row: 0,
    to_column: 0,
    from_x_offset: 0.0,
    from_y_offset: 0.0,
    to_x_offset: 0.0,
    to_y_offset: 0.0,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    description: "",
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
  let invalid = [
    { ..picture, kind: 3, },
    { ..picture, rotation: 21600001, },
    { ..picture, frame_width: 1.0, frame_height: 0.0, },
    { ..picture, frame_width: -1.0, frame_height: 1.0, },
    {
      ..picture,
      kind: 2,
      width: 100.0,
      height: 100.0,
      frame_width: 1.0e-320,
      frame_height: 1.0,
    },
    { ..picture, from_row: -1, },
    { ..picture, from_row: 2147483647, },
    { ..picture, alpha: Some(2.0F), },
    { ..picture, fill_left: -0.1, },
    { ..picture, fill_left: 0.6, fill_right: 0.6, },
    { ..picture, from_column: 2, },
    { ..picture, to_row: 2, },
    { ..picture, to_column: -1, },
  ]
  for value in invalid {
    let result = Ok(
      context.paint_picture(
        writer,
        value,
        [0.0, 10.0],
        [0.0, 10.0],
        10.0,
        None,
        16384,
      ),
    ) catch {
      error => Err(error)
    }
    match result {
      Err(InvalidArgument(_)) => ()
      _ => fail("expected an invalid picture argument")
    }
  }
}

///|
test "deferred picture children must refer to a grid tile" {
  let writer = @core.DocumentWriter::new()
  let grid : DrawnGrid = {
    geometry: {
      columns: [{ count: 1, size: 10.0F, }],
      rows: [{ count: 1, size: 10.0F, }],
      frozen_rows: 0,
    },
    tiles: [],
  }
  let named : NamedGrid = {
    id: "sheet1",
    title: "Sheet",
    grid,
    gridlines: true,
    frozen_columns: 0,
  }
  let result = Ok(
    store_grids(writer, [named], false, picture_children=[[(0, 0, b"child")]]),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(InvalidArgument(_)) => ()
    _ => fail("expected a missing picture child tile error")
  }
}

///|
test "picture tiles reject coordinates outside the integer range" {
  let context : GridDrawContext = {
    tiles: [],
    indexes: Map([]),
    width: 5000000000000.0,
    height: 10.0,
    document_language: "",
  }
  let writer = @core.DocumentWriter::new()
  let picture : GridPicture = {
    kind: 2,
    from_row: 0,
    from_column: 0,
    to_row: 0,
    to_column: 0,
    from_x_offset: 0.0,
    from_y_offset: 0.0,
    to_x_offset: 0.0,
    to_y_offset: 0.0,
    x: 4800000000000.0,
    y: 0.0,
    width: 10.0,
    height: 10.0,
    description: "",
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
  let result = Ok(
    context.paint_picture(
      writer,
      picture,
      [0.0, 10.0],
      [0.0, 10.0],
      context.width,
      None,
      16384,
    ),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(InvalidArgument(_)) => ()
    _ => fail("expected an out-of-range picture tile error")
  }
}

///|
test "pictures respect their cumulative tile budget" {
  let context : GridDrawContext = {
    tiles: [],
    indexes: Map([]),
    width: 10.0,
    height: 10.0,
    document_language: "",
  }
  let writer = @core.DocumentWriter::new()
  let picture : GridPicture = {
    kind: 2,
    from_row: 0,
    from_column: 0,
    to_row: 0,
    to_column: 0,
    from_x_offset: 0.0,
    from_y_offset: 0.0,
    to_x_offset: 0.0,
    to_y_offset: 0.0,
    x: 0.0,
    y: 0.0,
    width: 1.0,
    height: 1.0,
    description: "",
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
  let result = Ok(
    context.paint_picture(
      writer,
      picture,
      [0.0, 10.0],
      [0.0, 10.0],
      10.0,
      None,
      0,
    ),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(InvalidArgument(_)) => ()
    _ => fail("expected a picture tile budget error")
  }
}
