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
