///|
// Page layout: paragraphs, tables, columns, vertical sections and the
// header/footer stories are laid out here. The engine approximates font
// metrics, so its page counts can differ from Word's.

///|
priv struct DocxPlacedImage {
  item : DocxTextItem
  x : Double
  y : Double
  width : Double
  height : Double
  draw_width : Double
  draw_height : Double
  anchored : Bool
}

///|
// A floating object of the current page, waiting to be drawn in front of
// the text (a behind object is drawn where it is placed, before the text
// that follows it).
priv struct DocxFloat {
  image : DocxPlacedImage
  z : Int32
}

///|
// The area a floating object keeps the text out of. It is in page
// coordinates; the layout moves it into the coordinates of the column when
// it asks what a line has room for.
priv struct DocxExcl {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
  full : Bool
  side : String
}

///|
priv struct DocxParaLine {
  items : Array[DocxLineItem]
  images : Array[DocxPlacedImage]
  height : Double
  align : String
  justify : Bool
  distribute : Bool
  break_before : String
  mut shade : UInt32?
  mut borders : Array[DocxLineBorder?]
  mut border_top : Bool
  mut border_bottom : Bool
}

///|
priv struct DocxParaLayout {
  lines : Array[DocxParaLine]
  anchors : Array[DocxPlacedImage]
  notes : Array[(String, String)]
  trailing_break : String
}

///|
priv struct DocxStoryLayout {
  lines : Array[DocxParaLine]
  starts : Array[Int]
  props : Array[DocxParagraphProps]
  tables : Array[DocxTableLayout]
  anchors : Array[DocxPlacedImage]
  height : Double
}

///|
priv struct DocxTableCellLine {
  y : Double
  line : DocxParaLine
}

///|
priv struct DocxCellNestedBlock {
  y : Double
  layout : DocxTableLayout
  height : Double
}

///|
priv enum DocxCellBlockLayout {
  DocxCellLines(Array[DocxTableCellLine])
  DocxCellAnchors(Array[DocxPlacedImage])
  DocxCellNested(DocxCellNestedBlock)
}

///|
priv struct DocxTableCellLayout {
  x : Double
  w : Double
  height : Double
  valign : String
  mar_top : Double
  mar_left : Double
  mar_bottom : Double
  mar_right : Double
  blocks : Array[DocxCellBlockLayout]
  notes : Array[(String, String)]
}

///|
priv struct DocxTableRowLayout {
  mut height : Double
  cells : Array[DocxTableCellLayout]
}

///|
priv struct DocxTableLayout {
  table : DocxTable
  left : Double
  total_width : Double
  col_x : Array[Double]
  rows : Array[DocxTableRowLayout]
  notes : Array[(String, String)]
}

///|
fn docx_paragraph_natural(
  items : Array[DocxLineItem],
  images : Array[DocxPlacedImage],
) -> Double {
  let mut natural = 0.0
  for item in items {
    if item.kind != "field" && item.size * 1.2 > natural {
      natural = item.size * 1.2
    }
    if item.kind == "field" && item.size * 1.2 > natural {
      natural = item.size * 1.2
    }
  }
  for image in images {
    if image.height > natural {
      natural = image.height
    }
  }
  natural
}

///|
fn docx_line_box_height(
  natural : Double,
  props : DocxParagraphProps,
  pitch : Double,
) -> Double {
  let line = if props.line > 0.0 { props.line } else { 240.0 }
  let grid = if props.snap_to_grid && pitch > 0.0 { pitch } else { 0.0 }
  let gridded = if grid > 0.0 && natural > 0.0 {
    Double::max(1.0, @math.ceil(natural / grid - 0.01)) * grid
  } else {
    natural
  }
  match props.line_rule {
    "exact" => line / 20.0
    "atLeast" => Double::max(line / 20.0, gridded)
    _ => {
      let mult = if line / 240.0 <= 0.0 { 1.0 } else { line / 240.0 }
      gridded * mult
    }
  }
}

///|
fn docx_para_before(props : DocxParagraphProps) -> Double {
  if props.contextual { 0.0 } else { props.before }
}

///|
fn docx_para_after(props : DocxParagraphProps) -> Double {
  if props.contextual { 0.0 } else { props.after }
}

///|
fn docx_layout_paragraph(
  items : Array[DocxTextItem],
  props : DocxParagraphProps,
  width : Double,
  pitch : Double,
  mark_size : Double,
  allow_notes : Bool,
) -> DocxParaLayout {
  let lines : Array[DocxParaLine] = []
  let anchors : Array[DocxPlacedImage] = []
  let notes : Array[(String, String)] = []
  let start = props.left + props.first
  let right = width - props.right
  let current : Array[DocxLineItem] = []
  let current_images : Array[DocxPlacedImage] = []
  let mut line_x = start
  let mut line_natural = 0.0
  let align = props.alignment
  let mut pending_break = ""
  let mut line_started = false

  fn push_text(
    text : String,
    item : DocxTextItem,
    size : Double,
    advance : Double,
    rise : Double,
  ) -> Unit {
    current.push({
      kind: "text",
      text,
      link: item.link,
      field_format: "",
      language: docx_item_language(item.props, text),
      font: docx_font_family(item.props, text),
      weight: docx_font_weight(item.props),
      style: docx_font_style(item.props),
      size,
      color: docx_run_color(item.props),
      rise,
      underline: item.props.underline,
      strike: (item.props.toggles & 16) != 0 ||
        (item.props.toggles & 32) != 0,
      shadow: (item.props.toggles & 256) != 0,
      emphasis: item.props.emphasis,
      x: line_x,
      advance,
      shade: item.shade,
      border_width: item.border_width,
      border_color: item.border_color,
    })
    line_x += advance
    line_started = true
    let natural = size * 1.2
    if natural > line_natural {
      line_natural = natural
    }
  }

  fn flush() -> Unit {
    if current.is_empty() && current_images.is_empty() && !line_started {
      return
    }
    let natural = if line_natural <= 0.0 {
      mark_size * 1.2
    } else {
      line_natural
    }
    let height = Double::max(docx_line_box_height(natural, props, pitch), 1.0)
    lines.push({
      items: current.copy(),
      images: current_images.copy(),
      height,
      align,
      justify: false,
      distribute: false,
      break_before: pending_break,
      shade: None,
      borders: [],
      border_top: false,
      border_bottom: false,
    })
    current.clear()
    current_images.clear()
    line_x = props.left
    line_natural = 0.0
    pending_break = ""
    line_started = false
  }

  for item_index, item in items {
    match item.kind {
      "page" | "column" => {
        flush()
        pending_break = item.kind
      }
      "break" => flush()
      "tab" => {
        let relative = line_x - props.left
        let mut next = 0.0
        let mut leader = "none"
        let mut tab_alignment = "left"
        for stop in props.tabs {
          if stop.position > relative {
            if stop.alignment == "bar" {
              current.push({
                kind: "bar",
                text: "",
                link: "",
                field_format: "",
                language: "",
                font: docx_font_family(item.props, ""),
                weight: docx_font_weight(item.props),
                style: docx_font_style(item.props),
                size: item.props.size,
                color: 0x000000ffU,
                rise: 0.0,
                underline: "",
                strike: false,
                shadow: false,
                emphasis: "",
                x: props.left + stop.position,
                advance: 0.0,
                shade: None,
                border_width: 0.0,
                border_color: None,
              })
              continue
            }
            next = stop.position
            leader = stop.leader
            tab_alignment = stop.alignment
            break
          }
        }
        if next > 0.0 && tab_alignment != "left" {
          let width = docx_tab_width(
            items, item_index + 1, tab_alignment == "decimal",
          )
          let aligned = if tab_alignment == "right" {
            next - width
          } else if tab_alignment == "center" {
            next - width / 2.0
          } else if tab_alignment == "decimal" {
            next - width
          } else {
            next
          }
          if aligned > relative {
            next = aligned
          }
        }
        if next == 0.0 {
          next = docx_round_up(relative / 36.0) * 36.0
          if next <= relative {
            next += 36.0
          }
        }
        let leader_char = match leader {
          "dot" => "."
          "hyphen" => "-"
          "underscore" => "_"
          "heavy" => "_"
          "middleDot" => "\u00b7"
          _ => ""
        }
        if leader_char != "" && next > relative {
          let size = if item.props.size > 0.0 { item.props.size } else { 10.0 }
          let unit = docx_text_width(leader_char, size)
          let count = ((next - relative) / unit).to_int()
          if count > 0 {
            let text = StringBuilder()
            for _ in 0..<count {
              text.write_string(leader_char)
            }
            let advance = unit * count.to_double()
            current.push({
              kind: "text",
              text: text.to_string(),
              link: item.link,
              field_format: "",
              language: "",
              font: docx_font_family(item.props, text.to_string()),
              weight: docx_font_weight(item.props),
              style: docx_font_style(item.props),
              size,
              color: docx_run_color(item.props),
              rise: 0.0,
              underline: "",
              strike: false,
              shadow: false,
              emphasis: "",
              x: line_x,
              advance,
              shade: None,
              border_width: 0.0,
              border_color: None,
            })
            line_started = true
            let natural = size * 1.2
            if natural > line_natural {
              line_natural = natural
            }
          }
        }
        line_x = props.left + next
        line_started = true
      }
      "image" => {
        let mut image_width = if item.width > 0.0 { item.width } else { 72.0 }
        let mut image_height = if item.height > 0.0 {
          item.height
        } else {
          72.0
        }
        let mut effect_left = item.effect_left
        let mut effect_top = item.effect_top
        let mut outer_width = image_width + effect_left + item.effect_right
        let mut outer_height = image_height + effect_top + item.effect_bottom
        if item.anchored {
          anchors.push({
            item,
            x: item.x,
            y: item.y,
            width: image_width,
            height: image_height,
            draw_width: image_width,
            draw_height: image_height,
            anchored: true,
          })
        } else {
          let available = right - line_x
          if outer_width > available && (line_started || !current.is_empty()) {
            flush()
          }
          let available = right - line_x
          if available > 0.0 && outer_width > available {
            let scale = available / outer_width
            image_width *= scale
            image_height *= scale
            effect_left *= scale
            effect_top *= scale
            outer_width = available
            outer_height *= scale
          }
          current_images.push({
            item,
            x: line_x + effect_left,
            y: effect_top,
            width: outer_width,
            height: outer_height,
            draw_width: image_width,
            draw_height: image_height,
            anchored: false,
          })
          line_x += outer_width
          line_started = true
          if outer_height > line_natural {
            line_natural = outer_height
          }
        }
      }
      "footnote" | "endnote" => {
        let size = 7.5
        let advance = docx_text_width(item.text, size)
        if line_x + advance > right && line_started {
          flush()
        }
        if allow_notes {
          let mut known = false
          for note in notes {
            if note.0 == item.kind && note.1 == item.text {
              known = true
            }
          }
          if !known {
            notes.push((item.kind, item.text))
          }
          current.push({
            kind: "text",
            text: item.text,
            link: item.link,
            field_format: "",
            language: docx_item_language(item.props, item.text),
            font: "sans-serif",
            weight: 400,
            style: 0,
            size,
            color: 0x000000ffU,
            rise: 0.0,
            underline: "",
            strike: false,
            shadow: false,
            emphasis: "",
            x: line_x,
            advance,
            shade: None,
            border_width: 0.0,
            border_color: None,
          })
          line_x += advance
          line_started = true
          let natural = size * 1.2
          if natural > line_natural {
            line_natural = natural
          }
        } else {
          current.push({
            kind: "text",
            text: item.text,
            link: item.link,
            field_format: "",
            language: docx_item_language(item.props, item.text),
            font: "sans-serif",
            weight: 400,
            style: 0,
            size,
            color: 0x000000ffU,
            rise: 0.0,
            underline: "",
            strike: false,
            shadow: false,
            emphasis: "",
            x: line_x,
            advance,
            shade: None,
            border_width: 0.0,
            border_color: None,
          })
          line_x += advance
          line_started = true
        }
      }
      "bookmark" => {
        current.push({
          kind: "bookmark",
          text: item.text,
          link: "",
          field_format: "",
          language: "",
          font: "sans-serif",
          weight: 400,
          style: 0,
          size: 10.0,
          color: 0x000000ffU,
          rise: 0.0,
          underline: "",
          strike: false,
          shadow: false,
          emphasis: "",
          x: line_x,
          advance: 0.0,
          shade: None,
          border_width: 0.0,
          border_color: None,
        })
      }
      "field" => {
        let size = if item.props.size > 0.0 { item.props.size } else { 10.0 }
        let advance = size * 0.5
        if line_x + advance > right && line_started {
          flush()
        }
        current.push({
          kind: "field",
          text: item.text,
          link: item.link,
          field_format: item.field_format,
          language: docx_item_language(item.props, item.text),
          font: docx_font_family(item.props, item.text),
          weight: docx_font_weight(item.props),
          style: docx_font_style(item.props),
          size,
          color: docx_run_color(item.props),
          rise: 0.0,
          underline: "",
          strike: false,
          shadow: false,
          emphasis: "",
          x: line_x,
          advance,
          shade: item.shade,
          border_width: item.border_width,
          border_color: item.border_color,
        })
        line_x += advance
        line_started = true
        let natural = size * 1.2
        if natural > line_natural {
          line_natural = natural
        }
      }
      _ => {
        let base_size = if item.props.size > 0.0 { item.props.size } else { 10.0 }
        let (size, rise) = match item.props.vertical_align {
          "superscript" => (base_size * 0.65, base_size * 0.4)
          "subscript" => (base_size * 0.65, -base_size * 0.15)
          _ => (base_size, 0.0)
        }
        let rise = rise + item.props.position
        for c in item.text {
          let small = item.small_caps && c >= 'a' && c <= 'z'
          let char_size = if small { size * 0.8 } else { size }
          let advance = docx_char_width(c, char_size) + item.props.spacing
          if line_x + advance > right && line_started {
            if c == ' ' {
              // A space at the end of a line is not drawn.
              continue
            }
            let mut space_index = -1
            for i in 0..<current.length() {
              let candidate = current[i]
              if candidate.kind == "text" && candidate.text == " " {
                space_index = i
              }
            }
            if space_index >= 0 && space_index < current.length() - 1 {
              let moved : Array[DocxLineItem] = []
              while current.length() > space_index + 1 {
                moved.insert(0, current.pop().unwrap())
              }
              flush()
              let mut next_x = props.left
              for part in moved {
                let part_width = part.advance
                current.push({ ..part, x: next_x, })
                next_x += part_width
              }
              line_x = next_x
              line_started = true
              for part in moved {
                if part.size * 1.2 > line_natural {
                  line_natural = part.size * 1.2
                }
              }
            } else {
              flush()
            }
          }
          let text = StringBuilder()
          text.write_char(c)
          let text = if small {
            text.to_string().to_upper()
          } else {
            text.to_string()
          }
          push_text(text, item, char_size, advance, rise)
        }
      }
    }
  }
  flush()
  if lines.is_empty() && pending_break == "" {
    // An empty paragraph still occupies one line.
    let natural = mark_size * 1.2
    lines.push({
      items: [],
      images: [],
      height: Double::max(docx_line_box_height(natural, props, pitch), 1.0),
      align,
      justify: false,
      distribute: false,
      break_before: "",
      shade: None,
      borders: [],
      border_top: false,
      border_bottom: false,
    })
  }
  if (align == "both" || align == "distribute") && lines.length() > 1 {
    for index in 0..<(lines.length() - 1) {
      lines[index] = {
        ..lines[index],
        justify: true,
        distribute: align == "distribute",
      }
    }
  }
  for index, line in lines {
    line.borders = props.borders
    line.border_top = index == 0
    line.border_bottom = index == lines.length() - 1
  }
  match props.shade {
    Some(color) =>
      for line in lines {
        line.shade = Some(color)
      }
    None => ()
  }
  { lines, anchors, notes, trailing_break: pending_break, }
}

///|
fn docx_merge_line_items(items : Array[DocxLineItem]) -> Array[DocxLineItem] {
  let merged : Array[DocxLineItem] = []
  for item in items {
    let join = match merged.last() {
      Some(last) =>
        last.kind == "text" &&
        item.kind == "text" &&
        last.font == item.font &&
        last.weight == item.weight &&
        last.style == item.style &&
        last.size == item.size &&
        last.color == item.color &&
        last.link == item.link &&
        last.rise == item.rise &&
        last.shade == item.shade &&
        last.border_width == item.border_width &&
        last.border_color == item.border_color &&
        (item.x - (last.x + last.advance)).abs() < 0.25
      None => false
    }
    if join {
      let last = merged[merged.length() - 1]
      merged[merged.length() - 1] = {
        ..last,
        text: last.text + item.text,
        advance: last.advance + item.advance,
      }
    } else {
      merged.push(item)
    }
  }
  merged
}

///|
fn docx_tab_width(
  items : Array[DocxTextItem],
  start : Int,
  before_decimal : Bool,
) -> Double {
  let mut width = 0.0
  let mut index = start
  while index < items.length() {
    let item = items[index]
    if item.kind == "tab" ||
      item.kind == "break" ||
      item.kind == "page" ||
      item.kind == "column" ||
      item.kind == "image" {
      break
    }
    let text = if item.kind == "field" || item.kind == "text" || item.kind == "char" {
      item.text
    } else {
      ""
    }
    if text != "" {
      if before_decimal && item.kind == "text" {
        match text.find(".") {
          Some(position) => {
            width += docx_text_width(text[:position].to_owned(), if item.props.size > 0.0 { item.props.size } else { 10.0 })
            break
          }
          None => width += docx_text_width(text, if item.props.size > 0.0 { item.props.size } else { 10.0 })
        }
      } else {
        width += if item.kind == "field" {
          docx_text_width(text, if item.props.size > 0.0 { item.props.size } else { 10.0 })
        } else {
          docx_text_width(text, if item.props.size > 0.0 { item.props.size } else { 10.0 })
        }
      }
    }
    index += 1
  }
  width
}

///|
fn docx_link_target(
  package : @ooxml.OoxmlPackage,
  part : String,
  id : String,
) -> String {
  for rel in package.relationships(part) {
    if rel.id == id && rel.external {
      return rel.target
    }
  }
  ""
}

///|
fn docx_emit_image(
  object : @core.ObjectBuilder,
  writer : @core.DocumentWriter,
  package : @ooxml.OoxmlPackage,
  part : String,
  item : DocxTextItem,
  dx : Double,
  dy : Double,
  width : Double,
  height : Double,
  warnings : Array[String],
) -> Unit raise {
  let mut target = ""
  let mut external = false
  for rel in package.relationships(part) {
    if rel.id == item.text {
      target = rel.target
      external = rel.external
    }
  }
  if target == "" || external {
    raise DocxInvalid("DOCX image relationship is missing")
  }
  let bytes = package.read(target) catch {
    _ => raise DocxInvalid("DOCX image part is missing")
  }
  if @metafile.kind(bytes) != "" {
    let meta_warnings = @metafile.draw_into(
      object, writer, bytes, dx, dy, width, height,
    ) catch {
      _ => {
        warnings.push("DOCX: an EMF/WMF drawing could not be replayed")
        []
      }
    }
    for message in meta_warnings {
      warnings.push(message)
    }
    return
  }
  let hash = writer.add_part("img", bytes)
  let index = object.add_image(hash)
  let mut cropped = false
  if item.crop_left > 0.0 ||
    item.crop_top > 0.0 ||
    item.crop_right > 0.0 ||
    item.crop_bottom > 0.0 {
    match docx_png_size(bytes) {
      Some((image_width, image_height)) => {
        let sx = item.crop_left * image_width.to_double()
        let sy = item.crop_top * image_height.to_double()
        let sw = (1.0 - item.crop_left - item.crop_right) *
          image_width.to_double()
        let sh = (1.0 - item.crop_top - item.crop_bottom) *
          image_height.to_double()
        if sw > 0.0 && sh > 0.0 {
          object.image_sub(
            index,
            Float::from_double(sx),
            Float::from_double(sy),
            Float::from_double(sw),
            Float::from_double(sh),
            Float::from_double(dx),
            Float::from_double(dy),
            Float::from_double(width),
            Float::from_double(height),
          )
          cropped = true
        }
      }
      None => ()
    }
  }
  if !cropped {
    object.image(
      index,
      Float::from_double(dx),
      Float::from_double(dy),
      Float::from_double(width),
      Float::from_double(height),
    )
  }
  if item.border_width > 0.0 {
    object.line(Float::from_double(item.border_width), 0, 0, 8.0F)
    object.stroke_color(
      match item.border_color {
        Some(value) => value
        None => 0x000000ffU
      },
    )
    object.stroke_rect(
      Float::from_double(dx),
      Float::from_double(dy),
      Float::from_double(width),
      Float::from_double(height),
    )
  }
}

///|
fn docx_emit_placed_image(
  object : @core.ObjectBuilder,
  writer : @core.DocumentWriter,
  package : @ooxml.OoxmlPackage,
  part : String,
  image : DocxPlacedImage,
  x_origin : Double,
  y_origin : Double,
  warnings : Array[String],
) -> Unit raise {
  let item = image.item
  let dx = if image.anchored { image.x } else { x_origin + image.x }
  let dy = if image.anchored { image.y } else { y_origin + image.y }
  let draw_width = if image.draw_width > 0.0 {
    image.draw_width
  } else {
    image.width
  }
  let draw_height = if image.draw_height > 0.0 {
    image.draw_height
  } else {
    image.height
  }
  let transformed = item.rotation != 0.0 || item.flip_h || item.flip_v
  let center_x = dx + draw_width / 2.0
  let center_y = dy + draw_height / 2.0
  if transformed {
    object.save()
    object.translate(Float::from_double(center_x), Float::from_double(center_y))
    if item.rotation != 0.0 {
      let radians = item.rotation * 3.141592653589793 / 180.0
      let sine = @math.sin(radians)
      let cosine = @math.cos(radians)
      object.transform(
        Float::from_double(cosine),
        Float::from_double(sine),
        Float::from_double(-sine),
        Float::from_double(cosine),
        0.0F,
        0.0F,
      )
    }
    if item.flip_h || item.flip_v {
      object.scale(
        if item.flip_h {
          -1.0F
        } else {
          1.0F
        },
        if item.flip_v {
          -1.0F
        } else {
          1.0F
        },
      )
    }
    object.translate(
      Float::from_double(-center_x),
      Float::from_double(-center_y),
    )
  }
  docx_emit_image(
    object,
    writer,
    package,
    part,
    item,
    dx,
    dy,
    draw_width,
    draw_height,
    warnings,
  )
  if transformed {
    object.restore()
  }
}

///|
fn docx_stroke_border(
  object : @core.ObjectBuilder,
  coordinates : Array[Double],
  border : DocxLineBorder,
) -> Unit raise {
  let parts = if border.style == "double" {
    2
  } else if border.style == "triple" {
    3
  } else {
    1
  }
  let width = if parts > 1 { border.width / parts.to_double() } else { border.width }
  for part in 0..<parts {
    let offset = if parts == 1 {
      0.0
    } else {
      (part.to_double() - (parts - 1).to_double() / 2.0) * border.width
    }
    let shifted : Array[Double] = if coordinates[1] == coordinates[3] {
      [
        coordinates[0],
        coordinates[1] + offset,
        coordinates[2],
        coordinates[3] + offset,
      ]
    } else {
      [
        coordinates[0] + offset,
        coordinates[1],
        coordinates[2] + offset,
        coordinates[3],
      ]
    }
    object.line(Float::from_double(width), 0, 0, 8.0F)
    let dash : Array[Float] = match border.style {
      "dashed" | "dash" => [3.0F, 2.0F]
      "dotted" | "dot" => [1.0F, 2.0F]
      "dashDot" | "dotDash" => [3.0F, 2.0F, 1.0F, 2.0F]
      "dashDotDot" => [3.0F, 2.0F, 1.0F, 2.0F, 1.0F, 2.0F]
      "lgDash" => [6.0F, 2.0F]
      _ => []
    }
    if !dash.is_empty() {
      object.dash(dash, 0.0F)
    }
    object.stroke_color(border.color)
    object.stroke_path(
      object.add_path(
        @core.Inline({ verbs: Bytes::from_array([0, 1]), coordinates: shifted }),
      ),
    )
  }
}

///|
/// The MARK that starts a paragraph: a heading with its outline level, or a
/// plain paragraph.
fn docx_mark_paragraph_start(
  object : @core.ObjectBuilder,
  props : DocxParagraphProps,
) -> Unit {
  if props.outline >= 0 && props.outline < 6 && props.outline != 9 {
    object.mark(
      @core.MARK_HEADING,
      (props.outline + 1).to_string(),
    )
  } else {
    object.mark(@core.MARK_PARAGRAPH, "")
  }
}

///|
fn docx_break_space(c : Char) -> Bool {
  c == ' ' ||
  c == '\u{3000}' ||
  c == '\u{2009}' ||
  c == '\u{2002}' ||
  c == '\u{2003}'
}

///|
/// Whether two wrapped lines join without a space, as Word's line breaking
/// does between East Asian characters.
fn docx_lines_join(a : Char, b : Char) -> Bool {
  a.to_int() != 0 &&
  b.to_int() != 0 &&
  !docx_break_space(a) &&
  (@fontdb.is_cjk(a.to_int()) || @fontdb.is_cjk(b.to_int()))
}

///|
fn docx_line_edges(line : DocxParaLine) -> (Char, Char) {
  let mut first = '\u{0}'
  let mut last = '\u{0}'
  for item in line.items {
    if item.kind != "text" || item.text == "" {
      continue
    }
    for c in item.text {
      if first == '\u{0}' {
        first = c
      }
      last = c
    }
  }
  (first, last)
}

///|
/// The MARK before a line of a paragraph. The first line starts the
/// paragraph (HEADING or PARAGRAPH); a continuation gets WRAP when the lines
/// join without a space, and LINE otherwise.
fn docx_mark_line(
  object : @core.ObjectBuilder,
  first : Bool,
  previous_last : Char,
  next_first : Char,
  props : DocxParagraphProps,
) -> Unit {
  if first {
    docx_mark_paragraph_start(object, props)
  } else if docx_lines_join(previous_last, next_first) {
    object.mark(@core.MARK_WRAP, "")
  } else {
    object.mark(@core.MARK_LINE, "")
  }
}

///|
fn docx_emit_para_line(
  object : @core.ObjectBuilder,
  writer : @core.DocumentWriter,
  package : @ooxml.OoxmlPackage,
  part : String,
  line : DocxParaLine,
  x_origin : Double,
  top : Double,
  available : Double,
  fonts : Map[String, Int32],
  bookmark_pages : Map[String, Int32],
  field_value : (String, String) -> String,
  warnings : Array[String],
  doc_language : String,
  language : Ref[String],
) -> Unit raise {
  match line.shade {
    Some(color) => {
      object.fill_color(color)
      object.fill_rect(
        Float::from_double(x_origin),
        Float::from_double(top),
        Float::from_double(available),
        Float::from_double(line.height),
      )
    }
    None => ()
  }
  for index, border in line.borders {
    let draw = match border {
      Some(value) => value.width > 0.0
      None => false
    }
    if draw {
      let value = border.unwrap()
      let coordinates : Array[Double] = match index {
        0 =>
          if line.border_top {
            [x_origin, top - value.space, x_origin + available, top - value.space]
          } else {
            []
          }
        1 => [x_origin - value.space, top, x_origin - value.space, top + line.height]
        2 =>
          if line.border_bottom {
            [x_origin, top + line.height + value.space, x_origin + available, top + line.height + value.space]
          } else {
            []
          }
        _ => [x_origin + available + value.space, top, x_origin + available + value.space, top + line.height]
      }
      if coordinates.length() == 4 {
        docx_stroke_border(object, coordinates, value)
      }
    }
  }
  let mut source_items = line.items
  if line.justify && !line.items.is_empty() {
    let first = line.items[0]
    let last = line.items[line.items.length() - 1]
    let natural = last.x + last.advance - first.x
    let extra = available - natural
    let mut spaces = 0
    for item in line.items {
      if line.distribute {
        spaces += item.text.length()
      } else {
        for ch in item.text {
          if ch == ' ' {
            spaces += 1
          }
        }
      }
    }
    if spaces > 0 && extra > 0.0 {
      let each = extra / spaces.to_double()
      let adjusted : Array[DocxLineItem] = []
      let mut shift = 0.0
      for item in line.items {
        let mut count = 0
        if line.distribute {
          count = item.text.length()
        } else {
          for ch in item.text {
            if ch == ' ' {
              count += 1
            }
          }
        }
        let increase = each * count.to_double()
        adjusted.push({
          ..item,
          x: item.x + shift,
          advance: item.advance + increase,
        })
        shift += increase
      }
      source_items = adjusted
    }
  }
  let runs = docx_merge_line_items(source_items)
  let mut width = 0.0
  if !runs.is_empty() {
    let last = runs[runs.length() - 1]
    width = last.x + last.advance - runs[0].x
  }
  let offset = match line.align {
    "right" => Double::max(0.0, available - width)
    "center" => Double::max(0.0, (available - width) / 2.0)
    _ => 0.0
  }
  if !runs.is_empty() &&
    (runs[0].shade is Some(_) || runs[0].border_width > 0.0) {
    match runs[0].shade {
      Some(color) => {
        object.fill_color(color)
        object.fill_rect(
          Float::from_double(x_origin + offset),
          Float::from_double(top),
          Float::from_double(width),
          Float::from_double(line.height),
        )
      }
      None => ()
    }
    if runs[0].border_width > 0.0 {
      object.line(Float::from_double(runs[0].border_width), 0, 0, 8.0F)
      object.stroke_color(runs[0].border_color.unwrap_or(0x000000ffU))
      object.stroke_rect(
        Float::from_double(x_origin + offset),
        Float::from_double(top),
        Float::from_double(width),
        Float::from_double(line.height),
      )
    }
  }
  let mut baseline = 0.0
  for item in runs {
    if item.size > baseline {
      baseline = item.size
    }
  }
  for item in runs {
    if item.kind == "bookmark" {
      continue
    }
    if item.kind == "bar" {
      object.fill_color(item.color)
      object.fill_rect(
        Float::from_double(x_origin + offset + item.x),
        Float::from_double(top),
        0.75F,
        Float::from_double(line.height),
      )
      continue
    }
    let text = if item.kind == "field" {
      field_value(item.text, item.field_format)
    } else {
      item.text
    }
    let advance = if item.kind == "field" {
      docx_text_width(text, item.size)
    } else {
      item.advance
    }
    if (item.kind == "text" || item.kind == "field") && text != "" {
      let mut tag = item.language
      if tag == doc_language {
        tag = ""
      }
      if tag != language.val {
        object.mark(@core.MARK_LANG, tag)
        language.val = tag
      }
    }
    let key = item.font +
      "|" +
      item.weight.to_string() +
      "|" +
      item.style.to_string()
    let index = match fonts.get(key) {
      Some(value) => value
      None => {
        let value = object.add_font({
          hash: None,
          family: item.font,
          weight: item.weight,
          style: item.style,
        })
        fonts[key] = value
        value
      }
    }
    object.font(index, Float::from_double(item.size))
    if item.shadow {
      object.fill_color(0x808080ffU)
      object.fill_text(
        text,
        Float::from_double(x_origin + offset + item.x + 1.0),
        Float::from_double(top + baseline + 1.0 - item.rise),
        Float::from_double(advance),
      )
    }
    object.fill_color(item.color)
    object.fill_text(
      text,
      Float::from_double(x_origin + offset + item.x),
      Float::from_double(top + baseline - item.rise),
      Float::from_double(advance),
    )
    if item.link != "" {
      let url = if item.link.has_prefix("#anchor:") {
        let name = item.link[8:].to_owned()
        match bookmark_pages.get(name) {
          Some(page) => "#page=" + page.to_string()
          None => ""
        }
      } else {
        docx_link_target(package, part, item.link)
      }
      if url != "" {
        object.link(
          Float::from_double(x_origin + offset + item.x),
          Float::from_double(top),
          Float::from_double(advance),
          Float::from_double(line.height),
          url,
        )
      }
    }
    let draw_x = x_origin + offset + item.x
    if item.underline != "" && item.underline != "none" {
      object.fill_color(item.color)
      let underline_y = top + baseline + 1.5 - item.rise
      if item.underline == "double" {
        object.fill_rect(
          Float::from_double(draw_x),
          Float::from_double(underline_y),
          Float::from_double(advance),
          0.6F,
        )
        object.fill_rect(
          Float::from_double(draw_x),
          Float::from_double(underline_y + 1.6),
          Float::from_double(advance),
          0.6F,
        )
      } else if item.underline == "thick" {
        object.fill_rect(
          Float::from_double(draw_x),
          Float::from_double(underline_y),
          Float::from_double(advance),
          1.5F,
        )
      } else if item.underline == "dotted" || item.underline == "dashed" {
        let dash = if item.underline == "dotted" { 1.0 } else { 3.0 }
        let gap = if item.underline == "dotted" { 1.5 } else { 2.0 }
        let mut x = 0.0
        while x < advance {
          let width = Double::min(dash, advance - x)
          object.fill_rect(
            Float::from_double(draw_x + x),
            Float::from_double(underline_y),
            Float::from_double(width),
            0.6F,
          )
          x += dash + gap
        }
      } else {
        object.fill_rect(
          Float::from_double(draw_x),
          Float::from_double(underline_y),
          Float::from_double(advance),
          0.6F,
        )
      }
    }
    if item.strike {
      object.fill_color(item.color)
      object.fill_rect(
        Float::from_double(draw_x),
        Float::from_double(top + baseline - item.size * 0.35 - item.rise),
        Float::from_double(advance),
        0.6F,
      )
    }
    if item.emphasis != "" {
      let mark_size = Double::max(1.0, item.size * 0.12)
      let step = Double::max(item.size * 0.6, 3.0)
      let mark_y = if item.emphasis == "underDot" ||
        item.emphasis == "comma" {
        top + baseline + 2.0 - item.rise
      } else {
        top + 1.0 - item.rise
      }
      let mut count = (advance / step).to_int()
      if count > 1000 {
        count = 1000
      }
      object.fill_color(item.color)
      for index in 0..<count {
        object.fill_rect(
          Float::from_double(draw_x + step * index.to_double()),
          Float::from_double(mark_y),
          Float::from_double(mark_size),
          Float::from_double(mark_size),
        )
      }
    }
  }
  for image in line.images {
    docx_emit_placed_image(
      object,
      writer,
      package,
      part,
      image,
      x_origin + offset,
      top,
      warnings,
    )
  }
}

///|
fn docx_para_line_available(line : DocxParaLine) -> Double {
  let mut right = 0.0
  for item in line.items {
    if item.x + item.advance > right {
      right = item.x + item.advance
    }
  }
  right
}

///|
fn docx_default_margin(value : Double?, fallback : Double) -> Double {
  match value {
    Some(inner) => inner
    None => fallback
  }
}

///|
fn docx_table_cell_margins(
  table : DocxTable,
  cell : DocxTableCell,
) -> (Double, Double, Double, Double) {
  let top = docx_default_margin(
    cell.mar.top,
    docx_default_margin(table.cell_mar.top, 0.0),
  )
  let left = docx_default_margin(
    cell.mar.left,
    docx_default_margin(table.cell_mar.left, 5.4),
  )
  let bottom = docx_default_margin(
    cell.mar.bottom,
    docx_default_margin(table.cell_mar.bottom, 0.0),
  )
  let right = docx_default_margin(
    cell.mar.right,
    docx_default_margin(table.cell_mar.right, 5.4),
  )
  (top, left, bottom, right)
}

///|
fn docx_table_grid_count(table : DocxTable) -> Int32 {
  let mut count = 1
  for row in table.rows {
    for cell in row.cells {
      let end = cell.col + cell.span
      if end > count {
        count = end
      }
    }
  }
  count
}

fn docx_estimated_text_width(item : DocxTextItem) -> Double {
  if item.kind != "text" && item.kind != "char" {
    return item.width
  }
  let size = if item.props.size > 0.0 { item.props.size } else { 10.0 }
  let mut width = 0.0
  for character in item.text {
    let code = character.to_int()
    let wide = (code >= 0x2e80 && code <= 0x9fff) ||
      (code >= 0xac00 && code <= 0xd7af) ||
      (code >= 0xf900 && code <= 0xfaff) ||
      (code >= 0xff00 && code <= 0xffef)
    width += if wide { size } else { size * 0.5 }
  }
  width
}

///|
fn docx_table_natural_widths(
  table : DocxTable,
  available : Double,
) -> Array[Double] {
  let ncols = docx_table_grid_count(table)
  if ncols <= 0 {
    return []
  }
  let widths : Array[Double] = Array::make(ncols, 20.0)
  for row in table.rows {
    for cell in row.cells {
      if cell.span != 1 || cell.col < 0 || cell.col >= ncols {
        continue
      }
      let mut text_width = 0.0
      for block in cell.blocks {
        match block {
          DocxParaBlock(paragraph) =>
            for item in paragraph.items {
              text_width += docx_estimated_text_width(item)
            }
          DocxTableBlock(_) => ()
        }
      }
      let (_, left, _, right) = docx_table_cell_margins(table, cell)
      widths[cell.col] = Double::max(
        widths[cell.col], text_width + left + right,
      )
    }
  }
  let mut total = 0.0
  for value in widths {
    total += value
  }
  if total <= 0.0 {
    return widths
  }
  let target = match table.width_type {
    "dxa" => Double::min(table.width, available)
    "pct" => Double::min(available * table.width / 100.0, available)
    _ => Double::min(total, available)
  }
  if target > 0.0 {
    let scale = target / total
    for i in 0..<widths.length() {
      widths[i] = widths[i] * scale
    }
  }
  widths
}

///|
fn docx_table_grid_widths(table : DocxTable, width : Double) -> Array[Double] {
  let ncols = docx_table_grid_count(table)
  let grid : Array[Double] = table.grid.copy()
  while grid.length() < ncols {
    grid.push(0.0)
  }
  if ncols <= 0 {
    return grid
  }
  if table.layout_type == "autofit" {
    let natural = docx_table_natural_widths(table, width)
    let mut natural_total = 0.0
    for value in natural {
      natural_total += value
    }
    if natural_total > 0.0 {
      return natural
    }
  }
  let mut total = 0.0
  for column in grid {
    total += column
  }
  if total <= 0.0 {
    let each = width / ncols.to_double()
    for i in 0..<grid.length() {
      grid[i] = each
    }
    return grid
  }
  let target = match table.width_type {
    "dxa" => table.width
    "pct" => width * table.width / 100.0
    _ => 0.0
  }
  if target > 0.0 {
    let scale = Double::min(target, width) / total
    for i in 0..<grid.length() {
      grid[i] = grid[i] * scale
    }
  }
  grid
}

///|
fn docx_layout_table(
  table : DocxTable,
  width : Double,
  pitch : Double,
) -> DocxTableLayout {
  let ncols = docx_table_grid_count(table)
  let grid = docx_table_grid_widths(table, width)
  let mut total = 0.0
  for column in grid {
    total += column
  }
  let col_x : Array[Double] = [0.0]
  for column in grid {
    col_x.push(col_x[col_x.length() - 1] + column)
  }
  let left = match table.jc {
    "center" => (width - total) / 2.0
    "right" => width - total
    _ => table.ind
  }
  let rows : Array[DocxTableRowLayout] = []
  let table_notes : Array[(String, String)] = []
  for row in table.rows {
    let cells : Array[DocxTableCellLayout] = []
    let mut row_height = 0.0
    for cell in row.cells {
      let start = Int32::min(cell.col, ncols)
      let end = Int32::min(cell.col + cell.span, ncols)
      let spacing = table.cell_spacing
      let x0 = col_x[start] +
        (if start > 0 { spacing / 2.0 } else { 0.0 })
      let x1 = col_x[end] -
        (if end < ncols { spacing / 2.0 } else { 0.0 })
      let (mar_top, mar_left, mar_bottom, mar_right) = docx_table_cell_margins(
        table, cell,
      )
      if cell.vmerge == "continue" {
        cells.push({
          x: x0,
          w: x1 - x0,
          height: 0.0,
          valign: cell.valign,
          mar_top,
          mar_left,
          mar_bottom,
          mar_right,
          blocks: [],
          notes: [],
        })
        continue
      }
      let inner = Double::max(x1 - x0 - mar_left - mar_right, 1.0)
      let (blocks, content_height, notes) = docx_layout_cell_blocks(
        cell.blocks,
        inner,
        pitch,
      )
      for note in notes {
        let mut known = false
        for existing in table_notes {
          if existing.0 == note.0 && existing.1 == note.1 {
            known = true
          }
        }
        if !known {
          table_notes.push(note)
        }
      }
      let height = content_height + mar_top + mar_bottom
      cells.push({
        x: x0,
        w: x1 - x0,
        height,
        valign: cell.valign,
        mar_top,
        mar_left,
        mar_bottom,
        mar_right,
        blocks,
        notes,
      })
      if cell.row_span == 1 && height > row_height {
        row_height = height
      }
    }
    if row.exact && row.height > 0.0 {
      row_height = row.height
    } else if row.height > row_height {
      row_height = row.height
    }
    rows.push({ height: Double::max(row_height, 1.0), cells, })
  }
  // A merged cell taller than its rows stretches the last of them.
  for row_index, row in table.rows {
    for cell_index, cell in row.cells {
      if cell.row_span <= 1 || cell.vmerge != "restart" {
        continue
      }
      let last = Int32::min(row_index + cell.row_span, table.rows.length()) - 1
      let mut sum = 0.0
      for k in row_index..<=last {
        sum += rows[k].height
      }
      let cell_layout = rows[row_index].cells[cell_index]
      let need = cell_layout.height
      if need > sum && !table.rows[last].exact {
        rows[last].height += need - sum
      }
    }
  }
  { table, left, total_width: total, col_x, rows, notes: table_notes, }
}

///|
fn docx_layout_cell_blocks(
  blocks : Array[DocxBlock],
  width : Double,
  pitch : Double,
) -> (Array[DocxCellBlockLayout], Double, Array[(String, String)]) {
  let layout : Array[DocxCellBlockLayout] = []
  let notes : Array[(String, String)] = []
  let mut y = 0.0
  for block in blocks {
    match block {
      DocxParaBlock(paragraph) => {
        if docx_para_before(paragraph.props) > 0.0 {
          y += docx_para_before(paragraph.props)
        }
        let mark_size = if paragraph.mark.size > 0.0 {
          paragraph.mark.size
        } else {
          10.0
        }
        let para = docx_layout_paragraph(
          paragraph.items,
          paragraph.props,
          width,
          pitch,
          mark_size,
          true,
        )
        for note in para.notes {
          let mut known = false
          for existing in notes {
            if existing.0 == note.0 && existing.1 == note.1 {
              known = true
            }
          }
          if !known {
            notes.push(note)
          }
        }
        let para_top = y
        let lines : Array[DocxTableCellLine] = []
        for line in para.lines {
          lines.push({ y, line, })
          y += line.height
        }
        if !lines.is_empty() {
          layout.push(DocxCellLines(lines))
        }
        if !para.anchors.is_empty() {
          layout.push(
            DocxCellAnchors(
              para.anchors.map(fn(anchor) { { ..anchor, y: para_top + anchor.y } }),
            ),
          )
        }
        if docx_para_after(paragraph.props) > 0.0 {
          y += docx_para_after(paragraph.props)
        }
      }
      DocxTableBlock(table) => {
        let nested = docx_layout_table(table, width, pitch)
        let mut height = 0.0
        for row in nested.rows {
          height += row.height
        }
        layout.push(DocxCellNested({ y, layout: nested, height, }))
        for note in nested.notes {
          let mut known = false
          for existing in notes {
            if existing.0 == note.0 && existing.1 == note.1 {
              known = true
            }
          }
          if !known {
            notes.push(note)
          }
        }
        y += height
      }
    }
  }
  (layout, y, notes)
}

///|
priv struct DocxEmitContext {
  object : @core.ObjectBuilder
  writer : @core.DocumentWriter
  package : @ooxml.OoxmlPackage
  part : String
  fonts : Map[String, Int32]
  warnings : Array[String]
  bookmark_pages : Map[String, Int32]
  field_value : (String, String) -> String
  doc_language : String
  language : Ref[String]
}

///|
fn docx_draw_rule(
  ctx : DocxEmitContext,
  border : DocxLineBorder?,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit raise {
  match border {
    None => ()
    Some(value) => {
      let width = value.width
      ctx.object.fill_color(value.color)
      if (y0 - y1).abs() > 0.01 && (x0 - x1).abs() > 0.01 {
        let path = ctx.object.add_path(
          @core.Inline({
            verbs: Bytes::from_array([0, 1, 4]),
            coordinates: [x0, y0, x1, y1],
          }),
        )
        ctx.object.line(Float::from_double(width), 0, 0, 8.0F)
        ctx.object.stroke_color(value.color)
        ctx.object.stroke_path(path)
      } else if (value.style == "single" || value.style == "thick" ||
        value.style == "") {
        if (y0 - y1).abs() < 0.01 {
          ctx.object.fill_rect(
            Float::from_double(x0 - width / 2.0),
            Float::from_double(y0 - width / 2.0),
            Float::from_double(x1 - x0 + width),
            Float::from_double(width),
          )
        } else {
          ctx.object.fill_rect(
            Float::from_double(x0 - width / 2.0),
            Float::from_double(y0 - width / 2.0),
            Float::from_double(width),
            Float::from_double(y1 - y0 + width),
          )
        }
      } else if (y0 - y1).abs() < 0.01 {
        docx_stroke_border(ctx.object, [x0, y0, x1, y1], value)
      } else {
        docx_stroke_border(ctx.object, [x0, y0, x0, y1], value)
      }
    }
  }
}

///|
fn docx_table_border_for(
  layout : DocxTableLayout,
  row_index : Int32,
  cell : DocxTableCell,
  side : Int32,
) -> DocxLineBorder? {
  match cell.borders[side] {
    Some(value) => return Some(value)
    None => ()
  }
  let table = layout.table
  let rows = table.rows.length()
  let ncols = layout.col_x.length() - 1
  match side {
    0 => if row_index == 0 { table.borders[0] } else { table.borders[4] }
    1 => if cell.col == 0 { table.borders[1] } else { table.borders[5] }
    2 =>
      if row_index + cell.row_span >= rows {
        table.borders[2]
      } else {
        table.borders[4]
      }
    3 =>
      if cell.col + cell.span >= ncols {
        table.borders[3]
      } else {
        table.borders[5]
      }
    _ => None
  }
}

///|
fn docx_table_safe_cut(
  layout : DocxTableLayout,
  row_index : Int32,
  from : Double,
  to : Double,
) -> Double {
  let mut y = to
  for _ in 0..<20 {
    let mut moved = false
    let row = layout.table.rows[row_index]
    let row_layout = layout.rows[row_index]
    for cell_index, cell in row.cells {
      if cell.vmerge == "continue" {
        continue
      }
      let cell_layout = row_layout.cells[cell_index]
      for block in cell_layout.blocks {
        match block {
          DocxCellLines(lines) =>
            for positioned in lines {
              let top = cell_layout.mar_top + positioned.y
              let bottom = top + positioned.line.height
              if top < y - 0.01 && bottom > y + 0.01 {
                y = top
                moved = true
              }
            }
          DocxCellAnchors(_) => ()
          DocxCellNested(nested) => {
            let top = cell_layout.mar_top + nested.y
            let bottom = top + nested.height
            if top < y - 0.01 && bottom > y + 0.01 {
              y = top
              moved = true
            }
          }
        }
      }
    }
    if !moved {
      break
    }
  }
  if y <= from + 0.01 {
    from
  } else {
    y
  }
}

///|
fn docx_emit_table_lines(
  ctx : DocxEmitContext,
  cell_layout : DocxTableCellLayout,
  x_origin : Double,
  y_origin : Double,
  cut0 : Double,
  cut1 : Double,
  partial : Bool,
) -> Unit raise {
  for block in cell_layout.blocks {
    match block {
      DocxCellLines(lines) =>
        for positioned in lines {
          let top = cell_layout.mar_top + positioned.y
          if partial && (top < cut0 - 0.01 || top >= cut1 - 0.01) {
            continue
          }
          docx_emit_para_line(
            ctx.object,
            ctx.writer,
            ctx.package,
            ctx.part,
            positioned.line,
            x_origin,
            y_origin + top - cut0,
            cell_layout.w - cell_layout.mar_left - cell_layout.mar_right,
            ctx.fonts,
            ctx.bookmark_pages,
            ctx.field_value,
            ctx.warnings,
            ctx.doc_language,
            ctx.language,
          )
        }
      DocxCellAnchors(anchors) =>
        for anchor in anchors {
          docx_emit_image(
            ctx.object,
            ctx.writer,
            ctx.package,
            ctx.part,
            anchor.item,
            x_origin + anchor.x,
            y_origin + anchor.y,
            anchor.width,
            anchor.height,
            ctx.warnings,
          )
        }
      DocxCellNested(nested) => {
        let top = cell_layout.mar_top + nested.y
        if partial && (top < cut0 - 0.01 || top + nested.height > cut1 + 0.01) {
          continue
        }
        docx_emit_table_rows(
          ctx,
          nested.layout,
          x_origin,
          y_origin + top - cut0,
          cut0,
          cut1,
          partial,
        )
      }
    }
  }
}

///|
fn docx_emit_table_rows(
  ctx : DocxEmitContext,
  layout : DocxTableLayout,
  x_origin : Double,
  y_origin : Double,
  cut0 : Double,
  cut1 : Double,
  partial : Bool,
) -> Unit raise {
  let mut y = y_origin
  for row_index, row_layout in layout.rows {
    docx_emit_table_row(
      ctx,
      layout,
      row_index,
      0.0,
      row_layout.height,
      x_origin,
      y,
    )
    y += row_layout.height
  }
}

///|
fn docx_emit_table_row(
  ctx : DocxEmitContext,
  layout : DocxTableLayout,
  row_index : Int32,
  cut0 : Double,
  cut1 : Double,
  x_origin : Double,
  y_top : Double,
) -> Unit raise {
  let table = layout.table
  let row = table.rows[row_index]
  let row_layout = layout.rows[row_index]
  let partial = cut0 > 0.01 || cut1 < row_layout.height - 0.01
  for cell_index, cell in row.cells {
    if cell.vmerge == "continue" {
      continue
    }
    let cell_layout = row_layout.cells[cell_index]
    if cell_layout.w <= 0.0 {
      continue
    }
    let mut height = cut1 - cut0
    if cell.row_span > 1 && !partial {
      let mut next = row_index + 1
      let limit = row_index + cell.row_span
      while next < limit && next < table.rows.length() {
        height += layout.rows[next].height
        next += 1
      }
    }
    let bx = x_origin + layout.left + cell_layout.x
    let shade = match cell.shade {
      Some(color) => Some(color)
      None => table.shade
    }
    match shade {
      Some(color) => {
        ctx.object.fill_color(color)
        ctx.object.fill_rect(
          Float::from_double(bx),
          Float::from_double(y_top),
          Float::from_double(cell_layout.w),
          Float::from_double(height),
        )
      }
      None => ()
    }
    let content_height = cell_layout.height -
      cell_layout.mar_top -
      cell_layout.mar_bottom
    let mut voff = cell_layout.mar_top
    if !partial {
      match cell_layout.valign {
        "center" =>
          voff += (
              height -
              cell_layout.mar_top -
              cell_layout.mar_bottom -
              content_height
            ) /
            2.0
        "bottom" =>
          voff += height -
            cell_layout.mar_top -
            cell_layout.mar_bottom -
            content_height
        _ => ()
      }
    }
    docx_emit_table_lines(
      ctx,
      cell_layout,
      bx + cell_layout.mar_left,
      y_top + voff,
      cut0,
      cut1,
      partial,
    )
    let mut top_border = docx_table_border_for(layout, row_index, cell, 0)
    if partial && cut0 > 0.01 {
      top_border = table.borders[4]
    }
    let bottom_border = docx_table_border_for(layout, row_index, cell, 2)
    let left_border = docx_table_border_for(layout, row_index, cell, 1)
    let right_border = docx_table_border_for(layout, row_index, cell, 3)
    docx_draw_rule(ctx, top_border, bx, y_top, bx + cell_layout.w, y_top)
    docx_draw_rule(
      ctx,
      bottom_border,
      bx,
      y_top + height,
      bx + cell_layout.w,
      y_top + height,
    )
    docx_draw_rule(ctx, left_border, bx, y_top, bx, y_top + height)
    docx_draw_rule(
      ctx,
      right_border,
      bx + cell_layout.w,
      y_top,
      bx + cell_layout.w,
      y_top + height,
    )
    docx_draw_rule(
      ctx,
      cell.tl2br,
      bx,
      y_top,
      bx + cell_layout.w,
      y_top + height,
    )
    docx_draw_rule(
      ctx,
      cell.tr2bl,
      bx + cell_layout.w,
      y_top,
      bx,
      y_top + height,
    )
  }
}

///|
fn docx_story_part_height(
  document : DocxTextDocument,
  part : String,
  width : Double,
  pitch : Double,
) -> Double {
  let paragraphs = match document.stories.get(part) {
    Some(value) => value
    None => []
  }
  let tables = match document.story_tables.get(part) {
    Some(value) => value
    None => []
  }
  if paragraphs.is_empty() && tables.is_empty() {
    return 0.0
  }
  let mut height = 0.0
  for paragraph in paragraphs {
    if docx_para_before(paragraph.props) > 0.0 {
      height += docx_para_before(paragraph.props)
    }
    let mark_size = if paragraph.mark.size > 0.0 {
      paragraph.mark.size
    } else {
      10.0
    }
    let layout = docx_layout_paragraph(
      paragraph.items,
      paragraph.props,
      width,
      pitch,
      mark_size,
      false,
    )
    for line in layout.lines {
      height += line.height
    }
    if docx_para_after(paragraph.props) > 0.0 {
      height += docx_para_after(paragraph.props)
    }
  }
  for table in tables {
    let layout = docx_layout_table(table, width, pitch)
    for row in layout.rows {
      height += row.height
    }
  }
  height
}

///|
priv struct DocxPageNote {
  kind : String
  id : String
  lines : Array[String]
  height : Double
}

///|
priv struct DocxFlow {
  document : DocxTextDocument
  writer : @core.DocumentWriter
  package : @ooxml.OoxmlPackage
  total_pages : Int32
  warnings : Array[String]
  pages : Array[Json]
  index_runs : Array[@core.IndexRun]
  budget : @render.TextExtractionBudget
  stories : Map[String, DocxStoryLayout]
  bookmark_pages : Map[String, Int32]
  mut body : @core.ObjectBuilder
  mut header_object : @core.ObjectBuilder
  mut footer_object : @core.ObjectBuilder
  mut body_fonts : Map[String, Int32]
  mut header_fonts : Map[String, Int32]
  mut footer_fonts : Map[String, Int32]
  mut has_header : Bool
  mut page_open : Bool
  mut page_index : Int32
  mut page_number : Int32
  mut page_in_section : Int32
  mut next_number : Int32
  mut section : DocxSection
  mut section_index : Int32
  mut section_start : Int32
  mut story_kind : String
  language : Ref[String]
  mut col : Int32
  mut x0 : Double
  mut y : Double
  mut top : Double
  mut bottom : Double
  mut width : Double
  mut line_pitch : Double
  mut vertical : Bool
  mut col_bottom : Double
  mut note_height : Double
  page_notes : Array[DocxPageNote]
  floats : Array[DocxExcl]
  front : Array[DocxFloat]
}

///|
fn docx_roman(number : Int32) -> String {
  if number <= 0 || number > 3999 {
    return number.to_string()
  }
  let values = [
    (1000, "M"),
    (900, "CM"),
    (500, "D"),
    (400, "CD"),
    (100, "C"),
    (90, "XC"),
    (50, "L"),
    (40, "XL"),
    (10, "X"),
    (9, "IX"),
    (5, "V"),
    (4, "IV"),
    (1, "I"),
  ]
  let out = StringBuilder()
  let mut rest = number
  for pair in values {
    let (value, digits) = pair
    while rest >= value {
      out.write_string(digits)
      rest -= value
    }
  }
  out.to_string()
}

///|
fn docx_letters(number : Int32) -> String {
  if number <= 0 {
    return ""
  }
  let out = StringBuilder()
  let mut rest = number
  while rest > 0 {
    let index = (rest - 1) % 26
    out.write_char(Char::from_int('A'.to_int() + index))
    rest = (rest - 1) / 26
  }
  // The letters are produced from right to left.
  let text = out.to_string()
  let reversed = StringBuilder()
  for i in 0..<text.length() {
    reversed.write_char(text.get_char(text.length() - 1 - i).unwrap())
  }
  reversed.to_string()
}

///|
fn docx_full_width_digits(number : Int32) -> String {
  let out = StringBuilder()
  for c in number.to_string() {
    if c >= '0' && c <= '9' {
      out.write_char(Char::from_int(c.to_int() - '0'.to_int() + 0xff10))
    } else {
      out.write_char(c)
    }
  }
  out.to_string()
}

///|
fn docx_format_number(number : Int32, format : String) -> String {
  match format {
    "upperRoman" => docx_roman(number)
    "lowerRoman" => docx_roman(number).to_lower()
    "upperLetter" => docx_letters(number)
    "lowerLetter" => docx_letters(number).to_lower()
    "decimalZero" =>
      if number >= 0 && number < 10 {
        "0" + number.to_string()
      } else {
        number.to_string()
      }
    "decimalFullWidth" | "decimalFullWidth2" => docx_full_width_digits(number)
    "decimalEnclosedCircle" | "decimalEnclosedCircleChinese" =>
      if number >= 1 && number <= 20 {
        Char::from_int(0x2460 + number - 1).to_string()
      } else {
        number.to_string()
      }
    "numberInDash" => "- " + number.to_string() + " -"
    "none" => ""
    _ => number.to_string()
  }
}

///|
fn docx_section_line_length(section : DocxSection) -> Double {
  if section.vertical {
    Double::max(section.height - section.top - section.bottom, 36.0)
  } else {
    Double::max(section.width - section.left - section.right, 36.0)
  }
}

///|
fn docx_section_column(
  section : DocxSection,
  index : Int32,
) -> (Double, Double) {
  let columns = section.columns
  if columns.is_empty() {
    return (0.0, docx_section_line_length(section))
  }
  let position = if index < 0 || index >= columns.length() {
    columns.length() - 1
  } else {
    index
  }
  let (x, width) = columns[position]
  if section.vertical {
    (x, width)
  } else {
    (section.left + x, width)
  }
}

///|
fn docx_section_grid_pitch(section : DocxSection) -> Double {
  match section.grid_type {
    "lines" | "linesAndChars" | "snapToChars" => section.line_pitch
    _ => 0.0
  }
}

///|
fn docx_section_same_geometry(a : DocxSection, b : DocxSection) -> Bool {
  a.width == b.width &&
  a.height == b.height &&
  a.left == b.left &&
  a.right == b.right &&
  a.vertical == b.vertical
}

///|
fn docx_story_kind(flow : DocxFlow) -> String {
  let first = flow.page_in_section == 0
  if first && flow.section.title_page {
    "first"
  } else if flow.document.even_odd && flow.page_number % 2 == 0 {
    "even"
  } else {
    "default"
  }
}

///|
fn docx_flow_field_value(
  flow : DocxFlow,
  field : String,
  format : String,
) -> String {
  let (typ, arg) = match field.find("\u{0001}") {
    Some(index) =>
      (field[:index].to_owned(), field[index + 1:].to_owned())
    None => (field, "")
  }
  match typ {
    "PAGE" => {
      let page_format = if format != "" {
        format
      } else {
        flow.section.page_format
      }
      docx_format_number(flow.page_number, page_format)
    }
    "NUMPAGES" => {
      let page_format = if format != "" { format } else { "decimal" }
      docx_format_number(flow.total_pages, page_format)
    }
    "SECTIONPAGES" => {
      let page_format = if format != "" { format } else { "decimal" }
      docx_format_number(flow.total_pages, page_format)
    }
    "REF" => flow.document.bookmark_text.get(arg).unwrap_or("")
    "PAGEREF" =>
      match flow.bookmark_pages.get(arg) {
        Some(page) =>
          docx_format_number(
            page,
            if format != "" { format } else { "decimal" },
          )
        None => ""
      }
    _ => ""
  }
}

///|
fn docx_flow_story_layout(
  flow : DocxFlow,
  part : String,
  width : Double,
) -> DocxStoryLayout {
  let key = part + "|" + width.to_string() + "|" + flow.line_pitch.to_string()
  match flow.stories.get(key) {
    Some(value) => value
    None => {
      let paragraphs = match flow.document.stories.get(part) {
        Some(value) => value
        None => []
      }
      let lines : Array[DocxParaLine] = []
      let starts : Array[Int] = []
      let props : Array[DocxParagraphProps] = []
      let anchors : Array[DocxPlacedImage] = []
      let mut height = 0.0
      for paragraph in paragraphs {
        if docx_para_before(paragraph.props) > 0.0 {
          height += docx_para_before(paragraph.props)
        }
        let para_top = height
        let mark_size = if paragraph.mark.size > 0.0 {
          paragraph.mark.size
        } else {
          10.0
        }
        let layout = docx_layout_paragraph(
          paragraph.items,
          paragraph.props,
          width,
          flow.line_pitch,
          mark_size,
          false,
        )
        if !layout.lines.is_empty() {
          starts.push(lines.length())
          props.push(paragraph.props)
        }
        for line in layout.lines {
          lines.push(line)
          height += line.height
        }
        for anchor in layout.anchors {
          anchors.push({ ..anchor, y: para_top + anchor.y })
        }
        if docx_para_after(paragraph.props) > 0.0 {
          height += docx_para_after(paragraph.props)
        }
      }
      let tables : Array[DocxTableLayout] = []
      let story_tables = match flow.document.story_tables.get(part) {
        Some(value) => value
        None => []
      }
      for table in story_tables {
        let table_layout = docx_layout_table(table, width, flow.line_pitch)
        for row in table_layout.rows {
          height += row.height
        }
        tables.push(table_layout)
      }
      let value = { lines, starts, props, tables, anchors, height, }
      flow.stories[key] = value
      value
    }
  }
}

///|
fn docx_flow_emit_story(
  flow : DocxFlow,
  header : Bool,
  kind : String,
  fonts : Map[String, Int32],
) -> (Bool, Double) raise {
  let part = docx_story_part(flow.section, header, kind)
  if part == "" {
    return (false, 0.0)
  }
  flow.language.val = ""
  let width = Double::max(
    flow.section.width - flow.section.left - flow.section.right,
    36.0,
  )
  let layout = docx_flow_story_layout(flow, part, width)
  if layout.lines.is_empty() && layout.tables.is_empty() &&
    layout.anchors.is_empty() {
    return (false, 0.0)
  }
  let object = if header { flow.header_object } else { flow.footer_object }
  let mut y = if header {
    flow.section.header
  } else {
    flow.section.height - flow.section.footer - layout.height
  }
  let story_top = y
  let ctx : DocxEmitContext = {
    object,
    writer: flow.writer,
    package: flow.package,
    part,
    fonts,
    warnings: flow.warnings,
    bookmark_pages: flow.bookmark_pages,
    field_value: fn(typ, format) { docx_flow_field_value(flow, typ, format) },
    doc_language: flow.document.language,
    language: flow.language,
  }
  let mut paragraph = 0
  let mut first = true
  let mut previous_last = '\u{0}'
  for index, line in layout.lines {
    if paragraph < layout.starts.length() &&
      layout.starts[paragraph] == index {
      paragraph += 1
      first = true
      previous_last = '\u{0}'
    }
    let (next_first, next_last) = docx_line_edges(line)
    docx_mark_line(
      object,
      first,
      previous_last,
      next_first,
      layout.props[paragraph - 1],
    )
    first = false
    previous_last = next_last
    docx_emit_para_line(
      object,
      flow.writer,
      flow.package,
      part,
      line,
      flow.section.left,
      y,
      width,
      fonts,
      ctx.bookmark_pages,
      ctx.field_value,
      flow.warnings,
      ctx.doc_language,
      ctx.language,
    )
    y += line.height
  }
  for table_layout in layout.tables {
    let mut table_height = 0.0
    for row in table_layout.rows {
      table_height += row.height
    }
    docx_emit_table_rows(
      ctx,
      table_layout,
      flow.section.left,
      y,
      0.0,
      table_height,
      false,
    )
    y += table_height
  }
  for anchor in layout.anchors {
    docx_emit_image(
      object,
      flow.writer,
      flow.package,
      part,
      anchor.item,
      flow.section.left + anchor.x,
      story_top + anchor.y,
      anchor.width,
      anchor.height,
      flow.warnings,
    )
  }
  (true, layout.height)
}

///|
fn docx_flow_set_column(flow : DocxFlow) -> Unit {
  let (x0, width) = docx_section_column(flow.section, flow.col)
  flow.x0 = x0
  flow.width = width
}

///|
fn docx_flow_new_page(flow : DocxFlow) -> Unit raise {
  if flow.page_open {
    docx_flow_flush_page(flow)
  }
  flow.line_pitch = docx_section_grid_pitch(flow.section)
  flow.vertical = flow.section.vertical
  flow.language.val = ""
  flow.body = docx_object()
  if flow.section.vertical {
    flow.body.save()
    flow.body.transform(
      0.0F,
      1.0F,
      -1.0F,
      0.0F,
      Float::from_double(flow.section.width - flow.section.right),
      Float::from_double(flow.section.top),
    )
  }
  flow.header_object = docx_object()
  flow.footer_object = docx_object()
  flow.body_fonts = Map([])
  flow.header_fonts = Map([])
  flow.footer_fonts = Map([])
  flow.has_header = false
  flow.page_notes.clear()
  flow.note_height = 0.0
  flow.floats.clear()
  flow.front.clear()
  flow.page_number = flow.next_number
  flow.next_number = flow.next_number + 1
  flow.story_kind = docx_story_kind(flow)
  let (has_header, header_height) = docx_flow_emit_story(
    flow,
    true,
    flow.story_kind,
    flow.header_fonts,
  )
  flow.has_header = has_header
  let footer_part = docx_story_part(flow.section, false, flow.story_kind)
  let footer_height = if footer_part == "" {
    0.0
  } else {
    let width = Double::max(
      flow.section.width - flow.section.left - flow.section.right,
      36.0,
    )
    docx_flow_story_layout(flow, footer_part, width).height
  }
  let mut top = flow.section.top
  if !flow.section.top_exact && has_header {
    let pushed = flow.section.header + header_height
    if pushed > top {
      top = pushed
    }
  }
  let mut bottom = flow.section.height - flow.section.bottom
  if !flow.section.bottom_exact && footer_height > 0.0 {
    let pushed = flow.section.height - flow.section.footer - footer_height
    if pushed < bottom {
      bottom = pushed
    }
  }
  flow.vertical = flow.section.vertical
  flow.line_pitch = docx_section_grid_pitch(flow.section)
  flow.col = 0
  flow.col_bottom = top
  if flow.vertical {
    let text_width = Double::max(
      flow.section.width - flow.section.left - flow.section.right,
      36.0,
    )
    flow.top = 0.0
    flow.bottom = text_width
    flow.y = 0.0
  } else {
    flow.top = top
    flow.bottom = bottom
    flow.y = top
  }
  docx_flow_set_column(flow)
  flow.page_in_section = flow.page_in_section + 1
  flow.page_open = true
}

///|
fn docx_flow_next_column(flow : DocxFlow) -> Unit raise {
  if flow.col + 1 < flow.section.columns.length() {
    if flow.y > flow.col_bottom {
      flow.col_bottom = flow.y
    }
    flow.col = flow.col + 1
    docx_flow_set_column(flow)
    flow.y = flow.top
  } else {
    docx_flow_new_page(flow)
  }
}

///|
fn docx_flow_at_top(flow : DocxFlow) -> Bool {
  flow.y <= flow.top + 0.01
}

///|
fn docx_flow_limit(flow : DocxFlow) -> Double {
  flow.bottom - flow.note_height
}

///|
fn docx_flow_ensure(flow : DocxFlow, height : Double) -> Unit raise {
  if flow.y + height <= docx_flow_limit(flow) + 0.01 {
    return
  }
  if docx_flow_at_top(flow) {
    return
  }
  docx_flow_next_column(flow)
}

///|
// docx_float_sort orders the floating objects by their relative height:
// what stands higher is drawn last, over the objects below it.
fn docx_float_sort(floats : Array[DocxFloat]) -> Unit {
  let mut i = 1
  while i < floats.length() {
    let value = floats[i]
    let mut j = i
    while j > 0 && floats[j - 1].z > value.z {
      floats[j] = floats[j - 1]
      j -= 1
    }
    floats[j] = value
    i += 1
  }
}

///|
// docx_flow_avail narrows the line area [left, right] of the flow to the
// side of the floating objects beside a line at y of the given height. It
// returns the narrowed left and right edges and the bottom of the lowest
// object that took the space (0 when none did).
fn docx_flow_avail(
  flow : DocxFlow,
  y : Double,
  height : Double,
  left : Double,
  right : Double,
) -> (Double, Double, Double) {
  let mut l = left
  let mut r = right
  let mut until = 0.0
  for excl in flow.floats {
    if excl.y1 <= y + 0.01 || excl.y0 >= y + height - 0.01 {
      continue
    }
    if excl.y1 > until {
      until = excl.y1
    }
    if excl.full {
      return (l, l, until)
    }
    let x0 = excl.x0 - flow.x0
    let x1 = excl.x1 - flow.x0
    if x1 <= l || x0 >= r {
      continue
    }
    let left_width = x0 - l
    let right_width = r - x1
    match excl.side {
      "left" => r = Double::min(r, x0)
      "right" => l = Double::max(l, x1)
      _ =>
        if left_width >= right_width {
          r = Double::min(r, x0)
        } else {
          l = Double::max(l, x1)
        }
    }
  }
  (l, r, until)
}

///|
// docx_flow_float_bottom returns the lowest bottom of the floating objects
// that cover y: a line that finds no room beside them goes below them.
fn docx_flow_float_bottom(flow : DocxFlow, y : Double) -> Double {
  let mut bottom = y
  for excl in flow.floats {
    if excl.y0 <= y + 0.01 && excl.y1 > bottom {
      bottom = excl.y1
    }
  }
  bottom
}

///|
// docx_flow_float_pos returns the top left corner of a floating object
// anchored in a paragraph whose first line is at y. Positions relative to
// the page, the margins, the column or the paragraph are resolved here.
fn docx_flow_float_pos(
  flow : DocxFlow,
  anchor : DocxAnchor,
  image : DocxPlacedImage,
  y : Double,
) -> (Double, Double) {
  let section = flow.section
  let mut bx = flow.x0
  let mut bw = flow.width
  match anchor.h_rel {
    "page" => {
      bx = 0.0
      bw = section.width
    }
    "margin" => {
      bx = section.left
      bw = section.width - section.left - section.right
    }
    "leftMargin" | "insideMargin" => {
      bx = 0.0
      bw = section.left
    }
    "rightMargin" | "outsideMargin" => {
      bx = section.width - section.right
      bw = section.right
    }
    _ => ()
  }
  let mut x = bx + image.item.x
  match anchor.h_align {
    "left" | "inside" => x = bx
    "center" => x = bx + (bw - image.width) / 2.0
    "right" | "outside" => x = bx + bw - image.width
    _ => ()
  }
  let mut by = y
  let mut bh = 0.0
  match anchor.v_rel {
    "page" => {
      by = 0.0
      bh = section.height
    }
    "margin" => {
      by = flow.top
      bh = flow.bottom - flow.top
    }
    "topMargin" | "insideMargin" => {
      by = 0.0
      bh = flow.top
    }
    "bottomMargin" | "outsideMargin" => {
      by = flow.bottom
      bh = section.height - flow.bottom
    }
    _ => ()
  }
  let mut top = by + image.item.y
  match anchor.v_align {
    "top" | "inside" => top = by
    "center" => top = by + (bh - image.height) / 2.0
    "bottom" | "outside" => top = by + bh - image.height
    _ => ()
  }
  (x, top)
}

///|
// docx_flow_add_excl records the area an anchored object keeps the text out
// of. Tight and through wrapping are square wrapping, as in upstream.
fn docx_flow_add_excl(
  flow : DocxFlow,
  anchor : DocxAnchor,
  image : DocxPlacedImage,
) -> Unit {
  match anchor.wrap {
    "square" | "tight" | "through" =>
      flow.floats.push({
        x0: image.x - anchor.dist_left - anchor.effect_left,
        y0: image.y - anchor.dist_top - anchor.effect_top,
        x1: image.x +
          image.width +
          anchor.dist_right +
          anchor.effect_right,
        y1: image.y +
          image.height +
          anchor.dist_bottom +
          anchor.effect_bottom,
        full: false,
        side: anchor.side,
      })
    "topAndBottom" =>
      flow.floats.push({
        x0: image.x - anchor.effect_left,
        y0: image.y - anchor.dist_top - anchor.effect_top,
        x1: image.x + image.width + anchor.effect_right,
        y1: image.y +
          image.height +
          anchor.dist_bottom +
          anchor.effect_bottom,
        full: true,
        side: anchor.side,
      })
    _ => ()
  }
}

///|
// docx_flow_place_anchors places the floating objects of a paragraph whose
// first line is at y: behind objects under the text, the others in front of
// it, and the areas they keep free for the lines that follow. A paragraph
// whose paragraph-relative objects do not fit below the text of the page
// moves to the next column with them.
fn docx_flow_place_anchors(
  flow : DocxFlow,
  anchors : Array[DocxPlacedImage],
  y : Double,
) -> Unit raise {
  if anchors.is_empty() {
    return
  }
  let mut at = y
  let mut moved = false
  while true {
    let placements : Array[DocxPlacedImage] = []
    let mut fits = true
    for image in anchors {
      match image.item.anchor {
        Some(anchor) =>
          if flow.vertical {
            placements.push(image)
          } else {
            let (x, top) = docx_flow_float_pos(flow, anchor, image, at)
            placements.push({ ..image, x: x, y: top })
            if anchor.v_rel == "paragraph" &&
              !moved &&
              top + image.height + anchor.effect_bottom >
              flow.bottom + 0.01 &&
              !docx_flow_at_top(flow) {
              fits = false
            }
          }
        None => placements.push(image)
      }
    }
    if !fits {
      moved = true
      docx_flow_next_column(flow)
      at = flow.y
      continue
    }
    let behind : Array[DocxFloat] = []
    let legacy : Array[DocxPlacedImage] = []
    for index, image in anchors {
      let placed = placements[index]
      match image.item.anchor {
        Some(anchor) =>
          if flow.vertical {
            docx_emit_placed_image(
              flow.body,
              flow.writer,
              flow.package,
              flow.document.part,
              placed,
              0.0,
              0.0,
              flow.warnings,
            )
          } else {
            docx_flow_add_excl(flow, anchor, placed)
            if anchor.behind {
              behind.push({ image: placed, z: anchor.z })
            } else {
              flow.front.push({ image: placed, z: anchor.z })
            }
          }
        None => legacy.push(placed)
      }
    }
    docx_float_sort(behind)
    for item in behind {
      docx_emit_placed_image(
        flow.body,
        flow.writer,
        flow.package,
        flow.document.part,
        item.image,
        0.0,
        0.0,
        flow.warnings,
      )
    }
    for image in legacy {
      docx_emit_placed_image(
        flow.body,
        flow.writer,
        flow.package,
        flow.document.part,
        image,
        0.0,
        0.0,
        flow.warnings,
      )
    }
    return
  }
}

///|
// docx_flow_emit_front draws the floating objects that stand in front of
// the text of the page, once the text has been drawn.
fn docx_flow_emit_front(flow : DocxFlow) -> Unit raise {
  if flow.vertical {
    flow.front.clear()
    return
  }
  if flow.front.is_empty() {
    return
  }
  docx_float_sort(flow.front)
  for item in flow.front {
    docx_emit_placed_image(
      flow.body,
      flow.writer,
      flow.package,
      flow.document.part,
      item.image,
      0.0,
      0.0,
      flow.warnings,
    )
  }
  flow.front.clear()
}

///|
// docx_line_width measures a line of items from its first to its last edge.
fn docx_line_width(items : Array[DocxLineItem]) -> Double {
  if items.is_empty() {
    return 0.0
  }
  let mut right = items[0].x
  for item in items {
    if item.x + item.advance > right {
      right = item.x + item.advance
    }
  }
  right - items[0].x
}

///|
// docx_line_rebase moves a line of items so that its first starts at start.
fn docx_line_rebase(
  items : Array[DocxLineItem],
  start : Double,
) -> Array[DocxLineItem] {
  let out : Array[DocxLineItem] = []
  let mut x = start
  for item in items {
    out.push({ ..item, x: x, })
    x += item.advance
  }
  out
}

///|
// docx_line_split returns the number of items of a line that fit in
// available, breaking at the last space when there is one.
fn docx_line_split(items : Array[DocxLineItem], available : Double) -> Int {
  let mut x = 0.0
  let mut fit = 0
  let mut space = -1
  for index, item in items {
    if x + item.advance > available + 0.01 {
      break
    }
    x += item.advance
    fit = index + 1
    if item.kind == "text" && item.text == " " && index > 0 {
      space = index
    }
  }
  if space > 0 {
    space
  } else {
    fit
  }
}

///|
fn docx_note_lines(
  document : DocxTextDocument,
  kind : String,
  id : String,
  width : Double,
) -> Array[String] {
  let source = if kind == "footnote" {
    document.footnotes.get(id)
  } else {
    document.endnotes.get(id)
  }
  let note_lines = match source {
    Some(value) => value
    None => []
  }
  let out : Array[String] = []
  let mut first = true
  for text in note_lines {
    let prefix = if first { id + ". " } else { "" }
    first = false
    for wrapped in docx_wrap_note(prefix + text, width, 8.5) {
      out.push(wrapped)
    }
  }
  out
}

///|
fn docx_flow_add_note(flow : DocxFlow, kind : String, id : String) -> Unit {
  for note in flow.page_notes {
    if note.kind == kind && note.id == id {
      return
    }
  }
  let width = Double::max(flow.width, 36.0)
  let lines = docx_note_lines(flow.document, kind, id, width)
  let height = 4.0 + lines.length().to_double() * 10.2
  flow.note_height += height
  flow.page_notes.push({ kind, id, lines, height, })
}

///|
fn docx_flow_emit_notes(flow : DocxFlow) -> Unit raise {
  if flow.page_notes.is_empty() {
    return
  }
  let width = Double::min(Double::max(flow.width, 36.0), 144.0)
  let mut y = flow.bottom - flow.note_height
  if y < flow.top {
    y = flow.top
  }
  flow.body.fill_color(0x000000ffU)
  flow.body.fill_rect(
    Float::from_double(flow.x0),
    Float::from_double(y - 2.0),
    Float::from_double(width),
    0.5F,
  )
  let font_key = "sans-serif|400|0"
  let font = match flow.body_fonts.get(font_key) {
    Some(value) => value
    None => {
      let value = flow.body.add_font({
        hash: None,
        family: "sans-serif",
        weight: 400,
        style: 0,
      })
      flow.body_fonts[font_key] = value
      value
    }
  }
  flow.body.font(font, 8.5F)
  flow.body.fill_color(0x000000ffU)
  for note in flow.page_notes {
    y += 4.0
    for text in note.lines {
      flow.body.fill_text(
        text,
        Float::from_double(flow.x0),
        Float::from_double(y + 8.5),
        Float::from_double(width),
      )
      y += 10.2
    }
  }
}

///|
fn docx_append_page_index(
  flow : DocxFlow,
  encoded : Bytes,
  page_index : Int32,
  layer_index : Int32,
) -> Unit {
  let content = @render.extract_text_with_budget(
    @core.decode_object_resources(encoded),
    fn(_) { None },
    flow.budget,
  ) catch {
    _ => { runs: [], links: [], nodes: [], }
  }
  for i, run in content.runs {
    flow.index_runs.push({
      a: page_index,
      b: layer_index,
      ordinal: run.ordinal,
      separator: if i == 0 {
        2
      } else {
        run.separator
      },
      text: run.text,
    })
  }
}

///|
fn docx_page_border_color(border : DocxBorder) -> UInt32 {
  if border.color.length() == 6 {
    let parsed = @string.parse_int(border.color, base=16) catch { _ => -1 }
    if parsed >= 0 {
      return (parsed.to_uint() << 8) | 0xffU
    }
  }
  if border.theme_color != "" {
    match docx_theme_color(border.theme_color) {
      Some(color) => return color
      None => ()
    }
  }
  0x000000ffU
}

///|
/// The page-background object for one page, holding the four `w:pgBorders`
/// rules. None when the section has no visible border or the display rule
/// excludes this page.
fn docx_flow_page_borders(flow : DocxFlow) -> @core.ObjectBuilder? raise {
  let section = flow.section
  let mut visible = false
  for border in section.borders {
    match border {
      Some(value) =>
        if value.width > 0.0 && value.style != "nil" && value.style != "none" {
          visible = true
        }
      None => ()
    }
  }
  let background = flow.document.background
  let first = flow.page_in_section == 0
  let border_excluded = (section.border_first && !first) ||
    (section.border_not_first && first)
  if !visible || border_excluded {
    match background {
      Some(color) => {
        let object = docx_object()
        object.set_bbox(
          0.0F,
          0.0F,
          Float::from_double(section.width),
          Float::from_double(section.height),
        )
        object.fill_color(color)
        object.fill_rect(
          0.0F,
          0.0F,
          Float::from_double(section.width),
          Float::from_double(section.height),
        )
        return Some(object)
      }
      None => return None
    }
  }
  let top = section.borders[0]
  let left = section.borders[1]
  let bottom = section.borders[2]
  let right = section.borders[3]
  let mut x0 = 0.0
  let mut y0 = 0.0
  let mut x1 = section.width
  let mut y1 = section.height
  if section.border_from_text {
    x0 = section.left
    y0 = section.top
    x1 = section.width - section.right
    y1 = section.height - section.bottom
    match top {
      Some(value) => y0 -= value.space
      None => ()
    }
    match left {
      Some(value) => x0 -= value.space
      None => ()
    }
    match bottom {
      Some(value) => y1 += value.space
      None => ()
    }
    match right {
      Some(value) => x1 += value.space
      None => ()
    }
  } else {
    match top {
      Some(value) => y0 += value.space
      None => ()
    }
    match left {
      Some(value) => x0 += value.space
      None => ()
    }
    match bottom {
      Some(value) => y1 -= value.space
      None => ()
    }
    match right {
      Some(value) => x1 -= value.space
      None => ()
    }
  }
  let object = docx_object()
  object.set_bbox(
    0.0F,
    0.0F,
    Float::from_double(section.width),
    Float::from_double(section.height),
  )
  match background {
    Some(color) => {
      object.fill_color(color)
      object.fill_rect(
        0.0F,
        0.0F,
        Float::from_double(section.width),
        Float::from_double(section.height),
      )
    }
    None => ()
  }
  let sides = [top, left, bottom, right]
  let coordinates = [
    [x0, y0, x1, y0],
    [x0, y0, x0, y1],
    [x0, y1, x1, y1],
    [x1, y0, x1, y1],
  ]
  for index, border in sides {
    match border {
      Some(value) =>
        if value.width > 0.0 && value.style != "nil" && value.style != "none" {
          docx_stroke_border(
            object,
            coordinates[index],
            {
              width: value.width,
              color: docx_page_border_color(value),
              space: 0.0,
              style: value.style,
            },
          )
        }
      None => ()
    }
  }
  Some(object)
}

///|
/// An object the word processor draws into. Upstream's `wordproc` emitter
/// writes `font` and `fillColor` only when the value changes, so the
/// builder dedupes the state for these objects and for no others.
fn docx_object() -> @core.ObjectBuilder {
  @core.ObjectBuilder::new(dedupe_state=true)
}

///|
fn docx_flow_flush_page(flow : DocxFlow) -> Unit raise {
  if !flow.page_open {
    return
  }
  docx_flow_emit_notes(flow)
  let footer_part = docx_story_part(flow.section, false, flow.story_kind)
  let mut has_footer = false
  if footer_part != "" {
    let (has, _) = docx_flow_emit_story(
      flow,
      false,
      flow.story_kind,
      flow.footer_fonts,
    )
    has_footer = has
  }
  let section = flow.section
  if flow.vertical {
    flow.body.restore()
  }
  // The floating objects in front of the text go over it, as upstream's
  // body layer draws them after the body ops.
  docx_flow_emit_front(flow)
  if section.column_sep && section.columns.length() > 1 {
    flow.body.fill_color(0x000000ffU)
    for index in 1..<section.columns.length() {
      let (x, width) = section.columns[index - 1]
      let (next_x, _) = section.columns[index]
      let separator_x = section.left + x + width + (next_x - x - width) / 2.0
      flow.body.fill_rect(
        Float::from_double(separator_x - 0.25),
        Float::from_double(section.top),
        0.5,
        Float::from_double(section.height - section.top - section.bottom),
      )
    }
  }
  flow.body.set_bbox(
    0.0F,
    0.0F,
    Float::from_double(section.width),
    Float::from_double(section.height),
  )
  // The header and the footer keep the bounding box of what they draw;
  // the body is the page's box.
  let encoded = flow.body.encode()
  let hash = flow.writer.add_part("obj", encoded)
  let page_index = flow.page_index
  let layers : Array[Json] = []
  let mut text_layer = 0
  match docx_flow_page_borders(flow) {
    Some(background) => {
      let background_hash = flow.writer.add_part("obj", background.encode())
      layers.push(
        Json::object({
          "role": Json::string("background"),
          "obj": Json::string(background_hash),
        }),
      )
    }
    None => ()
  }
  if flow.has_header {
    let header_encoded = flow.header_object.encode()
    let header_hash = flow.writer.add_part("obj", header_encoded)
    layers.push(
      Json::object({
        "role": Json::string("header"),
        "obj": Json::string(header_hash),
      }),
    )
    docx_append_page_index(flow, header_encoded, page_index, text_layer)
    text_layer += 1
  }
  if has_footer {
    let footer_encoded = flow.footer_object.encode()
    let footer_hash = flow.writer.add_part("obj", footer_encoded)
    layers.push(
      Json::object({
        "role": Json::string("footer"),
        "obj": Json::string(footer_hash),
      }),
    )
    docx_append_page_index(flow, footer_encoded, page_index, text_layer)
    text_layer += 1
  }
  layers.push(
    Json::object({ "role": Json::string("body"), "obj": Json::string(hash) }),
  )
  docx_append_page_index(flow, encoded, page_index, text_layer)
  flow.pages.push(
    Json::object({
      "page": Json::number((page_index + 1).to_double()),
      "w": Json::number(section.width, repr=section.width.to_string()),
      "h": Json::number(section.height, repr=section.height.to_string()),
      "body": Json::object({
        "x": Json::number(section.left, repr=section.left.to_string()),
        "y": Json::number(section.top, repr=section.top.to_string()),
        "w": Json::number(
          section.width - section.left - section.right,
          repr=(section.width - section.left - section.right).to_string(),
        ),
        "h": Json::number(
          section.height - section.top - section.bottom,
          repr=(section.height - section.top - section.bottom).to_string(),
        ),
      }),
      "layers": Json::array(layers),
    }),
  )
  flow.page_index = flow.page_index + 1
  flow.page_open = false
}

///|
fn docx_flow_emit_paragraph(
  flow : DocxFlow,
  paragraph : DocxTextParagraph,
  next~ : DocxBlock? = None,
) -> Unit raise {
  let props = paragraph.props
  let mark_size = if paragraph.mark.size > 0.0 {
    paragraph.mark.size
  } else {
    10.0
  }
  let layout = docx_layout_paragraph(
    paragraph.items,
    props,
    flow.width,
    flow.line_pitch,
    mark_size,
    true,
  )
  if props.page_break_before && !docx_flow_at_top(flow) {
    docx_flow_new_page(flow)
  }
  if docx_para_before(props) > 0.0 {
    flow.y += docx_para_before(props)
  }
  if props.keep_next && !flow.vertical {
    let mut current = 0.0
    for line in layout.lines {
      current += line.height
    }
    let next_height = match next {
      Some(DocxParaBlock(value)) => {
        let next_layout = docx_layout_paragraph(
          value.items, value.props, flow.width, flow.line_pitch, 10.0, false,
        )
        if next_layout.lines.is_empty() {
          0.0
        } else {
          next_layout.lines[0].height
        }
      }
      Some(DocxTableBlock(_)) => 14.0
      None => 0.0
    }
    let room = flow.bottom - flow.section.top
    if current <= room && current + next_height > 0.0 {
      docx_flow_ensure(flow, current + next_height)
    }
  }
  if !flow.vertical &&
    (props.keep_lines || props.widow_control) &&
    !layout.lines.is_empty() {
    let mut keep = 0.0
    if props.keep_lines {
      for line in layout.lines {
        keep += line.height
      }
    } else if layout.lines.length() > 1 {
      keep = layout.lines[0].height + layout.lines[1].height
    }
    let room = flow.bottom - flow.section.top
    if keep > 0.0 && keep <= room {
      docx_flow_ensure(flow, keep)
    }
  }
  let ctx : DocxEmitContext = {
    object: flow.body,
    writer: flow.writer,
    package: flow.package,
    part: flow.document.part,
    fonts: flow.body_fonts,
    warnings: flow.warnings,
    bookmark_pages: flow.bookmark_pages,
    field_value: fn(typ, format) { docx_flow_field_value(flow, typ, format) },
    doc_language: flow.document.language,
    language: flow.language,
  }
  let mut emitted = false
  let mut previous_last = '\u{0}'
  fn emit(line : DocxParaLine, x : Double, available : Double) -> Unit raise {
    for item in line.items {
      if item.kind == "bookmark" {
        flow.bookmark_pages[item.text] = flow.page_number
      }
    }
    let (next_first, next_last) = docx_line_edges(line)
    docx_mark_line(flow.body, !emitted, previous_last, next_first, props)
    previous_last = next_last
    emitted = true
    docx_emit_para_line(
      flow.body,
      flow.writer,
      flow.package,
      flow.document.part,
      line,
      x,
      flow.y,
      available,
      flow.body_fonts,
      ctx.bookmark_pages,
      ctx.field_value,
      flow.warnings,
      ctx.doc_language,
      ctx.language,
    )
  }
  // The floating objects of the paragraph stand beside its first line. A
  // paragraph whose objects do not fit below the text of the page moves to
  // the next column with them.
  if !layout.lines.is_empty() {
    let first = layout.lines[0]
    if first.break_before == "page" {
      docx_flow_new_page(flow)
    } else if first.break_before == "column" {
      docx_flow_next_column(flow)
    }
    docx_flow_ensure(flow, first.height)
  }
  docx_flow_place_anchors(flow, layout.anchors, flow.y)
  let right_limit = flow.width - props.right
  let mut pending : Array[DocxLineItem] = []
  let mut index = 0
  let mut last_height = if layout.lines.is_empty() {
    12.0
  } else {
    layout.lines[0].height
  }
  let mut last_align = props.alignment
  let mut steps = 0
  while index < layout.lines.length() || !pending.is_empty() {
    steps += 1
    if steps > 100000 {
      break
    }
    let fresh = pending.is_empty()
    let mut items : Array[DocxLineItem] = []
    let mut images : Array[DocxPlacedImage] = []
    let mut height = last_height
    let mut align = last_align
    let mut justify = false
    let mut distribute = false
    let mut line_shade : UInt32? = None
    let mut line_borders : Array[DocxLineBorder?] = []
    let mut line_border_top = false
    let mut line_border_bottom = false
    if index < layout.lines.length() {
      let base = layout.lines[index]
      if fresh && index > 0 {
        if base.break_before == "page" {
          docx_flow_new_page(flow)
        } else if base.break_before == "column" {
          docx_flow_next_column(flow)
        }
      }
      images = base.images
      height = base.height
      align = base.align
      justify = base.justify
      distribute = base.distribute
      line_shade = base.shade
      line_borders = base.borders
      line_border_top = base.border_top
      line_border_bottom = base.border_bottom
      last_height = height
      last_align = align
      if fresh {
        items = base.items
      } else {
        let merged : Array[DocxLineItem] = []
        for item in pending {
          merged.push(item)
        }
        for item in base.items {
          merged.push(item)
        }
        items = docx_line_rebase(merged, props.left)
      }
    } else {
      items = pending
    }
    pending = []
    // Place the line beside the floating objects, breaking it into more
    // lines while a left or right object leaves it too little room.
    let mut placed = false
    let mut attempts = 0
    while !placed {
      attempts += 1
      if attempts > 1000 {
        break
      }
      docx_flow_ensure(flow, height)
      let (left, right, until) = docx_flow_avail(
        flow, flow.y, height, 0.0, flow.width,
      )
      // A band with no room beside it (top and bottom wrapping, or objects
      // that leave less than a short word) pushes the line below it.
      if right - left < Double::min(36.0, flow.width) && until > flow.y + 0.01 {
        flow.y = until
        continue
      }
      let narrowed = left > 0.01 || right < flow.width - 0.01
      if !narrowed {
        if !items.is_empty() || !images.is_empty() {
          emit(
            {
              items,
              images,
              height,
              align,
              justify,
              distribute,
              break_before: "",
              shade: line_shade,
              borders: line_borders,
              border_top: line_border_top,
              border_bottom: line_border_bottom,
            },
            flow.x0,
            flow.width,
          )
        }
        flow.y += height
        index += 1
        placed = true
        continue
      }
      let start = if items.is_empty() { props.left } else { items[0].x }
      let left_edge = Double::max(start, left)
      let mut available = Double::min(right_limit, right) - left_edge
      let natural = docx_line_width(items)
      if available <= 1.0 && images.is_empty() {
        let bottom = docx_flow_float_bottom(flow, flow.y)
        if bottom > flow.y + 0.01 {
          flow.y = bottom
          continue
        }
        available = Double::max(right_limit - left_edge, 1.0)
      }
      if natural <= available + 0.01 || !images.is_empty() {
        let shift = left_edge - start
        let rebased = docx_line_rebase(items, 0.0)
        let shifted : Array[DocxPlacedImage] = []
        for image in images {
          shifted.push({ ..image, x: image.x + shift, })
        }
        emit(
          { items: rebased, images: shifted, height, align, justify: false, distribute: false, break_before: "", shade: line_shade, borders: line_borders, border_top: line_border_top, border_bottom: line_border_bottom },
          flow.x0 + left_edge,
          available,
        )
        flow.y += height
        index += 1
        placed = true
        continue
      }
      let cut = docx_line_split(items, available)
      if cut <= 0 {
        let bottom = docx_flow_float_bottom(flow, flow.y)
        if bottom > flow.y + 0.01 {
          flow.y = bottom
          continue
        }
        let rebased = docx_line_rebase(items, 0.0)
        emit(
          { items: rebased, images, height, align, justify: false, distribute: false, break_before: "", shade: line_shade, borders: line_borders, border_top: line_border_top, border_bottom: line_border_bottom },
          flow.x0 + left_edge,
          Double::max(available, 1.0),
        )
        flow.y += height
        index += 1
        placed = true
        continue
      }
      let first_items : Array[DocxLineItem] = []
      let rest : Array[DocxLineItem] = []
      let mut position = 0
      for item in items {
        if position < cut {
          first_items.push(item)
        } else {
          rest.push(item)
        }
        position += 1
      }
      // The space the line broke at does not open the next one.
      let rest_items : Array[DocxLineItem] = []
      let mut skipping = true
      for item in rest {
        if skipping && item.kind == "text" && item.text == " " {
          continue
        }
        skipping = false
        rest_items.push(item)
      }
      emit(
        {
          items: docx_line_rebase(first_items, 0.0),
          images: [],
          height,
          align,
          justify: false,
          distribute: false,
          break_before: "",
          shade: line_shade,
          borders: line_borders,
          border_top: line_border_top,
          border_bottom: line_border_bottom,
        },
        flow.x0 + left_edge,
        available,
      )
      flow.y += height
      pending = docx_line_rebase(rest_items, props.left)
      index += 1
      placed = true
    }
    if attempts > 1000 {
      break
    }
  }
  if layout.trailing_break == "page" {
    docx_flow_new_page(flow)
  } else if layout.trailing_break == "column" {
    docx_flow_next_column(flow)
  }
  for note in layout.notes {
    docx_flow_add_note(flow, note.0, note.1)
  }
  if docx_para_after(props) > 0.0 {
    flow.y += docx_para_after(props)
  }
}

///|
fn docx_flow_table_context(flow : DocxFlow) -> DocxEmitContext {
  {
    object: flow.body,
    writer: flow.writer,
    package: flow.package,
    part: flow.document.part,
    fonts: flow.body_fonts,
    warnings: flow.warnings,
    bookmark_pages: flow.bookmark_pages,
    field_value: fn(typ, format) { docx_flow_field_value(flow, typ, format) },
    doc_language: flow.document.language,
    language: flow.language,
  }
}

///|
fn docx_flow_repeat_headers(
  flow : DocxFlow,
  layout : DocxTableLayout,
  header_rows : Int32,
  row_index : Int32,
) -> Bool raise {
  if row_index < header_rows {
    return true
  }
  for index in 0..<header_rows {
    let height = layout.rows[index].height
    docx_flow_ensure(flow, height)
    let ctx = docx_flow_table_context(flow)
    docx_emit_table_row(ctx, layout, index, 0.0, height, flow.x0, flow.y)
    flow.y += height
  }
  true
}

///|
fn docx_flow_emit_table(flow : DocxFlow, table : DocxTable) -> Unit raise {
  let layout = docx_layout_table(table, flow.width, flow.line_pitch)
  for note in layout.notes {
    docx_flow_add_note(flow, note.0, note.1)
  }
  let mut ctx = docx_flow_table_context(flow)
  let mut header_rows = 0
  while header_rows < table.rows.length() && table.rows[header_rows].header {
    header_rows += 1
  }
  let mut row_index = 0
  let mut cut = 0.0
  let mut fresh = false
  let mut steps = 0
  while row_index < layout.rows.length() {
    steps += 1
    if steps > 100000 {
      break
    }
    let row_height = layout.rows[row_index].height
    let remaining = row_height - cut
    let available = docx_flow_limit(flow) - flow.y

    if remaining <= available + 0.01 {
      docx_emit_table_row(
        ctx,
        layout,
        row_index,
        cut,
        row_height,
        flow.x0,
        flow.y,
      )
      flow.y += remaining
      row_index += 1
      cut = 0.0
      fresh = false
      continue
    }
    let row = table.rows[row_index]
    let may_split = !row.cant_split &&
      !row.header &&
      !fresh &&
      !docx_flow_at_top(flow)
    if may_split {
      let candidate = docx_table_safe_cut(
        layout,
        row_index,
        cut,
        cut + Double::max(available, 0.0),
      )
      if candidate > cut + 1.0 {
        docx_emit_table_row(
          ctx,
          layout,
          row_index,
          cut,
          candidate,
          flow.x0,
          flow.y,
        )
        flow.y += candidate - cut
        cut = candidate
        docx_flow_next_column(flow)
        fresh = docx_flow_repeat_headers(flow, layout, header_rows, row_index)
        ctx = docx_flow_table_context(flow)
        continue
      }
    }
    if fresh || docx_flow_at_top(flow) {
      docx_emit_table_row(
        ctx,
        layout,
        row_index,
        cut,
        row_height,
        flow.x0,
        flow.y,
      )
      flow.y += remaining
      row_index += 1
      cut = 0.0
      fresh = false
      continue
    }
    docx_flow_next_column(flow)
    fresh = docx_flow_repeat_headers(flow, layout, header_rows, row_index)
    ctx = docx_flow_table_context(flow)
  }
  flow.y += 1.0
}

///|
fn docx_flow_section(flow : DocxFlow, index : Int32) -> Unit raise {
  let previous = flow.section
  let section = docx_section_at(flow.document, index)
  let continuous = section.section_type == "continuous" ||
    section.section_type == "nextColumn"
  if continuous && docx_section_same_geometry(previous, section) {
    flow.section = section
    flow.section_index = index
    if section.page_start >= 0 {
      flow.next_number = section.page_start.to_int()
    }
    let top = Double::max(flow.y, flow.col_bottom)
    flow.vertical = section.vertical
    flow.line_pitch = docx_section_grid_pitch(section)
    flow.col = 0
    if flow.vertical {
      let text_width = Double::max(
        section.width - section.left - section.right,
        36.0,
      )
      flow.top = top
      flow.bottom = text_width
      flow.y = top
    } else {
      flow.top = top
      flow.y = top
    }
    docx_flow_set_column(flow)
  } else {
    docx_flow_flush_page(flow)
    flow.section = section
    flow.section_index = index
    let start = if section.page_start >= 0 {
      section.page_start.to_int()
    } else {
      Int32::max(flow.next_number, 1)
    }
    flow.section_start = start
    flow.next_number = start
    flow.page_in_section = 0
    flow.col_bottom = section.top
    let needs_blank = (section.section_type == "oddPage" && start % 2 == 0) ||
      (section.section_type == "evenPage" && start % 2 != 0)
    let mut content_start = start
    if needs_blank {
      docx_flow_new_page(flow)
      docx_flow_flush_page(flow)
      content_start = start + 1
    }
    flow.section_start = content_start
    flow.next_number = content_start
    docx_flow_new_page(flow)
  }
}

///|
fn docx_layout_document(
  document : DocxTextDocument,
  total_pages : Int32,
  writer : @core.DocumentWriter,
  package : @ooxml.OoxmlPackage,
  bookmarks~ : Map[String, Int32] = Map([]),
) -> (Array[Json], Array[@core.IndexRun], Array[String], Map[String, Int32]) raise {
  let warnings : Array[String] = ["DOCX layout uses approximate text metrics"]
  let section = docx_section_at(document, 0)
  let start = if section.page_start >= 0 {
    section.page_start.to_int()
  } else {
    1
  }
  let flow : DocxFlow = {
    document,
    writer,
    package,
    total_pages,
    warnings,
    pages: [],
    index_runs: [],
    budget: @render.TextExtractionBudget::new(),
    stories: Map([]),
    bookmark_pages: bookmarks,
    body: docx_object(),
    header_object: docx_object(),
    footer_object: docx_object(),
    body_fonts: Map([]),
    header_fonts: Map([]),
    footer_fonts: Map([]),
    has_header: false,
    floats: [],
    front: [],
    page_open: false,
    page_index: 0,
    page_number: start,
    page_in_section: 0,
    next_number: start,
    section,
    section_index: 0,
    section_start: start,
    story_kind: "default",
    language: Ref(""),
    col: 0,
    x0: section.left,
    y: section.top,
    top: section.top,
    bottom: section.height - section.bottom,
    width: section.width - section.left - section.right,
    line_pitch: docx_section_grid_pitch(section),
    vertical: section.vertical,
    col_bottom: section.top,
    note_height: 0.0,
    page_notes: [],
  }
  docx_flow_new_page(flow)
  for i, block in document.blocks {
    let index = match block {
      DocxParaBlock(paragraph) => paragraph.section_index
      DocxTableBlock(table) => table.section_index
    }
    if index != flow.section_index {
      docx_flow_section(flow, index)
    }
    let next = if i + 1 < document.blocks.length() {
      Some(document.blocks[i + 1])
    } else {
      None
    }
    match block {
      DocxParaBlock(paragraph) => docx_flow_emit_paragraph(flow, paragraph, next~)
      DocxTableBlock(table) => docx_flow_emit_table(flow, table)
    }
  }
  docx_flow_flush_page(flow)
  if flow.pages.is_empty() {
    docx_flow_new_page(flow)
    docx_flow_flush_page(flow)
  }
  (flow.pages, flow.index_runs, flow.warnings, flow.bookmark_pages)
}

///|
fn docx_render_meta(
  package : @ooxml.OoxmlPackage,
  title : String,
  language : String,
) -> Map[String, Json] {
  let core = package.core_properties()
  let meta : Map[String, Json] = {
    "source": Json::string("docx"),
    "generator": Json::string("bdf-go/0.1"),
  }
  let dc : Map[String, Json] = Map([])
  for
    entry in [
      ("title", core.title),
      ("creator", core.creator),
      ("subject", core.subject),
      ("description", core.description),
      ("identifier", core.identifier),
      ("language", core.language),
      ("created", core.created),
      ("modified", core.modified),
    ] {
    let (key, values) = entry
    if !values.is_empty() && values[0] != "" {
      dc[key] = Json::string(values[0])
    }
  }
  if !dc.contains("language") && language != "" {
    dc["language"] = Json::string(language)
  }
  if title != "" {
    dc["title"] = Json::string(title)
  }
  if !dc.is_empty() {
    meta["dc"] = Json::object(dc)
  }
  meta
}

///|
fn docx_render_document(
  document : DocxTextDocument,
  title : String,
  data : Bytes,
  views : String,
) -> DocxResult raise {
  let package = @ooxml.open_ooxml(data) catch {
    _ => raise DocxInvalid("invalid DOCX package")
  }
  let meta = docx_render_meta(package, title, document.language)
  let mut page_count = 0
  let mut bookmark_pages : Map[String, Int32] = Map([])
  if views != "scroll" {
    let probe = @core.DocumentWriter::new(meta=Json::object(meta))
    let (probe_pages, _, _, probe_bookmarks) = docx_layout_document(
      document, 0, probe, package,
    )
    bookmark_pages = probe_bookmarks
    page_count = probe_pages.length()
    if page_count == 0 {
      page_count = 1
    }
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let pages : Array[Json] = []
  let mut index_runs : Array[@core.IndexRun] = []
  let mut warnings : Array[String] = [
    "DOCX layout uses approximate text metrics",
  ]
  if views != "scroll" {
    let (rendered, runs, rendered_warnings, _) = docx_layout_document(
      document, page_count, writer, package, bookmarks=bookmark_pages,
    )
    for page in rendered {
      pages.push(page)
    }
    index_runs = runs
    warnings = rendered_warnings
    let view : Map[String, Json] = {
      "id": Json::string("pages"),
      "kind": Json::string("flow"),
      "pages": Json::array(pages),
      "continuous": Json::object({ "gap": Json::number(24.0) }),
    }
    if title != "" {
      view["title"] = Json::string(title)
    }
    if !index_runs.is_empty() {
      let encoded = @core.encode_text_index(index_runs) catch { _ => b"" }
      if encoded.length() > 0 {
        view["textIndex"] = Json::string(writer.add_part("idx", encoded))
      }
    }
    writer.add_view(Json::object(view))
  }
  let mut strips = 0
  if views != "pages" {
    let (scroll_pages, scroll_runs, strip_count) = docx_render_scroll(
      document, writer, package,
    )
    strips = strip_count
    if !scroll_pages.is_empty() {
      let scroll_view : Map[String, Json] = {
        "id": Json::string("scroll"),
        "kind": Json::string("scroll"),
        "pages": Json::array(scroll_pages),
      }
      if title != "" {
        scroll_view["title"] = Json::string(title)
      }
      if !scroll_runs.is_empty() {
        let encoded = @core.encode_text_index(scroll_runs) catch { _ => b"" }
        if encoded.length() > 0 {
          scroll_view["textIndex"] = Json::string(
            writer.add_part("idx", encoded),
          )
        }
      }
      writer.add_view(Json::object(scroll_view))
    }
  }
  let bdf = writer.write_single()
  {
    bdf,
    pages: if views == "scroll" {
      0
    } else {
      page_count
    },
    summary: "\{page_count} page" +
    (if page_count == 1 { "" } else { "s" }) +
    ", " +
    strips.to_string() +
    " scroll strip" +
    (if strips == 1 { "" } else { "s" }),
    warnings,
  }
}
