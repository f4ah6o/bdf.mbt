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
  #|(request) => self.postMessage({id:0,ok:true,formats:[{name:'image',description:'Image stored as it is: PNG, JPEG, GIF, WebP, AVIF, BMP, ICO or SVG',extensions:['.png','.apng','.jpg','.jpeg','.jpe','.jfif','.gif','.webp','.avif','.bmp','.ico','.svg']}]})

///|
// Page selections are parsed before selecting the format, even when the
// selected converter (such as image) does not use the selection.
extern "js" fn native_converter_pages_error(
  request : ConverterRequest,
) -> String =
  #|(request) => {const spec=typeof request.options?.pages==='string'?request.options.pages:'';const trim=s=>s.replace(/^[\u0009-\u000d\u0020\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]+|[\u0009-\u000d\u0020\u0085\u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000]+$/g,'');for(const entry of spec.split(',')){const part=trim(entry);if(!part)continue;const dash=part.indexOf('-');const number=s=>{s=trim(s);if(!/^\+?[0-9]+$/.test(s))return null;const n=BigInt(s);return n>0n&&n<=9223372036854775807n?n:null};const bad=s=>`bad page ${JSON.stringify(trim(s))} in ${JSON.stringify(part)}: pages are numbered from 1`;if(dash<0){if(number(part)===null)return bad(part);continue}const lo=part.slice(0,dash),hi=part.slice(dash+1);const from=trim(lo)?number(lo):1n,to=trim(hi)?number(hi):0n;if(from===null)return bad(lo);if(to===null)return bad(hi);if(to!==0n&&to<from)return `bad page range ${JSON.stringify(part)}: it ends before it starts`}return ''}

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
  let pages_error = native_converter_pages_error(request)
  if pages_error != "" {
    native_converter_error(request, kind + ": pages: " + pages_error, "")
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
        "image: input is not a supported BMP, ICO, JPEG, PNG, GIF, WebP, AVIF or SVG image" {
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
/// Install the MoonBit converter Worker for the native image formats.
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
