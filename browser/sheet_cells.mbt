///|
priv struct SheetCellData {
  view : @core.View
  tiles : Array[@core.Tile]
  cells : Map[String, Array[@render.CellText]]
}

///|
fn sheet_cell_data(
  view : @core.View,
  tiles : Array[@core.Tile],
) -> SheetCellData {
  {
    view,
    tiles: @render.sheet_tiles_in(tiles, [
      {
        x0: -2147483648.0,
        y0: -2147483648.0,
        x1: 2147483647.0,
        y1: 2147483647.0,
      },
    ]),
    cells: Map([]),
  }
}

///|
fn sheet_remember_cells(
  state : SheetCellData,
  tile : @core.Tile,
  content : @render.TextContent,
) -> Unit {
  let key = sheet_tile_key(tile.x, tile.y)
  if state.cells.contains(key) {
    return
  }
  let size = state.view.tile_size
  let runs = [
    for run in content.runs if run.x >= 0.0 &&
    run.x < size &&
    run.y >= 0.0 &&
    run.y < size => run
  ]
  state.cells[key] = @render.table_cells({ ..content, runs, })
}

///|
fn sheet_all_cells(state : SheetCellData) -> Array[@render.CellText] {
  let cells : Array[@render.CellText] = []
  let positions : Map[(Int32, Int32), Int32] = Map([])
  for tile in state.tiles {
    let key = sheet_tile_key(tile.x, tile.y)
    if state.cells.get(key) is Some(part) {
      for cell in part {
        match positions.get((cell.row, cell.col)) {
          None => {
            positions[(cell.row, cell.col)] = cells.length()
            cells.push(cell)
          }
          Some(index) =>
            if cell.text != "" {
              let previous = cells[index]
              cells[index] = {
                ..previous,
                text: if previous.text == "" {
                  cell.text
                } else {
                  previous.text + " " + cell.text
                },
              }
            }
        }
      }
    }
  }
  cells
}

///|
fn sheet_cells_ready(state : SheetCellData) -> Bool {
  state.cells.length() == state.tiles.length()
}

///|
priv struct SheetAxis {
  ends : Array[Int32]
  hidden : Array[Bool]
}

///|
fn sheet_axis(runs : Array[@core.SheetRun]) -> SheetAxis {
  let ends : Array[Int32] = []
  let hidden : Array[Bool] = []
  let mut count = 0
  for run in runs {
    count += run.count
    ends.push(count)
    hidden.push(run.size == 0.0)
  }
  { ends, hidden, }
}

///|
fn SheetAxis::is_hidden(self : SheetAxis, index : Int32) -> Bool {
  if index < 0 {
    return false
  }
  let mut lo = 0
  let mut hi = self.ends.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    if self.ends[mid] <= index {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  lo < self.hidden.length() && self.hidden[lo]
}

///|
fn SheetAxis::length(self : SheetAxis) -> Int32 {
  if self.ends.is_empty() {
    0
  } else {
    self.ends[self.ends.length() - 1]
  }
}

///|
extern "js" fn initialize_sheet_cells(
  container : BrowserHost,
  rows : Int32,
  cols : Int32,
  header_rows : Int32,
  header_cols : Int32,
  ready : () -> Bool,
  sync : () -> Unit,
  load : () -> @js_async.Promise[Unit],
  clipboard : (Int32, Int32, Int32, Int32) -> BrowserClipboard,
) -> Unit =
  #|(container,rows,cols,headerRows,headerCols,ready,sync,load,clipboard) => {
  #| const key=Symbol.for('f4ah6o.bdf.sheetCells'),tableKey=Symbol.for('f4ah6o.bdf.table');let pending;
  #| const doc=container.ownerDocument,styleKey=Symbol.for('f4ah6o.bdf.sheetCellStyle');if(!doc[styleKey]){const style=doc.createElement('style');style.textContent='[data-bdf-cells] .bdfTextLayer span::selection{background:transparent}';doc.head.append(style);doc[styleKey]=style}
  #| const info={sheet:true,anchor:container,layer:container,cells:[],size:0,rows,cols,headerRows,headerCols,ready,sync,clipboard,prepare(){if(ready())return Promise.resolve();if(!pending)pending=Promise.resolve().then(load).then(()=>{pending=undefined;container.ownerDocument.dispatchEvent(new Event('selectionchange'))},error=>{pending=undefined;throw error});return pending}};
  #| container[key]=info;container[tableKey]=info;
  #|}

///|
extern "js" fn add_sheet_cell_metadata(
  container : BrowserHost,
  row : Int32,
  col : Int32,
  rows : Int32,
  cols : Int32,
) -> Unit =
  #|(container,row,col,rows,cols) => container[Symbol.for('f4ah6o.bdf.sheetCells')].cells.push({row,col,rows,cols,box:null,metadata:true})

///|
extern "js" fn clear_sheet_cell_metadata(container : BrowserHost) -> Unit =
  #|(container) => {const info=container[Symbol.for('f4ah6o.bdf.sheetCells')];info.cells=info.cells.filter(cell=>!cell.metadata)}

///|
extern "js" fn sheet_container_is_current(
  host : BrowserHost,
  container : BrowserHost,
) -> Bool =
  #|(host,container) => host[Symbol.for('f4ah6o.bdf.sheet')]?.content===container

///|
extern "js" fn refresh_sheet_selection(host : BrowserHost) -> Unit =
  #|(host) => {const doc=host.ownerDocument,sel=doc.getSelection();if(sel?.anchorNode&&host.contains(sel.anchorNode))doc.dispatchEvent(new doc.defaultView.Event('selectionchange'))}
