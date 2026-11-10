# Changes

## Unreleased

### Added

- DocuWorks (`.xdw`) documents now carry a text index, so body text and
  annotation text are searchable in the converted BDF.
- `include_hidden` keeps text that a later opaque fill covers; the default
  leaves covered text out. It is reachable as `xdw_convert(include_hidden=)`,
  as `convert(..., params={"include_hidden": "1"})`, and through the browser
  worker's existing `request.options.params.include_hidden`. There is no CLI
  flag for it yet.
- Word (`.docx`) conversions accept a `pages` selection such as `1-3,5,8-`
  and keep only those pages of the page view, in document order; the scroll
  view still holds the whole document. It is reachable as
  `docx_convert(pages=)`, as `form/docx.fill(pages=)`, and through the browser
  worker's existing `request.options.pages`. The page count, summary and text
  index describe the selected pages, and a link to a page left out is dropped.
  An invalid selection is an error, as upstream's `ParsePages` makes it.

### Changed

### Fixed

- EMF text with a Shift_JIS font charset now preserves Japanese characters,
  including searchable body text in DocuWorks documents.

- Covered text is left out of the DocuWorks index only when a fill provably
  hides it. A fill clipped away from the run, a translucent fill, a gradient or
  pattern fill, and an image no longer count as covers.
- DocuWorks index runs keep the ordinal the viewer draws them with, so a search
  hit lands on the right character after an earlier run is left out.
- DocuWorks index runs keep the separator the viewer computes, so phrases that
  span a line break stay searchable.

### Deprecated

### Removed

### Security

### Migration
