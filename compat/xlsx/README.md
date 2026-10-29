# XLSX compatibility fixtures

`verify-workbook.mjs` compares workbook part resolution, date system, worksheet
and chart sheet references, visibility, ordering and unsupported-sheet warnings
against upstream. `verify-reference.mjs` checks cell references, column names
and Excel string escapes; `verify-strings.mjs` covers shared strings; `verify-cells.mjs` checks worksheet
rows and cells; `verify-date.mjs` checks ISO date serials;
`verify-geometry.mjs` and `verify-range.mjs` check worksheet layout; `verify-styles.mjs` checks fonts and cell formats; `verify-general.mjs` checks General number formatting; `verify-builtin.mjs` and `verify-sections.mjs` check built-in formats and section splitting; `verify-formats.mjs` checks format tokens, conditions, colors, section selection and numeric layout; `verify-numeric.mjs` compares numeric output pieces; `verify-date-format.mjs` and `verify-formatted.mjs` check date, number and text cell formatting; `verify-display.mjs` checks workbook cells and indexed color palettes; `verify-layout.mjs` checks initial extents and row/column runs using supplied fitted heights; `verify-paint.mjs` checks fills, gradients and borders; `verify-color.mjs` checks color resolution and tinting; `verify-locale.mjs` checks document metadata and workbook locale inference; `verify-table-values.mjs` checks used ranges, encoded Parquet tables and BDF table manifests; `verify-list-tables.mjs` checks worksheet ListObject references; `verify-store-sheet.mjs` checks sheet table storage, modes and warnings; `verify-render.mjs` checks the supported plain-sheet conversion end to end. The General fixture excludes inputs on which the upstream formatter recurses indefinitely. The cases include seven real workbooks and generated packages.

After building the JavaScript target, run `node compat/xlsx/verify-workbook.mjs` `node compat/xlsx/verify-reference.mjs`, `node compat/xlsx/verify-strings.mjs`,
`node compat/xlsx/verify-cells.mjs`, `node compat/xlsx/verify-date.mjs`,
`node compat/xlsx/verify-range.mjs`, `node compat/xlsx/verify-geometry.mjs`
`node compat/xlsx/verify-styles.mjs`, `node compat/xlsx/verify-general.mjs`, `node compat/xlsx/verify-builtin.mjs`, `node compat/xlsx/verify-sections.mjs`, `node compat/xlsx/verify-formats.mjs`, `node compat/xlsx/verify-numeric.mjs`, `node compat/xlsx/verify-date-format.mjs`, `node compat/xlsx/verify-formatted.mjs`, `node compat/xlsx/verify-display.mjs`, `node compat/xlsx/verify-layout.mjs`, `node compat/xlsx/verify-paint.mjs`, `node compat/xlsx/verify-color.mjs`, `node compat/xlsx/verify-locale.mjs`, `node compat/xlsx/verify-table-values.mjs`, `node compat/xlsx/verify-list-tables.mjs`, `node compat/xlsx/verify-store-sheet.mjs`, and `node compat/xlsx/verify-render.mjs`.
`npm run test:xlsx-compat` runs the complete XLSX and OOXML fixture suite; it is
also included in `npm run test:visual` after the JavaScript build.
The rendering fixtures include the upstream `form-pages.xlsx`, `print.xlsx`,
`form-fixed.xlsx`, and `form-rows.xlsx`
workbooks, along with generated cases for solid fills, colored and dashed
borders (including diagonals and multiple colors at one weight), named and
themed fonts and default font sizes, italic and decorated text, superscripts
and subscripts, merged rectangles, center-across-selection, wrapped, indented
and shrink-to-fit text, fixed and automatic row heights, hidden rows and
columns, single unformatted text runs, links, conditional font, solid-fill, and border formats,
row and column styles including solid backgrounds and borders, and
uncached formula warnings. Patterned base fills and complex base borders have
separate rejection cases. The rendering
cases are split into indexed chunks so individual fixture files stay small.
Copy `generate_render_test.go` without its build tag into upstream
`converter/xlsx` and run `TestCodexXLSXRender` to regenerate them.
The base-fill and base-border cases are regenerated separately using
`generate_base_fill_test.go` / `TestCodexBaseFill` and
`generate_base_border_test.go` / `TestCodexBaseBorder`.
Single-run cases use `generate_plain_run_test.go` and `TestCodexPlainRun`.
Link cases use `generate_links_test.go` / `TestCodexLinks` and
`generate_percent_links_test.go` / `TestCodexPercentLinks`.
Inactive conditional-format cases use `generate_inactive_cf_test.go` and
`TestCodexInactiveCF`.
Conditional-font cases use `generate_active_cf_test.go` and `TestCodexActiveCF`.
Conditional-fill cases use `generate_conditional_fill_test.go` and
`TestCodexConditionalFill`.
Conditional-border cases use `generate_conditional_border_test.go` and
`TestCodexConditionalBorder`.
Conditional comparison cases use `generate_conditional_ops_test.go` and
`TestCodexConditionalOps`.
Conditional interval cases use `generate_conditional_between_test.go` and
`TestCodexConditionalBetween`.
Conditional formula prefix cases use `generate_conditional_equals_test.go` and
`TestCodexConditionalEquals`.
Conditional font cases matching blank cells use `generate_conditional_blank_test.go`
and `TestCodexConditionalBlank`.
Blank-cell paint cases use `generate_conditional_paint_blank_test.go` and
`TestCodexConditionalPaintBlank`.
To regenerate fixtures, copy `generate_workbook_test.go` without its build tag
into upstream `converter/xlsx` and run `TestCodexXLSXWorkbook` with
`BDF_FIXTURE_ROOT` set to this repository.
