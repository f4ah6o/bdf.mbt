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

- `fontFiles` is an array of `{ name: string, bytes: Uint8Array | ArrayBuffer }`.
- `name` is a non-empty label of at most 255 characters without control
  characters. It labels the font database entry; it is not a path and is never
  fetched.
- `bytes` is a `Uint8Array` (including a view with a non-zero `byteOffset`) or
  an `ArrayBuffer`. Other views, strings, blobs and URLs are rejected.
- A missing or `null` `fontFiles` means "no byte-mode fonts". An empty array is
  accepted and behaves like no byte-mode fonts.
- `options.fonts` and a non-empty `options.fontFiles` are mutually exclusive.
  Supplying both is an error; the Worker does not choose one silently.
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
| URL and bytes together | `fonts: options.fonts and options.fontFiles cannot both be set` |

Diagnostics use the array index only. They never repeat a supplied name, a
family name, a URL or font data, and the Worker does not log any of these.

## Database contents

Every accepted file is passed to `@fontdb.Database::add_file`, which loads all
readable faces of an SFNT file or collection (TTC/OTC). Names must be unique:
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
| XLSX | Uses only the first face of the database. |
| PDF | Does not receive the database. |
| DOCX | Does not receive the database. |
| Image, AI, TIFF, PSD, EMF, XDW, IDML, Visio, Markdown, HTML, audio, Parquet | Do not receive the database. |

PDF and DOCX therefore ignore `fontFiles`; they do not silently use it. XLSX
embeds at most one face even when several are supplied. Formats that do not
receive the database keep their existing no-font behaviour and warnings.

## Tests

`compat/converter/native-font-files-test.mjs` runs the native Worker in
Chromium and checks, through the public `bdf_create_native_converter` client:

- CSV embedding with a real STIX TTF and OTF (different embedded part hashes);
- a two-face TTC loading both faces;
- `ArrayBuffer` input and a typed-array slice with a non-zero offset
  producing the same embedded face;
- duplicate names rejected for identical and different valid files, and a
  valid SFNT with an empty name table rejected as unusable both alone and
  after a usable file;
- caller buffers staying attached and unchanged;
- `open` accepting `fontFiles`;
- per-request isolation (a later request without `fontFiles` warns again);
- URL mode still fetching and embedding the same face;
- byte mode making no font requests;
- the validation errors above, including no name leakage;
- PDF output being byte-identical with and without `fontFiles`.
