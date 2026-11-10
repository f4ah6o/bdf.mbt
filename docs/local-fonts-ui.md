# Local font UI (viewer)

The viewer can use fonts installed on the visitor's machine through the
[Local Font Access API](https://wicg.github.io/local-font-access/). The UI lives
in `site/assets/local-fonts.js`; the viewer mounts it in
`site/pages/viewer/index.html` and passes the result to the converter.

## Contract with the converter Worker

`converter.convert(bytes, options)` accepts either:

- `options.fonts`: a URL of a font directory (unchanged), or
- `options.fontFiles`: an array of
  `{ name: string, postscriptName: string, bytes: Uint8Array | ArrayBuffer }`.
  `postscriptName` is the face's SFNT name ID 6, sent verbatim so the Worker can
  select exactly one face from a collection. `name` is a sanitized, unique
  internal file name and is not the selector.

The two are mutually exclusive. The viewer never sets `options.fonts`; it adds
`options.fontFiles` only when the visitor has selected at least one face. With
no selection the options are exactly what they were before this UI existed.

`getFontFiles()` returns fresh copies of the selected bytes, so a Worker that
transfers its input cannot detach the selection, and repeated conversions keep
working.

## Behaviour

- Nothing is enumerated on page load. The list is requested only from the
  "ローカルフォントを選ぶ" button, inside the click handler, so the permission
  prompt has a user gesture.
- Before calling `queryLocalFonts()` the UI checks `isSecureContext` and that
  `queryLocalFonts` is a function. Unsupported and insecure contexts get a
  message and no call.
- Faces are listed as native checkboxes in a `fieldset` with a `legend`, each
  with a `<label>`; nothing is checked by default. The status line is a
  `role="status"` live region.
- Bytes are read with `FontData.blob()` only for the checked faces, after the
  visitor presses "選択した書体を使う". A failed read discards the whole batch
  and keeps the previous selection.
- "選択を解除" drops the list and the bytes. A generation counter makes a
  pending query or read stale after a reset, and the buttons are disabled while
  a read is in flight.
- The original font names and bytes stay in page memory. They are not uploaded
  and not separately saved. There is no storage, no network request, no
  analytics and no console output. The page never writes font data to the
  repository.
- Generated BDF or PDF output may embed the selected font data. Clearing the
  selection does not erase font data from documents that were already
  generated.

## Output limitations

The selection is passed to and validated by the converter, but PDF and DOCX do
not use the selected font database. For supported source formats, the generated
BDF, or a PDF later produced from that BDF, may embed the selected font data.
XLSX uses only the first face. A face selected from a TTC
collection may not be safely embeddable in XLSX, so the Worker may reject that
conversion; the UI does not claim that only one TTC face is embedded. CSV,
PPTX and JWW use the selected fonts. The viewer states this next to the control, and repeats the
embedding note in the status line after a conversion that used fonts.

The UI enforces the Worker limits before allocating: at most 64 files, at most
32 MiB per file and at most 64 MiB in total. It checks `blob.size` first, then
the actual `byteLength` after reading. Empty blobs and zero-byte reads are
rejected. A rejected batch keeps the previous selection and says why.

Generated internal names replace control characters (including DEL), are capped
at 255 UTF-16 units including the suffix and extension without splitting a
surrogate pair, and are made distinct when two PostScript names sanitize to the
same value. Each actual `postscriptName` is validated before any `blob()` read:
it must be nonempty, at most 255 UTF-16 code units, free of C0/DEL characters,
and unique across the selected faces. A failure uses a generic no-name message,
keeps the previous selection, and never reports success; the value is never
logged.

## Tests

`node site/local-fonts-test.mjs` serves the module with mocked `FontData` and
`queryLocalFonts` and a synthetic font (an sfnt header plus a marker, not a real
typeface). It covers feature absence, insecure context, permission denial,
explicit selection, no selection, clearing, failed reads, stale results,
keyboard operation, accessible labels, absence of network/storage/console
traffic, and buffer copies. It never queries host fonts or host permissions.

`site/test.mjs` adds one viewer step that mocks `queryLocalFonts`, records the
`convert` messages posted to the Worker, and checks that no selection leaves the
old options untouched while a selection adds exactly one `fontFiles` entry and
no `fonts` URL.
