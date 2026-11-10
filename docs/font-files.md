# Local font bytes in the native converter Worker

The native converter Worker (`bdf_install_native_converter_worker`) accepts
font bytes supplied by the caller through `options.fontFiles`. The existing
`options.fonts` string URL keeps its previous behaviour. Both `convert` and
`open` requests support the new option; the client forwards `options`
unchanged, so no client API change is needed.

## Contract

```js
await converter.convert(data, {
  format: 'csv',
  fontFiles: [
    { name: 'stix.ttf', bytes: ttfBytes },       // Uint8Array
    { name: 'stix.otf', bytes: otfArrayBuffer }, // ArrayBuffer
  ],
});
```

- `fontFiles` is an array of
  `{ name: string, bytes: Uint8Array | ArrayBuffer, postscriptName?: string }`.
- `name` is a non-empty label of at most 255 characters without control
  characters. It labels the font database entry; it is not a path and is never
  fetched.
- `bytes` is a `Uint8Array` (including a view with a non-zero `byteOffset`) or
  an `ArrayBuffer`. Other views, strings, blobs and URLs are rejected.
- `postscriptName` is optional. When absent, the file's readable faces are all
  loaded, preserving explicit file-mode behaviour. When present, it must be a
  non-empty string of at most 255 characters without control characters, and
  exactly one face in that file must have that SFNT name ID 6 (PostScript
  name). Only that face is added to the database. Zero or multiple matches are
  rejected; the Worker never falls back to face 0.
- A missing or `null` `fontFiles` means "no byte-mode fonts". An empty array is
  accepted and behaves like no byte-mode fonts.
- `options.fonts` and a non-empty `options.fontFiles` are mutually exclusive
  only when `options.fonts` is a non-empty string. Supplying both is an error;
  the Worker does not choose one silently. A non-string `options.fonts` value
  keeps the legacy behaviour of being treated as absent, so it does not
  conflict with `fontFiles`.
- Byte mode never fetches. The supplied files are the whole font database for
  that request. URL mode keeps the existing `index.json` directory loader and
  its per-URL cache.

## Ownership and lifecycle

The client posts `options` through the default structured clone. The clone owns
its own copy of every `Uint8Array`/`ArrayBuffer`; the Worker never transfers
these buffers and never detaches or mutates the caller's buffers. The Worker
then copies each accepted byte range once more before parsing, so the font
database does not alias the cloned message. The database is built per request
and dropped when the request finishes; no byte-mode font is cached or shared
between requests. URL mode keeps its existing global directory cache.

A caller that passes an already detached `ArrayBuffer` or `Uint8Array` fails
inside the client's `postMessage` structured clone, before the request reaches
the Worker. That is a caller-side clone error; the Worker cannot return an
indexed `fontFiles[i]` diagnostic for it.

## Validation and limits

The Worker rejects, before conversion starts:

| Condition | Diagnostic |
| --- | --- |
| `fontFiles` is not an array | `fontFiles: expected an array of {name, bytes}` |
| entry is not an object | `fontFiles[i]: expected an object with name and bytes` |
| missing/empty/non-string name | `fontFiles[i]: name must be a non-empty string` |
| name longer than 255 or with control characters | `fontFiles[i]: name must be at most 255 characters without control characters` |
| bytes are not `Uint8Array`/`ArrayBuffer` | `fontFiles[i]: bytes must be a Uint8Array or ArrayBuffer` |
| empty bytes | `fontFiles[i]: bytes must not be empty` |
| more than 64 files | `fontFiles: at most 64 files are supported` |
| one file over 32 MiB | `fontFiles[i]: bytes exceed the 33554432 byte per-file limit` |
| all files over 64 MiB | `fontFiles: total bytes exceed the 67108864 byte limit` |
| no face parses | `fontFiles[i]: no usable font face` |
| a file adds no named face | `fontFiles[i]: no usable font face` |
| a name repeats an earlier entry | `fontFiles[i]: duplicate name` |
| a collection claims more than 256 faces | `fontFiles[i]: collection has more than 256 faces` |
| `postscriptName` is not a non-empty string | `fontFiles[i]: postscriptName must be a non-empty string` |
| `postscriptName` is too long or has control characters | `fontFiles[i]: postscriptName must be at most 255 characters without control characters` |
| no face has that PostScript name | `fontFiles[i]: postscriptName matches no face` |
| more than one face has that PostScript name | `fontFiles[i]: postscriptName matches multiple faces` |
| the same selector appears twice | `fontFiles[i]: duplicate postscriptName` |
| a face is already registered by an earlier entry | `fontFiles[i]: face already added` |
| a collection header is shorter than its claimed face count | `fontFiles[i]: malformed font collection` |
| nonempty string URL and bytes together | `fonts: options.fonts and options.fontFiles cannot both be set` |

Diagnostics use the array index only. They never repeat a supplied name, a
family name, a URL or font data, and the Worker does not log any of these.

## Database contents

Supported byte inputs are SFNT TrueType/OpenType (`.ttf`, `.otf`) and SFNT
collections (`.ttc`, `.otc`). WOFF and WOFF2 are not supported and are rejected
as `fontFiles[i]: no usable font face`.

Without a selector, every accepted file is passed to
`@fontdb.Database::add_file`, which loads all readable faces of an SFNT file or
collection (TTC/OTC). With a selector, the Worker parses the faces, matches
name ID 6 exactly, and adds only the matched face. Names must be unique:
the database keys faces by source name, so a repeated name would silently drop
the later file. The Worker rejects the later entry with
`fontFiles[i]: duplicate name` instead of choosing one, even when the bytes are
identical. Each distinct file must add at least one named face; a file that
parses but has no family name is rejected with
`fontFiles[i]: no usable font face` rather than being skipped because another
file was usable. A collection may contain faces without a family name as long
as at least one face is named.

## Per-format use

The database is passed only to the converters that already accept one. This is
the actual baseline, not a claim that every format uses fonts:

| Format | Font database |
| --- | --- |
| CSV | Receives the database; embeds the faces it uses. |
| PPTX | Receives the database. |
| JWW | Receives the database. |
| HPGL, DXF, SXF, CGM, draw.io | Receive the database (existing behaviour). |
| XLSX | Uses only the first face of the database. A selected face from a TTC/OTC is reconstructed as a standalone single-face SFNT before embedding; if that reconstruction fails, the request is rejected with `xlsx: selected collection face cannot be embedded as a standalone font` before conversion. It never embeds the whole collection for a selected face. |
| PDF | Does not use the database, but the supplied bytes are still validated and parsed into a per-request database before dispatch. |
| DOCX | Does not use the database, but the supplied bytes are still validated and parsed into a per-request database before dispatch. |
| Parquet | Receives the database argument but ignores it; it does not use fonts. |
| Image, AI, TIFF, PSD, EMF, XDW, IDML, Visio, Markdown, HTML, audio | Do not receive the database. |

PDF and DOCX do not use `fontFiles` for layout or embedding, but they do not
ignore the option either: every supplied file is validated and parsed before
dispatch, so invalid bytes still fail and valid bytes still cost CPU and memory
for that request. Bypassing validation for these formats would change the
error semantics and require format detection before the database is built, so
the current behaviour is kept. XLSX embeds at most one face even when several are supplied.
Formats that do not receive the database keep their existing no-font behaviour
and warnings. The cost is bounded by the 64-file, 32 MiB per-file, 64 MiB total
and 256-faces-per-collection limits, but a request that supplies fonts to a
format that does not use them still pays the parse cost.

## Tests

`compat/converter/native-font-files-test.mjs` runs the native Worker in
Chromium and checks, through the public `bdf_create_native_converter` client:

- CSV embedding with a real STIX TTF and OTF (different embedded part hashes);
- a two-face TTC loading both faces;
- `ArrayBuffer` input and a typed-array slice with a non-zero offset
  producing the same embedded face;
- `null` and empty `fontFiles` behaving as absent, and a non-string legacy
  `fonts` value not conflicting with byte mode;
- selecting each face of `bold.ttc` by its real PostScript name, checking the
  embedded font part's name and that only one face is embedded;
- a wrong selector, an empty/non-string selector and duplicate selectors;
- XLSX with a selected TTC face embedding a standalone SFNT whose PostScript
  name is the selected one, and XLSX without a selector keeping the existing
  whole-collection behaviour;
- duplicate names rejected for identical and different valid files, a valid
  SFNT with an empty name table rejected as unusable both alone and after a
  usable file, and a 257-face TTC rejected with the collection limit;
- caller buffers staying attached and unchanged;
- `open` accepting `fontFiles`;
- per-request isolation (a later request without `fontFiles` warns again);
- URL mode still fetching and embedding the same face;
- byte mode making no font requests;
- the validation errors above, including no name leakage;
- PDF output being byte-identical with and without `fontFiles`.
