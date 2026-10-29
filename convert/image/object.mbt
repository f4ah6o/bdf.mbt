///|
fn image_object(
  hash : String,
  width : Float,
  height : Float,
  alt : String,
  smooth : Bool,
) -> Bytes raise {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, width, height)
  let image = object.add_image(hash)
  object.mark(10, alt)
  if smooth {
    object.smoothing(true, 2)
  }
  object.image(image, 0.0F, 0.0F, width, height)
  object.mark(11, "")
  object.encode()
}
