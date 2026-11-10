///|
// Verification-only internal plane model for full-component dumps.
priv struct DecodeComponentPlaneInternal {
  component_index : Int
  width : Int
  height : Int
  bits_per_component : Int
  is_signed : Bool
  samples : Array[Int]
}

///|
fn component_int_at(values : Array[Int], index : Int, fallback : Int) -> Int {
  if index >= 0 && index < values.length() {
    return values[index]
  }
  fallback
}

///|
fn component_bool_at(
  values : Array[Bool],
  index : Int,
  fallback : Bool,
) -> Bool {
  if index >= 0 && index < values.length() {
    return values[index]
  }
  fallback
}

///|
fn build_component_sample_bytes(
  values : Array[Int],
  bits_per_component : Int,
) -> Result[Bytes, String] {
  if values.length() > 0 {
    return @input.make_sample_array_bytes_le(values, bits_per_component)
  }
  let empty : Array[Byte] = []
  Ok(Bytes::from_iter(empty.iter()))
}

///|
fn wrap_single_component_decode(
  decoded : DecodeSamplesResult,
) -> DecodeAllComponentsResult {
  {
    num_components: 1,
    sample_layout: "components:planar:le:wrapped:\{decoded.sample_layout}",
    components: [
      {
        component_index: 0,
        width: decoded.width,
        height: decoded.height,
        bits_per_component: decoded.bits_per_component,
        is_signed: decoded.is_signed,
        sample_layout: "component0:raster:le:wrapped:\{decoded.sample_layout}",
        samples: decoded.samples,
      },
    ],
  }
}

///|
fn finalize_component_planes_result(
  planes : Array[DecodeComponentPlaneInternal],
  layout : String,
) -> Result[DecodeAllComponentsResult, String] {
  let components : Array[DecodeSamplesComponentResult] = []
  for plane in planes {
    if plane.width > 0 &&
      plane.height > 0 &&
      plane.samples.length() != plane.width * plane.height {
      return Err(
        "decode_samples_all_components sample count mismatch for component \{plane.component_index}",
      )
    }
    let sample_bytes_v = build_component_sample_bytes(
      plane.samples,
      plane.bits_per_component,
    )
    guard sample_bytes_v is Ok(sample_bytes) else {
      return Err(
        "decode_samples_all_components failed to build sample buffer for component \{plane.component_index}",
      )
    }
    components.push({
      component_index: plane.component_index,
      width: plane.width,
      height: plane.height,
      bits_per_component: plane.bits_per_component,
      is_signed: plane.is_signed,
      sample_layout: "component\{plane.component_index}:raster:le:\{layout}",
      samples: sample_bytes,
    })
  }
  Ok({
    num_components: components.length(),
    sample_layout: "components:planar:le:\{layout}",
    components,
  })
}

///|
fn collect_component_precision_bits(
  stream : @core.Codestream,
  num_components : Int,
  fallback_bits : Int,
) -> Array[Int] {
  let bits : Array[Int] = []
  if stream.metadata.siz is Some(siz_meta) {
    for ci in 0..<num_components {
      if ci < siz_meta.components.length() {
        bits.push(siz_meta.components[ci].precision_bits)
      } else {
        bits.push(fallback_bits)
      }
    }
    return bits
  }
  for _ in 0..<num_components {
    bits.push(fallback_bits)
  }
  bits
}

///|
fn collect_component_signed_flags(
  stream : @core.Codestream,
  num_components : Int,
  fallback_signed : Bool,
) -> Array[Bool] {
  let signs : Array[Bool] = []
  if stream.metadata.siz is Some(siz_meta) {
    for ci in 0..<num_components {
      if ci < siz_meta.components.length() {
        signs.push(siz_meta.components[ci].is_signed)
      } else {
        signs.push(fallback_signed)
      }
    }
    return signs
  }
  for _ in 0..<num_components {
    signs.push(fallback_signed)
  }
  signs
}

///|
fn clamp_float_component_output(
  values : Array[Double],
  bits_per_component : Int,
  is_signed : Bool,
) -> Array[Int] {
  let dc_offset = if is_signed { 0 } else { 1 << (bits_per_component - 1) }
  // Upstream `store` clamps the float32 sample to [lo - shift, hi - shift]
  // before rounding. That range is [-2^(prec-1), 2^(prec-1) - 1] for both
  // signednesses, and `!(v >= lo)` maps NaN to the lower bound.
  let half = 1 << (bits_per_component - 1)
  let lo_f = Float::from_double((-half).to_double())
  let hi_f = Float::from_double((half - 1).to_double())
  let output : Array[Int] = []
  for value in values {
    let mut vf = Float::from_double(value)
    if !(vf >= lo_f) {
      vf = lo_f
    } else if vf > hi_f {
      vf = hi_f
    }
    // The clamp above bounds the sample up to 24-bit precision. Above that
    // float32(2^(prec-1) - 1) rounds up and upstream emits one past the
    // maximum, so the final clamp keeps the sample in range.
    output.push(
      clamp_sample_for_signedness(
        @math.round_half_away_f32(vf.to_double()) + dc_offset,
        is_signed,
        precision_bits=bits_per_component,
      ),
    )
  }
  output
}

///|
fn clamp_int_component_output(
  values : Array[Int],
  bits_per_component : Int,
  is_signed : Bool,
) -> Array[Int] {
  let dc_offset = if is_signed { 0 } else { 1 << (bits_per_component - 1) }
  let output : Array[Int] = []
  for value in values {
    output.push(
      clamp_sample_for_signedness(
        value + dc_offset,
        is_signed,
        precision_bits=bits_per_component,
      ),
    )
  }
  output
}
