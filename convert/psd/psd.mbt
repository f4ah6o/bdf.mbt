///|
pub(all) struct PsdResult {
  bdf : Bytes
  pages : Int32
  summary : String
  warnings : Array[String]
}

///|
priv struct PsdRegion {
  x : Int32
  y : Int32
  width : Int32
  height : Int32
  artboard : Bool
}

///|
/// Detect a Photoshop document or the large document format (PSB).
pub fn detect(data : Bytes) -> Bool {
  psd_detect(data)
}

///|
fn psd_crop(
  rgba : Bytes,
  canvas_width : Int32,
  x : Int32,
  y : Int32,
  width : Int32,
  height : Int32,
) -> Bytes {
  let out : FixedArray[Byte] = FixedArray::make(
    width * height * 4,
    (0).to_byte(),
  )
  for row in 0..<height {
    let source = ((y + row) * canvas_width + x) * 4
    let target = row * width * 4
    for i in 0..<(width * 4) {
      out[target + i] = rgba[source + i]
    }
  }
  Bytes::from_array(out)
}

///|
fn psd_metadata(file : PsdFile, title : String) -> Map[String, Array[String]] {
  let fields : Map[String, Array[String]] = Map([])
  match file.resources.get(PSD_XMP) {
    Some(packet) => {
      let values = @image.xmp_dublin_core(packet) catch { _ => Map([]) }
      for key, value in values {
        fields[key] = value
      }
    }
    None => ()
  }
  if title != "" {
    fields["title"] = [title]
  }
  fields
}

///|
/// Convert a Photoshop document: one page per visible artboard, in the
/// order of the Layers panel, or the whole canvas when it has none.
///
/// The converter stores the composite image the file keeps beside its
/// layers. A file saved without "Maximize Compatibility" has no composite;
/// the converter then fails with an explicit error because it does not
/// composite the layers itself yet.
pub fn convert(
  data : Bytes,
  title~ : String = "",
  artboards~ : Bool = true,
) -> PsdResult raise PsdError {
  let file = psd_read_file(data)
  if file.layer_error.is_some() {
    // The layer records are only needed for artboards; the composite can
    // still be converted.
  }
  if !psd_has_composite(file) {
    raise PsdInvalid(
      "psd: the document has no composite image; layer compositing is not supported",
    )
  }
  let warnings : Array[String] = []
  match file.layer_error {
    Some(message) => warnings.push("layers: " + message)
    None => ()
  }
  let planes = psd_read_planes(file)
  let rgba = psd_to_rgba(file, planes)
  let canvas_width = file.header.width
  let canvas_height = file.header.height
  let regions : Array[PsdRegion] = []
  let mut artboard_count = 0
  if artboards {
    for layer in file.layers {
      match layer.artboard {
        Some((top, left, bottom, right)) =>
          if !layer.hidden {
            let x0 = if left < 0 { 0 } else { left }
            let y0 = if top < 0 { 0 } else { top }
            let x1 = if right > canvas_width { canvas_width } else { right }
            let y1 = if bottom > canvas_height { canvas_height } else { bottom }
            if x1 > x0 && y1 > y0 {
              if regions.length() >= 256 {
                warnings.push(
                  "more than 256 artboards: the others are left out",
                )
                break
              }
              regions.push({
                x: x0,
                y: y0,
                width: x1 - x0,
                height: y1 - y0,
                artboard: true,
              })
              artboard_count += 1
            }
          }
        None => ()
      }
    }
  }
  if regions.is_empty() {
    regions.push({
      x: 0,
      y: 0,
      width: canvas_width,
      height: canvas_height,
      artboard: false,
    })
    artboard_count = 0
  }
  let (x_dpi, y_dpi) = psd_resolution(file)
  let fields = psd_metadata(file, title)
  let document_title = match fields.get("title") {
    Some(values) if !values.is_empty() => values[0]
    _ => title
  }
  let pages : Array[@raster.RasterPage] = []
  let mut scaled = 0
  for region in regions {
    let pixels = if region.width == canvas_width &&
      region.height == canvas_height {
      rgba
    } else {
      psd_crop(
        rgba,
        canvas_width,
        region.x,
        region.y,
        region.width,
        region.height,
      )
    }
    let width_pt = region.width.to_double() / x_dpi * 72.0
    let height_pt = region.height.to_double() / y_dpi * 72.0
    let (target_width, target_height) = @raster.fit_size(
      region.width,
      region.height,
      width_pt,
      height_pt,
    )
    let resized = target_width != region.width || target_height != region.height
    let final_pixels = if resized {
      scaled += 1
      @raster.resize_box(
        pixels,
        region.width,
        region.height,
        target_width,
        target_height,
      ) catch {
        @raster.InvalidRaster(message) => raise PsdInvalid(message)
      }
    } else {
      pixels
    }
    let image = @raster.encode_png(target_width, target_height, final_pixels) catch {
      @raster.InvalidRaster(message) => raise PsdInvalid(message)
    }
    pages.push({
      image,
      format: "png",
      width_px: target_width,
      height_px: target_height,
      draw_width: width_pt,
      draw_height: height_pt,
      page_width: width_pt,
      page_height: height_pt,
      transform: None,
      alt: document_title,
    })
  }
  let count = pages.length()
  let mut summary = if artboard_count > 0 {
    "\{artboard_count} artboard(s)"
  } else {
    "\{count} page(s)"
  }
  if scaled > 0 {
    summary += ", \{scaled} scaled down to the resolution cap"
  }
  {
    bdf: @raster.write_document(
      pages,
      title=document_title,
      source="psd",
      dc=fields,
    ) catch {
      @raster.InvalidRaster(message) => raise PsdInvalid(message)
    },
    pages: count,
    summary,
    warnings,
  }
}
