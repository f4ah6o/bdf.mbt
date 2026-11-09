///|
/// An audio conversion failure.
pub suberror AudioError {
  AudioInvalid(String)
}

///|
pub(all) struct AudioResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
/// The fields the readers of the formats gather; each format maps its own
/// tags onto them.
priv struct AudioTags {
  mut title : String
  mut subtitle : String
  mut grouping : String
  artists : Array[String]
  album_artists : Array[String]
  mut album : String
  composers : Array[String]
  lyricists : Array[String]
  conductors : Array[String]
  remixers : Array[String]
  mut genre : String
  mut track : String
  mut track_total : String
  mut disc : String
  mut disc_total : String
  mut year : String
  mut publisher : String
  mut copyright : String
  mut language : String
  mut isrc : String
  mut bpm : String
  mut comment : String
  mut lyrics : String
  mut synced_lyrics : Array[(Double, String)]
  chapters : Array[(Double, String)]
  mut cover : Bytes
  mut cover_format : String
  mut format : String
  mut codec : String
  mut duration : Double
  mut bitrate : Double
  mut sample_rate : Int32
  mut channels : Int32
}

///|
fn audio_tags() -> AudioTags {
  {
    title: "",
    subtitle: "",
    grouping: "",
    artists: [],
    album_artists: [],
    album: "",
    composers: [],
    lyricists: [],
    conductors: [],
    remixers: [],
    genre: "",
    track: "",
    track_total: "",
    disc: "",
    disc_total: "",
    year: "",
    publisher: "",
    copyright: "",
    language: "",
    isrc: "",
    bpm: "",
    comment: "",
    lyrics: "",
    synced_lyrics: [],
    chapters: [],
    cover: b"",
    cover_format: "",
    format: "",
    codec: "",
    duration: 0.0,
    bitrate: 0.0,
    sample_rate: 0,
    channels: 0,
  }
}

///|
fn audio_be16(data : Bytes, offset : Int32) -> Int32 {
  if offset < 0 || offset + 2 > data.length() { 0 } else {
    (data[offset].to_int() << 8) | data[offset + 1].to_int()
  }
}

///|
fn audio_be32(data : Bytes, offset : Int32) -> Int64 {
  if offset < 0 || offset + 4 > data.length() { 0L } else {
    (data[offset].to_int64() << 24) | (data[offset + 1].to_int64() << 16) |
    (data[offset + 2].to_int64() << 8) | data[offset + 3].to_int64()
  }
}

///|
fn audio_be64(data : Bytes, offset : Int32) -> Int64 {
  if offset < 0 || offset + 8 > data.length() { 0L } else {
    (data[offset].to_int64() << 56) | (data[offset + 1].to_int64() << 48) |
    (data[offset + 2].to_int64() << 40) | (data[offset + 3].to_int64() << 32) |
    (data[offset + 4].to_int64() << 24) | (data[offset + 5].to_int64() << 16) |
    (data[offset + 6].to_int64() << 8) | data[offset + 7].to_int64()
  }
}

///|
fn audio_le16(data : Bytes, offset : Int32) -> Int32 {
  if offset < 0 || offset + 2 > data.length() { 0 } else {
    data[offset].to_int() | (data[offset + 1].to_int() << 8)
  }
}

///|
fn audio_le32(data : Bytes, offset : Int32) -> Int64 {
  if offset < 0 || offset + 4 > data.length() { 0L } else {
    data[offset].to_int64() | (data[offset + 1].to_int64() << 8) |
    (data[offset + 2].to_int64() << 16) | (data[offset + 3].to_int64() << 24)
  }
}

///|
fn audio_le64(data : Bytes, offset : Int32) -> Int64 {
  if offset < 0 || offset + 8 > data.length() { 0L } else {
    data[offset].to_int64() | (data[offset + 1].to_int64() << 8) |
    (data[offset + 2].to_int64() << 16) | (data[offset + 3].to_int64() << 24) |
    (data[offset + 4].to_int64() << 32) | (data[offset + 5].to_int64() << 40) |
    (data[offset + 6].to_int64() << 48) | (data[offset + 7].to_int64() << 56)
  }
}

///|
fn audio_syncsafe(data : Bytes, offset : Int32) -> Int32 {
  ((data[offset].to_int() & 0x7f) << 21) |
  ((data[offset + 1].to_int() & 0x7f) << 14) |
  ((data[offset + 2].to_int() & 0x7f) << 7) |
  (data[offset + 3].to_int() & 0x7f)
}

///|
fn audio_latin1(data : Bytes) -> String {
  let out = StringBuilder()
  for byte in data {
    out.write_char(byte.to_char())
  }
  out.to_string()
}

///|
fn audio_starts_with(data : Bytes, offset : Int32, text : String) -> Bool {
  let bytes = @utf8.encode(text)
  if offset < 0 || offset + bytes.length() > data.length() {
    return false
  }
  for i in 0..<bytes.length() {
    if data[offset + i] != bytes[i] {
      return false
    }
  }
  true
}

///|
fn audio_clean(value : String) -> String {
  let cut = match value.find("\u{0000}") {
    Some(index) => value[:index].to_owned()
    None => value
  }
  let out = StringBuilder()
  for ch in cut.to_array() {
    let code = ch.to_int()
    if code == 0xfeff ||
      code == 0x7f ||
      (code < 0x20 && code != 10 && code != 9) ||
      (code >= 0x80 && code < 0xa0) {
      continue
    }
    out.write_char(ch)
  }
  out.to_string().trim().to_owned()
}

///|
/// A string a format stores without saying how it is encoded: UTF-8 when it
/// is valid UTF-8, else Latin-1.
fn audio_legacy_text(data : Bytes) -> String {
  let mut end = 0
  while end < data.length() && data[end] != 0 {
    end += 1
  }
  let raw = data[:end].to_owned()
  let text = @utf8.decode(raw) catch { _ => audio_latin1(raw) }
  audio_clean(text)
}

///|
fn audio_box_type(data : Bytes, offset : Int32) -> String {
  if offset < 0 || offset + 4 > data.length() {
    return ""
  }
  audio_latin1(data[offset:offset + 4].to_owned())
}

///|
fn audio_valid_frame_id(data : Bytes, offset : Int32) -> Bool {
  if offset < 0 || offset + 4 > data.length() {
    return false
  }
  for i in 0..<4 {
    let c = data[offset + i].to_int()
    if !((c >= 65 && c <= 90) || (c >= 48 && c <= 57)) {
      return false
    }
  }
  true
}

///|
fn audio_utf16_text(
  data : Bytes,
  offset : Int32,
  length : Int32,
  big : Bool,
) -> String {
  let end = (offset + length).min(data.length())
  if end <= offset {
    return ""
  }
  let slice = data[offset:end].to_owned()
  let encoding = if big { @utf16.Big } else { @utf16.Little }
  @utf16.decode_lossy(slice, endianness=encoding)
}

///|
fn audio_text(
  data : Bytes,
  offset : Int32,
  length : Int32,
  encoding : Int32,
) -> String {
  let end = (offset + length).min(data.length())
  if end <= offset {
    return ""
  }
  let raw = data[offset:end].to_owned()
  match encoding {
    0 => audio_latin1(raw)
    1 => audio_utf16_text(raw, 0, raw.length(), false)
    2 => audio_utf16_text(raw, 0, raw.length(), true)
    _ => @utf8.decode_lossy(raw, ignore_bom=true)
  }
}

///|
/// The values of a text frame: NUL separates several values in ID3v2.4, and
/// each value may join names with semicolons.
fn audio_text_values(
  data : Bytes,
  offset : Int32,
  length : Int32,
  encoding : Int32,
) -> Array[String] {
  let out : Array[String] = []
  let end = (offset + length).min(data.length())
  if end <= offset {
    return out
  }
  if encoding == 1 || encoding == 2 {
    let mut at = offset
    while at + 1 < end {
      let mut stop = at
      while stop + 1 < end {
        if data[stop] == 0 && data[stop + 1] == 0 {
          break
        }
        stop += 2
      }
      let value = audio_clean(audio_text(data, at, stop - at, encoding))
      if value != "" {
        out.push(value)
      }
      at = stop + 2
    }
  } else {
    let mut at = offset
    while at < end {
      let mut stop = at
      while stop < end && data[stop] != 0 {
        stop += 1
      }
      let value = audio_clean(audio_text(data, at, stop - at, encoding))
      if value != "" {
        out.push(value)
      }
      at = stop + 1
    }
  }
  out
}

///|
fn audio_cstring_end(data : Bytes, offset : Int32, encoding : Int32) -> Int32 {
  let mut i = offset
  if encoding == 1 || encoding == 2 {
    while i + 1 < data.length() {
      if data[i] == 0 && data[i + 1] == 0 {
        return i
      }
      i += 2
    }
  } else {
    while i < data.length() {
      if data[i] == 0 {
        return i
      }
      i += 1
    }
  }
  data.length()
}

///|
fn audio_clean_value(value : String) -> String {
  audio_clean(value)
}

///|
fn audio_split_people(values : Array[String]) -> Array[String] {
  let out : Array[String] = []
  for value in values {
    for part in value.split(";") {
      let name = audio_clean_value(part.to_owned())
      if name != "" {
        out.push(name)
      }
    }
  }
  out
}

///|
fn audio_push_unique(values : Array[String], value : String) -> Unit {
  let value = audio_clean_value(value)
  if value != "" && !values.contains(value) {
    values.push(value)
  }
}

///|
fn audio_push_all(values : Array[String], extra : Array[String]) -> Unit {
  for value in extra {
    audio_push_unique(values, value)
  }
}

///|
fn audio_first(values : Array[String]) -> String {
  if values.length() > 0 { values[0] } else { "" }
}

///|
fn audio_collapse_spaces(text : String) -> String {
  let out = StringBuilder()
  let mut space = false
  for part in text.split(" ") {
    let part = part.trim().to_owned()
    if part != "" {
      if space {
        out.write_char(' ')
      }
      out.write_string(part)
      space = true
    }
  }
  out.to_string()
}

///|
fn audio_parse_int_opt(text : String) -> Int32? {
  let value = @string.parse_int(text) catch { _ => return None }
  Some(value)
}

///|
/// Split "3/12" into its number and total ("3", "12").
fn audio_parse_number(value : String) -> (String, String) {
  let value = value.trim().to_owned()
  match value.find("/") {
    Some(index) => {
      (
        value[:index].to_owned().trim().to_owned(),
        value[index + 1:].to_owned().trim().to_owned(),
      )
    }
    None => (value, "")
  }
}

///|
fn audio_set_number(
  tags : AudioTags,
  is_track : Bool,
  value : String,
) -> Unit {
  let (number, total) = audio_parse_number(value)
  if is_track {
    if number != "" {
      tags.track = number
    }
    if total != "" {
      tags.track_total = total
    }
  } else {
    if number != "" {
      tags.disc = number
    }
    if total != "" {
      tags.disc_total = total
    }
  }
}

///|
let audio_genres : Array[String] = [
  "Blues", "Classic Rock", "Country", "Dance", "Disco", "Funk", "Grunge", "Hip-Hop", "Jazz", "Metal",
  "New Age", "Oldies", "Other", "Pop", "R&B", "Rap", "Reggae", "Rock", "Techno", "Industrial",
  "Alternative", "Ska", "Death Metal", "Pranks", "Soundtrack", "Euro-Techno", "Ambient", "Trip-Hop", "Vocal", "Jazz+Funk",
  "Fusion", "Trance", "Classical", "Instrumental", "Acid", "House", "Game", "Sound Clip", "Gospel", "Noise",
  "Alternative Rock", "Bass", "Soul", "Punk", "Space", "Meditative", "Instrumental Pop", "Instrumental Rock", "Ethnic", "Gothic",
  "Darkwave", "Techno-Industrial", "Electronic", "Pop-Folk", "Eurodance", "Dream", "Southern Rock", "Comedy", "Cult", "Gangsta",
  "Top 40", "Christian Rap", "Pop/Funk", "Jungle", "Native American", "Cabaret", "New Wave", "Psychedelic", "Rave", "Showtunes",
  "Trailer", "Lo-Fi", "Tribal", "Acid Punk", "Acid Jazz", "Polka", "Retro", "Musical", "Rock & Roll", "Hard Rock",
  "Folk", "Folk-Rock", "National Folk", "Swing", "Fast Fusion", "Bebop", "Latin", "Revival", "Celtic", "Bluegrass",
  "Avantgarde", "Gothic Rock", "Progressive Rock", "Psychedelic Rock", "Symphonic Rock", "Slow Rock", "Big Band", "Chorus", "Easy Listening", "Acoustic",
  "Humour", "Speech", "Chanson", "Opera", "Chamber Music", "Sonata", "Symphony", "Booty Bass", "Primus", "Porn Groove",
  "Satire", "Slow Jam", "Club", "Tango", "Samba", "Folklore", "Ballad", "Power Ballad", "Rhythmic Soul", "Freestyle",
  "Duet", "Punk Rock", "Drum Solo", "A cappella", "Euro-House", "Dance Hall", "Goa", "Drum & Bass", "Club-House", "Hardcore",
  "Terror", "Indie", "BritPop", "", "Polsk Punk", "Beat", "Christian Gangsta Rap", "Heavy Metal", "Black Metal", "Crossover",
  "Contemporary Christian", "Christian Rock", "Merengue", "Salsa", "Thrash Metal", "Anime", "JPop", "Synthpop", "Abstract", "Art Rock",
  "Baroque", "Bhangra", "Big Beat", "Breakbeat", "Chillout", "Downtempo", "Dub", "EBM", "Eclectic", "Electro",
  "Electroclash", "Emo", "Experimental", "Garage", "Global", "IDM", "Illbient", "Industro-Goth", "Jam Band", "Krautrock",
  "Leftfield", "Lounge", "Math Rock", "New Romantic", "Nu-Breakz", "Post-Punk", "Post-Rock", "Psytrance", "Shoegaze", "Space Rock",
  "Trop Rock", "World Music", "Neoclassical", "Audiobook", "Audio Theatre", "Neue Deutsche Welle", "Podcast", "Indie Rock", "G-Funk", "Dubstep",
  "Garage Rock", "Psybient",
]

///|
fn audio_genre_ref(name : String) -> String {
  if name == "RX" {
    return "Remix"
  }
  if name == "CR" {
    return "Cover"
  }
  match audio_parse_int_opt(name) {
    Some(number) => {
      if number >= 0 && number < audio_genres.length() {
        audio_genres[number]
      } else {
        name
      }
    }
    None => name
  }
}

///|
fn audio_genre_name(value : String) -> String {
  let value = value.trim().to_owned()
  if value == "" {
    return ""
  }
  if value.has_prefix("((") {
    return value[1:].to_owned()
  }
  if value.has_prefix("(") {
    match value.find(")") {
      Some(end) => return audio_genre_ref(value[1:end].to_owned())
      None => return value
    }
  }
  match audio_parse_int_opt(value) {
    Some(_) => audio_genre_ref(value)
    None => value
  }
}

///|
fn audio_user_key(name : String) -> String {
  let out = StringBuilder()
  for i in 0..<name.length() {
    let c = name.at(i).to_int()
    if c == 32 || c == 95 || c == 45 {
      continue
    }
    match c.to_char() {
      Some(ch) => out.write_char(ch)
      None => ()
    }
  }
  match out.to_string().to_upper() {
    "TITLE" => "title"
    "SUBTITLE" | "VERSION" => "subtitle"
    "ARTIST" => "artist"
    "ALBUMARTIST" | "ALBUMARTISTS" | "BAND" => "albumartist"
    "ALBUM" => "album"
    "COMPOSER" => "composer"
    "LYRICIST" | "WRITER" | "TEXT" => "lyricist"
    "CONDUCTOR" => "conductor"
    "REMIXER" | "MIXARTIST" => "remixer"
    "GENRE" => "genre"
    "DATE" | "YEAR" | "RELEASEDATE" => "date"
    "TRACKNUMBER" | "TRACK" => "track"
    "TRACKTOTAL" | "TOTALTRACKS" => "tracktotal"
    "DISCNUMBER" | "DISC" => "disc"
    "DISCTOTAL" | "TOTALDISCS" => "disctotal"
    "PUBLISHER" | "LABEL" | "ORGANIZATION" => "publisher"
    "COPYRIGHT" | "LICENSE" => "copyright"
    "LANGUAGE" => "language"
    "ISRC" => "isrc"
    "COMMENT" | "DESCRIPTION" => "comment"
    "LYRICS" | "UNSYNCEDLYRICS" | "USLT" | "SYNCEDLYRICS" => "lyrics"
    "GROUPING" | "CONTENTGROUP" => "grouping"
    "BPM" | "TEMPO" => "bpm"
    _ => ""
  }
}

///|
fn audio_set_tag(tags : AudioTags, key : String, value : String) -> Unit {
  let key = key.trim().to_lower()
  let value = audio_clean_value(value)
  match key {
    "title" | "tit2" | "inam" => if tags.title == "" { tags.title = value }
    "subtitle" | "tit3" | "isbj" => if tags.subtitle == "" { tags.subtitle = value }
    "grouping" | "tit1" | "contentgroup" => if tags.grouping == "" { tags.grouping = value }
    "artist" | "tpe1" | "iart" | "author" => audio_push_unique(tags.artists, value)
    "albumartist" | "albumartists" | "tpe2" | "aart" | "band" => {
      audio_push_unique(tags.album_artists, value)
    }
    "album" | "talb" | "iprd" => if tags.album == "" { tags.album = value }
    "composer" | "tcom" | "imus" => audio_push_unique(tags.composers, value)
    "lyricist" | "text" | "iwri" => audio_push_unique(tags.lyricists, value)
    "conductor" | "tpe3" => audio_push_unique(tags.conductors, value)
    "remixer" | "tpe4" | "mixartist" => audio_push_unique(tags.remixers, value)
    "genre" | "tcon" | "ignr" => if tags.genre == "" {
      tags.genre = audio_genre_name(value)
    }
    "tracknumber" | "trck" | "itrk" | "iprt" | "track" => audio_set_number(tags, true, value)
    "tracktotal" | "totaltracks" | "tracktotals" => if tags.track_total == "" {
      tags.track_total = value
    }
    "discnumber" | "tpos" | "disc" => audio_set_number(tags, false, value)
    "disctotal" | "totaldiscs" | "disctotals" => if tags.disc_total == "" {
      tags.disc_total = value
    }
    "date" | "tdrc" | "year" | "icrd" | "releasedate" => if tags.year == "" {
      tags.year = value
    }
    "publisher" | "tpub" | "label" | "organization" => if tags.publisher == "" {
      tags.publisher = value
    }
    "copyright" | "tcop" | "icop" | "license" => if tags.copyright == "" {
      tags.copyright = value
    }
    "language" | "tlan" | "ilng" => if tags.language == "" { tags.language = value }
    "isrc" | "tsrc" => if tags.isrc == "" { tags.isrc = value }
    "bpm" | "tbpm" | "tempo" => if tags.bpm == "" { tags.bpm = value }
    "comment" | "comm" | "icmt" | "description" => if tags.comment == "" {
      tags.comment = value
    }
    "lyrics" | "uslt" | "unsyncedlyrics" | "syncedlyrics" | "synchronisedlyrics" |
    "unsynchronisedlyrics" => if tags.lyrics == "" { tags.lyrics = value }
    "metadata_block_picture" => audio_vorbis_picture(value, tags)
    _ => ()
  }
}

///|
fn audio_user_tag(tags : AudioTags, description : String, values : Array[String]) -> Unit {
  let key = audio_user_key(description)
  if key == "" {
    return
  }
  for value in values {
    audio_set_tag(tags, key, value)
  }
}

///|
fn audio_iso639(code : String) -> String {
  match code {
    "eng" => "en"
    "jpn" => "ja"
    "fra" | "fre" => "fr"
    "deu" | "ger" => "de"
    "spa" => "es"
    "ita" => "it"
    "por" => "pt"
    "rus" => "ru"
    "zho" | "chi" => "zh"
    "kor" => "ko"
    "nld" | "dut" => "nl"
    "swe" => "sv"
    "nor" => "no"
    "dan" => "da"
    "fin" => "fi"
    "pol" => "pl"
    "ces" | "cze" => "cs"
    "slk" | "slo" => "sk"
    "hun" => "hu"
    "tur" => "tr"
    "ell" | "gre" => "el"
    "heb" => "he"
    "ara" => "ar"
    "hin" => "hi"
    "tha" => "th"
    "vie" => "vi"
    "ind" => "id"
    "ukr" => "uk"
    "ron" | "rum" => "ro"
    "bul" => "bg"
    "hrv" => "hr"
    "srp" => "sr"
    "slv" => "sl"
    "lit" => "lt"
    "lav" => "lv"
    "est" => "et"
    "cat" => "ca"
    "eus" | "baq" => "eu"
    _ => ""
  }
}

///|
fn audio_bcp47(language : String) -> String {
  let language = language.trim().to_lower().to_owned()
  match language {
    "" | "und" | "xxx" | "mul" | "zxx" | "mis" => return ""
    _ => ()
  }
  let mut base = language
  let mut region = ""
  match language.find("-") {
    Some(index) => {
      base = language[:index].to_owned()
      region = language[index + 1:].to_owned()
    }
    None => ()
  }
  let mapped = audio_iso639(base)
  let tag = if mapped != "" { mapped } else { base }
  if region != "" {
    tag + "-" + region.to_upper()
  } else {
    tag
  }
}

///|
fn audio_cover_format(data : Bytes) -> String {
  if audio_starts_with(data, 0, "\u{0089}PNG") {
    return "png"
  }
  if data.length() > 2 && data[0].to_int() == 0xff && data[1].to_int() == 0xd8 {
    return "jpeg"
  }
  if audio_starts_with(data, 0, "BM") {
    return "bmp"
  }
  ""
}

///|
fn audio_add_picture(tags : AudioTags, mime : String, data : Bytes) -> Unit {
  if data.length() == 0 || tags.cover.length() > 0 {
    return
  }
  let mime = mime.to_lower()
  let format = if mime.contains("png") {
    "png"
  } else if mime.contains("jpeg") || mime.contains("jpg") {
    "jpeg"
  } else if mime.contains("bmp") {
    "bmp"
  } else {
    audio_cover_format(data)
  }
  tags.cover = data
  tags.cover_format = format
}

///|
/// A FLAC picture block: type, MIME, description, width, height, depth,
/// colours, and the picture data.
fn audio_flac_picture(data : Bytes, tags : AudioTags) -> Unit {
  if data.length() < 32 {
    return
  }
  let mut at = 4
  let mime_length = audio_be32(data, at).to_int()
  at += 4
  if mime_length < 0 || at + mime_length > data.length() {
    return
  }
  let mime = @utf8.decode_lossy(data[at:at + mime_length].to_owned())
  at += mime_length
  if at + 4 > data.length() {
    return
  }
  let desc_length = audio_be32(data, at).to_int()
  at += 4
  if desc_length < 0 || at + desc_length + 20 > data.length() {
    return
  }
  at += desc_length + 16
  let data_length = audio_be32(data, at).to_int()
  at += 4
  if data_length <= 0 || at + data_length > data.length() {
    return
  }
  audio_add_picture(tags, mime, data[at:at + data_length].to_owned())
}

///|
fn audio_vorbis_picture(value : String, tags : AudioTags) -> Unit {
  let raw = @base64.decode(value[:], ignore_whitespace=true) catch { _ => return }
  audio_flac_picture(raw, tags)
}

///|
priv struct AudioLrcEntry {
  key : Int32
  order : Int32
  text : String
  pause : Bool
}

///|
fn audio_lrc_stamp_ms(line : String, start : Int32, stop : Int32) -> Int32 {
  let mut at = start
  let mut minutes = 0
  let mut digits = 0
  while at < stop && digits < 3 && line.at(at).to_int() >= 48 &&
    line.at(at).to_int() <= 57 {
    minutes = minutes * 10 + (line.at(at).to_int() - 48)
    at += 1
    digits += 1
  }
  if digits == 0 || at >= stop || line.at(at).to_int() != 58 {
    return -1
  }
  at += 1
  let mut seconds = 0
  digits = 0
  while at < stop && digits < 2 && line.at(at).to_int() >= 48 &&
    line.at(at).to_int() <= 57 {
    seconds = seconds * 10 + (line.at(at).to_int() - 48)
    at += 1
    digits += 1
  }
  if digits == 0 {
    return -1
  }
  let mut millis = 0
  if at < stop && (line.at(at).to_int() == 46 || line.at(at).to_int() == 58) {
    at += 1
    let mut fraction = 0
    digits = 0
    while at < stop && digits < 3 && line.at(at).to_int() >= 48 &&
      line.at(at).to_int() <= 57 {
      fraction = fraction * 10 + (line.at(at).to_int() - 48)
      at += 1
      digits += 1
    }
    if digits == 0 {
      return -1
    }
    while digits < 3 {
      fraction *= 10
      digits += 1
    }
    millis = fraction
  }
  if at != stop {
    return -1
  }
  minutes * 60000 + seconds * 1000 + millis
}

///|
fn audio_lrc_stamps(line : String) -> (Array[Int32], Int32) {
  let times : Array[Int32] = []
  let mut pos = 0
  let mut last = -1
  while pos < line.length() && line.at(pos).to_int() == 91 {
    let mut close = pos + 1
    while close < line.length() && line.at(close).to_int() != 93 {
      close += 1
    }
    if close >= line.length() {
      break
    }
    let millis = audio_lrc_stamp_ms(line, pos + 1, close)
    if millis < 0 {
      break
    }
    times.push(millis)
    last = close + 1
    pos = close + 1
  }
  (times, last)
}

///|
fn audio_lrc_tag(line : String) -> (String, String)? {
  if !line.has_prefix("[") || !line.has_suffix("]") {
    return None
  }
  let close = line.length() - 1
  let mut colon = -1
  let mut at = 1
  while at < close {
    let c = line.at(at).to_int()
    if c == 58 {
      colon = at
      break
    }
    if !((c >= 65 && c <= 90) ||
      (c >= 97 && c <= 122) ||
      c == 95 ||
      c == 35) {
      return None
    }
    at += 1
  }
  if colon < 0 {
    return None
  }
  let key = line[1:colon].to_lower().to_owned()
  match key {
    "ar" | "ti" | "al" | "au" | "lr" | "by" | "offset" | "length" | "re" | "ve" |
    "la" | "tool" | "id" | "#" => {
      Some((key, line[colon + 1:close].to_owned()))
    }
    _ => None
  }
}

///|
fn audio_lrc_strip_words(text : String) -> String {
  let mut out = ""
  let mut at = 0
  let mut last = 0
  while at < text.length() {
    if text.at(at).to_int() == 60 {
      let mut close = at + 1
      while close < text.length() && text.at(close).to_int() != 62 {
        close += 1
      }
      if close < text.length() && audio_lrc_stamp_ms(text, at + 1, close) >= 0 {
        out = out + text[last:at].to_owned() + " "
        at = close + 1
        last = at
        continue
      }
    }
    at += 1
  }
  out + text[last:].to_owned()
}

///|
fn audio_lrc_body(line : String, start : Int32) -> String {
  let body = if start <= 0 {
    line
  } else if start >= line.length() {
    ""
  } else {
    line[start:].to_owned()
  }
  audio_collapse_spaces(audio_lrc_strip_words(body))
}

///|
/// The synchronized lines of an LRC text: its tags and time stamps are not
/// part of the lines, and a line with several stamps is sung at each.
fn audio_parse_lrc(text : String) -> Array[(Double, String)] {
  let normalized = text.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
  let entries : Array[AudioLrcEntry] = []
  let mut offset = 0
  let mut timed = 0
  let mut plain = 0
  let mut key = -1
  let mut order = 0
  for raw in normalized.split("\n") {
    let line = raw.trim().to_owned()
    if line == "" {
      if entries.length() > 0 && !entries[entries.length() - 1].pause {
        entries.push({ key, order, text: "", pause: true })
        order += 1
      }
      continue
    }
    match audio_lrc_tag(line) {
      Some((tag_key, tag_value)) => {
        if tag_key == "offset" {
          offset = @string.parse_int(tag_value.trim()) catch { _ => 0 }
        }
        continue
      }
      None => ()
    }
    let (times, body_start) = audio_lrc_stamps(line)
    if times.is_empty() {
      plain += 1
      let body = audio_lrc_body(line, 0)
      let last = entries.length() - 1
      if last >= 0 && !entries[last].pause && entries[last].key >= 0 {
        entries[last] = {
          key: entries[last].key,
          order: entries[last].order,
          text: entries[last].text + "\n" + body,
          pause: false,
        }
      } else {
        entries.push({ key, order, text: body, pause: false })
        order += 1
      }
      continue
    }
    timed += 1
    let body = audio_lrc_body(line, body_start)
    for time in times {
      key = time
      if body == "" {
        entries.push({ key: time, order, text: "", pause: true })
      } else {
        entries.push({ key: time, order, text: body, pause: false })
      }
      order += 1
    }
  }
  if timed == 0 || timed < plain {
    return []
  }
  entries.sort_by((a, b) => {
    if a.key != b.key {
      a.key.compare(b.key)
    } else {
      a.order.compare(b.order)
    }
  })
  let out : Array[(Double, String)] = []
  for entry in entries {
    if !entry.pause && entry.text != "" {
      let at = if entry.key - offset > 0 { entry.key - offset } else { 0 }
      out.push((at.to_double() / 1000.0, entry.text))
    }
  }
  out
}

///|
/// The lines of the entries of a SYLT frame: entries that hold line feeds
/// break the text into lines, a line taking the time of its first piece.
fn audio_sylt_lines(entries : Array[(String, Double)]) -> Array[(Double, String)] {
  let out : Array[(Double, String)] = []
  let mut feeds = false
  let mut spaced = false
  for (text, _) in entries {
    if text.contains("\n") {
      feeds = true
    }
    if text.trim() != text {
      spaced = true
    }
  }
  if !feeds && !spaced {
    for (text, time) in entries {
      let line = audio_collapse_spaces(text)
      if line != "" {
        out.push((time, line))
      }
    }
    return out
  }
  let mut current = ""
  let mut at = -1.0
  for (text, time) in entries {
    let pieces = text.split("\n")
    let mut first = true
    for piece in pieces {
      if !first {
        let line = audio_collapse_spaces(current)
        if line != "" {
          out.push((at, line))
        }
        current = ""
        at = -1.0
      }
      first = false
      let trimmed = piece.trim().to_owned()
      if trimmed != "" && at < 0.0 {
        at = time
      }
      current = current + piece.to_owned()
    }
  }
  let line = audio_collapse_spaces(current)
  if line != "" {
    out.push((at, line))
  }
  out
}

///|
/// A SYLT frame (after its encoding byte): language, time stamp format,
/// content type, descriptor, then entries of a terminated text and a
/// 4-byte big-endian time stamp in milliseconds.
fn audio_sylt(content : Bytes, tags : AudioTags) -> Unit {
  if content.length() < 7 || !tags.synced_lyrics.is_empty() {
    return
  }
  let encoding = content[0].to_int()
  let timestamp_format = content[4].to_int()
  let content_type = content[5].to_int()
  if content_type != 1 || timestamp_format != 2 {
    return
  }
  let desc_end = audio_cstring_end(content, 6, encoding)
  let mut offset = if encoding == 1 || encoding == 2 {
    desc_end + 2
  } else {
    desc_end + 1
  }
  let entries : Array[(String, Double)] = []
  while offset < content.length() && entries.length() < 2000 {
    let text_end = audio_cstring_end(content, offset, encoding)
    let text = audio_text(content, offset, text_end - offset, encoding)
    let stamp_at = if encoding == 1 || encoding == 2 {
      text_end + 2
    } else {
      text_end + 1
    }
    if stamp_at + 4 > content.length() {
      break
    }
    let stamp = audio_be32(content, stamp_at).to_int()
    entries.push((text, stamp.to_double() / 1000.0))
    offset = stamp_at + 4
  }
  tags.synced_lyrics = audio_sylt_lines(entries)
}

///|
fn audio_lyrics_lines(tags : AudioTags) -> Array[String] {
  let out : Array[String] = []
  if tags.synced_lyrics.length() > 0 {
    for (_, text) in tags.synced_lyrics {
      if text != "" {
        out.push(text)
      }
    }
    return out
  }
  for line in tags.lyrics.split("\n") {
    let text = line.trim().to_owned()
    if text != "" {
      out.push(text)
    }
  }
  out
}

///|
fn audio_skip_comment(description : String) -> Bool {
  for prefix in [
    "iTun", "Songs-DB", "MusicMatch", "Media Jukebox", "Encoder", "Encoded by",
    "Encoding",
  ] {
    if description.has_prefix(prefix) {
      return true
    }
  }
  false
}

///|
fn audio_apic(content : Bytes, tags : AudioTags) -> Unit {
  if content.length() < 4 {
    return
  }
  let encoding = content[0].to_int()
  let mime_end = audio_cstring_end(content, 1, 0)
  if mime_end <= 1 || mime_end > content.length() {
    return
  }
  let mime = @utf8.decode_lossy(content[1:mime_end].to_owned()).to_lower()
  // The picture type byte comes before the description.
  if mime_end + 2 > content.length() {
    return
  }
  let desc_end = audio_cstring_end(content, mime_end + 2, encoding)
  let image_start = if encoding == 1 || encoding == 2 {
    desc_end + 2
  } else {
    desc_end + 1
  }
  if image_start < content.length() {
    audio_add_picture(tags, mime, content[image_start:].to_owned())
  }
}

///|
fn audio_frame_text(content : Bytes) -> String {
  if content.length() < 2 {
    return ""
  }
  let values = audio_text_values(
    content,
    1,
    content.length() - 1,
    content[0].to_int(),
  )
  audio_first(values)
}

///|
fn audio_frame_values(content : Bytes) -> Array[String] {
  if content.length() < 2 {
    return []
  }
  audio_text_values(content, 1, content.length() - 1, content[0].to_int())
}

///|
fn audio_frame_people(content : Bytes) -> Array[String] {
  audio_split_people(audio_frame_values(content))
}

///|
/// A COMM or USLT frame: its language, a description, and the text.
fn audio_frame_described(content : Bytes) -> (String, String) {
  if content.length() < 5 {
    return ("", "")
  }
  let encoding = content[0].to_int()
  let desc_end = audio_cstring_end(content, 4, encoding)
  let text_start = if encoding == 1 || encoding == 2 {
    desc_end + 2
  } else {
    desc_end + 1
  }
  let description = audio_clean(audio_text(content, 4, desc_end - 4, encoding))
  let text = if text_start <= content.length() {
    audio_clean(
      audio_text(content, text_start, content.length() - text_start, encoding),
    )
  } else {
    ""
  }
  (description, text)
}

///|
/// A CHAP frame: its element identifier, start and end times, offsets, and
/// the frames in it (its title).
fn audio_chap(content : Bytes, tags : AudioTags, version : Int32) -> Unit {
  if tags.chapters.length() >= 1000 {
    return
  }
  let id_end = audio_cstring_end(content, 0, 0)
  if id_end + 1 + 16 > content.length() {
    return
  }
  let id = audio_clean(audio_latin1(content[:id_end].to_owned()))
  let start = audio_be32(content, id_end + 1).to_int()
  let mut title = ""
  let mut at = id_end + 1 + 16
  while at + 10 <= content.length() {
    if content[at] == 0 || !audio_valid_frame_id(content, at) {
      break
    }
    let id_bytes = audio_box_type(content, at)
    let size = if version >= 4 {
      audio_syncsafe(content, at + 4)
    } else {
      audio_be32(content, at + 4).to_int()
    }
    if size <= 0 || at + 10 + size > content.length() {
      break
    }
    if id_bytes == "TIT2" {
      title = audio_frame_text(content[at + 10:at + 10 + size].to_owned())
      break
    }
    at += 10 + size
  }
  if title == "" {
    title = id
  }
  if title != "" {
    tags.chapters.push((start.to_double() / 1000.0, title))
  }
}

///|
fn audio_id3v1(data : Bytes, tags : AudioTags) -> Unit {
  if data.length() < 128 {
    return
  }
  let base = data.length() - 128
  if data[base].to_int() != 84 ||
    data[base + 1].to_int() != 65 ||
    data[base + 2].to_int() != 71 {
    return
  }
  if tags.title == "" {
    tags.title = audio_legacy_text(data[base + 3:base + 33].to_owned())
  }
  if tags.artists.is_empty() {
    audio_push_unique(tags.artists, audio_legacy_text(data[base + 33:base + 63].to_owned()))
  }
  if tags.album == "" {
    tags.album = audio_legacy_text(data[base + 63:base + 93].to_owned())
  }
  if tags.year == "" {
    let year = audio_legacy_text(data[base + 93:base + 97].to_owned())
    if year != "" {
      tags.year = year
    }
  }
  if tags.genre == "" {
    let number = data[base + 127].to_int()
    if number >= 0 && number < audio_genres.length() {
      tags.genre = audio_genres[number]
    }
  }
}

///|
fn audio_id3(data : Bytes, tags : AudioTags) -> Int32 {
  if data.length() < 10 ||
    data[0].to_int() != 73 ||
    data[1].to_int() != 68 ||
    data[2].to_int() != 51 {
    return 0
  }
  let version = data[3].to_int()
  let size = audio_syncsafe(data, 6)
  let end = (10 + size).min(data.length())
  let mut offset = 10
  let mut date_drc = ""
  let mut date_year = ""
  let mut date_ddat = ""
  let mut date_time = ""
  while offset + 10 <= end {
    if data[offset] == 0 || !audio_valid_frame_id(data, offset) {
      break
    }
    let id = audio_box_type(data, offset)
    let frame_size = if version >= 4 {
      audio_syncsafe(data, offset + 4)
    } else {
      audio_be32(data, offset + 4).to_int()
    }
    if frame_size <= 0 || offset + 10 + frame_size > end {
      break
    }
    let content = data[offset + 10:offset + 10 + frame_size].to_owned()
    match id {
      "APIC" => audio_apic(content, tags)
      "TIT2" => tags.title = audio_frame_text(content)
      "TIT3" => tags.subtitle = audio_frame_text(content)
      "TIT1" => tags.grouping = audio_frame_text(content)
      "TPE1" => audio_push_all(tags.artists, audio_frame_people(content))
      "TPE2" => audio_push_all(tags.album_artists, audio_frame_people(content))
      "TPE3" => audio_push_all(tags.conductors, audio_frame_people(content))
      "TPE4" => audio_push_all(tags.remixers, audio_frame_people(content))
      "TALB" => tags.album = audio_frame_text(content)
      "TCOM" => audio_push_all(tags.composers, audio_frame_people(content))
      "TEXT" => audio_push_all(tags.lyricists, audio_frame_people(content))
      "TCON" => {
        let genre = audio_first(audio_frame_values(content))
        if genre != "" {
          tags.genre = audio_genre_name(genre)
        }
      }
      "TRCK" => audio_set_number(tags, true, audio_frame_text(content))
      "TPOS" => audio_set_number(tags, false, audio_frame_text(content))
      "TPUB" => if tags.publisher == "" {
        tags.publisher = audio_frame_text(content)
      }
      "TCOP" => if tags.copyright == "" {
        tags.copyright = audio_frame_text(content)
      }
      "TLAN" => if tags.language == "" {
        tags.language = audio_frame_text(content)
      }
      "TSRC" => if tags.isrc == "" {
        tags.isrc = audio_frame_text(content)
      }
      "TBPM" => if tags.bpm == "" {
        tags.bpm = audio_frame_text(content)
      }
      "TDRC" => date_drc = audio_frame_text(content)
      "TYER" => date_year = audio_frame_text(content)
      "TDAT" => date_ddat = audio_frame_text(content)
      "TIME" => date_time = audio_frame_text(content)
      "TXXX" => {
        let desc_end = audio_cstring_end(content, 1, content[0].to_int())
        let description = audio_text(
          content,
          1,
          desc_end - 1,
          content[0].to_int(),
        )
        let value_start = if content[0].to_int() == 1 || content[0].to_int() == 2 {
          desc_end + 2
        } else {
          desc_end + 1
        }
        let values = if value_start <= content.length() {
          audio_text_values(
            content,
            value_start,
            content.length() - value_start,
            content[0].to_int(),
          )
        } else {
          []
        }
        audio_user_tag(tags, description, values)
      }
      "COMM" => {
        let (description, text) = audio_frame_described(content)
        if !audio_skip_comment(description) && tags.comment == "" && text != "" {
          tags.comment = text
        }
      }
      "USLT" => {
        let (_, text) = audio_frame_described(content)
        if tags.lyrics == "" && text != "" {
          tags.lyrics = text
        }
      }
      "SYLT" => audio_sylt(content, tags)
      "CHAP" => audio_chap(content, tags, version)
      _ => ()
    }
    offset += 10 + frame_size
  }
  let mut date = date_drc
  if date == "" && date_year != "" {
    date = date_year
    if date_ddat.length() == 4 && date_year.length() == 4 {
      date = date_year + "-" + date_ddat[2:].to_owned() + "-" +
        date_ddat[:2].to_owned()
      if date_time.length() == 4 {
        date = date + "T" + date_time[2:].to_owned() + ":" +
          date_time[:2].to_owned()
      }
    }
  }
  if date != "" {
    tags.year = date
  }
  end
}

///|
fn audio_mpeg_duration(data : Bytes, start : Int32, tags : AudioTags) -> Unit {
  let mut offset = start
  while offset + 4 <= data.length() && data[offset].to_int() != 0xff {
    offset += 1
  }
  if offset + 4 > data.length() {
    return
  }
  let header = (data[offset].to_int() << 24) | (data[offset + 1].to_int() << 16) |
    (data[offset + 2].to_int() << 8) | data[offset + 3].to_int()
  let version = (header >> 19) & 3
  let layer = (header >> 17) & 3
  let bitrate_index = (header >> 12) & 0xf
  let sample_index = (header >> 10) & 3
  let rates : Array[Int32] = if version == 3 {
    [44100, 48000, 32000]
  } else {
    [22050, 24000, 16000]
  }
  let bitrates : Array[Int32] = if version == 3 {
    if layer == 1 {
      [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
    } else {
      [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192]
    }
  } else {
    [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192]
  }
  if sample_index < rates.length() {
    tags.sample_rate = rates[sample_index]
  }
  if bitrate_index > 0 && bitrate_index < bitrates.length() {
    tags.bitrate = bitrates[bitrate_index].to_double() * 1000.0
  }
  tags.channels = if ((header >> 6) & 3) == 3 { 1 } else { 2 }
  if tags.bitrate > 0.0 {
    let bytes = (data.length() - offset).to_double()
    tags.duration = bytes * 8.0 / tags.bitrate
  }
}

///|
fn audio_wav(data : Bytes, tags : AudioTags) -> Unit {
  tags.format = "wav"
  tags.codec = "PCM"
  if data.length() < 12 {
    return
  }
  let mut offset = 12
  let mut bits = 0
  while offset + 8 <= data.length() {
    let id = audio_box_type(data, offset)
    let declared = audio_le32(data, offset + 4)
    let start = offset + 8
    if declared < 0L || declared > data.length().to_int64() - start.to_int64() {
      break
    }
    let size = declared.to_int()
    if id == "fmt " && size >= 16 {
      tags.channels = audio_le16(data, start + 2)
      tags.sample_rate = audio_le32(data, start + 4).to_int()
      bits = audio_le16(data, start + 14)
      let byte_rate = audio_le32(data, start + 8)
      tags.bitrate = byte_rate.to_double() * 8.0
    } else if id == "data" && tags.bitrate > 0.0 {
      tags.duration = size.to_double() / (tags.bitrate / 8.0)
    } else if id == "LIST" && size >= 4 {
      if audio_box_type(data, start) == "INFO" {
        let mut at = start + 4
        while at + 8 <= start + size {
          let key = audio_box_type(data, at)
          let length = audio_le32(data, at + 4).to_int()
          if length < 0 || at + 8 + length > start + size {
            break
          }
          let value = audio_legacy_text(data[at + 8:at + 8 + length].to_owned())
          audio_set_tag(tags, key, value)
          at += 8 + length + (if length % 2 == 1 { 1 } else { 0 })
        }
      }
    } else if (id == "id3 " || id == "ID3 ") && size > 0 {
      ignore(audio_id3(data[start:start + size].to_owned(), tags))
    }
    offset = start + size + (if size % 2 == 1 { 1 } else { 0 })
  }
  if tags.codec == "PCM" && tags.bitrate <= 0.0 && bits > 0 {
    tags.bitrate = tags.sample_rate.to_double() * tags.channels.to_double() *
      bits.to_double()
  }
}

///|
fn audio_extended(data : Bytes, offset : Int32) -> Double {
  if offset < 0 || offset + 10 > data.length() {
    return 0.0
  }
  let sign = if (data[offset].to_int() & 0x80) != 0 { -1.0 } else { 1.0 }
  let exponent = (audio_be16(data, offset) & 0x7fff) - 16383
  let mantissa = audio_be64(data, offset + 2).reinterpret_as_uint64()
  if exponent == -16383 && mantissa == 0UL {
    return 0.0
  }
  sign * mantissa.to_double() * @math.pow(2.0, (exponent - 63).to_double())
}

///|
fn audio_aiff(data : Bytes, tags : AudioTags) -> Unit {
  tags.format = "aiff"
  tags.codec = "PCM"
  if data.length() < 12 {
    return
  }
  let mut offset = 12
  while offset + 8 <= data.length() {
    let id = audio_box_type(data, offset)
    let declared = audio_be32(data, offset + 4)
    let start = offset + 8
    if declared < 0L || declared > data.length().to_int64() - start.to_int64() {
      break
    }
    let size = declared.to_int()
    if id == "COMM" && size >= 18 {
      tags.channels = audio_be16(data, start)
      let frames = audio_be32(data, start + 2)
      let bits = audio_be16(data, start + 6)
      let rate = audio_extended(data, start + 8)
      let sample_rate = (rate + 0.5).to_int()
      if sample_rate > 0 {
        tags.sample_rate = sample_rate
      }
      if tags.sample_rate > 0 {
        tags.duration = frames.to_double() / tags.sample_rate.to_double()
      }
      if bits > 0 && tags.sample_rate > 0 {
        tags.bitrate = (tags.sample_rate * tags.channels).to_double() *
          bits.to_double()
      }
    } else if id == "NAME" || id == "AUTH" || id == "(c) " || id == "ANNO" {
      let value = audio_legacy_text(data[start:start + size].to_owned())
      let key = if id == "NAME" {
        "title"
      } else if id == "AUTH" {
        "artist"
      } else if id == "(c) " {
        "copyright"
      } else {
        "comment"
      }
      audio_set_tag(tags, key, value)
    } else if id == "ID3 " || id == "id3 " {
      if size > 0 {
        ignore(audio_id3(data[start:start + size].to_owned(), tags))
      }
    }
    offset = start + size + (if size % 2 == 1 { 1 } else { 0 })
  }
}

///|
fn audio_vorbis_comment(comment : Bytes, tags : AudioTags) -> Unit {
  if comment.length() < 8 {
    return
  }
  let vendor = audio_le32(comment, 0).to_int()
  if vendor < 0 || vendor > comment.length() - 8 {
    return
  }
  let mut at = 4 + vendor
  let count = audio_le32(comment, at).to_int()
  at += 4
  if count < 0 {
    return
  }
  for _ in 0..<count {
    if at + 4 > comment.length() {
      break
    }
    let length = audio_le32(comment, at).to_int()
    at += 4
    if length < 0 || at + length > comment.length() {
      break
    }
    let entry = @utf8.decode_lossy(comment[at:at + length].to_owned())
    at += length
    match entry.find("=") {
      Some(index) => {
        let key = entry[:index].to_owned()
        let value = entry[index + 1:].to_owned()
        if key.to_lower() == "metadata_block_picture" {
          audio_vorbis_picture(value, tags)
        } else {
          audio_set_tag(tags, key, value)
        }
      }
      None => ()
    }
  }
}

///|
fn audio_flac(data : Bytes, tags : AudioTags) -> Unit {
  tags.format = "flac"
  tags.codec = "FLAC"
  if !audio_starts_with(data, 0, "fLaC") {
    return
  }
  let mut offset = 4
  while offset + 4 <= data.length() {
    let header = data[offset].to_int()
    let kind = header & 0x7f
    let length = (data[offset + 1].to_int() << 16) |
      (data[offset + 2].to_int() << 8) | data[offset + 3].to_int()
    let start = offset + 4
    if start + length > data.length() {
      break
    }
    if kind == 0 && length >= 18 {
      let sample_rate = (data[start + 10].to_int() << 12) |
        (data[start + 11].to_int() << 4) | (data[start + 12].to_int() >> 4)
      let channels = ((data[start + 12].to_int() >> 1) & 7) + 1
      let total = ((data[start + 13].to_int64() & 0xf) << 32) |
        (data[start + 14].to_int64() << 24) |
        (data[start + 15].to_int64() << 16) |
        (data[start + 16].to_int64() << 8) | data[start + 17].to_int64()
      tags.sample_rate = sample_rate
      tags.channels = channels
      if sample_rate > 0 {
        tags.duration = total.to_double() / sample_rate.to_double()
      }
    } else if kind == 4 {
      audio_vorbis_comment(data[start:start + length].to_owned(), tags)
    } else if kind == 6 && length > 32 {
      audio_flac_picture(data[start:start + length].to_owned(), tags)
    }
    offset = start + length
    if (header & 0x80) != 0 {
      break
    }
  }
  if tags.duration > 0.0 && offset < data.length() {
    tags.bitrate = (data.length() - offset).to_double() * 8.0 / tags.duration
  }
}

///|
fn audio_ogg_last_granule(data : Bytes) -> Int64? {
  if data.length() < 27 {
    return None
  }
  let mut at = data.length() - 27
  while at >= 0 {
    if data[at].to_int() == 79 &&
      data[at + 1].to_int() == 103 &&
      data[at + 2].to_int() == 103 &&
      data[at + 3].to_int() == 83 &&
      data[at + 4].to_int() == 0 {
      let granule = audio_le64(data, at + 6)
      if granule >= 0L {
        return Some(granule)
      }
    }
    at -= 1
  }
  None
}

///|
fn audio_ogg(data : Bytes, tags : AudioTags) -> Unit {
  tags.format = "ogg"
  if !audio_starts_with(data, 0, "OggS") {
    return
  }
  let mut offset = 0
  let mut pages = 0
  let mut serial = 0
  let mut codec = ""
  let packets : Array[Bytes] = []
  let packet = @buffer.Buffer()
  let mut done = false
  let mut preskip = 0L
  while offset + 27 <= data.length() && pages < 10000 && !done {
    pages += 1
    if !audio_starts_with(data, offset, "OggS") || data[offset + 4].to_int() != 0 {
      break
    }
    let page_type = data[offset + 5].to_int()
    let page_serial = audio_le32(data, offset + 14).to_int()
    let segments = data[offset + 26].to_int()
    if offset + 27 + segments > data.length() {
      break
    }
    let mut size = 0
    for i in 0..<segments {
      size += data[offset + 27 + i].to_int()
    }
    let start = offset + 27 + segments
    if start + size > data.length() {
      break
    }
    if codec == "" {
      if (page_type & 2) == 0 || size == 0 {
        offset = start + size
        continue
      }
      if audio_starts_with(data, start, "\u{0001}vorbis") {
        codec = "Vorbis"
        serial = page_serial
      } else if audio_starts_with(data, start, "OpusHead") {
        codec = "Opus"
        serial = page_serial
      } else {
        offset = start + size
        continue
      }
    } else if page_serial != serial {
      offset = start + size
      continue
    }
    let mut at = start
    for i in 0..<segments {
      let length = data[offset + 27 + i].to_int()
      if at + length > data.length() {
        break
      }
      packet.write_bytes(data[at:at + length])
      at += length
      if length < 255 {
        packets.push(packet.to_bytes())
        packet.reset()
        if packets.length() >= 2 {
          done = true
          break
        }
      }
    }
    offset = start + size
  }
  if codec == "" {
    tags.codec = "Vorbis"
    return
  }
  tags.codec = codec
  if packets.length() > 0 {
    let ident = packets[0]
    if codec == "Vorbis" {
      if ident.length() >= 16 {
        tags.channels = ident[11].to_int()
        tags.sample_rate = audio_le32(ident, 12).to_int()
        if ident.length() >= 24 {
          let nominal = audio_le32(ident, 20).to_int()
          if nominal > 0 {
            tags.bitrate = nominal.to_double()
          }
        }
      }
    } else {
      tags.sample_rate = 48000
      if ident.length() >= 12 {
        tags.channels = ident[9].to_int()
        preskip = audio_le16(ident, 10).to_int64()
      }
    }
  }
  if packets.length() > 1 {
    let comment = packets[1]
    if codec == "Vorbis" {
      if comment.length() > 7 && audio_starts_with(comment, 0, "\u{0003}vorbis") {
        audio_vorbis_comment(comment[7:].to_owned(), tags)
      }
    } else if comment.length() > 8 &&
      audio_starts_with(comment, 0, "OpusTags") {
      audio_vorbis_comment(comment[8:].to_owned(), tags)
    }
  }
  match audio_ogg_last_granule(data) {
    Some(granule) => {
      let seconds = if codec == "Opus" {
        (granule - preskip).to_double() / 48000.0
      } else if tags.sample_rate > 0 {
        granule.to_double() / tags.sample_rate.to_double()
      } else {
        0.0
      }
      if seconds > 0.0 {
        tags.duration = seconds
      }
    }
    None => ()
  }
  if tags.duration > 0.0 && tags.bitrate <= 0.0 {
    tags.bitrate = data.length().to_double() * 8.0 / tags.duration
  }
}

///|
fn audio_mp4_codec(kind : String) -> String {
  match kind {
    "mp4a" | "drms" | "drmi" => "AAC"
    "alac" => "Apple Lossless"
    "fLaC" => "FLAC"
    "Opus" => "Opus"
    ".mp3" | "mp3 " => "MP3"
    "lpcm" | "sowt" | "twos" | "raw " | "in24" | "in32" | "fl32" | "fl64" |
    "NONE" => "PCM"
    "ac-3" => "AC-3"
    "ec-3" => "E-AC-3"
    _ => kind.trim().to_owned()
  }
}

///|
fn audio_mp4_chpl(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  if start + 5 > end {
    return
  }
  let count = data[start + 4].to_int()
  let mut at = start + 5
  for _ in 0..<count {
    if at + 9 > end {
      break
    }
    let stamp = audio_be64(data, at)
    let length = data[at + 8].to_int()
    at += 9
    if length < 0 || at + length > end {
      break
    }
    let title = @utf8.decode_lossy(data[at:at + length].to_owned()).trim().to_owned()
    at += length
    if tags.chapters.length() < 1000 {
      tags.chapters.push((stamp.to_double() / 10000000.0, title))
    }
  }
}

///|
fn audio_mp4_item(
  data : Bytes,
  payload_start : Int32,
  payload_end : Int32,
  kind : Int32,
  name : String,
  tags : AudioTags,
) -> Unit {
  let text = match kind {
    0 | 1 => @utf8.decode_lossy(data[payload_start:payload_end].to_owned()).trim().to_owned()
    2 => audio_clean(
      audio_utf16_text(data, payload_start, payload_end - payload_start, true),
    )
    _ => ""
  }
  let number = if payload_end - payload_start >= 6 {
    audio_be16(data, payload_start + 2)
  } else {
    0
  }
  let total = if payload_end - payload_start >= 6 {
    audio_be16(data, payload_start + 4)
  } else {
    0
  }
  match name {
    "©nam" => if tags.title == "" { tags.title = text }
    "©st3" => if tags.subtitle == "" { tags.subtitle = text }
    "©ART" => audio_push_unique(tags.artists, text)
    "aART" => audio_push_unique(tags.album_artists, text)
    "©alb" => if tags.album == "" { tags.album = text }
    "©wrt" => audio_push_unique(tags.composers, text)
    "©day" => if tags.year == "" { tags.year = text }
    "©gen" => if tags.genre == "" { tags.genre = text }
    "gnre" => if tags.genre == "" {
      let n = audio_be16(data, payload_start)
      if n >= 1 && n <= audio_genres.length() {
        tags.genre = audio_genres[n - 1]
      }
    }
    "©cmt" => if tags.comment == "" { tags.comment = text }
    "desc" | "ldes" => if tags.comment == "" { tags.comment = text }
    "©lyr" => if tags.lyrics == "" { tags.lyrics = text }
    "cprt" | "©cpy" => if tags.copyright == "" { tags.copyright = text }
    "©grp" => if tags.grouping == "" { tags.grouping = text }
    "©pub" => if tags.publisher == "" { tags.publisher = text }
    "tmpo" => if tags.bpm == "" && number > 0 { tags.bpm = number.to_string() }
    "trkn" => {
      if number > 0 {
        tags.track = number.to_string()
      }
      if total > 0 {
        tags.track_total = total.to_string()
      }
    }
    "disk" => {
      if number > 0 {
        tags.disc = number.to_string()
      }
      if total > 0 {
        tags.disc_total = total.to_string()
      }
    }
    "covr" => {
      let mime = match kind {
        13 => "image/jpeg"
        14 => "image/png"
        27 => "image/bmp"
        _ => ""
      }
      audio_add_picture(tags, mime, data[payload_start:payload_end].to_owned())
    }
    _ => {
      if name.has_prefix("----:") {
        audio_user_tag(
          tags,
          name[5:].to_owned(),
          [text],
        )
      }
    }
  }
}

///|
fn audio_mp4_ilst(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  let mut at = start
  while at + 8 <= end {
    let size = audio_be32(data, at).to_int()
    let name = audio_box_type(data, at + 4)
    if size < 8 || at + size > end {
      break
    }
    let item_end = at + size
    let mut child = at + 8
    while child + 8 <= item_end {
      let child_size = audio_be32(data, child).to_int()
      let child_kind = audio_box_type(data, child + 4)
      if child_size < 8 || child + child_size > item_end {
        break
      }
      if child_kind == "data" && child_size >= 16 {
        let kind = (audio_be32(data, child + 8).to_int()) & 0xffffff
        audio_mp4_item(
          data,
          child + 16,
          child + child_size,
          kind,
          name,
          tags,
        )
      }
      child += child_size
    }
    at += size
  }
}

///|
fn audio_mp4_meta(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  // A full box in MP4, a plain box in QuickTime: the first child tells.
  let mut body = start
  let mut first = ""
  if start + 8 <= end {
    first = audio_box_type(data, start + 4)
  }
  if first != "hdlr" && first != "keys" && first != "ilst" {
    body = start + 4
  }
  let mut at = body
  while at + 8 <= end {
    let size = audio_be32(data, at).to_int()
    let kind = audio_box_type(data, at + 4)
    if size < 8 || at + size > end {
      break
    }
    if kind == "ilst" {
      audio_mp4_ilst(data, at + 8, at + size, tags)
    }
    at += size
  }
}

///|
fn audio_mp4_udta(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  let mut at = start
  while at + 8 <= end {
    let size = audio_be32(data, at).to_int()
    let kind = audio_box_type(data, at + 4)
    if size < 8 || at + size > end {
      break
    }
    if kind == "chpl" {
      audio_mp4_chpl(data, at + 8, at + size, tags)
    } else if kind == "meta" {
      audio_mp4_meta(data, at + 8, at + size, tags)
    } else if kind == "©nam" || kind == "©ART" || kind == "©alb" ||
      kind == "©day" || kind == "©cmt" || kind == "©gen" || kind == "©wrt" ||
      kind == "©cpy" || kind == "©lyr" || kind == "©grp" {
      if size >= 12 && audio_be16(data, at + 8) == size - 12 {
        audio_mp4_item(data, at + 12, at + size, 1, kind, tags)
      }
    }
    at += size
  }
}

///|
fn audio_mp4_stsd(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  if start + 8 > end {
    return
  }
  let count = audio_be32(data, start + 4).to_int()
  if count <= 0 {
    return
  }
  let entry = start + 8
  if entry + 8 > end {
    return
  }
  let size = audio_be32(data, entry).to_int()
  let kind = audio_box_type(data, entry + 4)
  if size < 8 || entry + size > end {
    return
  }
  tags.codec = audio_mp4_codec(kind)
  let entry_end = entry + size
  if entry + 36 > entry_end {
    return
  }
  let version = audio_be16(data, entry + 16)
  if version == 2 {
    if entry + 48 <= entry_end {
      let rate = audio_be64(data, entry + 36).reinterpret_as_double()
      tags.sample_rate = (rate + 0.5).to_int()
      tags.channels = audio_be32(data, entry + 44).to_int()
    }
  } else {
    tags.channels = audio_be16(data, entry + 24)
    tags.sample_rate = audio_be32(data, entry + 32).to_int() >> 16
  }
}

///|
fn audio_mp4_stbl(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  let mut at = start
  while at + 8 <= end {
    let size = audio_be32(data, at).to_int()
    let kind = audio_box_type(data, at + 4)
    if size < 8 || at + size > end {
      break
    }
    if kind == "stsd" {
      audio_mp4_stsd(data, at + 8, at + size, tags)
    }
    at += size
  }
}

///|
fn audio_mp4_minf(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  let mut at = start
  while at + 8 <= end {
    let size = audio_be32(data, at).to_int()
    let kind = audio_box_type(data, at + 4)
    if size < 8 || at + size > end {
      break
    }
    if kind == "stbl" {
      audio_mp4_stbl(data, at + 8, at + size, tags)
    }
    at += size
  }
}

///|
fn audio_mp4_mdhd(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  if start + 20 > end {
    return
  }
  let version = data[start].to_int()
  let mut timescale = 0
  let mut duration = 0L
  let mut language_code = 0
  if version == 1 {
    if start + 34 <= end {
      timescale = audio_be32(data, start + 20).to_int()
      duration = audio_be64(data, start + 24)
      language_code = audio_be16(data, start + 32)
    }
  } else {
    timescale = audio_be32(data, start + 12).to_int()
    duration = audio_be32(data, start + 16)
    language_code = audio_be16(data, start + 20)
  }
  if tags.duration <= 0.0 && timescale > 0 && duration > 0L {
    tags.duration = duration.to_double() / timescale.to_double()
  }
  if tags.language == "" &&
    language_code != 0 &&
    language_code != 0x7fff {
    let language = StringBuilder()
    for shift in [10, 5, 0] {
      let value = ((language_code >> shift) & 31) + 0x60
      match value.to_char() {
        Some(c) => language.write_char(c)
        None => ()
      }
    }
    tags.language = language.to_string()
  }
}

///|
fn audio_mp4_mdia(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  let mut handler = ""
  let mut at = start
  while at + 8 <= end {
    let size = audio_be32(data, at).to_int()
    let kind = audio_box_type(data, at + 4)
    if size < 8 || at + size > end {
      break
    }
    if kind == "hdlr" && at + 20 <= end {
      handler = audio_box_type(data, at + 16)
    }
    at += size
  }
  if handler != "" && handler != "soun" {
    return
  }
  at = start
  while at + 8 <= end {
    let size = audio_be32(data, at).to_int()
    let kind = audio_box_type(data, at + 4)
    if size < 8 || at + size > end {
      break
    }
    if kind == "mdhd" {
      audio_mp4_mdhd(data, at + 8, at + size, tags)
    } else if kind == "minf" {
      audio_mp4_minf(data, at + 8, at + size, tags)
    }
    at += size
  }
}

///|
fn audio_mp4_trak(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  let mut at = start
  while at + 8 <= end {
    let size = audio_be32(data, at).to_int()
    let kind = audio_box_type(data, at + 4)
    if size < 8 || at + size > end {
      break
    }
    if kind == "mdia" {
      audio_mp4_mdia(data, at + 8, at + size, tags)
    }
    at += size
  }
}

///|
fn audio_mp4_mvhd(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  if start + 20 > end {
    return
  }
  let version = data[start].to_int()
  if version == 1 {
    if start + 32 <= end {
      let timescale = audio_be32(data, start + 20).to_int()
      let duration = audio_be64(data, start + 24)
      if timescale > 0 && duration > 0L {
        tags.duration = duration.to_double() / timescale.to_double()
      }
    }
  } else {
    let timescale = audio_be32(data, start + 12).to_int()
    let duration = audio_be32(data, start + 16).to_int()
    if timescale > 0 && duration > 0 {
      tags.duration = duration.to_double() / timescale.to_double()
    }
  }
}

///|
fn audio_mp4_moov(data : Bytes, start : Int32, end : Int32, tags : AudioTags) -> Unit {
  let mut at = start
  while at + 8 <= end {
    let size = audio_be32(data, at).to_int()
    let kind = audio_box_type(data, at + 4)
    if size < 8 || at + size > end {
      break
    }
    if kind == "mvhd" {
      audio_mp4_mvhd(data, at + 8, at + size, tags)
    } else if kind == "trak" {
      audio_mp4_trak(data, at + 8, at + size, tags)
    } else if kind == "udta" {
      audio_mp4_udta(data, at + 8, at + size, tags)
    } else if kind == "meta" {
      audio_mp4_meta(data, at + 8, at + size, tags)
    }
    at += size
  }
}

///|
fn audio_mp4(data : Bytes, tags : AudioTags) -> Unit {
  tags.format = "m4a"
  tags.codec = "AAC"
  let mut offset = 0
  let mut moov_start = -1
  let mut moov_end = -1
  let mut mdat = 0L
  while offset + 8 <= data.length() {
    let size32 = audio_be32(data, offset)
    let kind = audio_box_type(data, offset + 4)
    let mut size = size32
    let mut header = 8L
    if size32 == 1L {
      if offset + 16 > data.length() {
        break
      }
      size = audio_be64(data, offset + 8)
      header = 16L
    } else if size32 == 0L {
      size = (data.length() - offset).to_int64()
    }
    if size < header || size > data.length().to_int64() - offset.to_int64() {
      break
    }
    if kind == "moov" && moov_start < 0 {
      moov_start = offset + header.to_int()
      moov_end = offset + size.to_int()
    } else if kind == "mdat" {
      mdat = mdat + size - header
    }
    offset += size.to_int()
  }
  if moov_start >= 0 {
    audio_mp4_moov(data, moov_start, moov_end, tags)
  }
  if tags.bitrate <= 0.0 && tags.duration > 0.0 && mdat > 0L {
    tags.bitrate = mdat.to_double() * 8.0 / tags.duration
  }
}

///|
fn audio_aac(data : Bytes, tags : AudioTags) -> Unit {
  tags.format = "aac"
  tags.codec = "AAC LC"
  let rates : Array[Int32] = [
    96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025,
    8000, 7350,
  ]
  let mut offset = 0
  while offset + 7 <= data.length() {
    if data[offset].to_int() == 0xff &&
      (data[offset + 1].to_int() & 0xf6) == 0xf0 {
      break
    }
    offset += 1
  }
  if offset + 7 > data.length() {
    tags.codec = "AAC"
    return
  }
  let first = data[offset + 1].to_int()
  let second = data[offset + 2].to_int()
  let third = data[offset + 3].to_int()
  if (first & 0xf6) != 0xf0 {
    tags.codec = "AAC"
    return
  }
  let profile = (second >> 6) & 3
  tags.codec = match profile {
    0 => "AAC Main"
    1 => "AAC LC"
    2 => "AAC SSR"
    _ => "AAC LTP"
  }
  let rate_index = (second >> 2) & 0xf
  if rate_index < rates.length() {
    tags.sample_rate = rates[rate_index]
  }
  tags.channels = ((second & 1) << 2) | ((third >> 6) & 3)
  if tags.channels == 0 {
    tags.channels = 1
  }
  let mut frames = 0
  let mut at = offset
  while at + 7 <= data.length() {
    if data[at].to_int() == 0xff && (data[at + 1].to_int() & 0xf6) == 0xf0 {
      let frame_length = ((data[at + 3].to_int() & 3) << 11) |
        (data[at + 4].to_int() << 3) | ((data[at + 5].to_int() >> 5) & 7)
      if frame_length >= 7 && at + frame_length <= data.length() {
        frames += 1
        at += frame_length
        continue
      }
    }
    at += 1
  }
  if tags.sample_rate > 0 && frames > 0 {
    tags.duration = (frames * 1024).to_double() / tags.sample_rate.to_double()
    tags.bitrate = data.length().to_double() * 8.0 / tags.duration
  }
}

///|
fn audio_finalize(tags : AudioTags) -> Unit {
  if tags.synced_lyrics.is_empty() && tags.lyrics != "" {
    let synced = audio_parse_lrc(tags.lyrics)
    if !synced.is_empty() {
      tags.synced_lyrics = synced
    }
  }
  if tags.chapters.length() > 1 {
    tags.chapters.sort_by((a, b) => a.0.compare(b.0))
  }
}

///|
fn audio_read(data : Bytes) -> AudioTags {
  let format = audio_detect_format(data)
  let tags = audio_tags()
  if format == "" {
    return tags
  }
  tags.format = format
  if format == "mp3" {
    tags.codec = "MP3"
    let start = audio_id3(data, tags)
    audio_id3v1(data, tags)
    audio_mpeg_duration(data, start, tags)
  } else if format == "wav" {
    audio_wav(data, tags)
  } else if format == "aiff" {
    audio_aiff(data, tags)
  } else if format == "flac" {
    audio_flac(data, tags)
  } else if format == "ogg" {
    audio_ogg(data, tags)
  } else if format == "m4a" {
    audio_mp4(data, tags)
  } else if format == "aac" {
    audio_aac(data, tags)
  }
  audio_finalize(tags)
  tags
}

///|
fn audio_detect_format(data : Bytes) -> String {
  if data.length() < 4 {
    return ""
  }
  if data[0].to_int() == 73 &&
    data[1].to_int() == 68 &&
    data[2].to_int() == 51 {
    return "mp3"
  }
  if audio_starts_with(data, 0, "fLaC") {
    return "flac"
  }
  if audio_starts_with(data, 0, "OggS") {
    return "ogg"
  }
  if data.length() >= 12 {
    let riff = audio_box_type(data, 0)
    let form = audio_box_type(data, 8)
    if (riff == "RIFF" || riff == "RF64") && form == "WAVE" {
      return "wav"
    }
    if riff == "FORM" && (form == "AIFF" || form == "AIFC") {
      return "aiff"
    }
    if audio_box_type(data, 4) == "ftyp" {
      return "m4a"
    }
  }
  if data[0].to_int() == 0xff && (data[1].to_int() & 0xf6) == 0xf0 {
    return "aac"
  }
  if data[0].to_int() == 0xff && (data[1].to_int() & 0xe0) == 0xe0 {
    return "mp3"
  }
  ""
}

///|
/// Detect a supported audio file.
pub fn detect(data : Bytes) -> Bool {
  audio_detect_format(data) != ""
}

///|
fn audio_mime(format : String) -> String {
  match format {
    "mp3" => "audio/mpeg"
    "m4a" => "audio/mp4"
    "aac" => "audio/aac"
    "flac" => "audio/flac"
    "ogg" => "audio/ogg"
    "wav" => "audio/wav"
    "aiff" => "audio/aiff"
    _ => "application/octet-stream"
  }
}

///|
fn audio_format_name(format : String) -> String {
  match format {
    "mp3" => "MP3"
    "m4a" => "M4A"
    "aac" => "ADTS"
    "flac" => "FLAC"
    "ogg" => "Ogg"
    "wav" => "WAV"
    "aiff" => "AIFF"
    _ => format.to_upper()
  }
}

///|
fn audio_format_label(tags : AudioTags) -> String {
  let name = audio_format_name(tags.format)
  if tags.codec != "" && tags.codec.to_lower() != name.to_lower() {
    name + " " + tags.codec
  } else {
    name
  }
}

///|
fn audio_clock(seconds : Double) -> String {
  let total = seconds.round().to_int()
  let minutes = total / 60
  let rest = total % 60
  "\{minutes}:\{if rest < 10 { "0" } else { "" }}\{rest}"
}

///|
fn audio_khz(rate : Int32) -> String {
  let whole = rate / 1000
  let rest = rate % 1000
  if rest == 0 {
    return "\{whole} kHz"
  }
  let mut fraction = rest.to_string()
  while fraction.length() < 3 {
    fraction = "0" + fraction
  }
  while fraction.length() > 1 && fraction.has_suffix("0") {
    fraction = fraction[:fraction.length() - 1].to_owned()
  }
  "\{whole}.\{fraction} kHz"
}

///|
fn audio_plural(count : Int32, noun : String) -> String {
  if count == 1 {
    "1 " + noun
  } else {
    "\{count} \{noun}s"
  }
}

///|
fn audio_iso_date(value : String) -> String {
  let value = value.trim().to_owned()
  if value.length() >= 10 &&
    value.at(4).to_int() == 47 &&
    value.at(7).to_int() == 47 {
    return value[:4].to_owned() + "-" + value[5:7].to_owned() + "-" +
      value[8:].to_owned()
  }
  value
}

///|
fn audio_dc_put(
  dc : Map[String, Json],
  key : String,
  values : Array[String],
) -> Unit {
  let unique : Array[String] = []
  for value in values {
    let value = audio_clean_value(value)
    if value != "" && !unique.contains(value) {
      unique.push(value)
    }
  }
  if unique.length() == 1 {
    dc[key] = Json::string(unique[0])
  } else if unique.length() > 1 {
    dc[key] = Json::array(unique.map(value => Json::string(value)))
  }
}

///|
/// The document's Dublin Core, from the tags the file carries.
fn audio_dc(tags : AudioTags) -> Map[String, Json] {
  let dc : Map[String, Json] = Map([])
  audio_dc_put(dc, "title", [tags.title])
  audio_dc_put(dc, "creator", tags.artists)
  audio_dc_put(dc, "subject", [tags.genre])
  audio_dc_put(dc, "description", [tags.comment])
  audio_dc_put(dc, "publisher", [tags.publisher])
  let contributors : Array[String] = []
  for values in [
    tags.album_artists, tags.composers, tags.lyricists, tags.conductors,
    tags.remixers,
  ] {
    for value in values {
      audio_push_unique(contributors, value)
    }
  }
  let filtered : Array[String] = []
  for value in contributors {
    if !tags.artists.contains(value) {
      filtered.push(value)
    }
  }
  audio_dc_put(dc, "contributor", filtered)
  audio_dc_put(dc, "date", [audio_iso_date(tags.year)])
  dc["type"] = Json::string("Sound")
  dc["format"] = Json::string(audio_mime(tags.format))
  audio_dc_put(dc, "identifier", [tags.isrc])
  let languages : Array[String] = []
  let language = audio_bcp47(tags.language)
  if language != "" {
    languages.push(language)
  }
  audio_dc_put(dc, "language", languages)
  audio_dc_put(dc, "relation", [tags.album])
  audio_dc_put(dc, "rights", [tags.copyright])
  dc
}

///|
/// Convert an audio file into a one-page card.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  file_name~ : String = "",
  play~ : Bool = true,
) -> AudioResult raise AudioError {
  let tags = audio_read(data)
  if tags.format == "" {
    raise AudioInvalid("audio: unsupported audio file")
  }
  let format = tags.format
  let document_title = if title != "" {
    title
  } else if tags.title != "" {
    tags.title
  } else if file_name != "" {
    file_name
  } else {
    "Audio"
  }
  let cover = tags.cover
  let mut cover_w = 300.0
  let mut cover_h = 300.0
  let mut has_cover = false
  if cover.length() > 0 && @raster.image_size(cover) is Some((w, h)) {
    has_cover = true
    cover_w = w.to_double() * 0.75
    cover_h = h.to_double() * 0.75
    let side = cover_w.min(300.0).max(160.0)
    cover_h = cover_h * side / cover_w
    cover_w = side
  }
  let width = if has_cover { cover_w.max(340.0) } else { 340.0 }
  let lyrics_lines = audio_lyrics_lines(tags)
  let lines : Array[(String, Double, Bool, UInt32)] = []
  lines.push((document_title, 22.0, true, 0x111111ffU))
  if !tags.artists.is_empty() {
    lines.push((tags.artists.join(", "), 14.0, false, 0x333333ffU))
  }
  if tags.album != "" {
    lines.push((tags.album, 13.0, false, 0x666666ffU))
  }
  if tags.grouping != "" {
    lines.push(("Grouping: " + tags.grouping, 11.0, false, 0x555555ffU))
  }
  if tags.subtitle != "" {
    lines.push(("Subtitle: " + tags.subtitle, 11.0, false, 0x555555ffU))
  }
  let details : Array[String] = []
  details.push(audio_format_label(tags))
  if tags.duration > 0.0 {
    details.push(audio_clock(tags.duration))
  }
  if tags.bitrate > 0.0 {
    details.push("\{(tags.bitrate / 1000.0).round().to_int()} kbps")
  }
  if tags.sample_rate > 0 {
    details.push(audio_khz(tags.sample_rate))
  }
  if tags.channels == 1 {
    details.push("mono")
  } else if tags.channels == 2 {
    details.push("stereo")
  } else if tags.channels > 2 {
    details.push("\{tags.channels} channels")
  }
  lines.push((details.join(", "), 10.0, false, 0x777777U))
  let extra : Array[String] = []
  if tags.year != "" {
    extra.push(tags.year)
  }
  if tags.genre != "" {
    extra.push(tags.genre)
  }
  if tags.track != "" {
    extra.push(
      "Track " +
      tags.track +
      (if tags.track_total != "" { " of " + tags.track_total } else { "" }),
    )
  }
  if tags.disc != "" {
    extra.push(
      "Disc " +
      tags.disc +
      (if tags.disc_total != "" { " of " + tags.disc_total } else { "" }),
    )
  }
  if !extra.is_empty() {
    lines.push((extra.join(" · "), 10.0, false, 0x777777U))
  }
  if !tags.composers.is_empty() {
    lines.push(("Composer: " + tags.composers.join(", "), 11.0, false, 0x555555ffU))
  }
  if tags.publisher != "" {
    lines.push(("Publisher: " + tags.publisher, 11.0, false, 0x555555ffU))
  }
  if !lyrics_lines.is_empty() {
    lines.push(("", 6.0, false, 0x000000ffU))
    lines.push(("Lyrics", 12.0, true, 0x555555ffU))
    for line in lyrics_lines {
      if lines.length() > 200 {
        break
      }
      lines.push((line, 11.0, false, 0x222222ffU))
    }
  }
  if !tags.chapters.is_empty() {
    lines.push(("", 6.0, false, 0x000000ffU))
    lines.push(("Chapters", 12.0, true, 0x555555ffU))
    for (start, chapter_title) in tags.chapters {
      if lines.length() > 220 {
        break
      }
      lines.push((
        audio_clock(start) + " " + chapter_title,
        11.0,
        false,
        0x222222ffU,
      ))
    }
  }
  let mut text_height = 0.0
  for (_, size, _, _) in lines {
    text_height += size * 1.5
  }
  let height = (if has_cover { cover_h } else { 60.0 }) + text_height + 80.0
  let dc = audio_dc(tags)
  if title != "" {
    dc["title"] = Json::string(title)
  }
  let meta : Map[String, Json] = {
    "source": Json::string(format),
    "generator": Json::string("bdf-go/0.1"),
  }
  if dc.length() > 0 {
    meta["dc"] = Json::object(dc)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, Float::from_double(width), Float::from_double(height))
  let font = object.add_font({ hash: None, family: "Arial", weight: 400, style: 0 })
  let bold = object.add_font({ hash: None, family: "Arial", weight: 700, style: 0 })
  let mut image_index : Int32? = None
  let mut image_hash : String = ""
  if has_cover {
    image_hash = writer.add_part("img", cover) catch { _ => "" }
    if image_hash != "" {
      image_index = Some(object.add_image(image_hash))
    }
  }
  let mut y = 0.0
  if has_cover {
    match image_index {
      Some(index) => {
        object.image(
          index,
          0.0F,
          0.0F,
          Float::from_double(cover_w),
          Float::from_double(cover_h),
        ) catch { _ => () }
      }
      None => ()
    }
    y = cover_h + 24.0
  } else {
    object.fill_color(0xe8e8f0ffU)
    object.fill_rect(0.0F, 0.0F, Float::from_double(width), 40.0F)
    object.fill_color(0x777777ffU)
    object.font(font, 20.0F) catch { _ => () }
    object.fill_text("♪ Audio", 18.0, 28.0, 0.0F)
    y = 60.0
  }
  let index_text = StringBuilder()
  for (text, size, is_bold, color) in lines {
    if text == "" {
      y += size
      continue
    }
    object.fill_color(color)
    object.font(if is_bold { bold } else { font }, Float::from_double(size)) catch { _ => () }
    object.fill_text(
      text,
      18.0,
      Float::from_double(y + size),
      0.0F,
    )
    index_text.write_string(text)
    index_text.write_char('\n')
    y += size * 1.5
  }
  let encoded = object.encode() catch {
    _ => raise AudioInvalid("audio card could not be stored")
  }
  let hash = writer.add_part("obj", encoded) catch {
    _ => raise AudioInvalid("audio card could not be stored")
  }
  let view : Map[String, Json] = {
    "id": Json::string("card"),
    "kind": Json::string("fixed"),
    "title": Json::string(document_title),
    "pages": Json::array([
      Json::object({
        "w": Json::number(width, repr=width.to_string()),
        "h": Json::number(height, repr=height.to_string()),
        "layers": Json::array([
          Json::object({
            "role": Json::string("body"),
            "obj": Json::string(hash),
          }),
        ]),
      }),
    ]),
  }
  let mut stored = false
  if play && data.length() <= 268435456 {
    let audio_hash = writer.add_part("audio", data) catch { _ => "" }
    if audio_hash != "" {
      stored = true
      view["play"] = Json::object({
        "audio": Json::string(audio_hash),
        "type": Json::string(audio_mime(format)),
      })
    }
  }
  let index_run : @core.IndexRun = {
    a: 0,
    b: 0,
    ordinal: 0,
    separator: 2,
    text: index_text.to_string(),
  }
  let encoded_index = @core.encode_text_index([index_run]) catch { _ => b"" }
  if encoded_index.length() > 0 {
    let index_hash = writer.add_part("idx", encoded_index) catch { _ => "" }
    if index_hash != "" {
      view["textIndex"] = Json::string(index_hash)
    }
  }
  writer.add_view(Json::object(view))
  let bdf = writer.write_single() catch {
    _ => raise AudioInvalid("audio document could not be written")
  }
  let cover_text = if has_cover {
    "cover " +
    cover_w.round().to_int().to_string() +
    " × " +
    cover_h.round().to_int().to_string() +
    " px" +
    (if tags.cover_format != "" {
      ", " + tags.cover_format.to_upper()
    } else {
      ""
    })
  } else {
    "no cover"
  }
  let more : Array[String] = []
  if stored {
    more.push("plays")
  }
  if lyrics_lines.length() > 0 {
    more.push(
      audio_plural(lyrics_lines.length(), "line") +
      " of " +
      (if tags.synced_lyrics.is_empty() {
        "lyrics"
      } else {
        "synchronized lyrics"
      }),
    )
  }
  if tags.chapters.length() > 0 {
    more.push(audio_plural(tags.chapters.length(), "chapter"))
  }
  let summary = "1 page (" + cover_text + "; " + details.join(", ") +
    (if more.is_empty() { "" } else { "; " + more.join(", ") }) + ")"
  {
    bdf,
    pages: 1,
    summary,
    warnings: [],
  }
}
