///|
/// Options for writing a BDF document as Markdown.
pub(all) struct MarkdownOptions {
  views : Array[String]
  skip_roles : Array[String]
  internal_links : Bool
  keep_running : Bool
  tables : String
  images : String
}

///|
pub fn MarkdownOptions::new() -> MarkdownOptions {
  {
    views: [],
    skip_roles: ["header", "footer", "master", "background"],
    internal_links: false,
    keep_running: false,
    tables: "inline",
    images: "zip",
  }
}

///|
/// A file written beside the Markdown, such as an image for the zip mode.
pub(all) struct MarkdownFile {
  name : String
  bytes : Bytes
}

///|
pub(all) struct MarkdownResult {
  markdown : String
  files : Array[MarkdownFile]
  warnings : Array[String]
  views : Int32
  images : Int32
  tables : Int32
}

///|
fn has(array : Array[String], value : String) -> Bool {
  for item in array {
    if item == value {
      return true
    }
  }
  false
}

///|
fn role_skipped(options : MarkdownOptions, role : String) -> Bool {
  if options.keep_running {
    false
  } else {
    has(options.skip_roles, role)
  }
}

///|
fn object_resolver(
  document : @core.Document,
) -> (String) -> @core.ObjectResources? raise {
  fn(hash) {
    let bytes = document.part(hash) catch { _ => return None }
    Some(@core.decode_object_resources(bytes)) catch {
      _ => None
    }
  }
}

///|
fn read_part(document : @core.Document, hash : String) -> Bytes raise {
  document.part(hash)
}

///|
fn selected_views(
  document : @core.Document,
  options : MarkdownOptions,
) -> Array[@core.View] {
  let selected : Array[@core.View] = []
  if options.views.length() > 0 {
    for view in document.manifest.views {
      if has(options.views, view.id) {
        selected.push(view)
      }
    }
    return selected
  }
  let mut scroll : @core.View? = None
  for view in document.manifest.views {
    if view.kind == "scroll" {
      scroll = Some(view)
    }
  }
  match scroll {
    Some(view) => [view]
    None => document.manifest.views
  }
}

///|
fn node_children(
  nodes : Array[@render.TextNode],
  parent : Int32,
) -> Array[Int32] {
  let children : Array[Int32] = []
  for index, node in nodes {
    if node.parent == parent {
      children.push(index)
    }
  }
  children
}

///|
fn node_contains(
  nodes : Array[@render.TextNode],
  start : Int32,
  target : Int32,
) -> Bool {
  let mut index = start
  let mut steps = 0
  while index >= 0 && index < nodes.length() && steps < nodes.length() {
    if index == target {
      return true
    }
    index = nodes[index].parent
    steps += 1
  }
  false
}

///|
fn runs_for(
  content : @render.TextContent,
  target : Int32,
) -> Array[@render.TextRun] {
  let runs : Array[@render.TextRun] = []
  for run in content.runs {
    if run.text == "" {
      continue
    }
    if run.node >= 0 && node_contains(content.nodes, run.node, target) {
      runs.push(run)
    }
  }
  runs
}

///|
fn clean_text(text : String) -> String {
  text.replace(old="\n", new=" ").trim().to_string()
}

///|
fn node_text(content : @render.TextContent, index : Int32) -> String {
  clean_text(@render.join_text(runs_for(content, index)))
}

///|
fn table_markdown(content : @render.TextContent, index : Int32) -> String {
  let cells = @render.table_cells(content, table=index)
  if cells.length() == 0 {
    return ""
  }
  let mut max_row = 0
  let mut max_col = 0
  for cell in cells {
    max_row = Int32::max(max_row, cell.row + cell.rows)
    max_col = Int32::max(max_col, cell.col + cell.cols)
  }
  if max_row == 0 || max_col == 0 {
    return ""
  }
  let grid : Array[Array[String]] = []
  for _ in 0..<max_row {
    let row : Array[String] = []
    for _ in 0..<max_col {
      row.push("")
    }
    grid.push(row)
  }
  for cell in cells {
    if cell.row >= 0 &&
      cell.row < max_row &&
      cell.col >= 0 &&
      cell.col < max_col {
      grid[cell.row][cell.col] = cell.text
        .replace(old="\n", new="<br>")
        .replace(old="|", new="\\|")
    }
  }
  let out = StringBuilder()
  for row in 0..<max_row {
    out.write_string("|")
    for col in 0..<max_col {
      out.write_string(" ")
      out.write_string(grid[row][col])
      out.write_string(" |")
    }
    out.write_string("\n")
    if row == 0 {
      out.write_string("|")
      for _ in 0..<max_col {
        out.write_string(" --- |")
      }
      out.write_string("\n")
    }
  }
  out.to_string()
}

///|
fn render_node(content : @render.TextContent, index : Int32) -> Array[String] {
  let blocks : Array[String] = []
  let node = content.nodes[index]
  match node.kind {
    "heading" => {
      let text = node_text(content, index)
      if text != "" {
        let level = match node.level {
          Some(value) if value >= 1 && value <= 6 => value
          _ => 2
        }
        let marks = StringBuilder()
        for _ in 0..<level {
          marks.write_string("#")
        }
        blocks.push(marks.to_string() + " " + text)
      }
    }
    "paragraph" => {
      let text = node_text(content, index)
      if text != "" {
        blocks.push(text)
      }
    }
    "code" => {
      let text = node_text(content, index)
      if text != "" {
        blocks.push("```\n" + text + "\n```")
      }
    }
    "list" => {
      let marker = match node.list {
        Some(value) if value == "ordered" => "1."
        _ => "-"
      }
      for child in node_children(content.nodes, index) {
        if content.nodes[child].kind == "item" {
          let text = node_text(content, child)
          if text != "" {
            blocks.push(marker + " " + text)
          }
        }
      }
    }
    "table" => {
      let table = table_markdown(content, index)
      if table != "" {
        blocks.push(table)
      }
    }
    "figure" => ()
    "cell" | "item" | "caption" => {
      let text = node_text(content, index)
      if text != "" {
        blocks.push(text)
      }
    }
    _ => {
      let text = node_text(content, index)
      if text != "" {
        blocks.push(text)
      } else {
        for child in node_children(content.nodes, index) {
          for block in render_node(content, child) {
            blocks.push(block)
          }
        }
      }
    }
  }
  blocks
}

///|
fn structured_blocks(content : @render.TextContent) -> Array[String] {
  let blocks : Array[String] = []
  for index, node in content.nodes {
    if node.parent == -1 {
      for block in render_node(content, index) {
        blocks.push(block)
      }
    }
  }
  blocks
}

///|
fn dominant_size(runs : Array[@render.TextRun]) -> Double {
  let sizes : Array[Double] = []
  for run in runs {
    if run.text.trim() != "" {
      sizes.push(run.size)
    }
  }
  if sizes.length() == 0 {
    return 10.0
  }
  sizes.sort()
  sizes[sizes.length() / 2]
}

///|
fn heading_level_for(size : Double, dominant : Double) -> Int32? {
  if dominant <= 0.0 {
    return None
  }
  if size >= dominant * 1.8 {
    Some(1)
  } else if size >= dominant * 1.4 {
    Some(2)
  } else if size >= dominant * 1.18 {
    Some(3)
  } else {
    None
  }
}

///|
fn guess_blocks(content : @render.TextContent) -> Array[String] {
  let runs : Array[@render.TextRun] = []
  for run in content.runs {
    if run.text != "" {
      runs.push(run)
    }
  }
  if runs.length() == 0 {
    return []
  }
  runs.sort_by((a, b) => {
    if (a.y - b.y).abs() > 0.5 {
      a.y.compare(b.y)
    } else {
      a.x.compare(b.x)
    }
  })
  let dominant = dominant_size(runs)
  let blocks : Array[String] = []
  let paragraph = StringBuilder()
  let mut paragraph_open = false
  let mut last_y = 0.0
  let mut last_height = 0.0
  let mut line_start = 0
  while line_start < runs.length() {
    let line_y = runs[line_start].y
    let mut line_size = runs[line_start].size
    let mut line_end = line_start
    while line_end < runs.length() {
      let run = runs[line_end]
      if (run.y - line_y).abs() > Double::max(run.size, line_size) * 0.5 {
        break
      }
      line_size = Double::max(line_size, run.size)
      line_end += 1
    }
    let line_runs : Array[@render.TextRun] = []
    for index in line_start..<line_end {
      line_runs.push(runs[index])
    }
    let text = clean_text(@render.join_text(line_runs))
    if text != "" {
      match heading_level_for(line_size, dominant) {
        Some(level) => {
          if paragraph_open {
            blocks.push(paragraph.to_string())
            paragraph.reset()
            paragraph_open = false
          }
          let marks = StringBuilder()
          for _ in 0..<level {
            marks.write_string("#")
          }
          blocks.push(marks.to_string() + " " + text)
        }
        None => {
          if paragraph_open && line_y - last_y > last_height * 1.8 {
            blocks.push(paragraph.to_string())
            paragraph.reset()
            paragraph_open = false
          }
          if paragraph_open {
            paragraph.write_string(" ")
          }
          paragraph.write_string(text)
          paragraph_open = true
        }
      }
      last_y = line_y
      last_height = line_size
    }
    line_start = line_end
  }
  if paragraph_open {
    blocks.push(paragraph.to_string())
  }
  blocks
}

///|
fn content_blocks(content : @render.TextContent) -> Array[String] {
  let mut has_structure = false
  let mut paragraphs = 0
  for node in content.nodes {
    match node.kind {
      "heading" | "list" | "table" | "figure" | "code" => has_structure = true
      "paragraph" => paragraphs += 1
      _ => ()
    }
  }
  if has_structure || paragraphs > 1 {
    let blocks = structured_blocks(content)
    if blocks.length() > 0 {
      return blocks
    }
  }
  guess_blocks(content)
}

///|
fn front_matter(meta : Json) -> String {
  let dc = match meta.value("dc") {
    Some(value) => value
    None => return ""
  }
  let fields : Array[String] = []
  for key in ["title", "creator", "description", "date", "language"] {
    let value = match dc.value(key) {
      Some(Json::String(text)) => text
      Some(Json::Array(items)) => {
        let parts : Array[String] = []
        for item in items {
          match item {
            Json::String(text) => parts.push(text)
            _ => ()
          }
        }
        parts.join("; ")
      }
      _ => ""
    }
    if value != "" {
      fields.push(key + ": " + value)
    }
  }
  if fields.length() == 0 {
    return ""
  }
  "---\n" + fields.join("\n") + "\n---\n\n"
}

///|
fn view_blocks(
  document : @core.Document,
  view : @core.View,
  options : MarkdownOptions,
  files : Array[MarkdownFile],
  warnings : Array[String],
) -> (Array[String], Int32) raise {
  let blocks : Array[String] = []
  let mut image_count = 0
  let resolve = object_resolver(document)
  if view.kind == "sheet" {
    let runs = @render.view_text_index(
      view,
      hash => read_part(document, hash),
      resolve,
    )
    let text = @core.index_plain_text(runs).trim().to_string()
    if text != "" {
      blocks.push(text)
    }
    return (blocks, 0)
  }
  for page in view.pages {
    for layer in page.layers {
      if role_skipped(options, layer.role) {
        continue
      }
      let resources = @core.decode_object_resources(document.part(layer.object)) catch {
        _ => {
          warnings.push("text layer could not be read")
          continue
        }
      }
      let content = @render.extract_text(resources, resolve) catch {
        _ => {
          warnings.push("text layer could not be extracted")
          continue
        }
      }
      for block in content_blocks(content) {
        blocks.push(block)
      }
      let alts : Array[String] = []
      for node in content.nodes {
        if node.kind == "figure" {
          alts.push(node.alt.unwrap_or(""))
        }
      }
      let images : Array[ImagePlacement] = []
      for
        warning in collect_images(
          document,
          resources,
          (1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
          0,
          images,
        ) {
        warnings.push(warning)
      }
      for index, image in images {
        let alt = if index < alts.length() { alts[index] } else { "" }
        let markdown = image_markdown(
          document,
          image,
          alt,
          options.images,
          files,
          warnings,
        )
        if markdown != "" {
          blocks.push(markdown)
          image_count += 1
        }
      }
    }
  }
  (blocks, image_count)
}

///|
/// Write an opened BDF document as Markdown.
pub fn write_document(
  document : @core.Document,
  options : MarkdownOptions,
) -> MarkdownResult raise {
  let views = selected_views(document, options)
  let blocks : Array[String] = []
  let warnings : Array[String] = []
  let files : Array[MarkdownFile] = []
  let mut image_count = 0
  for view in views {
    if views.length() > 1 {
      let title = if view.title == "" { view.id } else { view.title }
      blocks.push("## " + title)
    }
    let (view_blocks, count) = view_blocks(
      document, view, options, files, warnings,
    )
    image_count += count
    for block in view_blocks {
      blocks.push(block)
    }
  }
  let meta = match @core.manifest_json(document.data).value("meta") {
    Some(value) => value
    None => Json::empty_object()
  }
  let body = blocks.join("\n\n").trim().to_string()
  let markdown = front_matter(meta) +
    body +
    (if body == "" { "" } else { "\n" })
  {
    markdown,
    files,
    warnings,
    views: views.length(),
    images: image_count,
    tables: 0,
  }
}

///|
/// Write a single-file BDF document as Markdown.
pub fn write_bytes(
  data : Bytes,
  options : MarkdownOptions,
) -> MarkdownResult raise {
  write_document(@core.open_single(data), options)
}
