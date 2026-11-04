///|
// Text layout and drawing for DrawingML shapes.

///|
/// The theme's major and minor Latin and East Asian fonts.
priv struct PptxThemeFonts {
  major : String
  minor : String
  major_ea : String
  minor_ea : String
}

///|
priv struct PptxShapeContext {
  package : @ooxml.OoxmlPackage
  writer : @core.DocumentWriter
  part : String
  theme : Map[String, UInt32]
  theme_fonts : PptxThemeFonts
  theme_fills : Array[PptxXmlNode]
  theme_bg_fills : Array[PptxXmlNode]
  theme_lines : Array[PptxXmlNode]
  default_text_style : PptxXmlNode?
  layout_root : PptxXmlNode?
  master_root : PptxXmlNode?
  layout_placeholders : Array[PptxXmlNode]
  master_placeholders : Array[PptxXmlNode]
  is_body : Bool
  fonts : Map[String, Int32]
  font_ctx : PptxFontContext
  warnings : Array[String]
  warned : Map[String, Bool]
}

///|
priv struct PptxStyledChar {
  text : String
  family : String
  weight : Int32
  style : Int32
  size : Double
  color : UInt32
  advance : Double
  space : Bool
  cjk : Bool
  break_after : Bool
  hard_break : Bool
  mut no_break : Bool
  face : String
  choice : @fontdb.Choice?
  record_family : String
  record_weight : Int32
  record_style : Int32
  asc : Double
  desc : Double
}

///|
priv struct PptxTextLine {
  items : Array[PptxLineItem]
  start : Double
  width : Double
  height : Double
  max_size : Double
  asc : Double
  desc : Double
  wrap : Byte
}

///|
priv struct PptxParagraphLayout {
  lines : Array[PptxTextLine]
  align : Int32
  bullet : PptxBullet
  bullet_x : Double
  bullet_width : Double
  bullet_family : String
  bullet_weight : Int32
  bullet_style : Int32
  bullet_size : Double
  bullet_color : UInt32
  space_before : Double
  space_after : Double
}

///|
fn pptx_font_reference(name : String, fonts : PptxThemeFonts) -> String {
  match name {
    "" | "+mn-lt" => fonts.minor
    "+mj-lt" => fonts.major
    value => value
  }
}

///|
fn pptx_font_reference_ea(name : String, fonts : PptxThemeFonts) -> String {
  match name {
    "" | "+mn-ea" => fonts.minor_ea
    "+mj-ea" => fonts.major_ea
    value => value
  }
}

///|
fn pptx_run_style(
  ctx : PptxShapeContext,
  chain : Array[PptxXmlNode],
  run : PptxXmlNode,
  scale : Double,
) -> (String, String, Int32, Int32, Double, UInt32) {
  let rpr = pptx_child(Some(run), "rPr")
  let family = pptx_font_reference(
    match pptx_chain_run_child(chain, rpr, "latin") {
      Some(value) => pptx_attribute(value.element, "typeface", "")
      None => ""
    },
    ctx.theme_fonts,
  )
  let east_asian = pptx_font_reference_ea(
    match pptx_chain_run_child(chain, rpr, "ea") {
      Some(value) => pptx_attribute(value.element, "typeface", "")
      None => ""
    },
    ctx.theme_fonts,
  )
  let size_value = @string.parse_double(
    pptx_chain_run_attribute(chain, rpr, "sz", "1800"),
  ) catch {
    _ => 1800.0
  }
  let size = size_value / 100.0 * scale
  let weight = if pptx_chain_run_bool(chain, rpr, "b") { 700 } else { 400 }
  let style = if pptx_chain_run_bool(chain, rpr, "i") { 1 } else { 0 }
  let color = match pptx_chain_run_child(chain, rpr, "solidFill") {
    Some(value) =>
      pptx_solid_color(Some(value), ctx.theme).unwrap_or(0x000000ffU)
    None => 0x000000ffU
  }
  (family, east_asian, weight, style, size, color)
}

///|
fn pptx_math_run_style(
  ctx : PptxShapeContext,
  chain : Array[PptxXmlNode],
  node : PptxXmlNode,
  scale : Double,
) -> (String, String, Int32, Int32, Double, UInt32) {
  let (_, _, weight, _, default_size, color) = pptx_run_style(
    ctx, chain, node, 1.0,
  )
  let size = pptx_math_size(node).unwrap_or(default_size) * scale
  ("Cambria Math", "", weight, 1, size, color)
}

///|
fn pptx_body_autofit(body : PptxXmlNode) -> (Double, Double) {
  match pptx_child(Some(body), "bodyPr") {
    Some(props) =>
      match pptx_child(Some(props), "normAutofit") {
        Some(fit) => {
          let scale = match pptx_attribute(fit.element, "fontScale", "") {
            "" => 1.0
            value =>
              (@string.parse_double(value) catch { _ => 100000.0 }) / 100000.0
          }
          let reduce = match pptx_attribute(
            fit.element,
            "lnSpcReduction",
            "",
          ) {
            "" => 0.0
            value =>
              (@string.parse_double(value) catch { _ => 0.0 }) / 100000.0
          }
          (scale, reduce)
        }
        None => (1.0, 0.0)
      }
    None => (1.0, 0.0)
  }
}

///|
fn pptx_char_to_styled(
  fonts : PptxFontContext,
  text : String,
  family : String,
  east_asian : String,
  weight : Int32,
  style : Int32,
  size : Double,
  color : UInt32,
) -> Array[PptxStyledChar] {
  let out : Array[PptxStyledChar] = []
  for c in text {
    let code = c.to_int()
    let cjk = code >= 0x2e80
    let space = c == ' '
    let break_after = space ||
      cjk ||
      c == '-' ||
      c == '/' ||
      c == '\u{3001}' ||
      c == '\u{3002}' ||
      c == '\u{ff0c}' ||
      c == '\u{ff0e}'
    let metrics = pptx_font_metrics(
      fonts, family, east_asian, weight, style, size, code,
    )
    out.push({
      text: c.to_string(),
      family,
      weight,
      style,
      size,
      color,
      advance: metrics.advance,
      space,
      cjk,
      break_after,
      hard_break: false,
      no_break: false,
      face: metrics.face,
      choice: metrics.choice,
      record_family: metrics.record_family,
      record_weight: metrics.record_weight,
      record_style: metrics.record_style,
      asc: metrics.asc,
      desc: metrics.desc,
    })
  }
  out
}

///|
fn pptx_paragraph_chars(
  ctx : PptxShapeContext,
  shape : PptxXmlNode,
  body : PptxXmlNode,
  paragraph : PptxXmlNode,
  scale : Double,
) -> Array[PptxStyledChar] {
  let chain = pptx_text_chain(
    shape,
    body,
    paragraph,
    ctx.layout_placeholders,
    ctx.master_placeholders,
    ctx.master_root,
    ctx.default_text_style,
    ctx.is_body,
  )
  let chars : Array[PptxStyledChar] = []
  for child in pptx_children(Some(paragraph)) {
    match child.element.name.local_name {
      "r" | "fld" => {
        let text = match pptx_child(Some(child), "t") {
          Some(value) => value.text.to_string()
          None => ""
        }
        if text == "" {
          continue
        }
        let (family, east_asian, weight, style, size, color) = pptx_run_style(
          ctx, chain, child, scale,
        )
        for
          styled in pptx_char_to_styled(
            ctx.font_ctx,
            text,
            family,
            east_asian,
            weight,
            style,
            size,
            color,
          ) {
          chars.push(styled)
        }
      }
      "m" => {
        let text = pptx_omml_join(child)
        if text == "" {
          continue
        }
        let (family, east_asian, weight, style, size, color) = pptx_math_run_style(
          ctx, chain, child, scale,
        )
        let formula = pptx_char_to_styled(
          ctx.font_ctx,
          text,
          family,
          east_asian,
          weight,
          style,
          size,
          color,
        )
        for styled in formula {
          styled.no_break = true
          chars.push(styled)
        }
      }
      "br" =>
        chars.push({
          text: "",
          family: "",
          weight: 400,
          style: 0,
          size: 0.0,
          color: 0x000000ffU,
          advance: 0.0,
          space: false,
          cjk: false,
          break_after: false,
          hard_break: true,
          no_break: false,
          face: "",
          choice: None,
          record_family: "",
          record_weight: 400,
          record_style: 0,
          asc: 0.0,
          desc: 0.0,
        })
      _ => ()
    }
  }
  chars
}

///|
fn pptx_merge_line_items(
  chars : Array[PptxStyledChar],
  from : Int32,
  to : Int32,
) -> Array[PptxLineItem] {
  let items : Array[PptxLineItem] = []
  let mut index = from
  let mut placed = 0.0
  while index < to {
    if chars[index].hard_break {
      index += 1
      continue
    }
    let first = chars[index]
    let text = StringBuilder()
    let mut advance = 0.0
    while index < to &&
          !chars[index].hard_break &&
          chars[index].family == first.family &&
          chars[index].weight == first.weight &&
          chars[index].style == first.style &&
          chars[index].size == first.size &&
          chars[index].color == first.color &&
          chars[index].face == first.face &&
          chars[index].record_family == first.record_family &&
          chars[index].record_weight == first.record_weight &&
          chars[index].record_style == first.record_style {
      text.write_string(chars[index].text)
      advance += chars[index].advance
      index += 1
    }
    items.push({
      text: text.to_string(),
      family: first.family,
      weight: first.weight,
      style: first.style,
      size: first.size,
      color: first.color,
      x: placed,
      advance,
      face: first.face,
      choice: first.choice,
      record_family: first.record_family,
      record_weight: first.record_weight,
      record_style: first.record_style,
      asc: first.asc,
      desc: first.desc,
    })
    placed += advance
  }
  items
}

///|
fn pptx_layout_paragraph(
  chars : Array[PptxStyledChar],
  props : PptxParagraphProps,
  bullet_text : String,
  bullet_size : Double,
  bullet_family : String,
  bullet_weight : Int32,
  bullet_style : Int32,
  bullet_color : UInt32,
  bullet_blip : String,
  available : Double,
  fonts : PptxFontContext,
) -> PptxParagraphLayout {
  let bullet_width = if bullet_text == "" {
    0.0
  } else {
    pptx_measure_text(
      fonts, bullet_family, "", bullet_weight, bullet_style, bullet_size, bullet_text,
    )
  }
  let mut first_start = Double::max(props.mar_l + props.indent, 0.0)
  let bullet_x = first_start
  if bullet_text != "" {
    if props.indent >= 0.0 || bullet_x + bullet_width > props.mar_l {
      first_start = bullet_x + bullet_width
    } else {
      first_start = props.mar_l
    }
  }
  first_start = Double::max(first_start, 0.0)
  let lines : Array[PptxTextLine] = []
  let mut segment_start = 0
  let mut first = true
  let mut done = chars.is_empty()
  while !done {
    let start = if first { first_start } else { props.mar_l }
    let mut end = segment_start
    let mut width = start
    let mut last_break = -1
    let mut last_break_wrap : Byte = 1
    let mut hard = false
    while end < chars.length() {
      let c = chars[end]
      if c.hard_break {
        hard = true
        break
      }
      if width + c.advance > available &&
        end > segment_start &&
        (!c.no_break || !chars[end - 1].no_break) {
        break
      }
      width += c.advance
      if c.break_after {
        last_break = end + 1
        last_break_wrap = if c.space { 1 } else if c.cjk { 5 } else { 1 }
      }
      end += 1
    }
    let mut line_end = end
    let mut wrap : Byte = 1
    if !hard && end < chars.length() && last_break > segment_start {
      line_end = last_break
      wrap = last_break_wrap
    }
    while line_end > segment_start && chars[line_end - 1].space {
      line_end -= 1
    }
    let items = pptx_merge_line_items(chars, segment_start, line_end)
    let mut line_width = 0.0
    let mut max_size = 0.0
    let mut asc = 0.0
    let mut desc = 0.0
    for item in items {
      line_width = Double::max(line_width, item.x + item.advance)
      max_size = Double::max(max_size, item.size)
      asc = Double::max(asc, item.asc)
      desc = Double::max(desc, item.desc)
    }
    let natural = asc + desc
    let height = if props.ln_pts > 0.0 {
      props.ln_pts
    } else if natural > 0.0 {
      natural * (if props.ln_pct > 0.0 { props.ln_pct } else { 1.0 })
    } else {
      14.0
    }
    lines.push({
      items,
      start,
      width: line_width,
      height,
      max_size,
      asc,
      desc,
      wrap,
    })
    if hard {
      segment_start = end + 1
    } else if line_end >= chars.length() {
      done = true
    } else {
      segment_start = line_end
      while segment_start < chars.length() && chars[segment_start].space {
        segment_start += 1
      }
    }
    first = false
    if segment_start >= chars.length() {
      done = true
    }
  }
  if lines.is_empty() {
    lines.push({
      items: [],
      start: first_start,
      width: 0.0,
      height: 14.0,
      max_size: 0.0,
      asc: 14.0,
      desc: 0.0,
      wrap: 1,
    })
  }
  let mut natural = 0.0
  for line in lines {
    natural = Double::max(natural, line.asc + line.desc)
  }
  if natural <= 0.0 {
    natural = 14.0
  }
  let space_before = props.bef_pts + props.bef_pct * natural
  let space_after = props.aft_pts + props.aft_pct * natural
  {
    lines,
    align: props.align,
    bullet: {
      kind: if bullet_text == "" {
        "none"
      } else {
        "char"
      },
      text: bullet_text,
      start: 1,
      font: "",
      color_node: None,
      size_pct: 0.0,
      size_pts: 0.0,
      blip: bullet_blip,
    },
    bullet_x,
    bullet_width,
    bullet_family,
    bullet_weight,
    bullet_style,
    bullet_size,
    bullet_color,
    space_before,
    space_after,
  }
}

///|
fn pptx_bullet_text(
  bullet : PptxBullet,
  level : Int32,
  counters : Array[Int32],
  schemes : Array[String],
) -> String {
  if bullet.kind == "none" {
    return ""
  }
  if bullet.kind == "auto" {
    let scheme = "arabicPeriod"
    if schemes[level] != scheme || counters[level] == 0 {
      counters[level] = bullet.start
    } else {
      counters[level] += 1
    }
    schemes[level] = scheme
    pptx_auto_number(scheme, counters[level])
  } else {
    counters[level] = 0
    schemes[level] = ""
    bullet.text
  }
}

///|
fn pptx_body_prop_double(
  body_props : PptxXmlNode,
  name : String,
  default : Double,
) -> Double {
  match pptx_attribute(body_props.element, name, "") {
    "" => default
    value =>
      (@string.parse_double(value) catch { _ => default * 12700.0 }) / 12700.0
  }
}

///|
fn pptx_chars_have_text(chars : Array[PptxStyledChar]) -> Bool {
  for c in chars {
    if !c.hard_break {
      return true
    }
  }
  false
}

///|
fn pptx_first_char(chars : Array[PptxStyledChar]) -> PptxStyledChar? {
  for c in chars {
    if !c.hard_break {
      return Some(c)
    }
  }
  None
}

///|
fn pptx_bullet_image(
  ctx : PptxShapeContext,
  blip : String,
) -> Bytes? {
  if blip == "" || ctx.part == "" {
    return None
  }
  for rel in ctx.package.relationships(ctx.part) {
    if rel.id == blip && !rel.external {
      let bytes = ctx.package.read(rel.target) catch { _ => return None }
      return Some(bytes)
    }
  }
  None
}

///|
fn pptx_draw_shape_text(
  ctx : PptxShapeContext,
  object : @core.ObjectBuilder,
  shape : PptxXmlNode,
  body : PptxXmlNode,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  rotation : Double,
  center_x : Double,
  center_y : Double,
) -> Unit raise {
  let (scale, ln_reduce) = pptx_body_autofit(body)
  let mut left_inset = 7.2
  let mut top_inset = 3.6
  let mut right_inset = 7.2
  let mut bottom_inset = 3.6
  let mut anchor = "top"
  let mut vertical = ""
  match pptx_child(Some(body), "bodyPr") {
    Some(value) => {
      left_inset = pptx_body_prop_double(value, "lIns", 7.2)
      top_inset = pptx_body_prop_double(value, "tIns", 3.6)
      right_inset = pptx_body_prop_double(value, "rIns", 7.2)
      bottom_inset = pptx_body_prop_double(value, "bIns", 3.6)
      anchor = match pptx_attribute(value.element, "anchor", "") {
        "ctr" => "center"
        "b" => "bottom"
        _ => "top"
      }
      vertical = pptx_attribute(value.element, "vert", "")
    }
    None => ()
  }
  let available = Double::max(1.0, width - left_inset - right_inset)
  let origin_x = x + left_inset
  let top = y + top_inset
  let counters : Array[Int32] = Array::make(9, 0)
  let schemes : Array[String] = Array::make(9, "")
  let paragraphs : Array[PptxParagraphLayout] = []
  let mut total = 0.0
  for paragraph in pptx_children(Some(body)) {
    if paragraph.element.name.local_name != "p" {
      continue
    }
    let chain = pptx_text_chain(
      shape,
      body,
      paragraph,
      ctx.layout_placeholders,
      ctx.master_placeholders,
      ctx.master_root,
      ctx.default_text_style,
      ctx.is_body,
    )
    let props = pptx_paragraph_props(chain)
    let props = { ..props, ln_pct: Double::max(props.ln_pct - ln_reduce, 0.1) }
    let bullet = pptx_paragraph_bullet(chain)
    let chars = pptx_paragraph_chars(ctx, shape, body, paragraph, scale)
    let has_text = pptx_chars_have_text(chars)
    let bullet_text = if has_text {
      pptx_bullet_text(bullet, props.level, counters, schemes)
    } else {
      ""
    }
    let (bullet_family, bullet_weight, bullet_style, bullet_size, bullet_color) = match
      pptx_first_char(chars) {
      Some(c) => (c.family, c.weight, c.style, c.size, c.color)
      None => {
        let (family, _, weight, style, size, color) = pptx_run_style(
          ctx, chain, paragraph, scale,
        )
        (family, weight, style, size, color)
      }
    }
    let bullet_size = if bullet.size_pts > 0.0 {
      bullet.size_pts
    } else if bullet.size_pct > 0.0 {
      bullet_size * bullet.size_pct / 100.0
    } else {
      bullet_size
    }
    let bullet_color = match bullet.color_node {
      Some(node) =>
        pptx_solid_color(Some(node), ctx.theme).unwrap_or(bullet_color)
      None => bullet_color
    }
    let layout = pptx_layout_paragraph(
      chars,
      props,
      bullet_text,
      bullet_size,
      bullet_family,
      bullet_weight,
      bullet_style,
      bullet_color,
      bullet.blip,
      available,
      ctx.font_ctx,
    )
    total += layout.space_before + layout.space_after
    for line in layout.lines {
      total += line.height
    }
    paragraphs.push(layout)
  }
  if paragraphs.is_empty() {
    return
  }
  let mut anchor_offset = 0.0
  let content_height = Double::max(0.0, height - top_inset - bottom_inset)
  match anchor {
    "center" => anchor_offset = Double::max(0.0, (content_height - total) / 2.0)
    "bottom" => anchor_offset = Double::max(0.0, content_height - total)
    _ => ()
  }
  let vertical_rotation = match vertical {
    "vert" | "eaVert" => 90.0
    "vert270" => -90.0
    _ => 0.0
  }
  let text_rotation = rotation + vertical_rotation
  let rotated = text_rotation != 0.0
  if rotated {
    let radians = text_rotation * 3.141592653589793 / 180.0
    let sine = @math.sin(radians)
    let cosine = @math.cos(radians)
    object.save()
    object.translate(Float::from_double(center_x), Float::from_double(center_y))
    object.transform(
      Float::from_double(cosine),
      Float::from_double(sine),
      Float::from_double(-sine),
      Float::from_double(cosine),
      0.0F,
      0.0F,
    )
    object.translate(
      Float::from_double(-center_x),
      Float::from_double(-center_y),
    )
  }
  let mut line_y = top + anchor_offset
  for paragraph in paragraphs {
    line_y += paragraph.space_before
    object.mark(0, "")
    let mut bullet_drawn = false
    if paragraph.bullet.blip != "" {
      match pptx_bullet_image(ctx, paragraph.bullet.blip) {
        Some(bytes) => {
          let hash = ctx.writer.add_part("img", bytes)
          let index = object.add_image(hash)
          let baseline = line_y +
            paragraph.lines[0].height -
            paragraph.lines[0].desc
          object.image(
            index,
            Float::from_double(origin_x + paragraph.bullet_x),
            Float::from_double(baseline - paragraph.bullet_size),
            Float::from_double(paragraph.bullet_size),
            Float::from_double(paragraph.bullet_size),
          )
          bullet_drawn = true
        }
        None => ()
      }
    }
    if paragraph.bullet.text != "" && !bullet_drawn {
      let font = pptx_font_ref_text(
        ctx.font_ctx,
        object,
        paragraph.bullet_family,
        "",
        paragraph.bullet_weight,
        paragraph.bullet_style,
        paragraph.bullet_size,
        paragraph.bullet.text,
      )
      object.font(font, Float::from_double(paragraph.bullet_size))
      object.fill_color(paragraph.bullet_color)
      let baseline = line_y +
        paragraph.lines[0].height -
        paragraph.lines[0].desc
      object.fill_text(
        paragraph.bullet.text,
        Float::from_double(origin_x + paragraph.bullet_x),
        Float::from_double(baseline),
        Float::from_double(paragraph.bullet_width),
      )
      object.mark(1, "")
    }
    let mut first_line = true
    let mut previous_wrap : Byte = 1
    for line in paragraph.lines {
      if !first_line {
        object.mark(previous_wrap, "")
      }
      previous_wrap = line.wrap
      first_line = false
      let mut offset = 0.0
      if line.items.length() > 0 {
        match paragraph.align {
          1 => offset = Double::max(0.0, (available - line.width) / 2.0)
          2 => offset = Double::max(0.0, available - line.width)
          _ => ()
        }
      }
      let baseline = line_y + line.height - line.desc
      for item in line.items {
        let font = pptx_font_ref(
          ctx.font_ctx,
          object,
          item.face,
          item.choice,
          item.record_family,
          item.record_weight,
          item.record_style,
          item.text,
        )
        object.font(font, Float::from_double(item.size))
        object.fill_color(item.color)
        object.fill_text(
          item.text,
          Float::from_double(origin_x + line.start + offset + item.x),
          Float::from_double(baseline),
          Float::from_double(item.advance),
        )
      }
      line_y += line.height
    }
    line_y += paragraph.space_after
  }
  if rotated {
    object.restore()
  }
}

///|
fn PptxShapeContext::warn_once(
  self : PptxShapeContext,
  key : String,
  message : String,
) -> Unit {
  if !self.warned.contains(key) {
    self.warned[key] = true
    self.warnings.push(message)
  }
}
