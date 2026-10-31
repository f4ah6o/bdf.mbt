///|
/// Encode the resource contribution used when comparing object prefixes.
/// Kinds are `p` (path), `g` (paint), `f` (font), `i` (image), and `o` (child).
pub fn prefix_resource_data(
  resources : ObjectResources,
  kind : Byte,
  index : Int32,
) -> Bytes raise {
  let out = @buffer.Buffer()
  out.write_byte(kind)
  if index < 0 {
    raise BadFormat("negative prefix resource index")
  }
  match kind {
    b'p' => {
      if index >= resources.paths.length() {
        raise BadFormat("invalid prefix path")
      }
      match resources.paths[index] {
        Inline(path) => object_write_path(out, path)
        External(hash, path_index) => {
          object_write_hash(out, hash)
          if path_index < 0 {
            raise BadFormat("invalid prefix external path")
          }
          out.write_leb128(path_index.reinterpret_as_uint())
        }
      }
    }
    b'g' => {
      if index >= resources.paints.length() {
        raise BadFormat("invalid prefix paint")
      }
      let paint = resources.paints[index]
      object_write_paint(out, paint)
      if paint is Pattern(image, _, _) {
        if image < 0 || image >= resources.object.images.length() {
          raise BadFormat("invalid prefix pattern image")
        }
        object_write_hash(out, resources.object.images[image])
      }
    }
    b'f' => {
      if index >= resources.fonts.length() {
        raise BadFormat("invalid prefix font")
      }
      object_write_font(out, resources.fonts[index])
    }
    b'i' => {
      if index >= resources.object.images.length() {
        raise BadFormat("invalid prefix image")
      }
      object_write_hash(out, resources.object.images[index])
    }
    b'o' => {
      if index >= resources.object.objects.length() {
        raise BadFormat("invalid prefix child")
      }
      object_write_hash(out, resources.object.objects[index])
    }
    _ => raise BadFormat("invalid prefix resource kind")
  }
  out.to_bytes()
}
