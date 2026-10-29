///|
/// A feature tag grouped across records of a single OpenType layout table.
pub(all) struct FeatureGroup {
  table : String
  tag : String
  lookups : Array[Int32]
  scripts : Array[String]
  mut ui_name : String
  characters : Array[Int32]
}

///|
/// Group GSUB and GPOS features in table order, preserving the first occurrence
/// of each lookup, script/language system and feature-parameter character.
pub fn FileFace::feature_groups(self : FileFace) -> Array[FeatureGroup] {
  let groups : Array[FeatureGroup] = []
  let seen_lookups : Array[Map[Int32, Bool]] = []
  let seen_scripts : Array[Map[String, Bool]] = []
  let seen_characters : Array[Map[Int32, Bool]] = []
  let names = self.specimen_names()
  for table in ["GSUB", "GPOS"] {
    guard self.font.table(table) is Some(data) else { continue }
    guard @otlayout.parse_layout(data[:], gpos=table == "GPOS") is Some(layout) else {
      continue
    }
    let by_tag : Map[String, Int32] = Map([])
    let users = layout.script_features()
    for i, feature in layout.features {
      let index = match by_tag.get(feature.tag) {
        Some(index) => index
        None => {
          let index = groups.length()
          by_tag[feature.tag] = index
          groups.push({
            table,
            tag: feature.tag,
            lookups: [],
            scripts: [],
            ui_name: "",
            characters: [],
          })
          seen_lookups.push(Map([]))
          seen_scripts.push(Map([]))
          seen_characters.push(Map([]))
          index
        }
      }
      let group = groups[index]
      for lookup in feature.lookups {
        if !seen_lookups[index].contains(lookup) {
          seen_lookups[index][lookup] = true
          group.lookups.push(lookup)
        }
      }
      for script in users[i] {
        if !seen_scripts[index].contains(script) {
          seen_scripts[index][script] = true
          group.scripts.push(script)
        }
      }
      if feature.ui_name != 0 && group.ui_name == "" {
        group.ui_name = names.best(feature.ui_name)
      }
      for character in feature.characters {
        if !seen_characters[index].contains(character) {
          seen_characters[index][character] = true
          group.characters.push(character)
        }
      }
    }
  }
  groups
}

///|
fn feature_split_user(user : String) -> (String, String) {
  let script = StringBuilder()
  let language = StringBuilder()
  let mut found = false
  for c in user {
    if c == '/' && !found {
      found = true
    } else if found {
      language.write_char(c)
    } else {
      script.write_char(c)
    }
  }
  (font_trim(script.to_string()), language.to_string())
}

///|
/// Compact feature users in their original order, as in the specimen detail.
pub fn FeatureGroup::script_list(self : FeatureGroup) -> String {
  let order : Array[String] = []
  let langs : Map[String, Array[String]] = Map([])
  for user in self.scripts {
    let (script, language) = feature_split_user(user)
    if !langs.contains(script) {
      order.push(script)
      langs[script] = []
    }
    langs[script].push(
      if language == "" {
        "default"
      } else {
        font_trim(language)
      },
    )
  }
  let out : Array[String] = []
  for script in order {
    let languages = langs[script]
    if languages.length() == 1 && languages[0] == "default" {
      out.push(script)
    } else {
      out.push(script + " (" + languages.join(", ") + ")")
    }
  }
  out.join(", ")
}

///|
/// Unique script tags without their language systems, in first-seen order.
pub fn FeatureGroup::script_tags(self : FeatureGroup) -> String {
  let out : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  for user in self.scripts {
    let (script, _) = feature_split_user(user)
    if !seen.contains(script) {
      seen[script] = true
      out.push(script)
    }
  }
  out.join(" ")
}

///|
/// Name used by the feature summary, preferring a font-provided UI name.
pub fn FeatureGroup::display_name(self : FeatureGroup) -> String {
  if self.ui_name != "" {
    self.ui_name
  } else {
    @otlayout.feature_name(self.tag)
  }
}

///|
/// Explain whether the feature is applied automatically by text shapers.
pub fn FeatureGroup::default_note(self : FeatureGroup) -> String {
  match @otlayout.feature_default(self.tag) {
    1 => "on by default"
    2 => "applied by the script's shaper"
    3 => "in vertical text"
    _ => ""
  }
}
