# Notices

## This package

The file format plugin API and the DocuWorks adapter are part of the
bdf-format-plugin repository (MIT, `LICENSE`). The full design, boundaries
and trust model are documented in `docs/format-plugin-api.md`.

## Upstream lineage

- The BDF document format and converter lineage this port tracks is
  Yoshiki Shibukawa's bdf project
  (MIT, `licenses/Shibukawa-bdf.txt` in the repository). See
  https://github.com/shibukawa/bdf
- The DocuWorks converter in `convert/xdw` was developed against public
  DocuWorks sample documents from the EZPZ File corpus
  (MIT, `licenses/EZPZFile-xdw.txt` in the repository). This package ships
  no sample documents.

## Intentional exclusions

- Test corpora, fixtures and local paths are excluded from the staged
  package by `plugin/tools/pack.mjs`; source maps are never shipped.
