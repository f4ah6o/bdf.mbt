///|
/// A part of a match in one index run. Offsets are UTF-16 code units.
pub(all) struct HitSegment {
  run : Int32
  a : Int32
  b : Int32
  ordinal : Int32
  start : Int32
  mut end : Int32
} derive(Eq, Debug)

///|
/// A match with its original text and normalized surrounding context.
pub(all) struct SearchHit {
  segments : Array[HitSegment]
  text : String
  context : String
} derive(Eq, Debug)

///|
/// Fold each normalized character in the same order as the upstream reader.
fn fold_search(input : String, case_sensitive : Bool) -> String {
  let out = StringBuilder()
  for ch in input {
    if ch == '\u{2212}' {
      out.write_char('-')
      continue
    }
    let original = ch.to_string()
    let lower = if case_sensitive {
      original
    } else {
      let full = @unicode.to_lowercase(ch)
      if full == original {
        @unicode.to_simple_lowercase(ch).to_string()
      } else {
        full
      }
    }
    for c in lower {
      let cp = c.to_int()
      out.write_char(
        if cp >= 0x30a1 && cp <= 0x30f6 {
          (cp - 0x60).unsafe_to_char()
        } else {
          c
        },
      )
    }
  }
  out.to_string()
}

///|
/// Normalize a query using NFKC, optional lowercase, kana and minus folding.
pub fn normalize_query(
  query : String,
  case_sensitive~ : Bool = false,
) -> String {
  fold_search(@normalization.nfkc(query), case_sensitive)
}

///|
fn search_mark_start(s : String) -> Bool {
  for c in s {
    return @unicode.general_category(c).group() == @unicode.M
  }
  false
}

///|
/// The normalized text and its mapping back to the input runs.
pub struct TextSearch {
  runs : Array[IndexRun]
  case_sensitive : Bool
  normalized : String
  plain : String
  run_of : Array[Int32]
  start_of : Array[Int32]
  end_of : Array[Int32]
}

///|
fn search_piece(
  out : StringBuilder,
  run_of : Array[Int32],
  start_of : Array[Int32],
  end_of : Array[Int32],
  run : Int32,
  start : Int32,
  end : Int32,
  normalized : String,
  case_sensitive : Bool,
) -> Unit {
  let folded = fold_search(normalized, case_sensitive)
  out.write_string(folded)
  for _ in 0..<folded.length() {
    run_of.push(run)
    start_of.push(start)
    end_of.push(end)
  }
}

///|
/// Build a search index. Pieces are capped at 32 characters to keep long
/// sequences of combining marks linear in the size of the input.
pub fn TextSearch::new(
  runs : Array[IndexRun],
  case_sensitive~ : Bool = false,
) -> TextSearch {
  let out = StringBuilder()
  let run_of : Array[Int32] = []
  let start_of : Array[Int32] = []
  let end_of : Array[Int32] = []
  for ri, run in runs {
    if ri > 0 && run.separator != 0 {
      out.write_char(if run.separator == 2 { '\u{0}' } else { ' ' })
      run_of.push(-1)
      start_of.push(-1)
      end_of.push(-1)
    }
    let mut start = 0
    let mut offset = 0
    let mut piece = ""
    let mut normalized = ""
    let mut count = 0
    for ch in run.text {
      let c = ch.to_string()
      let ascii = ch.to_int() < 0x80
      let n = if ascii { c } else { @normalization.nfkc(c) }
      if piece != "" {
        if !ascii &&
          count < 32 &&
          (
            search_mark_start(n) ||
            @normalization.nfkc(piece + c) != normalized + n
          ) {
          piece = piece + c
          count += 1
          normalized = @normalization.nfkc(piece)
          offset += ch.utf16_len()
          continue
        }
        search_piece(
          out, run_of, start_of, end_of, ri, start, offset, normalized, case_sensitive,
        )
      }
      start = offset
      piece = c
      count = 1
      normalized = n
      offset += ch.utf16_len()
    }
    if piece != "" {
      search_piece(
        out, run_of, start_of, end_of, ri, start, offset, normalized, case_sensitive,
      )
    }
  }
  let normalized = out.to_string()
  let plain = normalized.replace_all(old="\u{0}", new="\n")
  { runs, case_sensitive, normalized, plain, run_of, start_of, end_of, }
}

///|
/// Searchable normalized text, with paragraph boundaries shown as newlines.
pub fn TextSearch::text(self : TextSearch) -> String {
  self.plain
}

///|
/// ECMAScript's whitespace set used by the upstream query's `/\s+/g`.
fn query_whitespace(c : Char) -> Bool {
  c == '\u{feff}' || (c != '\u{85}' && c.is_whitespace())
}

///|
fn collapse_query_whitespace(query : String) -> String {
  let out = StringBuilder()
  let mut whitespace = false
  for c in query {
    if query_whitespace(c) {
      if !whitespace {
        out.write_char(' ')
      }
      whitespace = true
    } else {
      out.write_char(c)
      whitespace = false
    }
  }
  out.to_string()
}

///|
/// Clamp an ECMAScript slice index, including negative indices from the end.
fn search_slice_index(index : Int64, length : Int32) -> Int32 {
  let len = length.to_int64()
  let offset = if index < 0L { (len + index).max(0L) } else { index.min(len) }
  offset.to_int()
}

///|
fn TextSearch::locate(
  self : TextSearch,
  start : Int32,
  end : Int32,
  context : Int32,
) -> SearchHit? {
  let segments : Array[HitSegment] = []
  for i in start..<end {
    let ri = self.run_of[i]
    if ri < 0 {
      continue
    }
    let run = self.runs[ri]
    let last = segments.length() - 1
    if last >= 0 && segments[last].run == ri {
      segments[last].end = segments[last].end.max(self.end_of[i])
    } else {
      segments.push({
        run: ri,
        a: run.a,
        b: run.b,
        ordinal: run.ordinal,
        start: self.start_of[i],
        end: self.end_of[i],
      })
    }
  }
  if segments.is_empty() {
    return None
  }
  let original = StringBuilder()
  let mut has_text = false
  for segment in segments {
    let run = self.runs[segment.run]
    if has_text && run.separator == 1 {
      original.write_char(' ')
    }
    // A caller can replace a run after the index was constructed. Match
    // String.slice's clamping rather than reading beyond the new text.
    let start = segment.start.min(run.text.length())
    let end = segment.end.min(run.text.length()).max(start)
    let text = run.text.unsafe_substring(start~, end~)
    original.write_string(text)
    if text != "" {
      has_text = true
    }
  }
  let plain = self.text()
  let left = search_slice_index(
    (start.to_int64() - context.to_int64()).max(0L),
    plain.length(),
  )
  let right = search_slice_index(
    (end.to_int64() + context.to_int64()).min(plain.length().to_int64()),
    plain.length(),
  ).max(left)
  let excerpt = plain
    .unsafe_substring(start=left, end=right)
    .replace_all(old="\n", new=" ⏎ ")
  Some({ segments, text: original.to_string(), context: excerpt, })
}

///|
/// Return overlapping matches and their UTF-16 positions in original runs.
pub fn TextSearch::search(
  self : TextSearch,
  query : String,
  limit~ : Int32 = 1000,
  context~ : Int32 = 40,
) -> Array[SearchHit] {
  let q = collapse_query_whitespace(
    normalize_query(query, case_sensitive=self.case_sensitive),
  )
  let hits : Array[SearchHit] = []
  if q == "" || limit <= 0 {
    return hits
  }
  let mut from = 0
  while hits.length() < limit && from <= self.normalized.length() {
    let remaining = self.normalized.clamped_view(start=from)
    match remaining.find(q[:]) {
      None => break
      Some(relative) => {
        // `from` can fall inside a surrogate pair after an overlapping hit.
        let skipped = self.normalized.length() - remaining.length() - from
        let at = from + skipped + relative
        from = at + 1
        match self.locate(at, at + q.length(), context) {
          Some(hit) => hits.push(hit)
          None => ()
        }
      }
    }
  }
  hits
}
