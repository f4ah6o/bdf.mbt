///|
/// A BITMAPV4HEADER with BI_BITFIELDS masks, then the given 32-bit pixels.
fn t_bitfields_v4(width : Int32, pixels : Array[Int32]) -> Bytes {
  let b = @buffer.Buffer()
  t_u32(b, 108) // biSize: BITMAPV4HEADER
  t_u32(b, width) // biWidth
  t_u32(b, 1) // biHeight
  t_u16(b, 1) // biPlanes
  t_u16(b, 32) // biBitCount
  t_u32(b, 3) // biCompression: BI_BITFIELDS
  t_u32(b, width * 4) // biSizeImage
  for _ in 0..<4 {
    t_u32(b, 0) // biXPelsPerMeter, biYPelsPerMeter, biClrUsed, biClrImportant
  }
  t_u32(b, 0x00ff0000) // bV4RedMask
  t_u32(b, 0x0000ff00) // bV4GreenMask
  t_u32(b, 0x000000ff) // bV4BlueMask
  t_u32(b, 0xff000000) // bV4AlphaMask
  for _ in 0..<13 {
    t_u32(b, 0) // bV4CSType, the endpoints and the gamma values
  }
  for pixel in pixels {
    t_u32(b, pixel)
  }
  b.to_bytes()
}

///|
test "a 32-bit bitfield keeps its semi-transparent alpha" {
  // half-transparent red, then a fully transparent pixel
  let data = t_bitfields_v4(2, [0x80ff0000, 0x00000000])
  let decoded = dib_decode(data, None)
  let dib = match decoded {
    Some(value) => value
    None => abort("the bitfield DIB did not decode")
  }
  guard dib.width == 2 && dib.height == 1 else {
    abort("the DIB is \{dib.width}x\{dib.height}, not 2x1")
  }
  let rgba = dib.rgba
  let red = rgba[0].to_int()
  let green = rgba[1].to_int()
  let blue = rgba[2].to_int()
  let alpha = rgba[3].to_int()
  guard red == 255 && green == 0 && blue == 0 else {
    abort("the colour mask is wrong: \{red},\{green},\{blue}")
  }
  guard alpha == 128 else {
    abort("a half-transparent pixel has alpha \{alpha}, not 128")
  }
  guard rgba[7].to_int() == 0 else {
    abort("a fully transparent pixel became opaque: \{rgba[7].to_int()}")
  }
}

///|
test "a 32-bit bitfield alpha mask in the high byte shifts down" {
  // the alpha mask alone, so a sign-extending shift shows up as 255
  guard mask_channel(0x80000000, 0xff000000) == 128 else {
    abort("0x80 in the high byte did not become 128")
  }
  guard mask_channel(0xff000000, 0xff000000) == 255 else {
    abort("0xff in the high byte did not become 255")
  }
  guard mask_channel(0x00000000, 0xff000000) == 0 else {
    abort("0x00 in the high byte did not become 0")
  }
  guard mask_channel(0x00ff0000, 0x00ff0000) == 255 else {
    abort("a low-byte mask regressed")
  }
}
