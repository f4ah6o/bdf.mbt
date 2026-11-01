///|
/// The formats of the upstream `@bdfkit/convert-office` Wasm preset that this
/// port converts (all of them but Parquet input). The conversion entry points
/// are referenced from `main` so the linker keeps their code; the program is
/// never run. See `compat/size/README.md`.
fn main {
  let data : Bytes = b""
  let database = @fontdb.Database::new()
  ignore(@csv.convert_with_fonts(data, database)) catch {
    _ => ()
  }
  ignore(@docx.convert(data)) catch {
    _ => ()
  }
  ignore(@epub.convert(data)) catch {
    _ => ()
  }
  ignore(@idml.convert(data)) catch {
    _ => ()
  }
  ignore(@pdf.convert(data)) catch {
    _ => ()
  }
  ignore(@pptx.convert(data)) catch {
    _ => ()
  }
  ignore(@visio.convert(data)) catch {
    _ => ()
  }
  ignore(@xlsx.convert_plain_no_fonts(data)) catch {
    _ => ()
  }
}
