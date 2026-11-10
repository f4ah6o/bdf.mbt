///|
/// Every format the native converter worker dispatches, in one wasm-gc
/// module. The conversion entry points are referenced from `main` so the
/// linker keeps their code; the program is never run. See
/// `compat/size/README.md`.
fn main {
  let data : Bytes = b""
  let database = @fontdb.Database::new()
  ignore(@ai.convert(data)) catch {
    _ => ()
  }
  ignore(@audio.convert(data)) catch {
    _ => ()
  }
  ignore(@csv.convert_with_fonts(data, database)) catch {
    _ => ()
  }
  ignore(@docx.convert(data)) catch {
    _ => ()
  }
  ignore(@emf.convert(data)) catch {
    _ => ()
  }
  ignore(@font.convert(data, database)) catch {
    _ => ()
  }
  ignore(@html.convert(data)) catch {
    _ => ()
  }
  ignore(@idml.convert(data)) catch {
    _ => ()
  }
  ignore(@image.convert(data)) catch {
    _ => ()
  }
  ignore(@markdown.convert(data)) catch {
    _ => ()
  }
  ignore(@pdf.convert(data)) catch {
    _ => ()
  }
  ignore(@pptx.convert(data)) catch {
    _ => ()
  }
  ignore(@psd.convert(data)) catch {
    _ => ()
  }
  ignore(@tiff.convert(data)) catch {
    _ => ()
  }
  ignore(@visio.convert(data)) catch {
    _ => ()
  }
  ignore(@xlsx.convert_plain_no_fonts(data)) catch {
    _ => ()
  }
  ignore(@hpgl.convert(data)) catch {
    _ => ()
  }
  ignore(@jww.convert(data)) catch {
    _ => ()
  }
  ignore(@dxf.convert(data)) catch {
    _ => ()
  }
  ignore(@sxf.convert(data)) catch {
    _ => ()
  }
  ignore(@cgm.convert(data)) catch {
    _ => ()
  }
  ignore(@drawio.convert(data)) catch {
    _ => ()
  }
  ignore(@parquet.convert(data)) catch {
    _ => ()
  }
}
