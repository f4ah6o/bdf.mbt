///|
/// One page of a raster document: an image stored as it is and the size at
/// which it is drawn on the page.
pub(all) struct RasterPage {
  image : Bytes
  format : String
  width_px : Int32
  height_px : Int32
  // The size the image is drawn at, in points.
  draw_width : Double
  draw_height : Double
  // The size of the page, in points.
  page_width : Double
  page_height : Double
  // How the image is placed on the page; `None` fills the page.
  transform : (Double, Double, Double, Double, Double, Double)?
  alt : String
}

///|
fn raster_object(
  hash : String,
  page_width : Double,
  page_height : Double,
  draw_width : Double,
  draw_height : Double,
  transform : (Double, Double, Double, Double, Double, Double)?,
  alt : String,
) -> Bytes raise RasterError {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(
    0.0F,
    0.0F,
    Float::from_double(page_width),
    Float::from_double(page_height),
  )
  let index = object.add_image(hash)
  object.mark(10, alt)
  object.smoothing(true, 2)
  match transform {
    Some(matrix) => {
      let (a, b, c, d, e, f) = matrix
      object.save()
      object.transform(
        Float::from_double(a),
        Float::from_double(b),
        Float::from_double(c),
        Float::from_double(d),
        Float::from_double(e),
        Float::from_double(f),
      )
      object.image(
        index,
        0.0F,
        0.0F,
        Float::from_double(draw_width),
        Float::from_double(draw_height),
      ) catch {
        error => raise InvalidRaster("raster: " + error.to_string())
      }
      object.restore()
    }
    None =>
      object.image(
        index,
        0.0F,
        0.0F,
        Float::from_double(draw_width),
        Float::from_double(draw_height),
      ) catch {
        error => raise InvalidRaster("raster: " + error.to_string())
      }
  }
  object.mark(11, "")
  object.encode() catch {
    error => raise InvalidRaster("raster: " + error.to_string())
  }
}

///|
fn raster_dc_json(fields : Map[String, Array[String]]) -> Map[String, Json] {
  let out : Map[String, Json] = Map([])
  for key, values in fields {
    if values.length() == 1 {
      out[key] = Json::string(values[0])
    } else if values.length() > 1 {
      out[key] = Json::array(values.map(value => Json::string(value)))
    }
  }
  out
}

///|
/// Write a fixed view of one image per page, with an optional document
/// title and Dublin Core metadata.
pub fn write_document(
  pages : Array[RasterPage],
  title~ : String = "",
  source~ : String = "",
  dc? : Map[String, Array[String]],
) -> Bytes raise RasterError {
  let fields : Map[String, Array[String]] = Map([])
  match dc {
    Some(values) =>
      for key, value in values {
        fields[key] = value
      }
    None => ()
  }
  if title != "" {
    fields["title"] = [title]
  }
  let meta : Map[String, Json] = Map([])
  if source != "" {
    meta["source"] = Json::string(source)
  }
  meta["generator"] = Json::string("bdf-go/0.1")
  let json_fields = raster_dc_json(fields)
  if json_fields.length() > 0 {
    meta["dc"] = Json::object(json_fields)
  }
  let writer = @core.DocumentWriter::new(meta=Json::object(meta))
  let page_json : Array[Json] = []
  for page in pages {
    let image_hash = writer.add_part("img", page.image) catch {
      error => raise InvalidRaster("raster: " + error.to_string())
    }
    let object_hash = writer.add_part(
      "obj",
      raster_object(
        image_hash,
        page.page_width,
        page.page_height,
        page.draw_width,
        page.draw_height,
        page.transform,
        page.alt,
      ),
    ) catch {
      error => raise InvalidRaster("raster: " + error.to_string())
    }
    page_json.push(
      Json::object({
        "w": Json::number(page.page_width, repr=page.page_width.to_string()),
        "h": Json::number(page.page_height, repr=page.page_height.to_string()),
        "layers": Json::array([
          Json::object({
            "role": Json::string("body"),
            "obj": Json::string(object_hash),
          }),
        ]),
      }),
    )
  }
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
    "pages": Json::array(page_json),
  }
  if title != "" {
    view["title"] = Json::string(title)
  }
  writer.add_view(Json::object(view))
  writer.write_single() catch {
    error => raise InvalidRaster("raster: " + error.to_string())
  }
}
