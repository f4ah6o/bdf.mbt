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
    to_row: 1,
    to_column: 1,
    x: 0.0,
    y: 0.0,
    width: 0.0,
    height: 0.0,
    description: "",
    image: b"",
  }
  let invalid = [
    { ..picture, kind: 3, },
    { ..picture, from_row: -1, },
    { ..picture, from_column: 2, },
    { ..picture, to_row: 2, },
    { ..picture, to_column: -1, },
    { ..picture, kind: 2, x: -1.0, },
  ]
  for value in invalid {
    let result = Ok(
      context.paint_picture(writer, value, [0.0, 10.0], [0.0, 10.0], 10.0, None),
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
    x: 4800000000000.0,
    y: 0.0,
    width: 10.0,
    height: 10.0,
    description: "",
    image: b"",
  }
  let result = Ok(
    context.paint_picture(
      writer,
      picture,
      [0.0, 10.0],
      [0.0, 10.0],
      context.width,
      None,
    ),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(InvalidArgument(_)) => ()
    _ => fail("expected an out-of-range picture tile error")
  }
}
