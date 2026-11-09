///|
priv struct DrawioCell {
  id : String
  value : String
  mut style : String
  vertex : Bool
  edge : Bool
  parent : String
  source : String
  target : String
  visible : Bool
  mut layer : String
  order : Int
  node : DrawioNode
}

///|
priv struct DrawioModel {
  cells : Array[DrawioCell]
  indexes : Map[String, Int]
  layers : Array[DrawioCell]
  attrs : Map[String, String]
}

///|
fn drawio_cell_from_node(outer : DrawioNode, inner : DrawioNode, order : Int) -> DrawioCell {
  let id = drawio_attr(outer, "id", "")
  let mut value = drawio_attr(inner, "value", "")
  if outer.name == "UserObject" || outer.name == "object" {
    let label = drawio_attr(outer, "label", "")
    if label != "" {
      value = label
    }
  }
  {
    id,
    value,
    style: drawio_attr(inner, "style", ""),
    vertex: drawio_attr(inner, "vertex", "") == "1",
    edge: drawio_attr(inner, "edge", "") == "1",
    parent: drawio_attr(inner, "parent", ""),
    source: drawio_attr(inner, "source", ""),
    target: drawio_attr(inner, "target", ""),
    visible: drawio_attr(inner, "visible", "1") != "0",
    layer: "",
    order,
    node: inner,
  }
}

///|
fn drawio_collect_cells(
  node : DrawioNode,
  cells : Array[DrawioCell],
  indexes : Map[String, Int],
) -> Unit {
  for child in node.children {
    let mut inner : DrawioNode? = None
    if child.name == "mxCell" {
      inner = Some(child)
    } else if child.name == "UserObject" || child.name == "object" {
      inner = drawio_find(child, "mxCell")
    }
    match inner {
      Some(cell_node) => {
        let cell = drawio_cell_from_node(child, cell_node, cells.length())
        if cell.id != "" && !indexes.contains(cell.id) {
          indexes[cell.id] = cells.length()
          cells.push(cell)
        }
        drawio_collect_cells(cell_node, cells, indexes)
      }
      None => {
        drawio_collect_cells(child, cells, indexes)
      }
    }
  }
}

///|
fn drawio_model(diagram : DrawioNode) -> DrawioModel {
  let model = match drawio_find(diagram, "mxGraphModel") {
    Some(value) => value
    None => diagram
  }
  let attrs : Map[String, String] = Map([])
  for key, value in model.attrs {
    attrs[key] = value
  }
  let root = match drawio_find(model, "root") {
    Some(value) => value
    None => model
  }
  let cells : Array[DrawioCell] = []
  let indexes : Map[String, Int] = Map([])
  drawio_collect_cells(root, cells, indexes)
  let layers : Array[DrawioCell] = []
  for index, cell in cells {
    let parent_is_root = cell.parent == "" || cell.parent == "0"
    let parent = indexes.get(cell.parent)
    if parent_is_root && !cell.vertex && !cell.edge {
      layers.push(cell)
    }
    let _ = index
  }
  if layers.is_empty() {
    layers.push({
      id: "",
      value: "",
      style: "",
      vertex: false,
      edge: false,
      parent: "",
      source: "",
      target: "",
      visible: true,
      layer: "",
      order: 0,
      node: root,
    })
  }
  // Resolve each cell's layer by walking up its parent chain.
  for index in 0..<cells.length() {
    let mut current = cells[index]
    let mut layer = ""
    let mut steps = 0
    while current.parent != "" && steps < 256 {
      steps += 1
      match indexes.get(current.parent) {
        Some(parent_index) => {
          let parent = cells[parent_index]
          if parent.parent == "" || parent.parent == "0" {
            layer = parent.id
            break
          }
          current = parent
        }
        None => break
      }
    }
    cells[index].layer = layer
  }
  { cells, indexes, layers, attrs }
}

///|
fn DrawioModel::cell(self : DrawioModel, id : String) -> DrawioCell? {
  match self.indexes.get(id) {
    Some(index) => Some(self.cells[index])
    None => None
  }
}

///|
fn DrawioCell::geometry(self : DrawioCell) -> DrawioNode? {
  drawio_find(self.node, "mxGeometry")
}

///|
fn DrawioCell::x(self : DrawioCell) -> Double {
  match self.geometry() {
    Some(geo) => drawio_num(geo, "x", 0.0)
    None => 0.0
  }
}

///|
fn DrawioCell::y(self : DrawioCell) -> Double {
  match self.geometry() {
    Some(geo) => drawio_num(geo, "y", 0.0)
    None => 0.0
  }
}

///|
fn DrawioCell::width(self : DrawioCell) -> Double {
  match self.geometry() {
    Some(geo) => drawio_num(geo, "width", 0.0)
    None => 0.0
  }
}

///|
fn DrawioCell::height(self : DrawioCell) -> Double {
  match self.geometry() {
    Some(geo) => drawio_num(geo, "height", 0.0)
    None => 0.0
  }
}

///|
fn DrawioModel::origin(self : DrawioModel, cell : DrawioCell) -> (Double, Double) {
  let mut x = 0.0
  let mut y = 0.0
  let mut current = cell
  let mut steps = 0
  while current.parent != "" && current.parent != "0" && steps < 256 {
    steps += 1
    match self.cell(current.parent) {
      Some(parent) => {
        if parent.vertex {
          x += parent.x()
          y += parent.y()
        }
        current = parent
      }
      None => break
    }
  }
  (x + cell.x(), y + cell.y())
}

///|
fn DrawioModel::absolute(self : DrawioModel, cell : DrawioCell) -> (Double, Double, Double, Double) {
  let (x, y) = self.origin(cell)
  (x, y, cell.width(), cell.height())
}

///|
fn DrawioModel::visible(self : DrawioModel, cell : DrawioCell) -> Bool {
  if !cell.visible {
    return false
  }
  let mut current = cell
  let mut steps = 0
  while current.parent != "" && current.parent != "0" && steps < 256 {
    steps += 1
    match self.cell(current.parent) {
      Some(parent) => {
        if !parent.visible {
          return false
        }
        current = parent
      }
      None => break
    }
  }
  true
}
