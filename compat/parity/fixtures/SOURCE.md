# Parity fixtures

The files under this directory are the upstream `converter/<format>/testdata`
fixtures of [shibukawa/bdf](https://github.com/shibukawa/bdf) at commit
`a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22`, distributed under the MIT
license (see `licenses/Shibukawa-bdf.txt`).

- `pdf/`: `converter/pdf/testdata`
- `docx/`: `converter/docx/testdata`, including `fonts/`
- `pptx/`: `converter/pptx/testdata`, including `fonts/`
- `xlsx/`: `converter/xlsx/testdata`
- `markdown/`: `converter/markdown/testdata`, including `images/`

They are copied verbatim. The font files keep their own licenses (SIL Open
Font License 1.1) beside them. Do not edit a fixture: regenerate it from the
upstream checkout and copy it again.
