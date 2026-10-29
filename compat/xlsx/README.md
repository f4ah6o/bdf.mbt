# XLSX compatibility fixtures

`verify-workbook.mjs` compares workbook part resolution, date system, worksheet
and chart sheet references, visibility, ordering and unsupported-sheet warnings
against upstream. `verify-reference.mjs` checks cell references, column names
and Excel string escapes; `verify-strings.mjs` covers shared strings. The cases include seven real workbooks and generated packages.

After building the JavaScript target, run `node compat/xlsx/verify-workbook.mjs` `node compat/xlsx/verify-reference.mjs` and `node compat/xlsx/verify-strings.mjs`.
To regenerate fixtures, copy `generate_workbook_test.go` without its build tag
into upstream `converter/xlsx` and run `TestCodexXLSXWorkbook` with
`BDF_FIXTURE_ROOT` set to this repository.
