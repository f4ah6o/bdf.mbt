///|
test "xdw samples convert and reopen" {
  for f in xdw_fixtures {
    let b = @base64.decode(f.1)
    let result = xdw_convert(b) catch {
      e => abort("convert {f.0}: " + e.to_string())
    }
    guard result.pages > 0 else {
      abort("convert {f.0}: no pages")
    }
    let opened = @core.open_single(result.bdf) catch {
      error => abort("reopen {f.0}: " + error.to_string())
    }
    ignore(opened)
  }
}
