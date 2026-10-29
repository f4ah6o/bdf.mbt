///|
/// Text selected for the font specimen overview and waterfall.
pub(all) struct SamplePlan {
  primary : SampleScript?
  scripts : Array[SampleScript]
  specimen : String
  charset : Array[String]
  waterfall : String
  rtl : Bool
  lang : String
}

///|
/// Return all text drawn by the plan, for sample-font glyph reachability.
pub fn SamplePlan::all(self : SamplePlan) -> String {
  let out = StringBuilder()
  out.write_string(self.specimen)
  out.write_string(self.waterfall)
  for line in self.charset {
    out.write_string(line)
  }
  for script in self.scripts {
    out.write_string(script.text)
  }
  out.to_string()
}

///|
fn FileFace::sample_has(self : FileFace, text : String) -> Bool {
  for c in text {
    if c.to_int() > 32 {
      match self.font.glyph(c.to_int()) {
        Some(g) if g < self.font.metrics.glyph_count => ()
        _ => return false
      }
    }
  }
  true
}

///|
fn FileFace::design_languages(self : FileFace) -> String {
  let (design, _) = metadata_languages(self.font.table("meta").unwrap_or(b""))
  design
}

///|
fn choose_primary(
  covered : Array[SampleScript],
  design : String,
) -> SampleScript {
  for tag in design.split(", ") {
    let mut code = ""
    for part in tag.split("-") {
      code = part.to_owned()
    }
    for script in covered {
      if script.code.to_lower() == code.to_lower().replace(old="ſ", new="s") {
        return script
      }
    }
  }
  for script in covered {
    if script.code != "Latn" &&
      script.code != "Grek" &&
      script.code != "Cyrl" &&
      script.code != "Armn" &&
      script.code != "Geor" {
      return script
    }
  }
  covered[0]
}

///|
/// Select sample scripts and fallback characters as the upstream converter does.
/// An empty text uses the chosen script's default waterfall.
pub fn FileFace::sample_plan(self : FileFace, text : String) -> SamplePlan {
  let covered : Array[SampleScript] = []
  let mut han = false
  for script in sample_scripts() {
    let cjk = script.lang == "ja" ||
      script.lang == "zh-Hans" ||
      script.lang == "zh-Hant"
    if (cjk && han) ||
      !self.sample_has(script.text) ||
      !self.sample_has(script.specimen) {
      continue
    }
    han = han || cjk
    covered.push(script)
  }
  let mut specimen = ""
  let mut waterfall = ""
  let charset : Array[String] = []
  let mut rtl = false
  let mut lang = ""
  let primary = if covered.length() > 0 {
    let script = choose_primary(covered, self.design_languages())
    specimen = script.specimen
    waterfall = script.text
    rtl = script.rtl
    lang = script.lang
    for line in script.charset {
      if self.sample_has(line) {
        charset.push(line)
      }
    }
    Some(script)
  } else {
    let chars : Array[Char] = []
    for code in self.font.characters() {
      guard code.to_char() is Some(c) else { continue }
      if specimen_graphic(code) {
        chars.push(c)
      }
      if chars.length() == 48 {
        break
      }
    }
    if chars.length() > 0 {
      specimen = String::from_array(
        chars[:Int32::min(2, chars.length())].to_array(),
      )
      waterfall = String::from_array(
        chars[:Int32::min(24, chars.length())].to_array(),
      )
      for i = 0; i < chars.length() && charset.length() < 4; i = i + 12 {
        charset.push(
          String::from_array(
            chars[i:Int32::min(i + 12, chars.length())].to_array(),
          ),
        )
      }
    }
    None
  }
  if text != "" {
    waterfall = text
  }
  { primary, scripts: covered, specimen, charset, waterfall, rtl, lang, }
}
