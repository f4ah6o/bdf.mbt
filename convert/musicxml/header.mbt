///|
/// MIDI instrument information from a MusicXML part list.
pub(all) struct MusicXmlInstrument {
  id : String
  channel : Int32
  program : Int32
  unpitched : Int32
  volume : Int32
  pan : Int32
}

///|
/// One MusicXML part and its declared instruments.
pub(all) struct MusicXmlPartHeader {
  id : String
  name : String
  abbreviation : String
  track_name : String
  instruments : Array[MusicXmlInstrument]
}

///|
/// Credits and parts extracted from a MusicXML score header.
pub(all) struct MusicXmlHeader {
  title : String
  subtitle : String
  composer : String
  lyricist : String
  arranger : String
  rights : String
  parts : Array[MusicXmlPartHeader]
  warnings : Array[String]
}

///|
priv struct MusicXmlCredit {
  text : String
  size : Double
  centered : Bool
  right : Bool
}

///|
fn MusicXmlNode::attribute(self : MusicXmlNode, name : String) -> String {
  self.attr(name).unwrap_or("")
}

///|
fn MusicXmlNode::child_text(self : MusicXmlNode, name : String) -> String {
  match self.child(name) {
    Some(child) => musicxml_trim(child.text)
    None => ""
  }
}

///|
fn musicxml_collapse(text : String) -> String {
  let out = StringBuilder()
  let mut started = false
  let mut pending = false
  for c in text {
    if c.is_whitespace() {
      if started {
        pending = true
      }
    } else {
      if pending {
        out.write_char(' ')
        pending = false
      }
      out.write_char(c)
      started = true
    }
  }
  out.to_string()
}

///|
fn musicxml_accidental_text(text : String) -> String {
  match text {
    "sharp" => "#"
    "flat" => "b"
    "double-sharp" | "sharp-sharp" => "##"
    "flat-flat" | "double-flat" => "bb"
    _ => ""
  }
}

///|
fn musicxml_display_name(part : MusicXmlNode, name : String) -> String {
  let child = match part.child(name) {
    Some(node) => node
    None => return ""
  }
  if child.attribute("print-object") == "no" {
    return ""
  }
  match part.child(name + "-display") {
    Some(display) => {
      if display.attribute("print-object") == "no" {
        return ""
      }
      let out = StringBuilder()
      for node in display.children {
        if node.name == "display-text" {
          out.write_string(node.text)
        } else if node.name == "accidental-text" {
          out.write_string(musicxml_accidental_text(musicxml_trim(node.text)))
        }
      }
      let text = musicxml_collapse(out.to_string())
      if text != "" {
        return text
      }
    }
    None => ()
  }
  musicxml_collapse(child.text)
}

///|
fn musicxml_instrument(node : MusicXmlNode) -> MusicXmlInstrument {
  let (channel, c_ok) = musicxml_integer(node.child_text("midi-channel"))
  let (program, p_ok) = musicxml_integer(node.child_text("midi-program"))
  let (unpitched, u_ok) = musicxml_integer(node.child_text("midi-unpitched"))
  let (volume, v_ok) = musicxml_float(node.child_text("volume"))
  let (pan, pan_ok) = musicxml_float(node.child_text("pan"))
  {
    id: node.attribute("id"),
    channel: if c_ok && channel >= 1L && channel <= 16L {
      channel.to_int() - 1
    } else {
      -1
    },
    program: if p_ok && program >= 1L && program <= 128L {
      program.to_int() - 1
    } else {
      -1
    },
    unpitched: if u_ok && unpitched >= 1L && unpitched <= 128L {
      unpitched.to_int() - 1
    } else {
      -1
    },
    volume: if v_ok {
      Double::min(
        Double::max(musicxml_round(volume * 127.0 / 100.0), 0.0),
        127.0,
      ).to_int()
    } else {
      -1
    },
    pan: if pan_ok {
      let v = Double::min(Double::max(pan, -90.0), 90.0)
      Double::min(
        Double::max(musicxml_round((v + 90.0) * 127.0 / 180.0), 0.0),
        127.0,
      ).to_int()
    } else {
      -1
    },
  }
}

///|
fn musicxml_credit_size(text : String) -> Double {
  let lower = text.to_lower()
  if lower == "nan" {
    return 0.0 / 0.0
  }
  if lower == "inf" ||
    lower == "+inf" ||
    lower == "infinity" ||
    lower == "+infinity" {
    return 1.0 / 0.0
  }
  if lower == "-inf" || lower == "-infinity" {
    return -1.0 / 0.0
  }
  let (value, ok) = musicxml_float(text)
  if ok {
    return value
  }
  let _ = @string.parse_double(text) catch {
    error => {
      if error.to_string().contains("out of range") {
        return if text.has_prefix("-") { -1.0 / 0.0 } else { 1.0 / 0.0 }
      }
      return 0.0
    }
  }
  0.0
}

///|
/// Read credits, part names and instrument metadata from a score element.
pub fn musicxml_header(root : MusicXmlNode) -> MusicXmlHeader {
  let mut work_title = ""
  let mut movement_title = ""
  let mut rights = ""
  let credits : Map[String, String] = Map([])
  let creators : Map[String, String] = Map([])
  let untyped : Array[MusicXmlCredit] = []
  let parts : Array[MusicXmlPartHeader] = []
  let by_id : Map[String, Bool] = Map([])
  let warnings : Array[String] = []
  for node in root.children {
    match node.name {
      "work" => {
        let text = musicxml_collapse(node.child_text("work-title"))
        if text != "" {
          work_title = text
        }
      }
      "movement-title" => movement_title = musicxml_collapse(node.text)
      "identification" =>
        for child in node.children {
          if child.name == "creator" {
            let typ = if child.attribute("type") == "poet" {
              "lyricist"
            } else {
              child.attribute("type")
            }
            let text = musicxml_collapse(child.text)
            if text != "" && creators.get(typ).unwrap_or("") == "" {
              creators[typ] = text
            }
          } else if child.name == "rights" {
            let text = musicxml_collapse(child.text)
            if text != "" && rights == "" {
              rights = text
            }
          }
        }
      "credit" => {
        let words : Array[String] = []
        let mut first : MusicXmlNode? = None
        for child in node.children {
          if child.name == "credit-words" {
            if first is None {
              first = Some(child)
            }
            let text = musicxml_collapse(child.text)
            if text != "" {
              words.push(text)
            }
          }
        }
        let text = words.join(" ")
        if text == "" {
          continue
        }
        let mut typed = false
        for child in node.children {
          if child.name != "credit-type" {
            continue
          }
          typed = true
          let value = musicxml_trim(child.text).to_lower()
          let typ = if value == "poet" { "lyricist" } else { value }
          if ["title", "subtitle", "composer", "lyricist", "arranger", "rights"].contains(
              typ,
            ) &&
            credits.get(typ).unwrap_or("") == "" {
            credits[typ] = text
          }
        }
        if typed ||
          (node.attribute("page") != "" && node.attribute("page") != "1") {
          continue
        }
        if first is Some(first) {
          let size = musicxml_credit_size(first.attribute("font-size"))
          let just = if first.attribute("justify") == "" {
            first.attribute("halign")
          } else {
            first.attribute("justify")
          }
          untyped.push({
            text,
            size,
            centered: just == "center",
            right: just == "right",
          })
        }
      }
      "part-list" =>
        for child in node.children {
          if child.name != "score-part" {
            continue
          }
          let id = child.attribute("id")
          if by_id.contains(id) {
            continue
          }
          if parts.length() >= 256 {
            if warnings.is_empty() {
              warnings.push(
                "musicxml: more than 256 parts; the rest are left out",
              )
            }
            break
          }
          let name = musicxml_display_name(child, "part-name")
          let raw_name = musicxml_collapse(child.child_text("part-name"))
          let instruments = [
            for item in child.children if item.name == "midi-instrument" => {
              musicxml_instrument(item)
            }
          ]
          parts.push({
            id,
            name,
            abbreviation: musicxml_display_name(child, "part-abbreviation"),
            track_name: if raw_name == "" {
              name
            } else {
              raw_name
            },
            instruments,
          })
          by_id[id] = true
        }
      _ => ()
    }
  }
  let mut title = credits.get("title").unwrap_or("")
  let mut subtitle = credits.get("subtitle").unwrap_or("")
  if title == "" && work_title != "" {
    title = work_title
    if subtitle == "" && movement_title != "" && movement_title != work_title {
      subtitle = movement_title
    }
  } else if title == "" {
    title = movement_title
  }
  let mut composer = credits
    .get("composer")
    .unwrap_or(creators.get("composer").unwrap_or(""))
  let lyricist = credits
    .get("lyricist")
    .unwrap_or(creators.get("lyricist").unwrap_or(""))
  let arranger = credits
    .get("arranger")
    .unwrap_or(creators.get("arranger").unwrap_or(""))
  let rights = credits.get("rights").unwrap_or(rights)
  if title == "" {
    let mut largest = 0.0
    let mut found = false
    for credit in untyped {
      if credit.centered && (!found || credit.size > largest) {
        title = credit.text
        largest = credit.size
        found = true
      }
    }
  }
  if composer == "" {
    for credit in untyped {
      if credit.right {
        composer = credit.text
        break
      }
    }
  }
  { title, subtitle, composer, lyricist, arranger, rights, parts, warnings, }
}
