# Notices

## This package

This package (`bdf.mbt`, MIT, see `LICENSE`) ships prebuilt JavaScript
bundles of the bdf.mbt MoonBit sources: the browser/viewer API, the render and
converter Workers, the form page API, the raw DocuWorks export, and the
versioned file format plugin API with its DocuWorks builtin adapter.

## Upstream lineage

- The BDF document format and converter lineage this port tracks is
  Yoshiki Shibukawa's bdf project (MIT, `licenses/Shibukawa-bdf.txt`).
  See https://github.com/shibukawa/bdf
- The DocuWorks converter was developed against public DocuWorks sample
  documents from the EZPZ File corpus (MIT, `licenses/EZPZFile-xdw.txt`).
  This package ships no sample documents.

## Third-party code and data compiled into the shipped bundles

The inclusion set below was verified against each bundle's link inputs (the
`.rsp` files the moon build emits), not estimated. The shipped JavaScript
contains the compiled code and data of these packages; full copyright and
license texts ship alongside this notice in `licenses/`.

### Ports carried by bdf.mbt's own sources

| File | What it covers in the bundles |
| --- | --- |
| `licenses/Go-x-image.txt` | BSD-style license of golang.org/x/image; the CCITT fax tables adapted into the PDF image filter (`convert/pdf/ccitt.mbt` in the source), Copyright 2019 The Go Authors |
| `licenses/Go-x-text.txt` | BSD-style license of golang.org/x/text; the shaping and text processing algorithms it carries, Copyright 2009 The Go Authors |
| `licenses/WHATWG-Encoding.txt` | The WHATWG Encoding Standard material (Apple, Google, Mozilla, Microsoft) behind the encoding label system of the CSV text decoders; the BSD-3-Clause applies to portions in code, see the text |
| `licenses/Adobe-CMap.txt` | Adobe's predefined CMaps (cmap-resources), Copyright 1990-2015 Adobe Systems Incorporated; the compressed CMap data embedded in the PDF text layer (`convert/pdf/cjk_data_generated.mbt` in the source) is generated from them |
| `licenses/Cephes.txt` | Cephes Math Library notices by Stephen L. Moshier, as carried by the Go standard library maths |

### Compiled MoonBit dependencies

The packages below are installed MoonBit dependencies compiled into the
shipped bundles (all Apache-2.0 unless the table says otherwise; their
manifests declare Apache-2.0 even where the distribution carries no separate
LICENSE file, so the common `licenses/Apache-2.0.txt` text is applied together
with this attribution table):

| Package (version) | Used for | License text |
| --- | --- | --- |
| `gaato/deflate@0.1.0` | DEFLATE/zlib paths | `licenses/Apache-2.0.txt` |
| `gaato/brotli@0.4.1` | brotli decompression; the embedded RFC 7932 static dictionary is Copyright (c) 2009, 2010, 2013-2016 by the Brotli Authors | `licenses/Apache-2.0.txt`, `licenses/Brotli-dictionary-MIT.txt` |
| `gaato/codec@0.1.0`, `gaato/codec_bytes@0.1.1` | shared decoding | `licenses/Apache-2.0.txt` |
| `gaato/zstd@0.3.1` | zstd decompression; its NOTICE (test frames and vectors, `licenses/Mooncake-gaato-zstd-NOTICE.txt`) is shipped in full for attribution although those specific test artifacts are not part of these bundles | `licenses/Apache-2.0.txt`, `licenses/Mooncake-gaato-zstd-NOTICE.txt` |
| `Milky2018/xml@0.6.1` | XML parsing (OOXML, SVG, IDML, ...) | `licenses/Apache-2.0.txt` |
| `LL728/moon_encoding@0.2.0` | text encodings; WHATWG-licensed code portions | `licenses/Apache-2.0.txt`, `licenses/Mooncake-moon-encoding-WHATWG.txt` |
| `moonbit-community/normalization@0.5.2` | Unicode NFC/NFD/NFKC/NFKD | `licenses/Apache-2.0.txt` |
| `moonbit-community/ucd@0.5.2` | Unicode 16.0.0 Character Database data | `licenses/Apache-2.0.txt` |
| `moonbit-community/yaml@0.0.8` | YAML reading; appears in the form bundle's link inputs | `licenses/Mooncake-yaml-MIT.txt` (MIT, International Digital Economy Academy) |
| `oilleelssq-wq/moonmarkdown@0.2.0` | Markdown conversion | `licenses/Mooncake-moonmarkdown-MIT.txt` (MIT), `licenses/Mooncake-moonmarkdown-THIRD-PARTY-NOTICES.txt` |
| `allenli178/moon-qrcode@0.2.0` | QR decoding in the form page API bundle | `licenses/Apache-2.0.txt` |
| `moonbitlang/async@0.22.5` | async runtime of the browser and worker bundles | `licenses/Apache-2.0.txt` |
| `moonbitlang/x@0.5.5` (`crypto`) | crypto helpers linked into the bundles | `licenses/Apache-2.0.txt` |
| `moonbitlang/core` (standard library, compiled into every bundle) | the standard library itself, and its own third-party attributions: V8-derived `double` routines (V8 project authors), fdlibm-adapted maths (Copyright (C) 1993 by Sun Microsystems, Inc.), Go-derived strconv/bigint/random (`Copyright 2009 The Go Authors`), FreeBSD `msun`-style notices, musl-derived bits | `licenses/Apache-2.0.txt`, `licenses/MoonBit-core-NOTICE.txt` |

## Intentional exclusions

- Test corpora, fixtures, source maps and local paths are excluded from
  this package; `plugin/tools/library-pack.mjs` in the source repository
  enforces the allowlist at pack time.
- This package carries no private or proprietary converter code. Builtin
  DocuWorks ships as the same public plugin contract any third party
  implements; proprietary adapters stay outside this package.
