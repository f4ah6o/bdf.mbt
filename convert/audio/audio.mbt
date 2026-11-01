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
priv struct AudioTags {
  mut title : String
  artists : Array[String]
  mut album : String
  mut genre : String
  mut track : String
  mut year : String
  mut lyrics : String
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
    artists: [],
    album: "",
    genre: "",
    track: "",
    year: "",
    lyrics: "",
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
fn audio_syncsafe(data : Bytes, offset : Int32) -> Int32 {
  ((data[offset].to_int() & 0x7f) << 21) |
  ((data[offset + 1].to_int() & 0x7f) << 14) |
  ((data[offset + 2].to_int() & 0x7f) << 7) |
  (data[offset + 3].to_int() & 0x7f)
}

///|
fn audio_utf16_text(data : Bytes, offset : Int32, length : Int32, big : Bool) -> String {
  let end = (offset + length).min(data.length())
  if end <= offset { return "" }
  let slice = data[offset:end].to_owned()
  let encoding = if big { @utf16.Big } else { @utf16.Little }
  @utf16.decode_lossy(slice, endianness=encoding)
}

///|
fn audio_text(data : Bytes, offset : Int32, length : Int32, encoding : Int32) -> String {
  let end = (offset + length).min(data.length())
  if end <= offset { return "" }
  let raw = data[offset:end].to_owned()
  match encoding {
    0 => {
      let out = StringBuilder()
      for byte in raw {
        let value = byte.to_int()
        out.write_char(Char::from_int(if value < 128 { value } else { value }))
      }
      out.to_string()
    }
    1 => audio_utf16_text(raw, 0, raw.length(), false)
    2 => audio_utf16_text(raw, 0, raw.length(), true)
    _ => @utf8.decode_lossy(raw, ignore_bom=true)
  }
}

///|
fn audio_cstring_end(data : Bytes, offset : Int32, encoding : Int32) -> Int32 {
  let mut i = offset
  if encoding == 1 || encoding == 2 {
    while i + 1 < data.length() {
      if data[i] == 0 && data[i + 1] == 0 { return i }
      i += 2
    }
  } else {
    while i < data.length() {
      if data[i] == 0 { return i }
      i += 1
    }
  }
  data.length()
}

///|
fn audio_set_tag(tags : AudioTags, key : String, value : String) -> Unit {
  let key = key.to_lower()
  match key {
    "title" | "tit2" | "inam" => tags.title = value
    "artist" | "tpe1" | "iart" | "author" => {
      if value != "" { tags.artists.push(value) }
    }
    "album" | "talb" | "iprd" => tags.album = value
    "genre" | "tcon" | "ignr" => tags.genre = value
    "tracknumber" | "trck" | "itrk" => tags.track = value
    "date" | "tdrc" | "year" | "icrd" => tags.year = value
    "lyrics" | "uslt" | "unsyncedlyrics" => tags.lyrics = value
    "comment" | "comm" | "icmt" => if tags.lyrics == "" { tags.lyrics = value }
    _ => ()
  }
}

///|
fn audio_id3(data : Bytes, tags : AudioTags) -> Int32 {
  if data.length() < 10 || data[0] != (73).to_byte() || data[1] != (68).to_byte() ||
    data[2] != (51).to_byte() {
    return 0
  }
  let version = data[3].to_int()
  let size = audio_syncsafe(data, 6)
  let end = (10 + size).min(data.length())
  let mut offset = 10
  while offset + 10 <= end {
    let id = @utf8.decode_lossy(data[offset:offset + 4].to_owned())
    if id == "\x00\x00\x00\x00" || id.trim() == "" { break }
    let frame_size = if version >= 4 {
      audio_syncsafe(data, offset + 4)
    } else {
      (audio_be32(data, offset + 4)).to_int()
    }
    if frame_size <= 0 || offset + 10 + frame_size > end { break }
    let content = data[offset + 10:offset + 10 + frame_size].to_owned()
    if id == "APIC" && content.length() > 4 {
      let encoding = content[0].to_int()
      let mime_end = audio_cstring_end(content, 1, 0)
      let mime = @utf8.decode_lossy(content[1:mime_end].to_owned())
      let desc_start = mime_end + 2
      let desc_end = audio_cstring_end(content, desc_start, encoding)
      let image_start = if encoding == 1 || encoding == 2 { desc_end + 2 } else { desc_end + 1 }
      if image_start < content.length() {
        tags.cover = content[image_start:].to_owned()
        tags.cover_format = if mime.contains("png") { "png" } else if mime.contains("jpeg") || mime.contains("jpg") { "jpeg" } else { "" }
      }
    } else if id.has_prefix("T") && content.length() > 1 {
      let encoding = content[0].to_int()
      let value = audio_text(content, 1, content.length() - 1, encoding).trim().to_string()
      audio_set_tag(tags, id, value)
    } else if id == "USLT" && content.length() > 4 {
      let encoding = content[0].to_int()
      let desc_end = audio_cstring_end(content, 4, encoding)
      let text_start = if encoding == 1 || encoding == 2 { desc_end + 2 } else { desc_end + 1 }
      tags.lyrics = audio_text(content, text_start, content.length() - text_start, encoding)
    }
    offset += 10 + frame_size
  }
  if data.length() >= 128 &&
    data[data.length() - 128] == (84).to_byte() && data[data.length() - 127] == (65).to_byte() &&
    data[data.length() - 126] == (71).to_byte() {
    if tags.title == "" {
      tags.title = audio_latin1(data[data.length() - 125:data.length() - 95].to_owned()).trim().to_string()
    }
    if tags.artists.is_empty() {
      let artist = audio_latin1(data[data.length() - 95:data.length() - 65].to_owned()).trim().to_string()
      if artist != "" { tags.artists.push(artist) }
    }
    if tags.album == "" {
      tags.album = audio_latin1(data[data.length() - 65:data.length() - 35].to_owned()).trim().to_string()
    }
  }
  end
}

///|
fn audio_latin1(data : Bytes) -> String {
  let out = StringBuilder()
  for byte in data {
    out.write_char(Char::from_int(byte.to_int()))
  }
  out.to_string()
}

///|
fn audio_mpeg_duration(data : Bytes, start : Int32, tags : AudioTags) -> Unit {
  let mut offset = start
  while offset + 4 <= data.length() && data[offset] != (0xff).to_byte() {
    offset += 1
  }
  if offset + 4 > data.length() { return }
  let header = (data[offset].to_int() << 24) | (data[offset + 1].to_int() << 16) |
    (data[offset + 2].to_int() << 8) | data[offset + 3].to_int()
  let version = (header >> 19) & 3
  let layer = (header >> 17) & 3
  let bitrate_index = (header >> 12) & 0xf
  let sample_index = (header >> 10) & 3
  let rates = if version == 3 { [44100, 48000, 32000] } else { [22050, 24000, 16000] }
  let bitrates = if version == 3 {
    if layer == 1 { [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320] } else { [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192] }
  } else {
    [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192]
  }
  if sample_index < rates.length() { tags.sample_rate = rates[sample_index] }
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
fn audio_parse_id3(data : Bytes, tags : AudioTags) -> Int32 {
  audio_id3(data, tags)
}

///|
fn audio_wav(data : Bytes, tags : AudioTags) -> Unit {
  tags.format = "wav"
  tags.codec = "PCM"
  let mut offset = 12
  while offset + 8 <= data.length() {
    let id = @utf8.decode_lossy(data[offset:offset + 4].to_owned())
    let size = audio_le32(data, offset + 4).to_int()
    let start = offset + 8
    if id == "fmt " && start + 16 <= data.length() {
      tags.channels = audio_le16(data, start + 2)
      tags.sample_rate = audio_le32(data, start + 4).to_int()
      let byte_rate = audio_le32(data, start + 8)
      if byte_rate > 0L && data.length() > start {
        tags.duration = (data.length() - start).to_double() / byte_rate.to_double()
      }
      tags.bitrate = byte_rate.to_double() * 8.0
    } else if id == "data" && tags.bitrate > 0.0 {
      tags.duration = size.to_double() / (tags.bitrate / 8.0)
    } else if id == "LIST" && start + 4 <= data.length() {
      let kind = @utf8.decode_lossy(data[start:start + 4].to_owned())
      if kind == "INFO" {
        let mut at = start + 4
        while at + 8 <= data.length() {
          let key = @utf8.decode_lossy(data[at:at + 4].to_owned())
          let length = audio_le32(data, at + 4).to_int()
          if at + 8 + length > data.length() { break }
          let value = audio_latin1(data[at + 8:at + 8 + length].to_owned()).trim().to_string()
          audio_set_tag(tags, key, value)
          at += 8 + length + (if length % 2 == 1 { 1 } else { 0 })
        }
      }
    } else if id == "id3 " || id == "ID3 " {
      ignore(audio_id3(data[start:start + size].to_owned(), tags))
    }
    offset = start + size + (if size % 2 == 1 { 1 } else { 0 })
  }
}

///|
fn audio_aiff(data : Bytes, tags : AudioTags) -> Unit {
  tags.format = "aiff"
  tags.codec = "PCM"
  let mut offset = 12
  while offset + 8 <= data.length() {
    let id = @utf8.decode_lossy(data[offset:offset + 4].to_owned())
    let size = audio_be32(data, offset + 4).to_int()
    let start = offset + 8
    if id == "COMM" && start + 18 <= data.length() {
      tags.channels = audio_be16(data, start)
      let frames = audio_be32(data, start + 2)
      let rate = audio_be32(data, start + 8)
      ignore(rate)
      // COMM stores an 80-bit extended float; the common 44100 form ends in 0xAC44.
      let sample_rate = audio_be16(data, start + 16)
      if sample_rate > 0 { tags.sample_rate = sample_rate }
      if tags.sample_rate > 0 {
        tags.duration = frames.to_double() / tags.sample_rate.to_double()
      }
    } else if id == "NAME" || id == "AUTH" || id == "ANNO" {
      let value = audio_latin1(data[start:start + size].to_owned()).trim().to_string()
      audio_set_tag(tags, if id == "NAME" { "title" } else if id == "AUTH" { "artist" } else { "comment" }, value)
    } else if id == "ID3 " {
      ignore(audio_id3(data[start:start + size].to_owned(), tags))
    }
    offset = start + size + (if size % 2 == 1 { 1 } else { 0 })
  }
}

///|
fn audio_flac(data : Bytes, tags : AudioTags) -> Unit {
  tags.format = "flac"
  tags.codec = "FLAC"
  let mut offset = 4
  while offset + 4 <= data.length() {
    let header = data[offset].to_int()
    let kind = header & 0x7f
    let length = (data[offset + 1].to_int() << 16) | (data[offset + 2].to_int() << 8) |
      data[offset + 3].to_int()
    let start = offset + 4
    if start + length > data.length() { break }
    if kind == 0 && length >= 18 {
      let sample_rate = (data[start + 10].to_int() << 12) |
        (data[start + 11].to_int() << 4) | (data[start + 12].to_int() >> 4)
      let channels = ((data[start + 12].to_int() >> 1) & 7) + 1
      let total = (data[start + 13].to_int64() << 24) |
        (data[start + 14].to_int64() << 16) | (data[start + 15].to_int64() << 8) |
        data[start + 16].to_int64() | ((data[start + 17].to_int64() & 0xf) << 32)
      tags.sample_rate = sample_rate
      tags.channels = channels
      if sample_rate > 0 {
        tags.duration = total.to_double() / sample_rate.to_double()
      }
    } else if kind == 4 {
      let mut at = start
      let vendor = audio_le32(data, at).to_int()
      at += 4 + vendor
      if at + 4 <= start + length {
        let count = audio_le32(data, at).to_int()
        at += 4
        for _ in 0..<count {
          if at + 4 > start + length { break }
          let len = audio_le32(data, at).to_int()
          at += 4
          if at + len > start + length { break }
          let entry = @utf8.decode_lossy(data[at:at + len].to_owned())
          at += len
          let eq = entry.find("=")
          match eq {
            Some(index) => audio_set_tag(tags, entry[:index].to_owned(), entry[index + 1:].to_owned())
            None => ()
          }
        }
      }
    } else if kind == 6 && length > 32 {
      let mut at = start + 4
      let mime_len = audio_be32(data, at).to_int()
      at += 4 + mime_len
      if at + 4 <= start + length {
        let desc_len = audio_be32(data, at).to_int()
        at += 4 + desc_len
        if at + 20 <= start + length {
          at += 16
          let data_len = audio_be32(data, at).to_int()
          at += 4
          if at + data_len <= start + length && data_len > 0 {
            tags.cover = data[at:at + data_len].to_owned()
            let mime = @utf8.decode_lossy(data[start + 4:start + 4 + mime_len].to_owned())
            tags.cover_format = if mime.contains("png") { "png" } else if mime.contains("jpeg") || mime.contains("jpg") { "jpeg" } else { "" }
          }
        }
      }
    }
    offset = start + length
    if (header & 0x80) != 0 { break }
  }
}

///|
fn audio_ogg(data : Bytes, tags : AudioTags) -> Unit {
  tags.format = "ogg"
  tags.codec = "Vorbis"
  let mut offset = 0
  let mut comment : Bytes = b""
  while offset + 27 <= data.length() {
    if @utf8.decode_lossy(data[offset:offset + 4].to_owned()) != "OggS" { break }
    let segments = data[offset + 26].to_int()
    if offset + 27 + segments > data.length() { break }
    let mut size = 0
    for i in 0..<segments {
      size += data[offset + 27 + i].to_int()
    }
    let start = offset + 27 + segments
    if start + size > data.length() { break }
    if size > 7 && data[start] == 3 &&
      @utf8.decode_lossy(data[start + 1:start + 7].to_owned()) == "vorbis" {
      comment = data[start + 7:start + size].to_owned()
      break
    }
    if size > 8 && @utf8.decode_lossy(data[start:start + 8].to_owned()) == "OpusTags" {
      comment = data[start + 8:start + size].to_owned()
      tags.codec = "Opus"
      break
    }
    offset = start + size
  }
  if comment.length() > 8 {
    let mut at = 0
    let vendor = audio_le32(comment, at).to_int()
    at += 4 + vendor
    if at + 4 <= comment.length() {
      let count = audio_le32(comment, at).to_int()
      at += 4
      for _ in 0..<count {
        if at + 4 > comment.length() { break }
        let len = audio_le32(comment, at).to_int()
        at += 4
        if at + len > comment.length() { break }
        let entry = @utf8.decode_lossy(comment[at:at + len].to_owned())
        at += len
        let eq = entry.find("=")
        match eq {
          Some(index) => audio_set_tag(tags, entry[:index].to_owned(), entry[index + 1:].to_owned())
          None => ()
        }
      }
    }
  }
  if tags.format == "ogg" && tags.codec == "Vorbis" {
    // Vorbis identification packet gives the sample rate and channels.
    let mut offset = 0
    if data.length() > 40 && @utf8.decode_lossy(data[28:34].to_owned()) == "vorbis" {
      tags.channels = data[39].to_int()
      tags.sample_rate = audio_le32(data, 40).to_int()
    }
  }
}

///|
fn audio_mp4(data : Bytes, tags : AudioTags) -> Unit {
  tags.format = "m4a"
  tags.codec = "AAC"
  let mut offset = 0
  while offset + 8 <= data.length() {
    let size = audio_be32(data, offset).to_int()
    let kind = @utf8.decode_lossy(data[offset + 4:offset + 8].to_owned())
    if size <= 0 || offset + size > data.length() || kind == "" { break }
    if kind == "moov" {
      let mut at = offset + 8
      let end = offset + size
      while at + 8 <= end {
        let child = audio_be32(data, at).to_int()
        let child_kind = @utf8.decode_lossy(data[at + 4:at + 8].to_owned())
        if child <= 0 || at + child > end { break }
        if child_kind == "mvhd" && child > 20 {
          let version = data[at + 8].to_int()
          if version == 0 {
            let timescale = audio_be32(data, at + 20).to_int()
            let duration = audio_be32(data, at + 24)
            if timescale > 0 {
              tags.duration = duration.to_double() / timescale.to_double()
            }
          } else if at + 36 < data.length() {
            let timescale = audio_be32(data, at + 28).to_int()
            let duration = audio_be32(data, at + 32)
            if timescale > 0 {
              tags.duration = duration.to_double() / timescale.to_double()
            }
          }
        }
        at += child
      }
    }
    offset += size
  }
}

///|
fn audio_detect_format(data : Bytes) -> String {
  if data.length() < 4 { return "" }
  if data[0] == (73).to_byte() && data[1] == (68).to_byte() && data[2] == (51).to_byte() {
    return "mp3"
  }
  let head = @utf8.decode_lossy(data[:(4).min(data.length())].to_owned())
  if head == "fLaC" { return "flac" }
  if head == "OggS" { return "ogg" }
  if data.length() >= 12 {
    let riff = @utf8.decode_lossy(data[:4].to_owned())
    let form = @utf8.decode_lossy(data[8:12].to_owned())
    if (riff == "RIFF" || riff == "RF64") && form == "WAVE" { return "wav" }
    if riff == "FORM" && (form == "AIFF" || form == "AIFC") { return "aiff" }
    if @utf8.decode_lossy(data[4:8].to_owned()) == "ftyp" { return "m4a" }
  }
  if data[0] == (0xff).to_byte() && (data[1].to_int() & 0xf6) == 0xf0 { return "aac" }
  if data[0] == (0xff).to_byte() && (data[1].to_int() & 0xe0) == 0xe0 { return "mp3" }
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
fn audio_clock(seconds : Double) -> String {
  let total = seconds.round().to_int()
  let minutes = total / 60
  let rest = total % 60
  "\{minutes}:\{if rest < 10 { "0" } else { "" }}\{rest}"
}

///|
fn audio_bytes_text(size : Int64) -> String {
  if size >= 1048576L {
    "\{size / 1048576L} MiB"
  } else if size >= 1024L {
    "\{size / 1024L} KiB"
  } else {
    "\{size} bytes"
  }
}

///|
/// Convert an audio file into a one-page card.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  file_name~ : String = "",
  play~ : Bool = true,
) -> AudioResult raise AudioError {
  let format = audio_detect_format(data)
  if format == "" {
    raise AudioInvalid("audio: unsupported audio file")
  }
  let tags = audio_tags()
  tags.format = format
  let mut start = 0
  if format == "mp3" {
    start = audio_parse_id3(data, tags)
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
  }
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
  let lines : Array[(String, Double, Bool, UInt32)] = []
  lines.push((document_title, 22.0, true, 0x111111ffU))
  if !tags.artists.is_empty() {
    lines.push((tags.artists.join(", "), 14.0, false, 0x333333ffU))
  }
  if tags.album != "" {
    lines.push((tags.album, 13.0, false, 0x666666ffU))
  }
  let details : Array[String] = []
  details.push(tags.format.to_upper())
  if tags.duration > 0.0 { details.push(audio_clock(tags.duration)) }
  if tags.bitrate > 0.0 { details.push("\{(tags.bitrate / 1000.0).round().to_int()} kbps") }
  if tags.sample_rate > 0 { details.push("\{(tags.sample_rate.to_double() / 1000.0).round().to_int()} kHz") }
  if tags.channels == 1 { details.push("mono") } else if tags.channels == 2 { details.push("stereo") }
  lines.push((details.join(", "), 10.0, false, 0x777777U))
  if tags.year != "" || tags.genre != "" || tags.track != "" {
    let extra : Array[String] = []
    if tags.year != "" { extra.push(tags.year) }
    if tags.genre != "" { extra.push(tags.genre) }
    if tags.track != "" { extra.push("Track " + tags.track) }
    lines.push((extra.join(" · "), 10.0, false, 0x777777U))
  }
  if tags.lyrics != "" {
    lines.push(("", 6.0, false, 0x000000ffU))
    for line in tags.lyrics.split("\n") {
      if lines.length() > 80 { break }
      lines.push((line.to_owned(), 11.0, false, 0x222222ffU))
    }
  }
  let mut text_height = 0.0
  for (_, size, _, _) in lines {
    text_height += size * 1.5
  }
  let height = (if has_cover { cover_h } else { 60.0 }) + text_height + 80.0
  let meta : Map[String, Json] = {
    "source": Json::string(format),
    "generator": Json::string("bdf-go/0.1"),
    "dc": Json::object({ "title": Json::string(document_title) }),
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
          index, 0.0F, 0.0F, Float::from_double(cover_w), Float::from_double(cover_h),
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
    object.fill_text("♪ Audio", 18.0, 28.0, Float::from_double(width - 36.0))
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
    object.fill_text(text, 18.0, Float::from_double(y + size), Float::from_double(width - 36.0))
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
  if play && data.length() <= 268435456 {
    let audio_hash = writer.add_part("audio", data) catch { _ => "" }
    if audio_hash != "" {
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
  let summary = "1 page (" + (if has_cover { "cover \{cover_w.round().to_int()} × \{cover_h.round().to_int()} px" } else { "no cover" }) +
    "; \{tags.format.to_upper()}" + (if tags.duration > 0.0 { ", " + audio_clock(tags.duration) } else { "" }) +
    (if tags.bitrate > 0.0 { ", \{(tags.bitrate / 1000.0).round().to_int()} kbps" } else { "" }) +
    (if play { "; plays" } else { "" }) + ")"
  ignore(start)
  {
    bdf,
    pages: 1,
    summary,
    warnings: [],
  }
}
