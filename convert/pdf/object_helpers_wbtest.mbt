///|
// Dictionaries are unordered in PDF. Normalize them for comparison with
// pdfcpu's map while retaining byte-exact keys and recursively nested values.
fn normalize_pdf_object(value : PdfObject) -> PdfObject {
  match value {
    PdfArray(items) =>
      PdfArray([ for item in items => normalize_pdf_object(item) ])
    PdfDict(items) => {
      let entries : Array[(Bytes, PdfObject)] = [
        for (key, item) in items => (key, normalize_pdf_object(item))
      ]
      entries.sort_by((left, right) => {
        let a = left.0
        let b = right.0
        let mut comparison = 0
        for i in 0..<Int32::min(a.length(), b.length()) {
          if a[i] != b[i] {
            comparison = a[i].to_int().compare(b[i].to_int())
            break
          }
        }
        if comparison != 0 {
          comparison
        } else {
          a.length().compare(b.length())
        }
      })
      PdfDict(entries)
    }
    _ => value
  }
}
