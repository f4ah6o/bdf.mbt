# Local font UI (viewer)

The viewer can use fonts installed on the visitor's machine through the
[Local Font Access API](https://wicg.github.io/local-font-access/). The UI lives
in `site/assets/local-fonts.js`; the viewer mounts it in
`site/pages/viewer/index.html` and passes the result to the converter.

## Contract with the converter Worker

`converter.convert(bytes, options)` accepts either:

- `options.fonts`: a URL of a font directory (unchanged), or
- `options.fontFiles`: an array of
  `{ name: string, postscriptName?: string, bytes: Uint8Array | ArrayBuffer }`.
  For Local Font Access, `postscriptName` is the face's SFNT name ID 6, sent verbatim so the Worker can
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
- Before the first conversion of a file the visitor opens, a modal asks whether
  to use local fonts. It embeds the same picker, so the query still starts from
  a direct click. "フォントなしで続ける" and Escape fall back to a conversion
  without fonts; unsupported or denied access leaves the same fallback. The
  built-in demo and later conversions in the same page do not ask again, and
  the picker stays available for later changes. The use/skip result belongs to
  the file that opened the dialog; it is not a page-wide flag. Closing the
  dialog by any route settles the shared promise, and a throwing `showModal`
  falls back to conversion. Concurrent selections share the same promise and
  only the newest file converts.
- Before calling `queryLocalFonts()` the UI checks `isSecureContext` and that
  `queryLocalFonts` is a function. Unsupported and insecure contexts get a
  message and no call.
- Faces are listed as native checkboxes in a `fieldset` with a `legend`, each
  with a `<label>`; nothing is checked by default. The status line is a
  `role="status"` live region.
- Search matches the display name, family, style and PostScript name. It does
  not read font bytes, and checked faces remain checked when filtered out.
  The count includes hidden selections; applying reads all checked faces.
- A separate file chooser is available when enumeration is unsupported,
  denied, empty, or undesired. It reads only explicitly selected files and
  enforces the same count and size limits. Its display name is the original
  file name; the internal name is sanitized and made unique. File inputs omit
  `postscriptName`, so the converter loads all readable faces of a collection;
  unlike Local Font Access, this path does not select an individual TTC face.
  Some conversions cannot embed a collection; their existing error applies.
- The list and selected-font summary use the same human-readable name:
  `fullName`, then `family` and `style`, then the PostScript name. This UI
  label is not a unique identifier and is never sent as the internal filename
  or the collection face selector.
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

### Desktop setup

On Linux, macOS and Windows, open the viewer over HTTPS or localhost in a
browser exposing Local Font Access (Chrome documents desktop support from
version 103), then press the list button and grant access if prompted. Search
and select faces, or use the file chooser to select font files available to
you. Support depends on the browser, secure context and permissions, not OS
name; the UI detects the API instead of guessing from the platform. If access
is denied, change the site's browser permission or choose files. These
OS-specific paths have not been verified on physical devices; browser tests
use synthetic metadata and bytes. See [Chrome's API guide](https://developer.chrome.com/docs/capabilities/web-apis/local-fonts).

- **Windows:** Check installed families in Settings → Personalization →
  Fonts. In the viewer, select the desired family from the API list, or use
  the file chooser for an accessible font file.
- **macOS:** Check installed families in Font Book. Select the desired face in
  the API list, or choose an accessible font file with the file chooser.
- **Linux:** Check installed families with your desktop's font manager or
  `fc-list` locally. Select the desired face in the API list, or choose an
  accessible font file with the file chooser. The command's output stays on
  your machine; it is not required by the viewer.

## Output limitations

The viewer does not send `fontFiles` for `.pdf`, `.docx`, `.docm`, `.dotx` or
`.dotm` (case-insensitive), because those formats cannot use the selection. The
direct Worker API still validates explicitly supplied `fontFiles`; the viewer
just avoids sending them. The selection is retained for later supported files. For supported source formats, the generated
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
free of leading or trailing whitespace (the raw value is never trimmed), and
unique across the selected faces. A failure uses a generic no-name message,
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
