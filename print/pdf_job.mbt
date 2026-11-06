///|
/// Write a BDF document as PDF for printing.
pub fn bdf_pdf(bdf : Bytes) -> @pdf.PdfResult raise {
  @pdf.write_bytes(bdf, @pdf.PdfOptions::new())
}

///|
/// Print a BDF document as a PDF job through a transport.
pub fn print_bdf(
  client : @ipp.Client,
  bdf : Bytes,
  name : String,
  transport : (Bytes) -> Bytes?,
) -> @ipp.JobStatus raise @ipp.IppError {
  let pdf = bdf_pdf(bdf) catch {
    _ => {
      @ipp.fail("print: the BDF document cannot be written as PDF")
      { bytes: Bytes::new(0), pages: 0, fonts: 0, warnings: [] }
    }
  }
  client.print_pdf(name, pdf.bytes, transport)
}
