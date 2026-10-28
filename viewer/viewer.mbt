///|
pub(all) enum Layout {
  Single
  Spread
  Continuous
} derive(Debug, Eq)

///|
pub(all) struct Placement {
  index : Int
  x : Double
  y : Double
  width : Double
  height : Double
}

///|
pub(all) struct Viewer {
  mut layout : Layout
  mut zoom : Double
  mut page : Int
  mut view_id : String
}

///|
pub suberror ViewerError {
  InvalidZoom
  NoSuchPage
  NoSuchView
}

///|
pub fn Viewer::new() -> Viewer {
  { layout: Single, zoom: 1.0, page: 0, view_id: "" }
}

///|
pub fn Viewer::set_layout(self : Viewer, value : Layout) -> Unit {
  self.layout = value
}

///|
pub fn Viewer::set_zoom(self : Viewer, value : Double) -> Unit raise {
  if value.is_nan() || value < 0.1 || value > 8.0 {
    raise InvalidZoom
  }
  self.zoom = value
}

///|
pub fn Viewer::set_view(self : Viewer, document : @core.Manifest, id : String) -> Unit raise {
  for v in document.views {
    if v.id == id {
      self.view_id = id
      self.page = 0
      return
    }
  }
  raise NoSuchView
}

///|
pub fn Viewer::scroll_to_page(self : Viewer, view : @core.View, index : Int) -> Placement raise {
  let pages = self.placements(view)
  if index < 0 || index >= pages.length() {
    raise NoSuchPage
  }
  self.page = index
  pages[index]
}

///|
/// Produce device-independent page positions. A browser host owns scrolling,
/// lazy rasterization, observers, and actual Canvas allocation.
pub fn Viewer::placements(self : Viewer, view : @core.View) -> Array[Placement] {
  let result : Array[Placement] = []
  let mut y = 0.0
  let gap = 16.0
  let zoom = self.zoom
  let pages = view.pages
  match self.layout {
    Single | Continuous => {
      for index, page in pages {
        let width = page.width * zoom
        let height = page.height * zoom
        result.push({ index, x: 0.0, y, width, height })
        y += height + gap
      }
    }
    Spread => {
      let mut index = 0
      while index < pages.length() {
        let page = pages[index]
        let width = page.width * zoom
        let height = page.height * zoom
        result.push({ index, x: 0.0, y, width, height })
        let mut row_height = height
        if index + 1 < pages.length() {
          let next = pages[index + 1]
          let next_height = next.height * zoom
          result.push({
            index: index + 1,
            x: width + gap,
            y,
            width: next.width * zoom,
            height: next_height,
          })
          if next_height > row_height {
            row_height = next_height
          }
        }
        y += row_height + gap
        index += 2
      }
    }
  }
  result
}
