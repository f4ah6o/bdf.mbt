///|
/// A pitched MusicXML note's written and sounding attributes.
pub(all) struct MusicXmlPitchNote {
  pitch : @music.Pitch
  sounding_key : Int32
  accidental : Int32
  cautionary : Bool
  head : Int32
  tie_start : Bool
  tie_stop : Bool
  sound_tie_start : Bool
  sound_tie_stop : Bool
  tab_string : Int32
  tab_fret : Int32
  has_alteration : Bool
  has_accidental : Bool
}

///|
/// Read the pitch, ties, accidentals and authored TAB position of a note.
/// Returns None for rests or notes without a pitched element.
pub fn musicxml_pitch_note(
  node : MusicXmlNode,
  transpose~ : Int32 = 0,
) -> MusicXmlPitchNote? {
  if node.child("rest") is Some(_) {
    return None
  }
  let pitch_node = match node.child("pitch") {
    Some(pitch) => pitch
    None => return None
  }
  let step = match pitch_node.child_text("step").to_upper() {
    "D" => 1
    "E" => 2
    "F" => 3
    "G" => 4
    "A" => 5
    "B" => 6
    _ => 0
  }
  let (raw_alter, _) = musicxml_float(pitch_node.child_text("alter"))
  let alter = musicxml_round(Double::min(Double::max(raw_alter, -4.0), 4.0)).to_int()
  let (raw_octave, valid_octave) = musicxml_integer(
    pitch_node.child_text("octave"),
  )
  let octave = if valid_octave {
    Int64::min(Int64::max(raw_octave, -1L), 9L).to_int()
  } else {
    4
  }
  let pitch : @music.Pitch = {
    step,
    alter: Int32::min(Int32::max(alter, -2), 2),
    octave,
  }
  let sounding_key = (octave + 1) * 12 +
    [0, 2, 4, 5, 7, 9, 11][step] +
    alter +
    transpose
  let acc_node = node.child("accidental")
  let (accidental, cautionary) = match acc_node {
    None => (1, false)
    Some(acc) =>
      (
        musicxml_accidental(musicxml_trim(acc.text), pitch.alter),
        acc.attribute("cautionary") == "yes" ||
        acc.attribute("parentheses") == "yes" ||
        acc.attribute("editorial") == "yes" ||
        acc.attribute("bracket") == "yes",
      )
  }
  let head = if ["x", "cross"].contains(node.child_text("notehead")) {
    1
  } else {
    0
  }
  let mut sound_start = false
  let mut sound_stop = false
  let mut draw_start = false
  let mut draw_stop = false
  let mut has_tie = false
  let mut tab_string = -1
  let mut tab_fret = -1
  for item in node.children {
    if item.name == "tie" {
      has_tie = true
      if item.attribute("type") == "start" {
        sound_start = true
      } else if item.attribute("type") == "stop" {
        sound_stop = true
      }
    } else if item.name == "notations" {
      for child in item.children {
        if child.name == "tied" {
          match child.attribute("type") {
            "start" => draw_start = true
            "stop" => draw_stop = true
            "continue" => {
              draw_start = true
              draw_stop = true
            }
            _ => ()
          }
        } else if child.name == "technical" {
          let (str, str_ok) = musicxml_integer(child.child_text("string"))
          let (fret, fret_ok) = musicxml_integer(child.child_text("fret"))
          if str_ok &&
            fret_ok &&
            str >= 1L &&
            str <= 6L &&
            fret >= 0L &&
            fret <= 24L {
            tab_string = str.to_int()
            tab_fret = fret.to_int()
          }
        }
      }
    }
  }
  if !has_tie {
    sound_start = draw_start
    sound_stop = draw_stop
  }
  Some({
    pitch,
    sounding_key,
    accidental,
    cautionary,
    head,
    tie_start: sound_start || draw_start,
    tie_stop: sound_stop || draw_stop,
    sound_tie_start: sound_start,
    sound_tie_stop: sound_stop,
    tab_string,
    tab_fret,
    has_alteration: alter != 0,
    has_accidental: acc_node is Some(_),
  })
}
