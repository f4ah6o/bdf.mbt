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
