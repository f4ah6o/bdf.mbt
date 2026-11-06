///|
/// Write one PWG Raster page from RGBA pixels.
pub fn encode_pwg(page : Page, image : RasterImage) -> Bytes raise RasterError {
  if image.width != page.width || image.height != page.height {
    raise RasterError("raster: the image and page sizes differ")
  }
  let writer = Writer::new()
  writer.start_page(page)
  for y in 0..<image.height {
    writer.write_image_row(image, y)
  }
  writer.close()
}

///|
/// Write one Apple Raster page from RGBA pixels.
pub fn encode_urf(page : Page, image : RasterImage) -> Bytes raise RasterError {
  if image.width != page.width || image.height != page.height {
    raise RasterError("raster: the image and page sizes differ")
  }
  let writer = Writer::new_urf(1)
  writer.start_page(page)
  for y in 0..<image.height {
    writer.write_image_row(image, y)
  }
  writer.close()
}

///|
/// Write one PCLm page from RGBA pixels.
pub fn encode_pclm(
  page : Page,
  image : RasterImage,
  options : PclmOptions,
) -> Bytes raise RasterError {
  if image.width != page.width || image.height != page.height {
    raise RasterError("raster: the image and page sizes differ")
  }
  let writer = PclmWriter::new(options)
  writer.start_page(page)
  for y in 0..<image.height {
    writer.write_image_row(image, y)
  }
  writer.close()
}
