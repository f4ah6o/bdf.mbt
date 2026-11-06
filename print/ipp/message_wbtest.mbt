///|
fn ipp_attr(message : Message, group_tag : Tag, name : String) -> Attribute? {
  for group in message.groups {
    if group.tag == group_tag {
      for attribute in group.attrs {
        if attribute.name == name {
          return Some(attribute)
        }
      }
    }
  }
  None
}

///|
test "ipp request round trip" {
  let request = new_request(OP_PRINT_JOB, 7, "", "")
  request.add(TAG_JOB, [
    attr("copies", [integer(2)]),
    attr("job-name", [name("hello")]),
    attr("sides", [keyword("one-sided"), keyword("two-sided-long-edge")]),
  ])
  let data = request.encode()
  let back = decode(data)
  assert_eq(back.major, 2)
  assert_eq(back.minor, 0)
  assert_eq(back.code, OP_PRINT_JOB)
  assert_eq(back.request_id, 7)
  assert_eq(back.groups.length(), 2)
  assert_eq(back.groups[0].tag, TAG_OPERATION)
  assert_eq(back.groups[1].tag, TAG_JOB)
  let charset_attr = ipp_attr(back, TAG_OPERATION, "attributes-charset")
  assert_true(charset_attr is Some(_))
  match charset_attr {
    Some(attribute) => {
      assert_eq(attribute.values[0].str, "utf-8")
      assert_eq(attribute.values[0].tag, TAG_CHARSET)
    }
    None => fail("missing charset")
  }
  let copies = ipp_attr(back, TAG_JOB, "copies")
  match copies {
    Some(attribute) => {
      assert_eq(attribute.values.length(), 1)
      assert_eq(attribute.values[0].int, 2)
      assert_eq(attribute.values[0].tag, TAG_INTEGER)
    }
    None => fail("missing copies")
  }
  let sides = ipp_attr(back, TAG_JOB, "sides")
  match sides {
    Some(attribute) => {
      assert_eq(attribute.values.length(), 2)
      assert_eq(attribute.values[1].str, "two-sided-long-edge")
    }
    None => fail("missing sides")
  }
}

///|
test "ipp value types" {
  let request = new_request(OP_VALIDATE_JOB, 9, "utf-8", "ja")
  request.add(TAG_JOB, [
    attr("resolution", [resolution(300, 600, 3)]),
    attr("range", [range(1, 99)]),
    attr("text", [text_lang("ja", "こんにちは")]),
    attr("octets", [octet_string(Bytes::from_array([1, 2, 3]))]),
    attr("date", [date_time(Bytes::from_array([0x07, 0xe8, 1, 2, 3, 4, 5, 6, 7, 8, 9]))]),
    attr("flag", [boolean(true)]),
  ])
  let back = decode(request.encode())
  let resolution_attr = ipp_attr(back, TAG_JOB, "resolution")
  match resolution_attr {
    Some(attribute) =>
      match attribute.values[0].res {
        Some((x, y, units)) => {
          assert_eq(x, 300)
          assert_eq(y, 600)
          assert_eq(units, 3)
        }
        None => fail("missing resolution")
      }
    None => fail("missing resolution attribute")
  }
  let range_attr = ipp_attr(back, TAG_JOB, "range")
  match range_attr {
    Some(attribute) =>
      match attribute.values[0].range {
        Some((lo, hi)) => {
          assert_eq(lo, 1)
          assert_eq(hi, 99)
        }
        None => fail("missing range")
      }
    None => fail("missing range attribute")
  }
  let text_attr = ipp_attr(back, TAG_JOB, "text")
  match text_attr {
    Some(attribute) => {
      assert_eq(attribute.values[0].lang, "ja")
      assert_eq(attribute.values[0].str, "こんにちは")
    }
    None => fail("missing text")
  }
  let octets = ipp_attr(back, TAG_JOB, "octets")
  match octets {
    Some(attribute) => assert_eq(attribute.values[0].raw.to_array().length(), 3)
    None => fail("missing octets")
  }
  let flag = ipp_attr(back, TAG_JOB, "flag")
  match flag {
    Some(attribute) => assert_true(attribute.values[0].bool())
    None => fail("missing boolean")
  }
}

///|
test "ipp errors" {
  let empty_name = try {
    ignore(Message::encode({ ..new_request(OP_PRINT_JOB, 1, "", ""), groups: [{ tag: TAG_OPERATION, attrs: [{ name: "", values: [integer(1)] }] }] }))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(empty_name, msg="an empty attribute name")
  let truncated = try {
    ignore(decode(Bytes::from_array([2, 0, 0, 2, 0, 0, 0, 1])))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(truncated, msg="a cut message")
  let bad_group = try {
    ignore(Message::encode({ ..new_request(OP_PRINT_JOB, 1, "", ""), groups: [{ tag: TAG_END, attrs: [] }] }))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(bad_group, msg="a non-group tag")
}
///|
test "ipp collections" {
  let request = new_request(OP_PRINT_JOB, 11, "", "")
  request.add(TAG_JOB, [
    attr("media-col", [
      collection([
        attr("media-size", [
          collection([
            attr("x-dimension", [integer(21000)]),
            attr("y-dimension", [integer(29700)]),
          ]),
        ]),
        attr("media-type", [keyword("stationery")]),
      ]),
    ]),
  ])
  let back = decode(request.encode())
  let media = ipp_attr(back, TAG_JOB, "media-col")
  match media {
    Some(attribute) =>
      match attribute.values[0].coll {
        Some(members) => {
          assert_eq(members.length(), 2)
          assert_eq(members[0].name, "media-size")
          match members[0].values[0].coll {
            Some(size) => {
              assert_eq(size.length(), 2)
              assert_eq(size[0].name, "x-dimension")
              assert_eq(size[0].values[0].int, 21000)
              assert_eq(size[1].name, "y-dimension")
              assert_eq(size[1].values[0].int, 29700)
            }
            None => fail("missing media-size collection")
          }
          assert_eq(members[1].name, "media-type")
          assert_eq(members[1].values[0].str, "stationery")
        }
        None => fail("missing collection")
      }
    None => fail("missing media-col")
  }
}

///|
test "ipp decode limits" {
  let request = new_request(OP_PRINT_JOB, 1, "", "")
  let data = request.encode()
  assert_eq(default_limits().max_bytes, 4 * 1024 * 1024)
  let too_big = try {
    ignore(decode_with(data, { ..default_limits(), max_bytes: 8 }))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(too_big, msg="the message bytes")
  let too_many_attributes = try {
    ignore(decode_with(data, { ..default_limits(), max_attributes: 1 }))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(too_many_attributes, msg="the attributes")
  let two_values = new_request(OP_PRINT_JOB, 1, "", "")
  two_values.add(TAG_JOB, [attr("sides", [keyword("a"), keyword("b")])])
  let too_many_values = try {
    ignore(decode_with(two_values.encode(), { ..default_limits(), max_values: 1 }))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(too_many_values, msg="the values")
  let nested = new_request(OP_PRINT_JOB, 1, "", "")
  nested.add(TAG_JOB, [
    attr("media-col", [collection([attr("media-size", [collection([attr("x", [integer(1)])])])])]),
  ])
  let too_deep = try {
    ignore(decode_with(nested.encode(), { ..default_limits(), max_depth: 1 }))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(too_deep, msg="the depth")
  let too_long = try {
    ignore(decode_with(data, { ..default_limits(), max_value_bytes: 1 }))
    false
  } catch {
    IppError(_) => true
  }
  assert_true(too_long, msg="a value")
}

