///|
/// Font faces defined by an OOXML major or minor theme font scheme.
pub(all) struct OoxmlFontScheme {
  mut latin : String
  mut east_asian : String
  mut complex : String
  scripts : Map[String, String]
}

///|
/// Major and minor theme fonts.
pub(all) struct OoxmlThemeFonts {
  major : OoxmlFontScheme
  minor : OoxmlFontScheme
}

///|
fn ooxml_font_attr(
  element : @xml.NamespaceElement,
  name : String,
  fallback : String,
) -> String {
  for attr in element.attributes {
    if attr.name.local_name == name {
      return attr.value
    }
  }
  fallback
}

///|
fn ooxml_default_theme_fonts() -> OoxmlThemeFonts {
  {
    major: {
      latin: "Calibri Light",
      east_asian: "",
      complex: "",
      scripts: Map([]),
    },
    minor: { latin: "Calibri", east_asian: "", complex: "", scripts: Map([]), },
  }
}

///|
fn ooxml_read_theme_fonts(data : Bytes) -> OoxmlThemeFonts raise {
  let text = @utf8.decode_lossy(data[:], ignore_bom=true)
  if text.contains("<!ENTITY") {
    raise InvalidOoxml("ooxml: the part declares entities")
  }
  let reader = @xml.NamespaceReader::from_string(text)
  let result = ooxml_default_theme_fonts()
  let mut depth = 0
  let mut elements_depth = -1
  let mut fonts_depth = -1
  let mut scheme_depth = -1
  let mut scheme : OoxmlFontScheme? = None
  let seen : Map[String, Bool] = Map([])
  while true {
    let event = reader.read_event()
    match event.kind {
      Start(element) | Empty(element) => {
        let name = element.name.local_name
        if depth == 1 && name == "themeElements" && !seen.contains("elements") {
          seen["elements"] = true
          if event.kind is Start(_) {
            elements_depth = depth + 1
          }
        } else if depth == elements_depth &&
          name == "fontScheme" &&
          !seen.contains("fonts") {
          seen["fonts"] = true
          if event.kind is Start(_) {
            fonts_depth = depth + 1
          }
        } else if depth == fonts_depth &&
          (name == "majorFont" || name == "minorFont") &&
          !seen.contains(name) {
          seen[name] = true
          scheme = Some(
            if name == "majorFont" {
              result.major
            } else {
              result.minor
            },
          )
          seen.remove("latin")
          seen.remove("ea")
          seen.remove("cs")
          if event.kind is Start(_) {
            scheme_depth = depth + 1
          }
        } else if depth == scheme_depth {
          if scheme is Some(s) {
            if name == "font" {
              s.scripts[ooxml_font_attr(element, "script", "")] = ooxml_font_attr(
                element, "typeface", "",
              )
            } else if (name == "latin" || name == "ea" || name == "cs") &&
              !seen.contains(name) {
              seen[name] = true
              if name == "latin" {
                s.latin = ooxml_font_attr(element, "typeface", s.latin)
              } else if name == "ea" {
                s.east_asian = ooxml_font_attr(element, "typeface", "")
              } else {
                s.complex = ooxml_font_attr(element, "typeface", "")
              }
            }
          }
        }
        if event.kind is Start(_) {
          depth += 1
        } else if depth == 0 {
          break
        }
      }
      End(_) => {
        depth -= 1
        if depth + 1 == elements_depth {
          elements_depth = -1
        }
        if depth + 1 == fonts_depth {
          fonts_depth = -1
        }
        if depth + 1 == scheme_depth {
          scheme_depth = -1
          scheme = None
        }
        if depth == 0 {
          break
        }
      }
      Eof =>
        if depth == 0 {
          break
        } else {
          raise InvalidOoxml("ooxml: unexpected EOF")
        }
      _ => ()
    }
  }
  result
}

///|
/// Load theme fonts related to a workbook, presentation or document part.
pub fn OoxmlPackage::theme_fonts(
  self : OoxmlPackage,
  part : String,
) -> OoxmlThemeFonts {
  let relationship = match self.relationship_of_type(part, "/theme") {
    Some(r) => r
    None => return ooxml_default_theme_fonts()
  }
  let data = self.read(relationship.target) catch {
    _ => return ooxml_default_theme_fonts()
  }
  ooxml_read_theme_fonts(data) catch {
    _ => ooxml_default_theme_fonts()
  }
}

///|
/// Resolve a theme font reference and an optional script tag.
pub fn OoxmlThemeFonts::resolve(
  self : OoxmlThemeFonts,
  typeface : String,
  script : String,
) -> String {
  let bytes = @utf8.encode(typeface)
  if bytes.length() < 4 || bytes[0] != b'+' {
    return typeface
  }
  let scheme = if bytes[1] == b'm' && bytes[2] == b'j' {
    self.major
  } else {
    self.minor
  }
  match @utf8.decode_lossy(bytes[3:]) {
    "-lt" => scheme.latin
    "-ea" =>
      if scheme.east_asian != "" {
        scheme.east_asian
      } else {
        scheme.scripts.get(script).unwrap_or("")
      }
    "-cs" =>
      if scheme.complex != "" {
        scheme.complex
      } else {
        scheme.scripts.get(script).unwrap_or("")
      }
    _ => typeface
  }
}
