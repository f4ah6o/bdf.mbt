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
extern "js" fn native_converter_param(
  request : ConverterRequest,
  name : String,
) -> String =
  #|(request,name) => {const v=request.options?.params?.[name];return ['string','number','boolean'].includes(typeof v)?String(v):''}

///|
extern "js" fn native_unsupported_named_format(name : String) -> Bool =
  #|(name) => /\.(?:epub|emf|wmf|mid|midi|smf|kar|rmi|xlsx|xlsm|xltx|xltm|md|markdown|mdown|mkd|mdx|idml|mp3|m4a|m4b|m4p|aac|flac|ogg|oga|opus|spx|wav|wave|aif|aiff|aifc|dxf|vsdx|vsdm|vstx|vstm|drawio|dio|docx|docm|dotx|dotm|cgm|cgz|pptx|pptm|ppsx|ppsm|potx|potm|plt|hpgl|hgl|hpg|hp2|rtl|p21|p2z|sfc|tif|tiff|jww|kicad_sch|kicad_pcb|kicad_pro|pdf|html|htm|xhtml|mhtml|mht|psd|psb|parquet|parq|pqt|ttf|otf|ttc|otc|woff|woff2|musicxml|mxl|ai|mml|gbr|ger|gtl|gbl|gto|gbo|gts|gbs|gtp|gbp|gko|gml|gm1|g1|g2|g3|g4|gp1|gp2|pho|art|cmp|sol|plc|pls|stc|sts|crc|crs|drl|drd|xln|exc|zip)$/i.test(name)

///|
extern "js" fn native_converter_formats(request : ConverterRequest) -> Unit =
  #|(request) => self.postMessage({id:0,ok:true,formats:[{name:'csv',description:'CSV or TSV (comma-, tab-, semicolon- or bar-separated values)',extensions:['.csv','.tsv','.tab']},{name:'image',description:'Image stored as it is: PNG, JPEG, GIF, WebP, AVIF, BMP, ICO or SVG',extensions:['.png','.apng','.jpg','.jpeg','.jpe','.jfif','.gif','.webp','.avif','.bmp','.ico','.svg']}]})

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
  // Validate before selecting a format, even when it ignores page selection.
  ignore(@convert.parse_pages(native_converter_option(request, "pages"))) catch {
    @convert.InvalidInput(detail) => {
      native_converter_error(request, kind + ": pages: " + detail, "")
      return
    }
    error => {
      native_converter_error(
        request,
        kind + ": pages: " + error.to_string(),
        "",
      )
      return
    }
  }
  let format = native_converter_option(request, "format")
  if format != "" && format != "image" && format != "csv" {
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
  let data = native_converter_data(request)
  if format == "csv" {
    native_convert_csv(request, data, name, kind == "open")
    return
  }
  let result = @image.convert(data, name~) catch {
    @image.ImageFailure(message) => {
      if format == "" &&
        message ==
        "image: input is not a supported BMP, ICO, JPEG, PNG, GIF, WebP, AVIF or SVG image" {
        let lower = name.to_lower()
        let csv_named = lower.has_suffix(".csv") ||
          lower.has_suffix(".tsv") ||
          lower.has_suffix(".tab")
        let head = data[:if data.length() < 1024 {
          data.length()
        } else {
          1024
        }].to_owned()
        let strong_other = @hpgl.detect(head) ||
          @utf8.decode_lossy(head).contains("%PDF-")
        let csv_detected = if csv_named ||
          native_unsupported_named_format(name) ||
          strong_other {
          false
        } else {
          @csv.detect(data) catch {
            _ => false
          }
        }
        if !strong_other && (csv_named || csv_detected) {
          native_convert_csv(request, data, name, kind == "open")
          return
        }
      }
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
fn native_convert_csv(
  request : ConverterRequest,
  data : Bytes,
  file_name : String,
  opened : Bool,
) -> Unit {
  let params : Map[String, String] = Map([])
  for key in ["charset", "delimiter", "quote", "header", "data", "table"] {
    params[key] = native_converter_param(request, key)
  }
  let options = @csv.parse_params(params) catch {
    @csv.InvalidDialect(message) => {
      native_converter_error(request, message, "")
      return
    }
    error => {
      native_converter_error(request, error.to_string(), "")
      return
    }
  }
  let name = if file_name == "" { "" } else { @csv.sheet_name(file_name) }
  let result = @csv.convert_no_fonts(
    data,
    name~,
    charset=options.charset,
    delimiter=options.delimiter,
    quote=options.quote,
    header=options.header,
    data_mode=options.data_mode,
    table_style=options.table_style,
  ) catch {
    @csv.InvalidDialect(message) => {
      native_converter_error(request, message, "")
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
    "csv",
    @csv.summary(result.parsed),
    result.warnings,
    opened,
  )
}

///|
extern "js" fn install_native_converter_listener(
  dispatch : (ConverterRequest) -> Unit,
) -> Unit =
  #|(dispatch) => {self.onmessage=event=>{const request=event.data;try{dispatch(request)}catch(e){const id=request?.type==='init'?0:Number(request?.id);self.postMessage({id,ok:false,error:e?.message??String(e),code:e?.code})}}}

///|
/// Install the MoonBit converter Worker for native image and CSV formats.
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
