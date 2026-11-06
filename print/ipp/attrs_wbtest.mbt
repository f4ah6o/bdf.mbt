///|
test "ipp attribute helpers" {
  let request = new_request(OP_PRINT_JOB, 3, "", "")
  request.add(TAG_JOB, [
    attr("copies", [integer(2)]),
    attr("sides", [keyword("one-sided"), keyword("two-sided-long-edge")]),
    attr("resolution", [resolution(300, 600, 3)]),
    attr("range", [range(1, 9)]),
    attr("media-col", [collection([attr("media-type", [keyword("stationery")])])]),
    attr("unsupported", [out_of_band(TAG_UNSUPPORTED)]),
  ])
  let back = decode(request.encode())
  assert_true(back.group(TAG_JOB) is Some(_))
  assert_true(back.group(TAG_PRINTER) is None)
  let copies = back.attr(TAG_JOB, "copies")
  match copies {
    Some(attribute) => {
      assert_eq(attribute.int(), Some(2))
      assert_eq(attribute.ints(), [2])
      assert_eq(attribute.text(), "")
    }
    None => fail("missing copies")
  }
  let sides = back.attr(TAG_JOB, "sides")
  match sides {
    Some(attribute) => {
      assert_eq(attribute.text(), "one-sided")
      assert_eq(attribute.strings().length(), 2)
      assert_true(attribute.has("two-sided-long-edge"))
      assert_true(!attribute.has("duplex"))
    }
    None => fail("missing sides")
  }
  let resolution_attr = back.attr(TAG_JOB, "resolution")
  match resolution_attr {
    Some(attribute) => assert_eq(attribute.resolutions(), [(300, 600, 3)])
    None => fail("missing resolution")
  }
  let range_attr = back.attr(TAG_JOB, "range")
  match range_attr {
    Some(attribute) => assert_eq(attribute.ranges(), [(1, 9)])
    None => fail("missing range")
  }
  let media = back.attr(TAG_JOB, "media-col")
  match media {
    Some(attribute) => {
      let collections = attribute.collections()
      assert_eq(collections.length(), 1)
      match find_attr(collections[0], "media-type") {
        Some(member) => assert_eq(member.text(), "stationery")
        None => fail("missing media-type")
      }
    }
    None => fail("missing media-col")
  }
  let unsupported = back.attr(TAG_JOB, "unsupported")
  match unsupported {
    Some(attribute) => assert_eq(attribute.out_of_band(), Some(TAG_UNSUPPORTED))
    None => fail("missing unsupported")
  }
  assert_true(back.attr(TAG_JOB, "missing") is None)
}
