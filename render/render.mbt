///|
pub(all) enum Command {
  Save
  Restore
  Transform(Double, Double, Double, Double, Double, Double)
  Translate(Double, Double)
  Scale(Double, Double)
  ClipRect(Double, Double, Double, Double)
  FillColor(Int)
  StrokeColor(Int)
  Line(Double, Int, Int, Double)
  Alpha(Double)
  Font(Int, Double)
  TextStyle(Int, Int, Int, Double)
  FillRect(Double, Double, Double, Double)
  StrokeRect(Double, Double, Double, Double)
  ClearRect(Double, Double, Double, Double)
  FillText(String, Double, Double, Double)
  StrokeText(String, Double, Double, Double)
  Image(String, Double, Double, Double, Double)
  ImageSub(String, Double, Double, Double, Double, Double, Double, Double, Double)
  Smoothing(Bool, Int)
  Ext(Bytes)
} derive(Debug)

///|
pub suberror RenderError {
  UnsupportedOpcode(Int)
  InvalidReference(String)
}

///|
fn read_text(r : @core.Reader, strings : Array[String]) -> String raise {
  let index = r.varuint()
  if index >= strings.length() {
    raise InvalidReference("string index out of range")
  }
  strings[index]
}

///|
fn read_image(r : @core.Reader, images : Array[String]) -> String raise {
  let index = r.varuint()
  if index >= images.length() {
    raise InvalidReference("image index out of range")
  }
  images[index]
}

///|
/// Decode BDF opset 1 into an immutable, backend-neutral Canvas command list.
/// Unknown draw opcodes are rejected, never silently skipped.
pub fn compile_object(object : @core.ObjectPart) -> Array[Command] raise {
  let r = @core.Reader::new(object.ops)
  let commands : Array[Command] = []
  while r.remaining() > 0 {
    let opcode = r.u8()
    match opcode {
      0x01 => commands.push(Save)
      0x02 => commands.push(Restore)
      0x03 => commands.push(Transform(r.f32(), r.f32(), r.f32(), r.f32(), r.f32(), r.f32()))
      0x04 => commands.push(Translate(r.f32(), r.f32()))
      0x05 => commands.push(Scale(r.f32(), r.f32()))
      0x07 => commands.push(ClipRect(r.f32(), r.f32(), r.f32(), r.f32()))
      0x10 => commands.push(FillColor(r.u32()))
      0x12 => commands.push(StrokeColor(r.u32()))
      0x14 => commands.push(Line(r.f32(), r.u8(), r.u8(), r.f32()))
      0x16 => commands.push(Alpha(r.f32()))
      0x1a => commands.push(Font(r.varuint(), r.f32()))
      0x1b => commands.push(TextStyle(r.u8(), r.u8(), r.u8(), r.f32()))
      0x20 => commands.push(FillRect(r.f32(), r.f32(), r.f32(), r.f32()))
      0x21 => commands.push(StrokeRect(r.f32(), r.f32(), r.f32(), r.f32()))
      0x26 => commands.push(ClearRect(r.f32(), r.f32(), r.f32(), r.f32()))
      0x30 => commands.push(FillText(read_text(r, object.strings), r.f32(), r.f32(), r.f32()))
      0x31 => commands.push(StrokeText(read_text(r, object.strings), r.f32(), r.f32(), r.f32()))
      0x40 => commands.push(Image(read_image(r, object.images), r.f32(), r.f32(), r.f32(), r.f32()))
      0x41 => commands.push(ImageSub(read_image(r, object.images), r.f32(), r.f32(), r.f32(), r.f32(), r.f32(), r.f32(), r.f32(), r.f32()))
      0x42 => commands.push(Smoothing(r.u8() != 0, r.u8()))
      0xff => commands.push(Ext(r.take(r.u32())))
      _ => raise UnsupportedOpcode(opcode)
    }
  }
  commands
}

///|
/// This convenience API validates both the BOBJ part and its supported ops.
pub fn decode_commands(object_bytes : Bytes) -> Array[Command] raise {
  compile_object(@core.decode_object(object_bytes))
}
