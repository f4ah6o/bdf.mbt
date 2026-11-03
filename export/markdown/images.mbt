///|
/// An image drawn by a BDF object, with its bounds in page coordinates.
struct ImagePlacement {
  hash : String
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
fn mat_mul(
  a : (Double, Double, Double, Double, Double, Double),
  b : (Double, Double, Double, Double, Double, Double),
) -> (Double, Double, Double, Double, Double, Double) {
  let (a0, a1, a2, a3, a4, a5) = a
  let (b0, b1, b2, b3, b4, b5) = b
  (
    a0 * b0 + a2 * b1,
    a1 * b0 + a3 * b1,
    a0 * b2 + a2 * b3,
    a1 * b2 + a3 * b3,
    a0 * b4 + a2 * b5 + a4,
    a1 * b4 + a3 * b5 + a5,
  )
}

///|
fn matrix_point(
  m : (Double, Double, Double, Double, Double, Double),
  x : Double,
  y : Double,
) -> (Double, Double) {
  let (a, b, c, d, e, f) = m
  (a * x + c * y + e, b * x + d * y + f)
}

///|
fn placement(
  m : (Double, Double, Double, Double, Double, Double),
  hash : String,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> ImagePlacement {
  let (x0, y0) = matrix_point(m, x, y)
  let (x1, y1) = matrix_point(m, x + w, y)
  let (x2, y2) = matrix_point(m, x, y + h)
  let (x3, y3) = matrix_point(m, x + w, y + h)
  {
    hash,
    x0: Double::min(Double::min(x0, x1), Double::min(x2, x3)),
    y0: Double::min(Double::min(y0, y1), Double::min(y2, y3)),
    x1: Double::max(Double::max(x0, x1), Double::max(x2, x3)),
    y1: Double::max(Double::max(y0, y1), Double::max(y2, y3)),
  }
}

///|
fn collect_images(
  document : @core.Document,
  resources : @core.ObjectResources,
  matrix : (Double, Double, Double, Double, Double, Double),
  depth : Int32,
  out : Array[ImagePlacement],
) -> Array[String] raise {
  let warnings : Array[String] = []
  if depth > 32 {
    warnings.push("objects draw objects too deep")
    return warnings
  }
  let commands = @render.compile_object(resources.object) catch {
    _ => {
      warnings.push("image object could not be read")
      return warnings
    }
  }
  let stack : Array[(Double, Double, Double, Double, Double, Double)] = []
  let mut current = matrix
  for command in commands {
    match command {
      @render.Save => stack.push(current)
      @render.Restore =>
        if stack.length() > 0 {
          current = stack.pop().unwrap()
        }
      @render.Transform(a, b, c, d, e, f) =>
        current = mat_mul(current, (a, b, c, d, e, f))
      @render.Translate(x, y) =>
        current = mat_mul(current, (1.0, 0.0, 0.0, 1.0, x, y))
      @render.Scale(x, y) =>
        current = mat_mul(current, (x, 0.0, 0.0, y, 0.0, 0.0))
      @render.Image(hash, x, y, w, h) =>
        out.push(placement(current, hash, x, y, w, h))
      @render.ImageSub(hash, x, y, w, h, _, _, _, _) =>
        out.push(placement(current, hash, x, y, w, h))
      @render.Use(child) => {
        let child_resources = @core.decode_object_resources(
          document.part(child),
        ) catch {
          _ => {
            warnings.push("image child object could not be read")
            continue
          }
        }
        for
          warning in collect_images(
            document,
            child_resources,
            current,
            depth + 1,
            out,
          ) {
          warnings.push(warning)
        }
      }
      @render.UseAt(child, x, y) => {
        let child_resources = @core.decode_object_resources(
          document.part(child),
        ) catch {
          _ => {
            warnings.push("image child object could not be read")
            continue
          }
        }
        let moved = mat_mul(current, (1.0, 0.0, 0.0, 1.0, x, y))
        for
          warning in collect_images(
            document,
            child_resources,
            moved,
            depth + 1,
            out,
          ) {
          warnings.push(warning)
        }
      }
      _ => ()
    }
  }
  warnings
}

///|
fn image_kind(bytes : Bytes) -> (String, String) {
  if bytes.length() >= 8 &&
    bytes[0] == b'\x89' &&
    bytes[1] == b'P' &&
    bytes[2] == b'N' &&
    bytes[3] == b'G' {
    ("png", "image/png")
  } else if bytes.length() >= 2 && bytes[0] == b'\xff' && bytes[1] == b'\xd8' {
    ("jpg", "image/jpeg")
  } else if bytes.length() >= 4 &&
    bytes[0] == b'G' &&
    bytes[1] == b'I' &&
    bytes[2] == b'F' {
    ("gif", "image/gif")
  } else if bytes.length() >= 12 &&
    bytes[0] == b'R' &&
    bytes[1] == b'I' &&
    bytes[2] == b'F' &&
    bytes[3] == b'F' &&
    bytes[8] == b'W' &&
    bytes[9] == b'E' &&
    bytes[10] == b'B' &&
    bytes[11] == b'P' {
    ("webp", "image/webp")
  } else if bytes.length() > 0 && bytes[0] == b'<' {
    ("svg", "image/svg+xml")
  } else {
    ("bin", "application/octet-stream")
  }
}

///|
fn image_alt(alt : String) -> String {
  if alt == "" {
    "image"
  } else {
    alt.replace(old="]", new="\\]")
  }
}

///|
fn image_markdown(
  document : @core.Document,
  placement : ImagePlacement,
  alt : String,
  mode : String,
  files : Array[MarkdownFile],
  warnings : Array[String],
) -> String {
  if mode == "none" {
    return ""
  }
  let bytes = document.part(placement.hash) catch {
    _ => {
      warnings.push("image part could not be read")
      return ""
    }
  }
  let (extension, mime) = image_kind(bytes)
  let alt = image_alt(alt)
  if mode == "embed" {
    return "![" +
      alt +
      "](data:" +
      mime +
      ";base64," +
      @base64.encode(bytes) +
      ")"
  }
  let name = "images/image-" +
    (files.length() + 1).to_string() +
    "." +
    extension
  files.push({ name, bytes, })
  "![" + alt + "](" + name + ")"
}
