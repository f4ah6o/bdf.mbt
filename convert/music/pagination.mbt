///|
/// Vertical extent of one staff in staff spaces, and its owning part.
pub(all) struct MusicStaffExtent {
  part : Int32
  above : Double
  below : Double
}

///|
/// Staff extents for a system, with an optional explicit page break.
pub(all) struct MusicSystemExtent {
  staves : Array[MusicStaffExtent]
  page_break : Bool
}

///|
/// Positioned system: staff offsets are in staff spaces, top is in points.
pub(all) struct MusicSystemPlacement {
  staff_y : Array[Double]
  above : Double
  below : Double
  mut top : Double
  page : Int32
}

///|
/// Paginate systems whose staff drawings already have measured extents.
/// Each system must contain at least one staff. Title height and page height
/// are in points, while staff extents are in staff spaces.
pub fn paginate_systems(
  systems : Array[MusicSystemExtent],
  page_height : Double,
  staff_space : Double,
  title_height : Double,
) -> Array[MusicSystemPlacement] {
  let margin = 14.0 * (72.0 / 25.4)
  let bottom = page_height - margin
  let result : Array[MusicSystemPlacement] = []
  let pages : Array[Array[Int32]] = [[]]
  let mut y = margin + title_height
  for index, sys in systems {
    let offsets : Array[Double] = [0.0]
    for i in 1..<sys.staves.length() {
      let previous = sys.staves[i - 1]
      let staff = sys.staves[i]
      let minimum = if staff.part == previous.part { 5.5 } else { 6.5 }
      let gap = Double::max(minimum, previous.below - 4.0 - staff.above + 1.0)
      offsets.push(offsets[i - 1] + 4.0 + gap)
    }
    let above = sys.staves[0].above
    let last = sys.staves.length() - 1
    let below = offsets[last] + sys.staves[last].below
    let mut top = y - above * staff_space
    let mut current = pages[pages.length() - 1]
    if !current.is_empty() {
      let previous = result[current[current.length() - 1]]
      top = Double::max(
        top + 2.5 * staff_space,
        previous.top +
        (previous.staff_y[previous.staff_y.length() - 1] + 4.0 + 8.0) *
        staff_space,
      )
    }
    if !current.is_empty() &&
      (top + below * staff_space > bottom || (index > 0 && sys.page_break)) {
      current = []
      pages.push(current)
      top = margin - above * staff_space
    }
    result.push({
      staff_y: offsets,
      above,
      below,
      top,
      page: pages.length() - 1,
    })
    y = top + below * staff_space
    current.push(index)
  }
  for pi in 0..<(pages.length() - 1) {
    let page = pages[pi]
    if page.length() < 2 {
      continue
    }
    let last = result[page[page.length() - 1]]
    let free = bottom - (last.top + last.below * staff_space)
    let start = margin + (if pi == 0 { title_height } else { 0.0 })
    let used = last.top + last.below * staff_space - start
    if used < 0.6 * (bottom - start) {
      continue
    }
    let step = Double::min(
      free / (page.length() - 1).to_double(),
      10.0 * staff_space,
    )
    for k, si in page {
      result[si].top += step * k.to_double()
    }
  }
  result
}
