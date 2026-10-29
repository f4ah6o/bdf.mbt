# XLSX compatibility fixtures

`verify-workbook.mjs` compares workbook part resolution, date system, worksheet
and chart sheet references, visibility, ordering and unsupported-sheet warnings
against upstream. The cases include seven real workbooks and generated packages.

After building the JavaScript target, run `node compat/xlsx/verify-workbook.mjs`.
To regenerate fixtures, copy `generate_workbook_test.go` without its build tag
into upstream `converter/xlsx` and run `TestCodexXLSXWorkbook` with
`BDF_FIXTURE_ROOT` set to this repository.
