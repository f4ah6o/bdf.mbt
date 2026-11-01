///|
pub(all) struct TiffResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
fn tiff_default_dpi(dpi : Double) -> Double {
  if dpi > 0.0 && !dpi.is_nan() && !dpi.is_inf() {
    dpi
  } else {
    96.0
  }
}

///|
fn tiff_page_resolution(ifd : TiffIfd, default : Double) -> (Double, Double) {
  let (x_value, y_value, unit) = ifd.resolution()
  let mut x = x_value
  let mut y = y_value
  if x == 0.0 {
    x = y
  }
  if y == 0.0 {
    y = x
  }
  if x == 0.0 {
    return (default, default)
  }
  if unit == TIFF_RESOLUTION_CENTIMETER {
    x = x * 2.54
    y = y * 2.54
  } else if unit == TIFF_RESOLUTION_NONE && (if x < y { x } else { y }) < 50.0 {
    return (default, default * y / x)
  }
  if x < 1.0 || y < 1.0 {
    return (default, default)
  }
  (x, y)
}

///|
fn tiff_orientation_transform(
  orientation : Int32,
  image_width : Double,
  image_height : Double,
) -> (Double, Double, Double, Double, Double, Double)? {
  match orientation {
    2 => Some((-1.0, 0.0, 0.0, 1.0, image_width, 0.0))
    3 => Some((-1.0, 0.0, 0.0, -1.0, image_width, image_height))
    4 => Some((1.0, 0.0, 0.0, -1.0, 0.0, image_height))
    5 => Some((0.0, 1.0, 1.0, 0.0, 0.0, 0.0))
    6 => Some((0.0, 1.0, -1.0, 0.0, image_height, 0.0))
    7 => Some((0.0, -1.0, -1.0, 0.0, image_height, image_width))
    8 => Some((0.0, -1.0, 1.0, 0.0, 0.0, image_width))
    _ => None
  }
}

///|
fn tiff_datetime(value : String) -> String? {
  if value.length() != 19 {
    return None
  }
  let bytes = value.to_bytes()
  for index in 0..<19 {
    let ch = bytes[index]
    let digit = ch >= b'0' && ch <= b'9'
    if index == 4 || index == 7 {
      if ch != b':' {
        return None
      }
    } else if index == 10 {
      if ch != b' ' {
        return None
      }
    } else if index == 13 || index == 16 {
      if ch != b':' {
        return None
      }
    } else if !digit {
      return None
    }
  }
  if bytes[0] == b'0' &&
    bytes[1] == b'0' &&
    bytes[2] == b'0' &&
    bytes[3] == b'0' {
    return None
  }
  let year = value.substring(start=0, end=4)
  let month = value.substring(start=5, end=7)
  let day = value.substring(start=8, end=10)
  let hour = value.substring(start=11, end=13)
  let minute = value.substring(start=14, end=16)
  let second = value.substring(start=17, end=19)
  Some("\{year}-\{month}-\{day}T\{hour}:\{minute}:\{second}")
}

///|
fn tiff_metadata(ifd : TiffIfd, title : String) -> Map[String, Array[String]] {
  let fields : Map[String, Array[String]] = Map([])
  let document_title = if title != "" {
    title
  } else {
    let names = ifd.strings(TIFF_TAG_DOCUMENT_NAME)
    if names.is_empty() {
      ""
    } else {
      names[0]
    }
  }
  if document_title != "" {
    fields["title"] = [document_title]
  }
  let description = ifd.strings(TIFF_TAG_IMAGE_DESCRIPTION)
  if !description.is_empty() {
    fields["description"] = description
  }
  let creators : Array[String] = []
  for artist in ifd.strings(TIFF_TAG_ARTIST) {
    for part in artist.split(";") {
      let value = part.trim().to_owned()
      if value != "" && !creators.contains(value) {
        creators.push(value)
      }
    }
  }
  if !creators.is_empty() {
    fields["creator"] = creators
  }
  let rights = ifd.strings(TIFF_TAG_COPYRIGHT)
  if !rights.is_empty() {
    fields["rights"] = rights
  }
  let dates = ifd.strings(TIFF_TAG_DATE_TIME)
  if !dates.is_empty() {
    match tiff_datetime(dates[0]) {
      Some(value) => fields["modified"] = [value]
      None => ()
    }
  }
  fields
}

///|
/// Convert a TIFF or BigTIFF file, one page per image of the IFD chain.
///
/// The JPEG compression, DNG camera raw files and YCbCr pixels outside
/// JPEG are not supported. Pages finer than the resolution cap are scaled
/// down and the page keeps its physical size.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  dpi~ : Double = 0.0,
) -> TiffResult raise TiffError {
  let file = tiff_open(data)
  let pages : Array[TiffIfd] = []
  for ifd in file.ifds {
    if (ifd.uint(TIFF_TAG_NEW_SUBFILE_TYPE, 0L) & 5L) == 0L {
      pages.push(ifd)
    }
  }
  if pages.is_empty() {
    raise TiffInvalid(
      "TIFF: the file has no pages, only reduced-resolution images or masks",
    )
  }
  let warnings : Array[String] = []
  let warned : Map[String, Bool] = Map([])
  let warn = fn(message : String) {
    if !warned.contains(message) {
      warned[message] = true
      warnings.push(message)
    }
  }
  match file.chain_error {
    Some(message) =>
      warn("\{message}: the pages after page \{pages.length()} are missing")
    None => ()
  }
  let default_dpi = tiff_default_dpi(dpi)
  let fields = tiff_metadata(pages[0], title)
  let document_title = match fields.get("title") {
    Some(values) if !values.is_empty() => values[0]
    _ => title
  }
  let description = match fields.get("description") {
    Some(values) if !values.is_empty() => values[0]
    _ => ""
  }
  let alt = if description != "" { description } else { document_title }
  let raster_pages : Array[@raster.RasterPage] = []
  let mut scaled = 0
  let blank = @raster.encode_png(1, 1, b"\x00\x00\x00\x00") catch {
    @raster.InvalidRaster(message) => raise TiffInvalid(message)
  }
  for page_index in 0..<pages.length() {
    let page_number = page_index + 1
    let ifd = pages[page_index]
    let (width, height) = ifd.size()
    let (x_dpi, y_dpi) = tiff_page_resolution(ifd, default_dpi)
    let image_width = width.to_double() / x_dpi * 72.0
    let image_height = height.to_double() / y_dpi * 72.0
    let orientation = ifd.orientation()
    let (page_width, page_height) = if orientation >= 5 {
      (image_height, image_width)
    } else {
      (image_width, image_height)
    }
    let transform = tiff_orientation_transform(
      orientation, image_width, image_height,
    )
    if width <= 0 || height <= 0 {
      warn("page \{page_number} has no size; it is left out")
      continue
    }
    let (target_width, target_height) = @raster.fit_size(
      width, height, image_width, image_height,
    )
    let resized = target_width != width || target_height != height
    let decoded = tiff_decode(ifd, data) catch {
      TiffInvalid(message) => {
        warn("page \{page_number}: \{message}; the page is left blank")
        raster_pages.push({
          image: blank,
          format: "png",
          width_px: 1,
          height_px: 1,
          draw_width: page_width,
          draw_height: page_height,
          page_width,
          page_height,
          transform: None,
          alt: "",
        })
        continue
      }
    }
    let (pixels, damaged) = decoded
    if damaged {
      warn(
        "page \{page_number}: the pixel data is damaged; what is missing is left blank",
      )
    }
    let layout = tiff_layout(ifd, data) catch {
      _ => raise TiffInvalid("TIFF: the page layout is invalid")
    }
    let bilevel = tiff_bilevel(layout)
    if ifd.photometric() == TIFF_SEPARATED {
      warn("CMYK pages are converted to RGB without colour management")
    }
    let final_pixels = if resized {
      scaled += 1
      @raster.resize_box(
        pixels,
        width,
        height,
        target_width,
        target_height,
        bilevel~,
      ) catch {
        @raster.InvalidRaster(message) => raise TiffInvalid(message)
      }
    } else {
      pixels
    }
    let image = @raster.encode_png(target_width, target_height, final_pixels) catch {
      @raster.InvalidRaster(message) => raise TiffInvalid(message)
    }
    raster_pages.push({
      image,
      format: "png",
      width_px: target_width,
      height_px: target_height,
      draw_width: image_width,
      draw_height: image_height,
      page_width,
      page_height,
      transform,
      alt,
    })
  }
  let count = raster_pages.length()
  let mut summary = "\{count} page(s)"
  if scaled > 0 {
    summary += ", \{scaled} scaled down to the resolution cap"
  }
  {
    bdf: @raster.write_document(
      raster_pages,
      title=document_title,
      source="tiff",
      dc=fields,
    ) catch {
      @raster.InvalidRaster(message) => raise TiffInvalid(message)
    },
    pages: count,
    summary,
    warnings,
  }
}
