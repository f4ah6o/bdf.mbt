///|
#export_name("xlsx_workbook")
pub fn xlsx_workbook(data : Bytes) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    let sheets = workbook.sheets.map(sheet => {
      Json::array([
        Json::string(sheet.name),
        Json::string(sheet.part),
        Json::boolean(sheet.chart),
        Json::boolean(sheet.hidden),
        Json::number(sheet.index.to_double()),
      ])
    })
    Json::array([
      Json::string(workbook.part),
      Json::boolean(workbook.date1904),
      Json::array(sheets),
      Json::array(workbook.warnings.map(w => Json::string(w))),
    ]).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("xlsx_reference")
pub fn xlsx_reference(text : String, column : Int32) -> String {
  let (col, row, ok) = @xlsx.xlsx_parse_ref(text)
  Json::array([
    Json::number(col.to_double()),
    Json::number(row.to_double()),
    Json::boolean(ok),
    Json::string(@xlsx.xlsx_col_name(column)),
    Json::string(@xlsx.xlsx_decode_string(text)),
  ]).stringify()
}

///|
#export_name("xlsx_strings")
pub fn xlsx_strings(data : Bytes) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    Json::array(workbook.shared_strings().map(s => Json::string(s))).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("xlsx_iso_date")
pub fn xlsx_iso_date(value : String, date1904 : Bool) -> String {
  match @xlsx.xlsx_iso_serial(value, date1904) {
    None => Json::array([Json::number(0.0), Json::boolean(false)]).stringify()
    Some(v) => Json::array([Json::number(v), Json::boolean(true)]).stringify()
  }
}

///|
fn xlsx_row_json(row : @xlsx.XlsxRow) -> Json {
  let cells = row.cells.map(fn(c) {
    Json::array([
      Json::number(c.column.to_double()),
      Json::number(c.style.to_double()),
      Json::number(c.kind.to_double()),
      Json::number(c.number),
      Json::string(c.text),
    ])
  })
  Json::array([
    Json::number(row.index.to_double()),
    Json::number(row.height),
    Json::boolean(row.custom_height),
    Json::boolean(row.hidden),
    Json::number(row.style.to_double()),
    Json::array(cells),
  ])
}

///|
#export_name("xlsx_cells")
pub fn xlsx_cells(data : Bytes, part : String) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    let sheet = workbook.read_sheet_cells(part)
    Json::array([
      Json::array(sheet.rows.map(xlsx_row_json)),
      Json::number(sheet.missing_formula_values.to_double()),
      Json::array(sheet.sorted_rows().map(xlsx_row_json)),
    ]).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("xlsx_range")
pub fn xlsx_range(value : String) -> String {
  match @xlsx.xlsx_parse_range(value) {
    None =>
      Json::array([
        Json::number(0.0),
        Json::number(0.0),
        Json::number(0.0),
        Json::number(0.0),
        Json::boolean(false),
      ]).stringify()
    Some(r) =>
      Json::array([
        Json::number(r.row_start.to_double()),
        Json::number(r.column_start.to_double()),
        Json::number(r.row_end.to_double()),
        Json::number(r.column_end.to_double()),
        Json::boolean(true),
      ]).stringify()
  }
}

///|
fn xlsx_range_json(r : @xlsx.XlsxRange) -> Json {
  Json::array([
    Json::number(r.row_start.to_double()),
    Json::number(r.column_start.to_double()),
    Json::number(r.row_end.to_double()),
    Json::number(r.column_end.to_double()),
  ])
}

///|
#export_name("xlsx_geometry")
pub fn xlsx_geometry(data : Bytes, part : String) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    let s = workbook.read_sheet_geometry(part)
    let cols = s.columns.map(c => {
      Json::array([
        Json::number(c.first.to_double()),
        Json::number(c.last.to_double()),
        Json::number(c.width),
        Json::boolean(c.hidden),
        Json::number(c.style.to_double()),
      ])
    })
    Json::array([
      Json::number(s.default_column_width),
      Json::number(s.base_column_width),
      Json::number(s.default_row_height),
      Json::boolean(s.zero_height),
      Json::boolean(s.show_grid),
      Json::boolean(s.show_zero),
      Json::boolean(s.right_to_left),
      Json::number(s.frozen_columns.to_double()),
      Json::number(s.frozen_rows.to_double()),
      Json::array(cols),
      Json::array(s.merges.map(xlsx_range_json)),
      match s.auto_filter {
        None => Json::null()
        Some(r) => xlsx_range_json(r)
      },
    ]).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("xlsx_styles")
pub fn xlsx_styles(data : Bytes) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    let styles = workbook.styles()
    let fonts = styles.fonts.map(fn(f) {
      let color = f.color
      Json::array([
        Json::string(f.name),
        Json::number(f.size),
        Json::boolean(f.bold),
        Json::boolean(f.italic),
        Json::string(f.underline),
        Json::boolean(f.strike),
        Json::number(color.kind.to_double()),
        Json::number(((color.rgb >> 16) & 255U).to_double() / 255.0),
        Json::number(((color.rgb >> 8) & 255U).to_double() / 255.0),
        Json::number((color.rgb & 255U).to_double() / 255.0),
        Json::number(color.index.to_double()),
        Json::number(color.tint),
        Json::string(f.vertical),
        Json::string(f.scheme),
        Json::number(f.family.to_double()),
      ])
    })
    let ids : Array[Int32] = []
    for id, _ in styles.number_formats {
      ids.push(id)
    }
    ids.sort()
    let formats = ids.map(id => {
      Json::array([
        Json::number(id.to_double()),
        Json::string(styles.number_formats[id]),
      ])
    })
    let xfs = styles.cell_formats.map(fn(x) {
      let a = x.alignment
      Json::array([
        Json::number(x.number_format.to_double()),
        Json::number(x.font.to_double()),
        Json::number(x.fill.to_double()),
        Json::number(x.border.to_double()),
        Json::string(a.horizontal),
        Json::string(a.vertical),
        Json::boolean(a.wrap),
        Json::boolean(a.shrink),
        Json::number(a.indent.to_double()),
        Json::number(a.rotation.to_double()),
        Json::boolean(a.justify_last),
      ])
    })
    Json::array([Json::array(fonts), Json::array(formats), Json::array(xfs)]).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("xlsx_general")
pub fn xlsx_general(value : Double, width : Int32) -> String {
  @xlsx.xlsx_format_general(value, width)
}

///|
#export_name("xlsx_builtin")
pub fn xlsx_builtin(id : Int32, locale : String) -> String {
  @xlsx.xlsx_builtin_format(id, locale)
}

///|
#export_name("xlsx_format_sections")
pub fn xlsx_format_sections(code : String) -> String {
  Json::array(@xlsx.xlsx_split_format_sections(code).map(Json::string)).stringify()
}

///|
#export_name("xlsx_parse_format")
pub fn xlsx_parse_format(code : String) -> String {
  let sections = @xlsx.xlsx_parse_number_format(
    code,
    @xlsx.xlsx_default_palette(),
  )
  Json::array(
    sections.map(fn(section) {
      let tokens = section.tokens.map(fn(token) {
        Json::array([
          Json::number(token.kind.to_double()),
          Json::string(token.text),
        ])
      })
      Json::array([
        Json::array(tokens),
        match section.color {
          Some(color) => Json::number(color.to_double())
          None => Json::null()
        },
        Json::string(section.condition_operator),
        Json::number(section.condition_value),
        Json::boolean(section.date),
        Json::boolean(section.text),
        Json::string(section.locale),
        Json::number(section.dbnum.to_double()),
      ])
    }),
  ).stringify()
}

///|
#export_name("xlsx_select_format")
pub fn xlsx_select_format(code : String, value : Double) -> String {
  let sections = @xlsx.xlsx_parse_number_format(
    code,
    @xlsx.xlsx_default_palette(),
  )
  let (index, unsigned) = @xlsx.xlsx_select_format_section(sections, value)
  Json::array([Json::number(index.to_double()), Json::boolean(unsigned)]).stringify()
}

///|
#export_name("xlsx_format_layouts")
pub fn xlsx_format_layouts(code : String) -> String {
  let sections = @xlsx.xlsx_parse_number_format(
    code,
    @xlsx.xlsx_default_palette(),
  )
  Json::array(
    sections.map(fn(section) {
      let layout = @xlsx.xlsx_analyze_number_format(section)
      Json::array([
        Json::string(layout.integer),
        Json::string(layout.fraction_digits),
        Json::boolean(layout.point),
        Json::boolean(layout.thousands),
        Json::number(layout.scale.to_double()),
        Json::number(layout.percent.to_double()),
        Json::string(layout.exponent),
        Json::string(layout.exponent_digits),
        Json::string(layout.numerator),
        Json::string(layout.denominator),
        Json::number(layout.fixed_denominator.to_double()),
        Json::boolean(layout.fraction),
        Json::boolean(layout.general),
      ])
    }),
  ).stringify()
}

///|
#export_name("xlsx_numeric")
pub fn xlsx_numeric(code : String, value : Double) -> String {
  let sections = @xlsx.xlsx_parse_number_format(
    code,
    @xlsx.xlsx_default_palette(),
  )
  let (pieces, general) = @xlsx.xlsx_format_numeric(sections[0], value)
  Json::array([
    Json::array(
      pieces.map(fn(piece) {
        Json::array([
          Json::number(piece.kind.to_double()),
          Json::string(piece.text),
        ])
      }),
    ),
    Json::boolean(general),
  ]).stringify()
}

///|
#export_name("xlsx_date_format")
pub fn xlsx_date_format(
  code : String,
  value : Double,
  date1904 : Bool,
) -> String {
  let sections = @xlsx.xlsx_parse_number_format(
    code,
    @xlsx.xlsx_default_palette(),
  )
  let pieces = @xlsx.xlsx_format_date(sections[0], value, date1904)
  Json::array([
    match pieces {
      Some(pieces) =>
        Json::array(
          pieces.map(fn(piece) {
            Json::array([
              Json::number(piece.kind.to_double()),
              Json::string(piece.text),
            ])
          }),
        )
      None => Json::array([])
    },
    Json::boolean(pieces is Some(_)),
  ]).stringify()
}

///|
fn xlsx_formatted_json(result : @xlsx.XlsxFormatted) -> String {
  Json::array([
    Json::array(
      result.pieces.map(fn(piece) {
        Json::array([
          Json::number(piece.kind.to_double()),
          Json::string(piece.text),
        ])
      }),
    ),
    match result.color {
      Some(c) => Json::number(c.to_double())
      None => Json::null()
    },
    Json::boolean(result.general),
    Json::boolean(result.number),
  ]).stringify()
}

///|
#export_name("xlsx_formatted_number")
pub fn xlsx_formatted_number(
  code : String,
  value : Double,
  date1904 : Bool,
) -> String {
  let sections = @xlsx.xlsx_parse_number_format(
    code,
    @xlsx.xlsx_default_palette(),
  )
  xlsx_formatted_json(@xlsx.xlsx_format_number(sections, value, date1904))
}

///|
#export_name("xlsx_formatted_text")
pub fn xlsx_formatted_text(code : String, value : String) -> String {
  let sections = @xlsx.xlsx_parse_number_format(
    code,
    @xlsx.xlsx_default_palette(),
  )
  xlsx_formatted_json(@xlsx.xlsx_format_text(sections, value))
}

///|
#export_name("xlsx_display")
pub fn xlsx_display(data : Bytes, part : String, locale : String) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    let styles = workbook.styles()
    let sheet = workbook.read_sheet_cells(part)
    let rows = sheet.rows.map(fn(row) {
      Json::array(
        row.cells.map(fn(cell) {
          match styles.format_cell(cell, workbook.date1904, locale) {
            None => Json::null()
            Some(result) =>
              @json.parse(xlsx_formatted_json(result)) catch {
                _ => Json::null()
              }
          }
        }),
      )
    })
    Json::array([
      Json::array(styles.palette.map(x => Json::number(x.to_double()))),
      Json::array(rows),
    ]).stringify()
  } catch {
    _ => "null"
  }
}

///|
#export_name("xlsx_layout")
pub fn xlsx_layout(
  data : Bytes,
  part : String,
  mdw : Double,
  line : Double,
) -> String {
  try {
    let workbook = @xlsx.read_xlsx_workbook(data)
    let cells = workbook.read_sheet_cells(part)
    let geometry = workbook.read_sheet_geometry(part)
    let (rows, columns) = @xlsx.xlsx_initial_extent(cells, geometry, [])
    let runs = @xlsx.xlsx_column_runs(geometry, columns, mdw)
    let sorted = cells.sorted_rows()
    let fitted : Map[Int32, Double] = Map([])
    for row in sorted {
      if row.index % 3 == 0 {
        fitted[row.index] = 22.5 + (row.index % 5).to_double() * 1.5
      }
    }
    let row_runs = @xlsx.xlsx_row_runs(sorted, geometry, rows, line, fitted)
    Json::array([
      Json::number(rows.to_double()),
      Json::number(columns.to_double()),
      Json::array(
        runs.map(fn(run) {
          Json::array([
            Json::number(run.count.to_double()),
            Json::number(run.size.to_double()),
          ])
        }),
      ),
      Json::array(
        row_runs.map(fn(run) {
          Json::array([
            Json::number(run.count.to_double()),
            Json::number(run.size.to_double()),
          ])
        }),
      ),
    ]).stringify()
  } catch {
    _ => "null"
  }
}

///|
fn xlsx_paint_color(c : @xlsx.XlsxColor) -> Json {
  Json::array([
    Json::number(c.kind.to_double()),
    Json::number(c.rgb.to_double()),
    Json::number(c.index.to_double()),
    Json::number(c.tint),
  ])
}

///|
fn xlsx_paint_side(s : @xlsx.XlsxBorderSide) -> Json {
  Json::array([Json::string(s.style), xlsx_paint_color(s.color)])
}

///|
#export_name("xlsx_paint")
pub fn xlsx_paint(data : Bytes) -> String {
  try {
    let styles = @xlsx.read_xlsx_workbook(data).styles()
    let fills = styles.fills.map(fn(f) {
      let gradient = match f.gradient {
        None => Json::null()
        Some(g) =>
          Json::array([
            Json::boolean(g.path),
            Json::number(g.degree),
            Json::number(g.left),
            Json::number(g.right),
            Json::number(g.top),
            Json::number(g.bottom),
            Json::array(
              g.stops.map(fn(s) {
                Json::array([
                  Json::number(s.position),
                  xlsx_paint_color(s.color),
                ])
              }),
            ),
          ])
      }
      Json::array([
        Json::string(f.pattern),
        xlsx_paint_color(f.foreground),
        xlsx_paint_color(f.background),
        gradient,
      ])
    })
    let borders = styles.borders.map(fn(b) {
      Json::array([
        xlsx_paint_side(b.left),
        xlsx_paint_side(b.right),
        xlsx_paint_side(b.top),
        xlsx_paint_side(b.bottom),
        xlsx_paint_side(b.diagonal),
        Json::boolean(b.diagonal_up),
        Json::boolean(b.diagonal_down),
        xlsx_paint_side(b.vertical),
        xlsx_paint_side(b.horizontal),
      ])
    })
    Json::array([Json::array(fills), Json::array(borders)]).stringify()
  } catch {
    _ => "null"
  }
}
