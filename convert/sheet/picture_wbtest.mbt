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
      context.paint_picture(writer, value, [0.0, 10.0], [0.0, 10.0]),
    ) catch {
      error => Err(error)
    }
    match result {
      Err(InvalidArgument(_)) => ()
      _ => fail("expected an invalid picture argument")
    }
  }
}
