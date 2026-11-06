///|
// PCLm 1.0: a PDF of pages made of compressed strips.
pub(all) struct PclmOptions {
  strip_height : Int
  compression : String
}

///|
pub fn PclmOptions::new() -> PclmOptions {
  { strip_height: 16, compression: "flate" }
}

///|
pub(all) struct PclmWriter {
  out : Array[Byte]
  offsets : Array[Int]
  pages : Array[Int]
  mut page : Page?
  mut rows : Int
  mut unit : Int
  mut strip : Array[Byte]
  mut in_strip : Int
  mut strips : Array[Int]
  mut heights : Array[Int]
  strip_height : Int
  compression : String
}

///|
pub fn PclmWriter::new(options : PclmOptions) -> PclmWriter raise RasterError {
  let compression = if options.compression == "" { "flate" } else { options.compression }
  if compression != "rle" && compression != "flate" {
    raise RasterError("raster: PCLm compression \"" + compression + "\" is not supported")
  }
  let strip_height = if options.strip_height <= 0 { 16 } else { options.strip_height }
  let out : Array[Byte] = []
  for byte in [b'%', b'P', b'D', b'F', b'-', b'1', b'.', b'7', b'\n', b'%', b'P', b'C', b'L', b'm', b' ', b'1', b'.', b'0', b'\n'] {
    out.push(byte)
  }
  {
    out,
    offsets: [0, 0, 0],
    pages: [],
    page: None,
    rows: 0,
    unit: 0,
    strip: [],
    in_strip: 0,
    strips: [],
    heights: [],
    strip_height,
    compression,
  }
}

///|
fn pclm_append(writer : PclmWriter, text : String) -> Unit {
  for byte in @utf8.encode(text) {
    writer.out.push(byte)
  }
}

///|
fn pclm_object(writer : PclmWriter) -> Int {
  writer.offsets.push(writer.out.length())
  let number = writer.offsets.length() - 1
  pclm_append(writer, number.to_string() + " 0 obj\n")
  number
}

///|
fn pclm_num(value : Double) -> String {
  let negative = value < 0.0
  let scaled = (value.abs() * 1000000.0 + 0.5).floor().to_int()
  let whole = scaled / 1000000
  let fraction = scaled % 1000000
  let mut text = if negative { "-" } else { "" }
  text += whole.to_string()
  if fraction != 0 {
    let mut digits = fraction.to_string()
    while digits.length() < 6 {
      digits = "0" + digits
    }
    while digits.length() > 0 && digits[digits.length() - 1] == '0' {
      digits = digits[:digits.length() - 1].to_owned()
    }
    text += "." + digits
  }
  text
}

///|
fn pclm_run_length(data : Bytes) -> Bytes {
  let out : Array[Byte] = []
  let mut i = 0
  while i < data.length() {
    let mut j = i + 1
    while j < data.length() && j - i < 128 && data[j] == data[i] {
      j += 1
    }
    if j - i > 1 {
      out.push((257 - (j - i)).to_byte())
      out.push(data[i])
      i = j
      continue
    }
    j = i + 1
    while j < data.length() &&
      j - i < 128 &&
      !(j + 1 < data.length() && data[j] == data[j + 1]) {
      j += 1
    }
    out.push((j - i - 1).to_byte())
    for k in i..<j {
      out.push(data[k])
    }
    i = j
  }
  out.push(b'\x80')
  Bytes::from_array(out)
}

///|
fn PclmWriter::write_strip(self : PclmWriter) -> Unit raise RasterError {
  let page = match self.page {
    Some(value) => value
    None => raise RasterError("raster: a strip before a page")
  }
  let width = page.width
  let height = self.in_strip
  let space = if self.unit == 3 { "/DeviceRGB" } else { "/DeviceGray" }
  let raw = Bytes::from_array(self.strip)
  let data = if self.compression == "flate" {
    @zlib.compress(raw)
  } else {
    pclm_run_length(raw)
  }
  let filter_name = if self.compression == "flate" {
    "/FlateDecode"
  } else {
    "/RunLengthDecode"
  }
  let number = pclm_object(self)
  pclm_append(
    self,
    "<< /Type /XObject /Subtype /Image /Width " +
    width.to_string() +
    " /Height " +
    height.to_string() +
    " /ColorSpace " +
    space +
    " /BitsPerComponent 8 /Filter " +
    filter_name +
    " /Length " +
    data.length().to_string() +
    " >>\nstream\n",
  )
  for byte in data {
    self.out.push(byte)
  }
  pclm_append(self, "\nendstream\nendobj\n")
  self.strips.push(number)
  self.heights.push(height)
  self.strip.clear()
  self.in_strip = 0
}

///|
pub fn PclmWriter::start_page(self : PclmWriter, page : Page) -> Unit raise RasterError {
  self.end_page()
  if page.width <= 0 || page.height <= 0 || page.xdpi <= 0 {
    raise RasterError("raster: an empty page")
  }
  self.unit = if page.typ == SGRAY_8 {
    1
  } else if page.typ == SRGB_8 {
    3
  } else {
    raise RasterError("raster: PCLm has no type \"" + page.typ + "\"")
  }
  self.page = Some(page)
  self.rows = 0
  self.in_strip = 0
  self.strips = []
  self.heights = []
  self.strip = []
}

///|
/// Add a row of gray or RGB bytes.
pub fn PclmWriter::write_row(self : PclmWriter, row : Bytes) -> Unit raise RasterError {
  let page = match self.page {
    Some(value) => value
    None => raise RasterError("raster: a row before a page")
  }
  if row.length() != page.width * self.unit {
    raise RasterError("raster: a row of another width")
  }
  if self.rows >= page.height {
    raise RasterError("raster: the rows run past the page")
  }
  for byte in row {
    self.strip.push(byte)
  }
  self.rows += 1
  self.in_strip += 1
  if self.in_strip == self.strip_height || self.rows == page.height {
    self.write_strip()
  }
}

///|
pub fn PclmWriter::end_page(self : PclmWriter) -> Unit raise RasterError {
  match self.page {
    None => ()
    Some(page) => {
      if self.rows != page.height {
        raise RasterError(
          "raster: the rows do not fill the page: " +
          self.rows.to_string() +
          " of " +
          page.height.to_string(),
        )
      }
      self.page = None
      let scale = 72.0 / page.xdpi.to_double()
      let y_scale = 72.0 / (if page.ydpi > 0 { page.ydpi } else { page.xdpi }).to_double()
      let mut content = pclm_num(scale) + " 0 0 " + pclm_num(y_scale) + " 0 0 cm\n/P <</MCID 0>> BDC\n"
      let mut y = page.height
      let mut xobjects = ""
      for i, strip in self.strips {
        y -= self.heights[i]
        content += "q " +
          page.width.to_string() +
          " 0 0 " +
          self.heights[i].to_string() +
          " 0 " +
          y.to_string() +
          " cm /S" +
          i.to_string() +
          " Do Q\n"
        xobjects += " /S" + i.to_string() + " " + strip.to_string() + " 0 R"
      }
      content += "EMC\n"
      let content_object = pclm_object(self)
      pclm_append(
        self,
        "<< /Length " +
        @utf8.encode(content).length().to_string() +
        " >>\nstream\n" +
        content +
        "\nendstream\nendobj\n",
      )
      let page_object = pclm_object(self)
      pclm_append(
        self,
        "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 " +
        pclm_num(page.width.to_double() * scale) +
        " " +
        pclm_num(page.height.to_double() * y_scale) +
        "] /Resources << /XObject <<" +
        xobjects +
        " >> >> /Contents " +
        content_object.to_string() +
        " 0 R >>\nendobj\n",
      )
      self.pages.push(page_object)
    }
  }
}

///|
pub fn PclmWriter::close(self : PclmWriter) -> Bytes raise RasterError {
  self.end_page()
  self.offsets[1] = self.out.length()
  pclm_append(self, "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
  self.offsets[2] = self.out.length()
  let mut kids = ""
  for page in self.pages {
    kids += page.to_string() + " 0 R "
  }
  pclm_append(
    self,
    "2 0 obj\n<< /Type /Pages /Kids [" +
    kids +
    "] /Count " +
    self.pages.length().to_string() +
    " >>\nendobj\n",
  )
  let xref = self.out.length()
  pclm_append(
    self,
    "xref\n0 " + self.offsets.length().to_string() + "\n0000000000 65535 f \n",
  )
  for i in 1..<self.offsets.length() {
    let offset = self.offsets[i].to_string()
    let mut padded = offset
    while padded.length() < 10 {
      padded = "0" + padded
    }
    pclm_append(self, padded + " 00000 n \n")
  }
  pclm_append(
    self,
    "trailer\n<< /Size " +
    self.offsets.length().to_string() +
    " /Root 1 0 R >>\nstartxref\n" +
    xref.to_string() +
    "\n%%EOF\n",
  )
  Bytes::from_array(self.out)
}

///|
/// Convert and add row y of an RGBA image to the PCLm page.
pub fn PclmWriter::write_image_row(
  self : PclmWriter,
  image : RasterImage,
  y : Int,
) -> Unit raise RasterError {
  let page = match self.page {
    Some(value) => value
    None => raise RasterError("raster: a row before a page")
  }
  if image.width != page.width || image.height != page.height {
    raise RasterError("raster: the image and page sizes differ")
  }
  self.write_row(row_bytes(image, y, page.typ))
}

