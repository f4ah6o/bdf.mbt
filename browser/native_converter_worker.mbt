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
  #|(request) => self.postMessage({id:0,ok:true,formats:[{name:'csv',description:'CSV or TSV (comma-, tab-, semicolon- or bar-separated values)',extensions:['.csv','.tsv','.tab']},{name:'font',description:'Font file (TrueType, OpenType, WOFF)',extensions:['.ttf','.otf','.ttc','.otc','.woff','.woff2']},{name:'image',description:'Image stored as it is: PNG, JPEG, GIF, WebP, AVIF, BMP, ICO or SVG',extensions:['.png','.apng','.jpg','.jpeg','.jpe','.jfif','.gif','.webp','.avif','.bmp','.ico','.svg']}]})

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
async fn NativeConverterState::dispatch(
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
  let url = native_converter_option(request, "fonts")
  let database = if url == "" {
    None
  } else {
    let directory = native_font_directory(url).wait()
    if !native_font_directory_ok(directory) {
      native_converter_error(
        request,
        native_font_directory_error(directory),
        "",
      )
      return
    }
    let db = @fontdb.Database::new()
    for index in 0..<native_font_directory_count(directory) {
      ignore(
        db.add_file(
          native_font_directory_name(directory, index),
          native_font_directory_bytes(directory, index),
        ),
      )
    }
    Some(db)
  }
  let format = native_converter_option(request, "format")
  if format != "" && format != "image" && format != "csv" && format != "font" {
    native_converter_error(request, "unknown format \"" + format + "\"", "")
    return
  }
  let name = native_converter_option(request, "name")
  let data = native_converter_data(request)
  if format == "csv" {
    native_convert_csv(request, data, name, kind == "open", database)
    return
  }
  if format == "font" || (format == "" && @font.detect(data)) {
    native_convert_font(request, data, kind == "open", database)
    return
  }
  let result = @image.convert(data, name~) catch {
    @image.ImageFailure(message) => {
      if format == "" &&
        message ==
        "image: input is not a supported BMP, ICO, JPEG, PNG, GIF, WebP, AVIF or SVG image" {
        let lower = name.to_lower()
        let font_named = lower.has_suffix(".ttf") ||
          lower.has_suffix(".otf") ||
          lower.has_suffix(".ttc") ||
          lower.has_suffix(".otc") ||
          lower.has_suffix(".woff") ||
          lower.has_suffix(".woff2")
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
        if font_named && !strong_other {
          native_convert_font(request, data, kind == "open", database)
          return
        }
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
          native_convert_csv(request, data, name, kind == "open", database)
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
  database : @fontdb.Database?,
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
  let convert = () => {
    match database {
      Some(db) =>
        @csv.convert_with_fonts(
          data,
          db,
          name~,
          charset=options.charset,
          delimiter=options.delimiter,
          quote=options.quote,
          header=options.header,
          data_mode=options.data_mode,
          table_style=options.table_style,
        )
      None =>
        @csv.convert_no_fonts(
          data,
          name~,
          charset=options.charset,
          delimiter=options.delimiter,
          quote=options.quote,
          header=options.header,
          data_mode=options.data_mode,
          table_style=options.table_style,
        )
    }
  }
  let result = convert() catch {
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
fn native_convert_font(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
) -> Unit {
  let example_limit = @font.parse_example_limit(
    native_converter_param(request, "examples"),
  ) catch {
    @font.InvalidFontInput(message) => {
      native_converter_error(request, message, "")
      return
    }
    error => {
      native_converter_error(request, error.to_string(), "")
      return
    }
  }
  let options = @font.SpecimenOptions::new()
  let options : @font.SpecimenOptions = {
    selection: native_converter_param(request, "font"),
    title: options.title,
    text: native_converter_param(request, "text"),
    examples: example_limit,
    system_fonts: options.system_fonts,
    no_subset: options.no_subset,
    ignore_restrictions: options.ignore_restrictions,
    no_text_index: options.no_text_index,
  }
  let db = database.unwrap_or(@fontdb.Database::new())
  let result = @font.convert(data, db, options~) catch {
    @font.InvalidFontInput(message) => {
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
    "font",
    result.summary,
    result.warnings,
    opened,
  )
}

///|
extern "js" fn install_native_converter_listener(
  dispatch : (ConverterRequest) -> @js_async.Promise[Unit],
) -> Unit =
  #|(dispatch) => {self.onmessage=event=>{const request=event.data;Promise.resolve().then(()=>dispatch(request)).catch(e=>{const id=request?.type==='init'?0:Number(request?.id);self.postMessage({id,ok:false,error:e?.message??String(e),code:e?.code})})}}

///|
/// Install the MoonBit converter Worker for native image, CSV and font formats.
#export_name("bdf_install_native_converter_worker")
pub fn bdf_install_native_converter_worker() -> Unit {
  let state : NativeConverterState = { ready: false, }
  install_native_converter_listener(request => {
    @js_async.Promise::from_async(() => state.dispatch(request))
  })
}

///|
/// Create a Worker backed by the MoonBit converter, with no Go runtime.
#export_name("bdf_create_native_converter")
pub fn bdf_create_native_converter(worker_url : String) -> BrowserConverter {
  bdf_create_converter(worker_url, "")
}
