# Port status

## Green gates

- `moon check --target js`
- `moon test --target js`
- `moon build --target js`
- `moon check --target wasm-gc`
- `moon test --target wasm-gc`
- `moon build --target wasm-gc`
- `npm run build:demo`
- `npm run test:demo`

## README Port backlog

- Done: opset 1 Canvas decoder, browser renderer and resource checks.
- Done: viewer `openFile` integration and PDF/DOCX/PPTX page streams.
- Done: DOM/OffscreenCanvas viewer, lazy pages, sheets, search, ARIA and MIDI.
- Done: MoonBit converters for the demo format set (PDF, DOCX, PPTX, XLSX,
  CSV, image, font, MIDI/MML/MusicXML, HPGL).
- Remaining: cryptography on non-JavaScript hosts. PBKDF2-HMAC-SHA-256 and
  AES-KW are in `crypto`; AES-GCM, ECDH and encrypted-document unlock are still
  to be integrated.

## Converter gaps

- PDF: Type1 `/FontFile` programs still use the system-font fallback; bare CFF
  programs are wrapped as OpenType. Tiling patterns, JPX/JBIG2/CCITT images,
  form-field actions and encrypted PDFs are not supported.
- DOCX/PPTX: the converters intentionally implement the documented subsets.
  Unsupported features fail closed or are documented in `compat/docx` and
  `compat/pptx`.
- Upstream-only formats outside the demo set (for example EPUB, DXF, Visio,
  CGM, Markdown and HTML) are not ported.

## Next steps

1. Implement AES-GCM and ECDH, then wire password/ECDH unlocking into
   `core.open_encrypted_single`-based readers without a browser dependency.
2. Port Type1 font programs to CFF so `/FontFile` fonts embed natively.
3. Continue closing the documented converter subsets only where a source
   fixture can be compared with upstream.
