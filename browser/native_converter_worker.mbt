///|
extern "js" fn native_converter_data(request : ConverterRequest) -> Bytes =
  #|(request) => new Uint8Array(request.data)

///|
extern "js" fn native_converter_option(
  request : ConverterRequest,
  name : String,
) -> String =
  #|(request,name) => typeof request.options?.[name]==='string'?request.options[name]:''

///|
extern "js" fn native_converter_formats(request : ConverterRequest) -> Unit =
  #|(request) => self.postMessage({id:0,ok:true,formats:[{name:'image',description:'Image stored as it is: BMP, ICO, JPEG, PNG, GIF or WebP',extensions:['.bmp','.ico','.jpg','.jpeg','.jpe','.jfif','.png','.apng','.gif','.webp']}]})

///|
extern "js" fn native_converter_result(
  request : ConverterRequest,
  data : Bytes,
  format : String,
  summary : String,
  warnings : Array[String],
  opened : Bool,
) -> Unit =
  #|(request,bdf,format,summary,warnings,opened) => {const result={bdf,format,summary,warnings,protected:false};if(opened)result.pages=0;self.postMessage({id:Number(request.id),ok:true,result},[bdf.buffer])}

///|
extern "js" fn native_converter_error(
  request : ConverterRequest,
  message : String,
  code : String,
) -> Unit =
  #|(request,error,code) => self.postMessage({id:Number(request.id),ok:false,error,...(code?{code}:{})})

///|
priv struct NativeConverterState {
  mut ready : Bool
}

///|
fn NativeConverterState::dispatch(
  self : NativeConverterState,
  request : ConverterRequest,
) -> Unit {
  let kind = converter_request_type(request)
  if kind == "init" {
    self.ready = true
    native_converter_formats(request)
    return
  }
  if !self.ready {
    converter_reply_error(request, "converter is not ready")
    return
  }
  if kind == "close" {
    converter_reply_value(request, converter_null_value())
    return
  }
  if kind == "page" || kind == "finish" {
    converter_reply_error(
      request,
      "no conversion " + converter_stream_name(request),
    )
    return
  }
  if kind != "convert" && kind != "open" {
    converter_reply_error(request, "unknown request " + kind)
    return
  }
  let format = native_converter_option(request, "format")
  if format != "" && format != "image" {
    native_converter_error(request, "unknown format \"" + format + "\"", "")
    return
  }
  if native_converter_option(request, "fonts") != "" {
    native_converter_error(
      request, "native converter does not yet support font URLs", "",
    )
    return
  }
  let name = native_converter_option(request, "name")
  let result = @image.convert(native_converter_data(request), name~) catch {
    @image.ImageFailure(message) => {
      let code = if format == "" &&
        message ==
        "image: input is not a supported BMP, ICO, JPEG, PNG, GIF or WebP image" {
        "unknown-format"
      } else {
        ""
      }
      native_converter_error(request, message, code)
      return
    }
    error => {
      native_converter_error(request, error.to_string(), "")
      return
    }
  }
  native_converter_result(
    request,
    result.bdf,
    result.format,
    result.summary,
    result.warnings,
    kind == "open",
  )
}

///|
extern "js" fn install_native_converter_listener(
  dispatch : (ConverterRequest) -> Unit,
) -> Unit =
  #|(dispatch) => {self.onmessage=event=>{const request=event.data;try{dispatch(request)}catch(e){const id=request?.type==='init'?0:Number(request?.id);self.postMessage({id,ok:false,error:e?.message??String(e),code:e?.code})}}}

///|
/// Install the MoonBit converter Worker. Currently supports BMP, ICO, JPEG, PNG, GIF and WebP.
#export_name("bdf_install_native_converter_worker")
pub fn bdf_install_native_converter_worker() -> Unit {
  let state : NativeConverterState = { ready: false, }
  install_native_converter_listener(request => state.dispatch(request))
}

///|
/// Create a Worker backed by the MoonBit converter, with no Go runtime.
#export_name("bdf_create_native_converter")
pub fn bdf_create_native_converter(worker_url : String) -> BrowserConverter {
  bdf_create_converter(worker_url, "")
}
