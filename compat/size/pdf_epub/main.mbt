///|
/// The PDF and EPUB converters, the same two formats as the upstream
/// `@bdfkit/convert-pdf-epub` Wasm preset. Every conversion entry point is
/// referenced from `main` so the linker keeps its code; the program is never
/// run. See `compat/size/README.md`.
fn main {
  let data : Bytes = b""
  ignore(@pdf.convert(data)) catch {
    _ => ()
  }
  ignore(@epub.convert(data)) catch {
    _ => ()
  }
}
