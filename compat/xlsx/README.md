# XLSX compatibility fixtures

`verify-workbook.mjs` compares workbook part resolution, date system, worksheet
and chart sheet references, visibility, ordering and unsupported-sheet warnings
against upstream. `verify-reference.mjs` checks cell references, column names
and Excel string escapes; `verify-strings.mjs` covers shared strings; `verify-cells.mjs` checks worksheet
rows and cells; `verify-date.mjs` checks ISO date serials;
`verify-geometry.mjs` and `verify-range.mjs` check worksheet layout. The cases include seven real workbooks and generated packages.

After building the JavaScript target, run `node compat/xlsx/verify-workbook.mjs` `node compat/xlsx/verify-reference.mjs`, `node compat/xlsx/verify-strings.mjs`,
`node compat/xlsx/verify-cells.mjs`, `node compat/xlsx/verify-date.mjs`,
`node compat/xlsx/verify-range.mjs` and `node compat/xlsx/verify-geometry.mjs`.
To regenerate fixtures, copy `generate_workbook_test.go` without its build tag
into upstream `converter/xlsx` and run `TestCodexXLSXWorkbook` with
`BDF_FIXTURE_ROOT` set to this repository.
