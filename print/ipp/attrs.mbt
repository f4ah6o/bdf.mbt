///|
/// The first group of the tag.
pub fn Message::group(self : Message, tag : Tag) -> Group? {
  for group in self.groups {
    if group.tag == tag {
      return Some(group)
    }
  }
  None
}

///|
/// The first attribute of the name in the first group of the tag.
pub fn Message::attr(self : Message, tag : Tag, name : String) -> Attribute? {
  match self.group(tag) {
    Some(group) => group.get(name)
    None => None
  }
}

///|
/// The first attribute of the name.
pub fn Group::get(self : Group, name : String) -> Attribute? {
  for attribute in self.attrs {
    if attribute.name == name {
      return Some(attribute)
    }
  }
  None
}

///|
/// The first member of a collection with the name.
pub fn find_attr(members : Array[Attribute], name : String) -> Attribute? {
  for member in members {
    if member.name == name {
      return Some(member)
    }
  }
  None
}

///|
pub fn Attribute::first(self : Attribute) -> Value? {
  if self.values.length() == 0 {
    None
  } else {
    Some(self.values[0])
  }
}

///|
pub fn Attribute::strings(self : Attribute) -> Array[String] {
  let out : Array[String] = []
  for value in self.values {
    if tag_is_string(value.tag) ||
      value.tag == TAG_TEXT_LANG ||
      value.tag == TAG_NAME_LANG ||
      value.tag == TAG_OCTET_STRING {
      out.push(value.str)
    }
  }
  out
}

///|
pub fn Attribute::text(self : Attribute) -> String {
  let values = self.strings()
  if values.length() > 0 {
    values[0]
  } else {
    ""
  }
}

///|
pub fn Attribute::has(self : Attribute, value : String) -> Bool {
  for item in self.strings() {
    if item == value {
      return true
    }
  }
  false
}

///|
pub fn Attribute::ints(self : Attribute) -> Array[Int] {
  let out : Array[Int] = []
  for value in self.values {
    if value.tag == TAG_INTEGER || value.tag == TAG_ENUM || value.tag == TAG_BOOLEAN {
      out.push(value.int)
    }
  }
  out
}

///|
pub fn Attribute::int(self : Attribute) -> Int? {
  let values = self.ints()
  if values.length() > 0 {
    Some(values[0])
  } else {
    None
  }
}

///|
pub fn Attribute::bool(self : Attribute) -> Bool? {
  match self.int() {
    Some(value) => Some(value != 0)
    None => None
  }
}

///|
pub fn Attribute::collections(self : Attribute) -> Array[Array[Attribute]] {
  let out : Array[Array[Attribute]] = []
  for value in self.values {
    if value.tag == TAG_BEGIN_COLLECTION {
      match value.coll {
        Some(members) => out.push(members)
        None => out.push([])
      }
    }
  }
  out
}

///|
pub fn Attribute::resolutions(self : Attribute) -> Array[(Int, Int, Int)] {
  let out : Array[(Int, Int, Int)] = []
  for value in self.values {
    if value.tag == TAG_RESOLUTION {
      match value.res {
        Some(resolution) => out.push(resolution)
        None => ()
      }
    }
  }
  out
}

///|
pub fn Attribute::ranges(self : Attribute) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  for value in self.values {
    if value.tag == TAG_RANGE {
      match value.range {
        Some(range) => out.push(range)
        None => ()
      }
    }
  }
  out
}

///|
pub fn Attribute::out_of_band(self : Attribute) -> Tag? {
  match self.first() {
    Some(value) => if tag_is_out_of_band(value.tag) { Some(value.tag) } else { None }
    None => None
  }
}
