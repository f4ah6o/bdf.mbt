///|
/// What a draw.io cell's style asks the converter to draw. The registry is
/// a practical subset of draw.io's shape libraries: the mxGraph core
/// shapes, the draw.io boxes that appear in flowchart, UML and BPMN
/// diagrams, and the stencils that can be approximated by one of them.
/// Everything else falls back to a labelled rectangle (with a warning for
/// unknown stencil names).
priv enum DrawioShapeKind {
  DkRect
  DkRoundedRect
  DkEllipse
  DkDoubleEllipse
  DkRhombus
  DkTriangle
  DkHexagon
  DkStadium
  DkParallelogram
  DkTrapezoid
  DkStep
  DkNote
  DkDocument
  DkCylinder
  DkCube
  DkCloud
  DkActor
  DkUmlActor
  DkCallout
  DkProcess
  DkSwimlane
  DkTable
  DkTableRow
  DkPartialRect
  DkUmlBoundary
  DkUmlEntity
  DkUmlControl
  DkUmlDestroy
  DkUmlLifeline
  DkUmlFrame
  DkUmlState
  DkComponent
  DkModule
  DkLollipop
  DkLine
  DkOctagon
  DkCross
  DkStar
  ///| A `mxgraph.*` stencil drawn from the embedded stencil library.
  DkStencil
  DkText
} derive(Eq, Debug)

///|
/// The `shape=` value of the style, or the bare keyword that draw.io uses
/// for the same purpose (`ellipse`, `rhombus`, `swimlane`, `text`, …).
fn drawio_shape_name(style : String) -> String {
  let shape = drawio_style(style, "shape", "")
  if shape != "" && shape != "1" {
    return shape
  }
  for part in style.split(";") {
    let item = sfc_drawio_trim(part)
    if item != "" && !item.contains("=") && !item.contains(":") {
      return item
    }
  }
  ""
}

///|
/// Whether a shape name belongs to a stencil library (`mxgraph.*`) or is an
/// inline `shape=stencil(...)` definition.
fn drawio_is_stencil_name(name : String) -> Bool {
  name.has_prefix("mxgraph.") || name.has_prefix("stencil(")
}

///|
/// The library part of a stencil name: the parts between `mxgraph` and the
/// shape name joined with `/`, like draw.io's `getBasenameForStencil`.
fn drawio_stencil_library(name : String) -> String {
  if !name.has_prefix("mxgraph.") {
    return ""
  }
  let mut last = -1
  let mut index = 0
  while index < name.length() {
    if name[index].unsafe_to_char() == '.' {
      last = index
    }
    index += 1
  }
  if last <= 8 {
    return ""
  }
  name[8:last].to_owned()
}

///|
/// The last part of a stencil name (`start_1` of
/// `mxgraph.flowchart.start_1`).
fn drawio_stencil_leaf(name : String) -> String {
  let mut last = -1
  let mut index = 0
  while index < name.length() {
    if name[index].unsafe_to_char() == '.' {
      last = index
    }
    index += 1
  }
  if last < 0 || last + 1 >= name.length() {
    return ""
  }
  name[last + 1:].to_owned()
}

///|
/// The shape kind a stencil name maps to, or None for a stencil that is not
/// in the practical registry (the caller then warns and draws a rectangle).
fn drawio_stencil_kind(name : String) -> DrawioShapeKind? {
  let library = drawio_stencil_library(name)
  let leaf = drawio_stencil_leaf(name)
  if library == "" || leaf == "" {
    return None
  }
  if library == "flowchart" {
    if leaf == "process" || leaf == "predefined_process" {
      return Some(DkProcess)
    }
    if leaf == "decision" || leaf == "merge_or_storage" || leaf == "or" ||
      leaf == "or_2" || leaf == "sort" || leaf == "collate" {
      return Some(DkRhombus)
    }
    if leaf == "terminator" || leaf == "start_1" || leaf == "start_2" ||
      leaf == "end_1" || leaf == "end_2" || leaf == "connector" {
      return Some(DkStadium)
    }
    if leaf == "data" || leaf == "manual_input" {
      return Some(DkParallelogram)
    }
    if leaf == "document" || leaf == "multidocument" {
      return Some(DkDocument)
    }
    if leaf == "database" || leaf == "direct_data" || leaf == "sequential_data" {
      return Some(DkCylinder)
    }
    if leaf == "preparation" {
      return Some(DkHexagon)
    }
    if leaf == "display" || leaf == "delay" {
      return Some(DkRoundedRect)
    }
    if leaf == "extract_or_measurement" {
      return Some(DkTriangle)
    }
    if leaf == "summing_junction" {
      return Some(DkEllipse)
    }
    if leaf == "internal_storage" || leaf == "stored_data" || leaf == "card" ||
      leaf == "paper_tape" || leaf == "manual_operation" || leaf == "loop_limit" ||
      leaf == "parallel_mode" || leaf == "transfer" || leaf == "summing_function" ||
      leaf == "off_page_reference" || leaf == "on_page_reference" ||
      leaf == "annotation_1" || leaf == "annotation_2" {
      return Some(DkRect)
    }
    return None
  }
  if library == "basic" {
    if leaf == "rect" {
      return Some(DkRect)
    }
    if leaf == "octagon" || leaf == "octagon2" {
      return Some(DkOctagon)
    }
    if leaf == "cross" || leaf == "cross2" || leaf == "x" {
      return Some(DkCross)
    }
    if leaf == "4_point_star" || leaf == "4_point_star_2" || leaf == "6_point_star" ||
      leaf == "8_point_star" || leaf == "star" {
      return Some(DkStar)
    }
    if leaf == "document" {
      return Some(DkDocument)
    }
    if leaf == "trapezoid" {
      return Some(DkTrapezoid)
    }
    if leaf == "parallelepiped" || leaf == "parallelogram" {
      return Some(DkParallelogram)
    }
    if leaf == "isocube" {
      return Some(DkCube)
    }
    if leaf == "cloud_rect" || leaf == "cloud_callout" {
      return Some(DkCloud)
    }
    if leaf == "rectangular_callout" || leaf == "rounded_rectangular_callout" ||
      leaf == "oval_callout" || leaf == "loud_callout" {
      return Some(DkCallout)
    }
    if leaf == "acute_triangle" || leaf == "orthogonal_triangle" ||
      leaf == "obtuse_triangle" {
      return Some(DkTriangle)
    }
    return None
  }
  if library == "bpmn" {
    if leaf == "gateway" || leaf == "gateway2" || leaf == "gateway_and" ||
      leaf == "gateway_or" || leaf == "gateway_xor_(data)" ||
      leaf == "gateway_xor_(event)" || leaf == "gateway_complex" {
      return Some(DkRhombus)
    }
    if leaf == "task" || leaf == "task2" || leaf == "business_rule_task" ||
      leaf == "manual_task" || leaf == "script_task" || leaf == "service_task" ||
      leaf == "user_task" {
      return Some(DkRoundedRect)
    }
    if leaf == "data" || leaf == "data2" {
      return Some(DkParallelogram)
    }
    if leaf == "swimlane" {
      return Some(DkSwimlane)
    }
    if leaf == "conversation" || leaf == "conversation2" {
      return Some(DkHexagon)
    }
    if leaf == "general_start" {
      return Some(DkEllipse)
    }
    if leaf == "general_end" || leaf == "general_intermediate" ||
      leaf == "message_start" || leaf == "message_end" ||
      leaf == "message_intermediate" || leaf == "timer_start" ||
      leaf == "timer_intermediate" || leaf == "rule_start" ||
      leaf == "rule_intermediate" || leaf == "link_start" || leaf == "link_end" ||
      leaf == "link_intermediate" || leaf == "multiple_start" ||
      leaf == "multiple_end" || leaf == "multiple_intermediate" ||
      leaf == "cancel_end" || leaf == "cancel_intermediate" ||
      leaf == "compensation_end" || leaf == "compensation_intermediate" ||
      leaf == "error_end" || leaf == "error_intermediate" || leaf == "terminate" ||
      leaf == "event" {
      return Some(DkDoubleEllipse)
    }
    if leaf == "shape" || leaf == "sendmarker" || leaf == "ad_hoc" ||
      leaf == "compensation" || leaf == "loop" || leaf == "loop_marker" ||
      leaf == "multiple_instances" || leaf == "marker" {
      return Some(DkRect)
    }
    return None
  }
  if library == "uml" || library == "uml25" {
    if leaf == "actor" {
      return Some(DkUmlActor)
    }
    if leaf == "lifeline" {
      return Some(DkUmlLifeline)
    }
    if leaf == "frame" {
      return Some(DkUmlFrame)
    }
    if leaf == "state" {
      return Some(DkUmlState)
    }
    if leaf == "component" {
      return Some(DkComponent)
    }
    if leaf == "boundary" {
      return Some(DkUmlBoundary)
    }
    if leaf == "entity" {
      return Some(DkUmlEntity)
    }
    if leaf == "control" {
      return Some(DkUmlControl)
    }
    if leaf == "destroy" {
      return Some(DkUmlDestroy)
    }
    if leaf == "package" || leaf == "class" || leaf == "interface" ||
      leaf == "object" || leaf == "use_case" || leaf == "note" {
      return Some(DkRect)
    }
    return None
  }
  if library == "er" {
    if leaf == "entity" || leaf == "weak_entity" {
      return Some(DkRect)
    }
    if leaf == "attribute" {
      return Some(DkEllipse)
    }
    if leaf == "relationship" {
      return Some(DkRhombus)
    }
    return None
  }
  if library == "dfd" {
    if leaf == "process" {
      return Some(DkEllipse)
    }
    if leaf == "data_store" || leaf == "external_entity" || leaf == "external" {
      return Some(DkRect)
    }
    return None
  }
  if library == "c4" {
    if leaf == "person" {
      return Some(DkUmlActor)
    }
    if leaf == "database" {
      return Some(DkCylinder)
    }
    if leaf == "container" || leaf == "component" || leaf == "system" {
      return Some(DkRect)
    }
    return None
  }
  None
}

///|
/// The kind of a core mxGraph/draw.io shape name, before style modifiers.
fn drawio_core_shape_kind(name : String) -> DrawioShapeKind? {
  if name == "" || name == "rectangle" || name == "group" || name == "transparent" {
    return Some(DkRect)
  }
  if name == "label" {
    return Some(DkRect)
  }
  if name == "text" || name == "edgeLabel" || name == "textbox" || name == "labelText" {
    return Some(DkText)
  }
  if name == "image" {
    return Some(DkText)
  }
  if name == "line" || name == "tableLine" {
    return Some(DkLine)
  }
  if name == "ellipse" {
    return Some(DkEllipse)
  }
  if name == "doubleEllipse" {
    return Some(DkDoubleEllipse)
  }
  if name == "rhombus" || name == "decision" {
    return Some(DkRhombus)
  }
  if name == "triangle" {
    return Some(DkTriangle)
  }
  if name == "hexagon" {
    return Some(DkHexagon)
  }
  if name == "stadium" {
    return Some(DkStadium)
  }
  if name == "parallelogram" {
    return Some(DkParallelogram)
  }
  if name == "trapezoid" {
    return Some(DkTrapezoid)
  }
  if name == "step" {
    return Some(DkStep)
  }
  if name == "note" {
    return Some(DkNote)
  }
  if name == "document" {
    return Some(DkDocument)
  }
  if name == "cylinder" || name == "cylinder3" || name == "database" ||
    name == "datastore" || name == "seqDatabase" {
    return Some(DkCylinder)
  }
  if name == "cube" || name == "isoCube" || name == "isoCube2" {
    return Some(DkCube)
  }
  if name == "cloud" {
    return Some(DkCloud)
  }
  if name == "actor" {
    return Some(DkActor)
  }
  if name == "umlActor" || name == "seqActorStick" {
    return Some(DkUmlActor)
  }
  if name == "callout" || name == "wedgeCallout" {
    return Some(DkCallout)
  }
  if name == "process" || name == "process2" {
    return Some(DkProcess)
  }
  if name == "swimlane" {
    return Some(DkSwimlane)
  }
  if name == "table" {
    return Some(DkTable)
  }
  if name == "tableRow" {
    return Some(DkTableRow)
  }
  if name == "partialRectangle" {
    return Some(DkPartialRect)
  }
  if name == "umlBoundary" || name == "seqBoundary" {
    return Some(DkUmlBoundary)
  }
  if name == "umlEntity" || name == "seqEntity" {
    return Some(DkUmlEntity)
  }
  if name == "umlControl" || name == "seqControl" {
    return Some(DkUmlControl)
  }
  if name == "umlDestroy" {
    return Some(DkUmlDestroy)
  }
  if name == "umlLifeline" {
    return Some(DkUmlLifeline)
  }
  if name == "umlFrame" {
    return Some(DkUmlFrame)
  }
  if name == "umlState" {
    return Some(DkUmlState)
  }
  if name == "component" {
    return Some(DkComponent)
  }
  if name == "module" {
    return Some(DkModule)
  }
  if name == "lollipop" || name == "requires" || name == "requiredInterface" ||
    name == "providedRequiredInterface" {
    return Some(DkLollipop)
  }
  None
}

///|
/// Resolve a shape name, warning once for each unknown stencil that has to
/// fall back to a rectangle.
fn drawio_shape_kind(style : String, warn : DrawioWarn) -> DrawioShapeKind {
  let name = drawio_shape_name(style)
  let resolved = match drawio_core_shape_kind(name) {
    Some(kind) => Some(kind)
    None =>
      if drawio_is_stencil_name(name) {
        if drawio_stencil_lookup(name) is Some(_) {
          Some(DkStencil)
        } else {
          drawio_stencil_kind(name)
        }
      } else {
        None
      }
  }
  let base = match resolved {
    Some(kind) => kind
    None => {
      if name.has_prefix("stencil(") {
        warn.once(
          "stencil-inline",
          "drawio: inline shape=stencil(...) definitions are not supported; drawn as a rectangle",
        )
      } else if drawio_is_stencil_name(name) {
        warn.once(
          "stencil:" + name,
          "drawio: stencil \"" + name + "\" is not supported; drawn as a rectangle",
        )
      }
      DkRect
    }
  }
  let rounded = drawio_style(style, "rounded", "") == "1"
  if drawio_style(style, "ellipse", "") == "1" && (base == DkRect || base == DkRoundedRect) {
    DkEllipse
  } else if rounded && (base == DkRect || base == DkSwimlane || base == DkTable) {
    DkRoundedRect
  } else {
    base
  }
}

///|
fn drawio_shape_is_text(kind : DrawioShapeKind) -> Bool {
  kind == DkText
}

///|
/// Whether the label is drawn turned a quarter turn counter-clockwise
/// (`horizontal=0`).
fn drawio_shape_vertical(style : String) -> Bool {
  let horizontal = drawio_style(style, "horizontal", "1")
  horizontal == "0" || horizontal == "false"
}

///|
/// The rotation of a cell's label in degrees: the shape's rotation, turned
/// -90° for vertical labels (mxShape.getTextRotation).
fn drawio_shape_label_rotation(style : String, kind : DrawioShapeKind) -> Double {
  let rotation = if kind == DkLine {
    0.0
  } else {
    drawio_num_from_style(style, "rotation", 0.0)
  }
  if drawio_shape_vertical(style) {
    rotation - 90.0
  } else {
    rotation
  }
}

///|
/// The rectangle a cell's label is laid out in, before rotation: the whole
/// shape for most kinds, the header for a swimlane.
fn drawio_shape_label_rect(
  kind : DrawioShapeKind,
  style : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> (Double, Double, Double, Double) {
  if kind == DkSwimlane {
    let start = Double::min(
      Double::max(drawio_num_from_style(style, "startSize", 40.0), 0.0),
      if drawio_shape_vertical(style) { Double::max(w, 0.0) } else { Double::max(h, 0.0) },
    )
    if start <= 0.0 {
      return (x, y, w, h)
    }
    if drawio_shape_vertical(style) {
      (x, y, start, h)
    } else {
      (x, y, w, start)
    }
  } else if kind == DkTable || kind == DkTableRow {
    (x, y, w, h)
  } else {
    (x, y, w, h)
  }
}

///|
/// The vertices of the polygonal shapes, shared by painting and by edge
/// attachment so that an edge always meets the outline that is drawn.
fn drawio_shape_vertices(
  kind : DrawioShapeKind,
  style : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Array[(Double, Double)] {
  if kind == DkRhombus {
    [
      (x + w / 2.0, y),
      (x + w, y + h / 2.0),
      (x + w / 2.0, y + h),
      (x, y + h / 2.0),
    ]
  } else if kind == DkTriangle {
    let direction = drawio_style(style, "direction", "east")
    if direction == "north" {
      [(x, y + h), (x + w, y + h), (x + w / 2.0, y)]
    } else if direction == "south" {
      [(x, y), (x + w, y), (x + w / 2.0, y + h)]
    } else if direction == "west" {
      [(x + w, y), (x, y + h / 2.0), (x + w, y + h)]
    } else {
      [(x, y), (x + w, y + h / 2.0), (x, y + h)]
    }
  } else if kind == DkHexagon {
    let inset = Double::min(w * 0.2, h / 2.0)
    [
      (x + inset, y),
      (x + w - inset, y),
      (x + w, y + h / 2.0),
      (x + w - inset, y + h),
      (x + inset, y + h),
      (x, y + h / 2.0),
    ]
  } else if kind == DkParallelogram {
    let inset = Double::min(w * 0.2, w / 2.0)
    [(x + inset, y), (x + w, y), (x + w - inset, y + h), (x, y + h)]
  } else if kind == DkTrapezoid {
    let inset = Double::min(w * 0.2, w / 2.0)
    [(x + inset, y), (x + w - inset, y), (x + w, y + h), (x, y + h)]
  } else if kind == DkStep {
    let inset = Double::min(w * 0.2, w / 2.0)
    [
      (x, y),
      (x + w - inset, y),
      (x + w, y + h / 2.0),
      (x + w - inset, y + h),
      (x, y + h),
      (x + inset, y + h / 2.0),
    ]
  } else if kind == DkNote {
    let fold = Double::min(w * 0.2, 14.0)
    [(x, y), (x + w - fold, y), (x + w, y + fold), (x + w, y + h), (x, y + h)]
  } else if kind == DkOctagon {
    let inset = Double::min(w, h) * 0.3
    [
      (x + inset, y),
      (x + w - inset, y),
      (x + w, y + inset),
      (x + w, y + h - inset),
      (x + w - inset, y + h),
      (x + inset, y + h),
      (x, y + h - inset),
      (x, y + inset),
    ]
  } else if kind == DkCross {
    let a = w / 3.0
    let b = h / 3.0
    [
      (x + a, y),
      (x + w - a, y),
      (x + w - a, y + b),
      (x + w, y + b),
      (x + w, y + h - b),
      (x + w - a, y + h - b),
      (x + w - a, y + h),
      (x + a, y + h),
      (x + a, y + h - b),
      (x, y + h - b),
      (x, y + b),
      (x + a, y + b),
    ]
  } else if kind == DkStar {
    let cx = x + w / 2.0
    let cy = y + h / 2.0
    let rx = w / 2.0
    let ry = h / 2.0
    let points : Array[(Double, Double)] = []
    for index in 0..<10 {
      let angle = -3.141592653589793 / 2.0 + index.to_double() * 3.141592653589793 / 5.0
      let scale = if index % 2 == 0 { 1.0 } else { 0.382 }
      points.push((
        cx + @math.cos(angle) * rx * scale,
        cy + @math.sin(angle) * ry * scale,
      ))
    }
    points
  } else {
    [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]
  }
}
