///|
priv struct IdmlFrameRef {
  key : String
  story : String
  rect : @drawingml.TextRect
}

///|
fn idml_collect_frames(
  items : Array[IdmlXmlNode],
  parent : IdmlMatrix,
  page : IdmlPage,
  output : Array[IdmlFrameRef],
) -> Unit {
  for item in items {
    let matrix = idml_item_matrix(item, parent)
    if item.element.name.local_name == "Group" {
      idml_collect_frames(item.children, matrix, page, output)
      continue
    }
    if item.element.name.local_name != "TextFrame" {
      continue
    }
    let story = idml_attr(Some(item), "ParentStory", "")
    if story == "" {
      continue
    }
    let rect = match idml_text_frame_bounds(item, matrix) {
      Some((left, top, right, bottom)) => {
        let left = left.max(0.0)
        let top = top.max(0.0)
        let right = right.min(page.width)
        let bottom = bottom.min(page.height)
        if right - left <= 1.0 || bottom - top <= 1.0 {
          continue
        }
        @drawingml.TextRect::{
          x: left,
          y: top,
          width: right - left,
          height: bottom - top,
        }
      }
      None => continue
    }
    output.push({
      key: idml_attr(Some(item), "Self", ""),
      story,
      rect,
    })
  }
}

///|
fn idml_flow_stories(
  doc : IdmlDocument,
) -> (Map[String, Array[@drawingml.TextLine]], Bool) {
  let frames : Map[String, Array[@drawingml.TextRect]] = Map([])
  let keys : Map[String, Array[String]] = Map([])
  for spread in doc.spreads {
    for page in spread.pages {
      let refs : Array[IdmlFrameRef] = []
      idml_collect_frames(spread.items, page.transform, page, refs)
      for ref in refs {
        if !frames.contains(ref.story) {
          frames[ref.story] = []
          keys[ref.story] = []
        }
        frames[ref.story].push(ref.rect)
        keys[ref.story].push(ref.key)
      }
    }
  }
  let flow : Map[String, Array[@drawingml.TextLine]] = Map([])
  let mut overflow = false
  for story, rects in frames {
    let body = match doc.story_bodies.get(story) {
      Some(value) => value
      None => continue
    }
    let (lines, did_overflow) = @drawingml.flow(body, rects)
    if did_overflow {
      overflow = true
    }
    let story_keys = keys.get(story).unwrap_or([])
    for i, frame_lines in lines {
      if i < story_keys.length() {
        flow[story_keys[i]] = frame_lines
      }
    }
  }
  (flow, overflow)
}
