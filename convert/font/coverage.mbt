///|
/// A Unicode block's bounds and the number of assigned characters.
pub(all) struct UnicodeBlock {
  first : Int32
  last : Int32
  name : String
  assigned : Int32
}

///|
/// A block represented in the font's character map.
pub(all) struct BlockCoverage {
  block : UnicodeBlock
  mapped : Int32
}

///|
/// List represented Unicode blocks in order, followed by a "No block" entry
/// for mapped code points outside every block, as in the upstream converter.
pub fn FileFace::coverage(self : FileFace) -> Array[BlockCoverage] {
  let chars = self.font.characters()
  let result : Array[BlockCoverage] = []
  let stray : Array[Int32] = []
  let mut i = 0
  for block in specimen_blocks {
    while i < chars.length() && chars[i] < block.first {
      stray.push(chars[i])
      i += 1
    }
    let start = i
    while i < chars.length() && chars[i] <= block.last {
      i += 1
    }
    if i > start {
      result.push({ block, mapped: i - start, })
    }
  }
  while i < chars.length() {
    stray.push(chars[i])
    i += 1
  }
  if stray.length() > 0 {
    result.push({
      block: {
        first: stray[0],
        last: stray[stray.length() - 1],
        name: "No block",
        assigned: 0,
      },
      mapped: stray.length(),
    })
  }
  result
}

///|
fn specimen_graphic(code : Int32) -> Bool {
  let mut low = 0
  let mut high = specimen_graphic_ranges.length()
  while low < high {
    let mid = low + (high - low) / 2
    let (first, last) = specimen_graphic_ranges[mid]
    if code < first {
      high = mid
    } else if code > last {
      low = mid + 1
    } else {
      return true
    }
  }
  false
}
