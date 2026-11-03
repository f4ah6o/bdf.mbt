///|
pub fn decode(data : Bytes) -> ImageData raise DecodeError {
  match @decoder.decode_samples(data) {
    Ok(result) =>
      {
        width: result.width,
        height: result.height,
        num_components: result.num_components,
        bits_per_component: result.bits_per_component,
        is_signed: result.is_signed,
        data: result.samples,
      }
    Err(msg) => raise DecodeFailed(msg)
  }
}

///|
fn wrap_decode_samples_result(
  result : @orchestrate.DecodeSamplesResult,
) -> DecodeSamplesResult {
  {
    width: result.width,
    height: result.height,
    num_components: result.num_components,
    bits_per_component: result.bits_per_component,
    is_signed: result.is_signed,
    sample_layout: result.sample_layout,
    samples: result.samples,
  }
}

///|
pub fn decode_with_layout(data : Bytes) -> (ImageData, String) raise DecodeError {
  match decode_samples(data) {
    Ok(result) =>
      (
        {
          width: result.width,
          height: result.height,
          num_components: result.num_components,
          bits_per_component: result.bits_per_component,
          is_signed: result.is_signed,
          data: result.samples,
        },
        result.sample_layout,
      )
    Err(msg) => raise DecodeFailed(msg)
  }
}

///|
pub fn decode_all_components(data : Bytes) -> (ImageData, String) raise DecodeError {
  match @decoder.decode_samples_all_components_debug(data) {
    Ok(result) => {
      if result.components.is_empty() {
        raise DecodeFailed("JPEG 2000 image has no components")
      }
      let first = result.components[0]
      let samples : Array[Byte] = []
      for component in result.components {
        samples.append(component.samples.to_array())
      }
      (
        {
          width: first.width,
          height: first.height,
          num_components: result.num_components,
          bits_per_component: first.bits_per_component,
          is_signed: first.is_signed,
          data: Bytes::from_array(samples),
        },
        "components:planar:le",
      )
    }
    Err(msg) => raise DecodeFailed(msg)
  }
}

///|
fn decode_samples(data : Bytes) -> Result[DecodeSamplesResult, String] {
  match @decoder.decode_samples(data) {
    Ok(result) => Ok(wrap_decode_samples_result(result))
    Err(msg) => Err(msg)
  }
}

///|
fn decode_samples_audit(
  data : Bytes,
  packet_audit_limit? : Int = 300,
  force_relocated_ppt? : Bool = false,
) -> Result[DecodeSamplesResult, String] {
  match
    @decoder.decode_samples_audit(
      data,
      packet_audit_limit~,
      force_relocated_ppt~,
    ) {
    Ok(result) => Ok(wrap_decode_samples_result(result))
    Err(msg) => Err(msg)
  }
}
