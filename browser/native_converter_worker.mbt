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
  #|(name) => /\.(?:mid|midi|smf|kar|rmi|xlsx|xlsm|xltx|xltm|dxf|drawio|dio|docx|docm|dotx|dotm|cgm|cgz|pptx|pptm|ppsx|ppsm|potx|potm|plt|hpgl|hgl|hpg|hp2|rtl|p21|p2z|sfc|jww|kicad_sch|kicad_pcb|kicad_pro|pdf|mhtml|mht|parquet|parq|pqt|ttf|otf|ttc|otc|woff|woff2|musicxml|mxl|mml|gbr|ger|gtl|gbl|gto|gbo|gts|gbs|gtp|gbp|gko|gml|gm1|g1|g2|g3|g4|gp1|gp2|pho|art|cmp|sol|plc|pls|stc|sts|crc|crs|drl|drd|xln|exc|zip)$/i.test(name)

///|
extern "js" fn native_converter_formats(request : ConverterRequest) -> Unit =
  #|(request) => self.postMessage({id:0,ok:true,formats:[{name:'csv',description:'CSV or TSV (comma-, tab-, semicolon- or bar-separated values)',extensions:['.csv','.tsv','.tab']},{name:'xlsx',description:'Excel workbook (limited worksheet subset)',extensions:['.xlsx']},{name:'docx',description:'Word document (limited text layout)',extensions:['.docx']},{name:'pptx',description:'PowerPoint presentation (limited shape and text layout)',extensions:['.pptx']},{name:'font',description:'Font file (TrueType, OpenType, WOFF)',extensions:['.ttf','.otf','.ttc','.otc','.woff','.woff2']},{name:'midi',description:'Standard MIDI File',extensions:['.mid','.midi','.smf','.kar','.rmi']},{name:'mml',description:'Music Macro Language (MML)',extensions:['.mml']},{name:'musicxml',description:'MusicXML score',extensions:['.musicxml','.mxl']},{name:'pdf',description:'PDF document (checked subset)',extensions:['.pdf']},{name:'image',description:'Image stored as it is: PNG, JPEG, GIF, WebP, AVIF, BMP, ICO or SVG',extensions:['.png','.apng','.jpg','.jpeg','.jpe','.jfif','.gif','.webp','.avif','.bmp','.ico','.svg']},{name:'ai',description:'Adobe Illustrator artwork',extensions:['.ai']},{name:'tiff',description:'TIFF image, one page or more',extensions:['.tif','.tiff']},{name:'psd',description:'Photoshop document',extensions:['.psd','.psb']},{name:'emf',description:'Windows metafile',extensions:['.emf','.wmf']},{name:'idml',description:'InDesign document (IDML)',extensions:['.idml']},{name:'visio',description:'Visio drawing',extensions:['.vsdx','.vsdm','.vstx','.vstm']},{name:'markdown',description:'Markdown document (CommonMark/GFM scroll view)',extensions:['.md','.markdown','.mdown','.mkd','.mdx']},{name:'html',description:'HTML document (reader mode)',extensions:['.html','.htm','.xhtml']},{name:'epub',description:'EPUB publication (reader mode)',extensions:['.epub']},{name:'audio',description:'Audio file (MP3, AAC, M4A, FLAC, Ogg Vorbis/Opus, WAV, AIFF)',extensions:['.mp3','.m4a','.m4b','.m4p','.aac','.flac','.ogg','.oga','.opus','.spx','.wav','.wave','.aif','.aiff','.aifc']},{name:'hpgl',description:'HP-GL/2 plot file (PCL/HP RTL raster not supported)',extensions:['.plt','.hpgl','.hgl','.hpg','.hp2','.rtl']},{name:'jww',description:'Jw_cad drawing',extensions:['.jww']},{name:'dxf',description:'AutoCAD DXF drawing (text and binary; model space)',extensions:['.dxf']},{name:'sxf',description:'SXF drawing (SFC; P21/P2Z not yet supported)',extensions:['.sfc','.p21','.p2z']},{name:'cgm',description:'Computer Graphics Metafile (binary)',extensions:['.cgm','.cgz']},{name:'gerber',description:'Gerber / Excellon fabrication data (single files)',extensions:['.gbr','.ger','.gtl','.gbl','.gto','.gbo','.gts','.gbs','.gtp','.gbp','.gko','.drl','.drd','.xln','.exc']},{name:'kicad',description:'KiCad board front view (schematics not yet supported)',extensions:['.kicad_pcb','.kicad_sch']},{name:'drawio',description:'draw.io diagram (practical shape subset)',extensions:['.drawio','.dio','.drawio.svg','.drawio.png']},{name:'parquet',description:'Apache Parquet table',extensions:['.parquet','.parq','.pqt']}]})

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
extern "js" fn native_converter_page_result(
  request : ConverterRequest,
  data : Bytes,
) -> Unit =
  #|(request,bdf) => self.postMessage({id:Number(request.id),ok:true,result:{bdf,warnings:[]}},[bdf.buffer])

///|
extern "js" fn native_converter_stream_open(
  request : ConverterRequest,
  bdf : Bytes,
  format : String,
  summary : String,
  warnings : Array[String],
  pages : Int32,
  stream_id : Int32,
) -> Unit =
  #|(request,bdf,format,summary,warnings,pages,stream_id) => {const result={bdf,format,summary,warnings,protected:false,pages,stream:Number(stream_id)};self.postMessage({id:Number(request.id),ok:true,result})}

///|
extern "js" fn native_converter_request_page(
  request : ConverterRequest,
) -> Int32 =
  #|(request) => Number(request.index)||0

///|
priv struct NativeStream {
  bdf : Bytes
  pages : Int32
  format : String
  summary : String
  warnings : Array[String]
}

///|
priv struct NativeConverterState {
  mut ready : Bool
  streams : Map[Int32, NativeStream]
  mut next_stream : Int32
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
    let id = converter_request_stream(request)
    self.streams.remove(id)
    converter_reply_value(request, converter_null_value())
    return
  }
  if kind == "finish" {
    let id = converter_request_stream(request)
    match self.streams.get(id) {
      Some(stream) =>
        native_converter_result(
          request,
          Bytes::makei(stream.bdf.length(), i => stream.bdf[i]),
          stream.format,
          stream.summary,
          stream.warnings,
          false,
        )
      None =>
        converter_reply_error(
          request,
          "no conversion " + converter_stream_name(request),
        )
    }
    return
  }
  if kind == "page" {
    let id = converter_request_stream(request)
    match self.streams.get(id) {
      Some(stream) => {
        let index = native_converter_request_page(request).to_int64() + 1L
        let bdf = @core.select_pages(stream.bdf, [index]) catch {
          _ => stream.bdf
        }
        native_converter_page_result(request, bdf)
      }
      None =>
        converter_reply_error(
          request,
          "no conversion " + converter_stream_name(request),
        )
    }
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
  if format != "" &&
    format != "image" &&
    format != "csv" &&
    format != "xlsx" &&
    format != "docx" &&
    format != "pptx" &&
    format != "font" &&
    format != "midi" &&
    format != "mml" &&
    format != "pdf" &&
    format != "ai" &&
    format != "tiff" &&
    format != "psd" &&
    format != "emf" &&
    format != "idml" &&
    format != "visio" &&
    format != "markdown" &&
    format != "html" &&
    format != "epub" &&
    format != "audio" &&
    format != "hpgl" &&
    format != "jww" &&
    format != "dxf" &&
    format != "sxf" &&
    format != "cgm" &&
    format != "gerber" &&
    format != "kicad" &&
    format != "drawio" &&
    format != "parquet" &&
    format != "musicxml" {
    native_converter_error(request, "unknown format \"" + format + "\"", "")
    return
  }
  let name = native_converter_option(request, "name")
  let data = native_converter_data(request)
  if format == "midi" || (format == "" && @midi.detect(data)) {
    native_convert_music(request, data, kind == "open", database, false, false)
    return
  }
  let head = data[:if data.length() < 1024 { data.length() } else { 1024 }].to_owned()
  if format == "mml" || (format == "" && @mml.detect_mml(head)) {
    native_convert_music(request, data, kind == "open", database, true, false)
    return
  }
  if format == "musicxml" || (format == "" && @musicxml.detect(data)) {
    native_convert_music(request, data, kind == "open", database, false, true)
    return
  }
  if format == "ai" || (format == "" && @ai.kind(data) != "") {
    native_convert_ai(self, request, data, kind == "open")
    return
  }
  if format == "visio" || (format == "" && @visio.detect(data)) {
    native_convert_visio(self, request, data, kind == "open")
    return
  }
  if format == "idml" || (format == "" && @idml.detect(data)) {
    native_convert_idml(self, request, data, kind == "open")
    return
  }
  if format == "pdf" || (format == "" && @pdf.detect(data)) {
    native_convert_pdf(self, request, data, kind == "open")
    return
  }
  if format == "docx" || (format == "" && @docx.detect(data)) {
    native_convert_docx(self, request, data, kind == "open")
    return
  }
  if format == "pptx" || (format == "" && @pptx.detect(data)) {
    native_convert_pptx(self, request, data, kind == "open")
    return
  }
  if format == "xlsx" {
    native_convert_xlsx(request, data, kind == "open", database)
    return
  }
  if format == "csv" {
    native_convert_csv(request, data, name, kind == "open", database)
    return
  }
  if format == "font" || (format == "" && @font.detect(data)) {
    native_convert_font(request, data, kind == "open", database)
    return
  }
  if format == "tiff" || (format == "" && @tiff.detect(data)) {
    native_convert_tiff(self, request, data, kind == "open")
    return
  }
  if format == "psd" || (format == "" && @psd.detect(data)) {
    native_convert_psd(self, request, data, kind == "open")
    return
  }
  if format == "emf" || (format == "" && @emf.detect(data)) {
    native_convert_emf(request, data, kind == "open")
    return
  }
  if format == "hpgl" || (format == "" && @hpgl.detect(head)) {
    native_convert_hpgl(self, request, data, kind == "open", database)
    return
  }
  if format == "jww" || (format == "" && @jww.detect(data)) {
    native_convert_jww(request, data, kind == "open", database)
    return
  }
  if format == "dxf" || (format == "" && @dxf.detect(data)) {
    native_convert_dxf(request, data, kind == "open", database)
    return
  }
  if format == "sxf" || (format == "" && @sxf.detect(data)) {
    native_convert_sxf(request, data, kind == "open", database)
    return
  }
  if format == "cgm" || (format == "" && @cgm.detect(data)) {
    native_convert_cgm(request, data, kind == "open", database)
    return
  }
  if format == "gerber" || (format == "" && @gerber.detect(data)) {
    native_convert_gerber(request, data, kind == "open", database)
    return
  }
  if format == "kicad" || (format == "" && @kicad.detect(data)) {
    native_convert_kicad(request, data, kind == "open", database)
    return
  }
  if format == "drawio" || (format == "" && @drawio.detect(data)) {
    native_convert_drawio(request, data, kind == "open", database)
    return
  }
  if format == "parquet" || (format == "" && @parquet.detect(data)) {
    native_convert_parquet(request, data, kind == "open", database)
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
        let midi_named = lower.has_suffix(".mid") ||
          lower.has_suffix(".midi") ||
          lower.has_suffix(".smf") ||
          lower.has_suffix(".kar") ||
          lower.has_suffix(".rmi")
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
        if lower.has_suffix(".xlsx") && !strong_other {
          native_convert_xlsx(request, data, kind == "open", database)
          return
        }
        if midi_named && !strong_other {
          native_convert_music(request, data, kind == "open", database, false, false)
          return
        }
        if lower.has_suffix(".mml") && !strong_other {
          native_convert_music(request, data, kind == "open", database, true, false)
          return
        }
        if (lower.has_suffix(".musicxml") || lower.has_suffix(".mxl")) &&
          !strong_other {
          native_convert_music(request, data, kind == "open", database, false, true)
          return
        }
        if font_named && !strong_other {
          native_convert_font(request, data, kind == "open", database)
          return
        }
        if (lower.has_suffix(".mp3") || lower.has_suffix(".m4a") ||
          lower.has_suffix(".m4b") || lower.has_suffix(".m4p") ||
          lower.has_suffix(".aac") || lower.has_suffix(".flac") ||
          lower.has_suffix(".ogg") || lower.has_suffix(".oga") ||
          lower.has_suffix(".opus") || lower.has_suffix(".spx") ||
          lower.has_suffix(".wav") || lower.has_suffix(".wave") ||
          lower.has_suffix(".aif") || lower.has_suffix(".aiff") ||
          lower.has_suffix(".aifc")) && !strong_other {
          native_convert_audio(request, data, kind == "open")
          return
        }
        if lower.has_suffix(".epub") && !strong_other {
          native_convert_epub(self, request, data, kind == "open")
          return
        }
        if (lower.has_suffix(".html") || lower.has_suffix(".htm") ||
          lower.has_suffix(".xhtml")) && !strong_other {
          native_convert_html(self, request, data, kind == "open")
          return
        }
        if (lower.has_suffix(".md") || lower.has_suffix(".markdown") ||
          lower.has_suffix(".mdown") || lower.has_suffix(".mkd") ||
          lower.has_suffix(".mdx")) && !strong_other {
          native_convert_markdown(self, request, data, kind == "open")
          return
        }
        if (lower.has_suffix(".vsdx") || lower.has_suffix(".vsdm") ||
          lower.has_suffix(".vstx") || lower.has_suffix(".vstm")) &&
          !strong_other {
          native_convert_visio(self, request, data, kind == "open")
          return
        }
        if lower.has_suffix(".idml") && !strong_other {
          native_convert_idml(self, request, data, kind == "open")
          return
        }
        let parquet_named = lower.has_suffix(".parquet") || lower.has_suffix(".parq") || lower.has_suffix(".pqt")
        if parquet_named && !strong_other {
          native_convert_parquet(request, data, kind == "open", database)
          return
        }
        let drawio_named = lower.has_suffix(".drawio") || lower.has_suffix(".dio") ||
          lower.has_suffix(".drawio.svg") || lower.has_suffix(".drawio.png")
        if drawio_named && !strong_other {
          native_convert_drawio(request, data, kind == "open", database)
          return
        }
        let kicad_named = lower.has_suffix(".kicad_pcb") || lower.has_suffix(".kicad_sch")
        if kicad_named && !strong_other {
          native_convert_kicad(request, data, kind == "open", database)
          return
        }
        let gerber_named = lower.has_suffix(".gbr") ||
          lower.has_suffix(".ger") ||
          lower.has_suffix(".gtl") ||
          lower.has_suffix(".gbl") ||
          lower.has_suffix(".drl") ||
          lower.has_suffix(".xln")
        if gerber_named && !strong_other {
          native_convert_gerber(request, data, kind == "open", database)
          return
        }
        let cgm_named = lower.has_suffix(".cgm") || lower.has_suffix(".cgz")
        if cgm_named && !strong_other {
          native_convert_cgm(request, data, kind == "open", database)
          return
        }
        let sxf_named = lower.has_suffix(".sfc") ||
          lower.has_suffix(".p21") ||
          lower.has_suffix(".p2z")
        if sxf_named && !strong_other {
          native_convert_sxf(request, data, kind == "open", database)
          return
        }
        let dxf_named = lower.has_suffix(".dxf")
        if dxf_named && !strong_other {
          native_convert_dxf(request, data, kind == "open", database)
          return
        }
        let jww_named = lower.has_suffix(".jww")
        if jww_named && !strong_other {
          native_convert_jww(request, data, kind == "open", database)
          return
        }
        let hpgl_named = lower.has_suffix(".plt") ||
          lower.has_suffix(".hpgl") ||
          lower.has_suffix(".hgl") ||
          lower.has_suffix(".hpg") ||
          lower.has_suffix(".hp2") ||
          lower.has_suffix(".rtl")
        if hpgl_named && !strong_other {
          native_convert_hpgl(self, request, data, kind == "open", database)
          return
        }
        let ai_named = lower.has_suffix(".ai")
        let tiff_named = lower.has_suffix(".tif") || lower.has_suffix(".tiff")
        let psd_named = lower.has_suffix(".psd") || lower.has_suffix(".psb")
        let emf_named = lower.has_suffix(".emf") || lower.has_suffix(".wmf")
        if ai_named && !strong_other {
          native_convert_ai(self, request, data, kind == "open")
          return
        }
        if tiff_named && !strong_other {
          native_convert_tiff(self, request, data, kind == "open")
          return
        }
        if psd_named && !strong_other {
          native_convert_psd(self, request, data, kind == "open")
          return
        }
        if emf_named && !strong_other {
          native_convert_emf(request, data, kind == "open")
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
          no_woff2=true,
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
fn native_stream_multipage(
  state : NativeConverterState,
  request : ConverterRequest,
  bdf : Bytes,
  format : String,
  summary : String,
  warnings : Array[String],
  pages : Int32,
  opened : Bool,
) -> Unit {
  if opened && native_converter_option(request, "pages") == "" && pages > 0 {
    let id = state.next_stream
    state.next_stream += 1
    state.streams[id] = { bdf, pages, format, summary, warnings, }
    native_converter_stream_open(request, bdf, format, summary, warnings, pages, id)
  } else {
    native_converter_result(request, bdf, format, summary, warnings, false)
  }
}

///|
fn native_convert_ai(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let result = @ai.convert(
    data,
    box=native_converter_param(request, "box"),
    title=native_converter_param(request, "title"),
    no_text_index=native_converter_param(request, "no_text_index") == "true",
    no_share_prefix=native_converter_param(request, "no_share_prefix") == "true",
  ) catch {
    @ai.AiInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  native_stream_multipage(
    state, request, bdf, "ai", result.summary, result.warnings, result.pages, opened,
  )
}

///|
fn native_tiff_message(message : String) -> String {
  if message.has_prefix("TIFF: ") {
    "tiff: " + message[6:].to_string()
  } else if message.has_prefix("tiff: ") {
    message
  } else {
    "tiff: " + message
  }
}

///|
fn native_convert_html(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let result = @html.convert(
    data,
    title=native_converter_param(request, "title"),
  ) catch {
    @html.HtmlInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  native_stream_multipage(
    state, request, bdf, "html", result.summary, result.warnings, result.pages,
    opened,
  )
}

///|
fn native_convert_audio(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let play_text = native_converter_param(request, "play")
  let play = if play_text == "" {
    true
  } else {
    match play_text.to_lower() {
      "true" | "1" | "yes" | "on" => true
      "false" | "0" | "no" | "off" => false
      _ => {
        native_converter_error(
          request,
          "audio: parameter play: \"" + play_text + "\" is not a boolean",
          "",
        )
        return
      }
    }
  }
  let result = @audio.convert(
    data,
    title=native_converter_param(request, "title"),
    file_name=native_converter_param(request, "name"),
    play~,
  ) catch {
    @audio.AudioInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  native_converter_result(
    request, result.bdf, "audio", result.summary, result.warnings, opened,
  )
}

///|
fn native_convert_epub(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let result = @epub.convert(
    data,
    title=native_converter_param(request, "title"),
  ) catch {
    @epub.EpubInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  native_stream_multipage(
    state, request, bdf, "epub", result.summary, result.warnings, result.pages,
    opened,
  )
}

///|
fn native_convert_markdown(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let result = @markdown.convert(
    data,
    title=native_converter_param(request, "title"),
    size=@string.parse_double(native_converter_param(request, "size")) catch {
      _ => 0.0
    },
    width=@string.parse_double(native_converter_param(request, "width")) catch {
      _ => 0.0
    },
    font=native_converter_param(request, "font"),
    mono=native_converter_param(request, "mono"),
  ) catch {
    @markdown.MarkdownInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  native_stream_multipage(
    state, request, bdf, "markdown", result.summary, result.warnings,
    result.pages, opened,
  )
}

///|
fn native_convert_visio(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let result = @visio.convert(
    data,
    title=native_converter_param(request, "title"),
  ) catch {
    @visio.VisioInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  native_stream_multipage(
    state, request, bdf, "visio", result.summary, result.warnings, result.pages,
    opened,
  )
}

///|
fn native_convert_idml(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let result = @idml.convert(
    data,
    title=native_converter_param(request, "title"),
  ) catch {
    @idml.IdmlInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  native_stream_multipage(
    state, request, bdf, "idml", result.summary, result.warnings, result.pages,
    opened,
  )
}

///|
fn native_convert_tiff(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let dpi_text = native_converter_param(request, "dpi")
  let dpi = if dpi_text == "" {
    0.0
  } else {
    @string.parse_double(dpi_text) catch {
      _ => {
        native_converter_error(
          request,
          "parameter dpi: \"" + dpi_text + "\" is not a positive number",
          "",
        )
        return
      }
    }
  }
  if dpi_text != "" && !(dpi > 0.0) {
    native_converter_error(
      request,
      "parameter dpi: \"" + dpi_text + "\" is not a positive number",
      "",
    )
    return
  }
  let result = @tiff.convert(
    data,
    title=native_converter_param(request, "title"),
    dpi~,
  ) catch {
    @tiff.TiffInvalid(message) => {
      native_converter_error(request, native_tiff_message(message), "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  native_stream_multipage(
    state, request, bdf, "tiff", result.summary, result.warnings, result.pages,
    opened,
  )
}

///|
fn native_convert_psd(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let artboards_text = native_converter_param(request, "artboards")
  let artboards = if artboards_text == "" {
    true
  } else {
    match artboards_text.to_lower() {
      "true" | "1" | "yes" | "on" => true
      "false" | "0" | "no" | "off" => false
      _ => {
        native_converter_error(
          request,
          "parameter artboards: \"" + artboards_text + "\" is not a boolean",
          "",
        )
        return
      }
    }
  }
  let result = @psd.convert(
    data,
    title=native_converter_param(request, "title"),
    artboards~,
  ) catch {
    @psd.PsdInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  native_stream_multipage(
    state, request, bdf, "psd", result.summary, result.warnings, result.pages,
    opened,
  )
}

///|
fn native_convert_emf(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let result = @emf.convert(
    data,
    title=native_converter_param(request, "title"),
  ) catch {
    @emf.EmfInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  native_converter_result(
    request, result.bdf, "emf", result.summary, result.warnings, opened,
  )
}

///|
fn native_select_pages(
  request : ConverterRequest,
  bdf : Bytes,
  count : Int32,
) -> Bytes {
  let spec = native_converter_option(request, "pages")
  if spec == "" || count <= 0 {
    return bdf
  }
  let spans = @convert.parse_pages(spec) catch { _ => return bdf }
  let numbers = @convert.page_numbers(spans, count.to_int64()) catch {
    _ => return bdf
  }
  match numbers {
    Some(values) if !values.is_empty() =>
      @core.select_pages(bdf, values) catch {
        _ => bdf
      }
    _ => bdf
  }
}

///|
fn native_convert_hpgl(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
) -> Unit {
  let result = @hpgl.convert(
    data,
    title=native_converter_param(request, "title"),
    colors=native_converter_param(request, "colors"),
    no_text_index=native_converter_param(request, "no_text_index") == "true",
    db=database,
  ) catch {
    @hpgl.HpglInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  native_stream_multipage(
    state, request, bdf, "hpgl", result.summary, result.warnings, result.pages, opened,
  )
}

///|
fn native_convert_jww(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
) -> Unit {
  let result = @jww.convert(
    data,
    title=native_converter_param(request, "title"),
    colors=native_converter_param(request, "colors"),
    no_text_index=native_converter_param(request, "no_text_index") == "true",
    db=database,
  ) catch {
    @jww.JwwInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  native_converter_result(request, result.bdf, "jww", result.summary, result.warnings, opened)
}

///|
fn native_convert_dxf(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
) -> Unit {
  let result = @dxf.convert(
    data,
    title=native_converter_param(request, "title"),
    views=native_converter_param(request, "views"),
    light=native_converter_param(request, "light") == "true",
    no_text_index=native_converter_param(request, "no_text_index") == "true",
    db=database,
  ) catch {
    @dxf.DxfInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  native_converter_result(request, result.bdf, "dxf", result.summary, result.warnings, opened)
}

///|
fn native_convert_sxf(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
) -> Unit {
  let result = @sxf.convert(
    data,
    title=native_converter_param(request, "title"),
    light=native_converter_param(request, "light") == "true",
    no_text_index=native_converter_param(request, "no_text_index") == "true",
    db=database,
  ) catch {
    @sxf.SxfInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  native_converter_result(request, result.bdf, "sxf", result.summary, result.warnings, opened)
}

///|
fn native_convert_cgm(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
) -> Unit {
  let result = @cgm.convert(
    data,
    title=native_converter_param(request, "title"),
    no_text_index=native_converter_param(request, "no_text_index") == "true",
    db=database,
  ) catch {
    @cgm.CgmInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  native_converter_result(request, result.bdf, "cgm", result.summary, result.warnings, opened)
}

///|
fn native_convert_gerber(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
) -> Unit {
  let result = @gerber.convert(
    data,
    title=native_converter_param(request, "title"),
    db=database,
  ) catch {
    @gerber.GerberInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  native_converter_result(request, result.bdf, "gerber", result.summary, result.warnings, opened)
}

///|
fn native_convert_kicad(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
) -> Unit {
  let result = @kicad.convert(
    data,
    title=native_converter_param(request, "title"),
    db=database,
  ) catch {
    @kicad.KicadInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  native_converter_result(request, result.bdf, "kicad", result.summary, result.warnings, opened)
}

///|
fn native_convert_drawio(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
) -> Unit {
  let result = @drawio.convert(
    data,
    title=native_converter_param(request, "title"),
    db=database,
  ) catch {
    @drawio.DrawioInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  native_converter_result(request, result.bdf, "drawio", result.summary, result.warnings, opened)
}

///|
fn native_convert_parquet(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
) -> Unit {
  let _ = database
  let result = @parquet.convert(
    data,
    title=native_converter_param(request, "title"),
    no_text_index=native_converter_param(request, "no_text_index") == "true",
  ) catch {
    @parquet.ParquetInputInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  native_converter_result(request, result.bdf, "parquet", result.summary, result.warnings, opened)
}

///|
fn native_convert_pdf(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let password = match native_converter_param(request, "password") {
    "" => native_converter_option(request, "password")
    value => value
  }
  let result = @pdf.convert(
    data,
    box=native_converter_param(request, "box"),
    kind=native_converter_param(request, "kind"),
    title=native_converter_param(request, "title"),
    no_text_index=native_converter_param(request, "no_text_index") == "true",
    no_share_prefix=native_converter_param(request, "no_share_prefix") == "true",
    password~,
  ) catch {
    @pdf.PdfFailure(message) => {
      native_converter_error(request, "pdf: " + message, "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  if opened &&
    native_converter_option(request, "pages") == "" &&
    result.pages > 0 {
    let id = state.next_stream
    state.next_stream += 1
    state.streams[id] = {
      bdf,
      pages: result.pages,
      format: "pdf",
      summary: result.summary,
      warnings: result.warnings,
    }
    native_converter_stream_open(
      request,
      bdf,
      "pdf",
      result.summary,
      result.warnings,
      result.pages,
      id,
    )
  } else {
    native_converter_result(
      request,
      bdf,
      "pdf",
      result.summary,
      result.warnings,
      false,
    )
  }
}

///|
fn native_convert_docx(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let result = @docx.convert(
    data,
    title=native_converter_param(request, "title"),
  ) catch {
    @docx.DocxInvalid(message) => {
      native_converter_error(request, "docx: " + message, "")
      return
    }
    _ => {
      native_converter_error(request, "docx: conversion failed", "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  if opened &&
    native_converter_option(request, "pages") == "" &&
    result.pages > 0 {
    let id = state.next_stream
    state.next_stream += 1
    state.streams[id] = {
      bdf,
      pages: result.pages,
      format: "docx",
      summary: result.summary,
      warnings: result.warnings,
    }
    native_converter_stream_open(
      request,
      bdf,
      "docx",
      result.summary,
      result.warnings,
      result.pages,
      id,
    )
  } else {
    native_converter_result(
      request,
      bdf,
      "docx",
      result.summary,
      result.warnings,
      false,
    )
  }
}

///|
fn native_convert_pptx(
  state : NativeConverterState,
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
) -> Unit {
  let result = @pptx.convert(
    data,
    title=native_converter_param(request, "title"),
  ) catch {
    @pptx.PptxInvalid(message) => {
      native_converter_error(request, "pptx: " + message, "")
      return
    }
    _ => {
      native_converter_error(request, "pptx: conversion failed", "")
      return
    }
  }
  let bdf = native_select_pages(request, result.bdf, result.pages)
  if opened &&
    native_converter_option(request, "pages") == "" &&
    result.pages > 0 {
    let id = state.next_stream
    state.next_stream += 1
    state.streams[id] = {
      bdf,
      pages: result.pages,
      format: "pptx",
      summary: result.summary,
      warnings: result.warnings,
    }
    native_converter_stream_open(
      request,
      bdf,
      "pptx",
      result.summary,
      result.warnings,
      result.pages,
      id,
    )
  } else {
    native_converter_result(
      request,
      bdf,
      "pptx",
      result.summary,
      result.warnings,
      false,
    )
  }
}

///|
fn native_convert_xlsx(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
) -> Unit {
  let font_data = match database {
    Some(db) if db.faces().length() > 0 => Some(db.face(0).unwrap().font.data())
    _ => None
  }
  let result = try {
    match font_data {
      Some(font) => @xlsx.convert_plain_with_font(data, font)
      None => @xlsx.convert_plain_no_fonts(data)
    }
  } catch {
    @xlsx.InvalidXlsxInput(message) => {
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
    "xlsx",
    "\{result.sheets} sheet(s)",
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
    no_woff2: true,
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
fn native_convert_music(
  request : ConverterRequest,
  data : Bytes,
  opened : Bool,
  database : @fontdb.Database?,
  is_mml : Bool,
  is_musicxml : Bool,
) -> Unit {
  let tab = @music.parse_music_tab(native_converter_param(request, "tab")) catch {
    @music.InvalidMusicParameter(message) => {
      native_converter_error(request, message, "")
      return
    }
  }
  let source = if is_mml {
    "mml"
  } else if is_musicxml {
    "musicxml"
  } else {
    "midi"
  }
  let label = if is_mml || is_musicxml { source + ": " } else { "" }
  let dialect = if is_mml {
    native_converter_param(request, "dialect").to_lower()
  } else {
    ""
  }
  if dialect != "" &&
    dialect != "auto" &&
    dialect != "generic" &&
    dialect != "mabinogi" &&
    dialect != "ppmck" {
    native_converter_error(
      request,
      "mml: parameter dialect: " +
      Json::string(dialect).stringify() +
      " is not auto, generic, mabinogi or ppmck",
      "",
    )
    return
  }
  let octave_value = if is_mml {
    native_converter_param(request, "octave").to_lower()
  } else {
    ""
  }
  let octave = match octave_value {
    "" | "auto" => 0
    "normal" => 1
    "reverse" => 2
    _ => {
      native_converter_error(
        request,
        "mml: parameter octave: " +
        Json::string(octave_value).stringify() +
        " is not auto, normal or reverse",
        "",
      )
      return
    }
  }
  let program_value = if is_mml {
    native_converter_param(request, "program")
  } else {
    ""
  }
  let program = if program_value == "" {
    -1
  } else {
    let bytes = @utf8.encode(program_value)
    let mut i = if bytes.length() > 0 && (bytes[0] == b'+' || bytes[0] == b'-') {
      1
    } else {
      0
    }
    let mut valid = i < bytes.length()
    while i < bytes.length() {
      if bytes[i] < b'0' || bytes[i] > b'9' {
        valid = false
      }
      i += 1
    }
    let n = @string.parse_int64(program_value) catch {
      _ => {
        valid = false
        0L
      }
    }
    if !valid || n < 0L || n > 127L {
      native_converter_error(
        request,
        "mml: parameter program: " +
        Json::string(program_value).stringify() +
        " is not a number 0–127",
        "",
      )
      return
    }
    n.to_int()
  }
  let time_value = native_converter_param(request, "time")
  let time = if time_value == "" {
    None
  } else {
    Some(@music.parse_music_time(time_value)) catch {
      @music.InvalidMusicParameter(message) => {
        native_converter_error(
          request,
          label + message,
          "",
        )
        return
      }
    }
  }
  let key_value = native_converter_param(request, "key")
  let key = if key_value == "" {
    None
  } else {
    Some(@music.parse_music_key(key_value)) catch {
      @music.InvalidMusicParameter(message) => {
        native_converter_error(
          request,
          label + message,
          "",
        )
        return
      }
    }
  }
  let pages = @convert.parse_pages(native_converter_option(request, "pages")) catch {
    @convert.InvalidInput(message) => {
      native_converter_error(request, "convert: pages: " + message, "")
      return
    }
    error => {
      native_converter_error(
        request,
        "convert: pages: " + error.to_string(),
        "",
      )
      return
    }
  }
  let options : @midi.MidiScoreOptions = {
    page: { width: 0.0, height: 0.0, staff_space: 0.0, title: "", },
    pages: None,
    time,
    key,
    no_play: false,
    no_text_index: false,
    system_fonts: false,
    no_subset: false,
    ignore_restrictions: false,
    no_woff2: true,
  }
  let db = database.unwrap_or(@fontdb.Database::new())
  let result = try {
    if is_mml {
      @mml.convert(
        data,
        db,
        options~,
        dialect~,
        octave~,
        program~,
        guitar_tab=tab,
        page_ranges=pages,
      )
    } else if is_musicxml {
      @musicxml.convert(
        data,
        db,
        options~,
        guitar_tab=tab,
        page_ranges=pages,
      )
    } else {
      @midi.convert(data, db, options~, guitar_tab=tab, page_ranges=pages)
    }
  } catch {
    @mml.InvalidMmlInput(message) => {
      native_converter_error(request, message, "")
      return
    }
    @midi.InvalidMidiInput(message) => {
      native_converter_error(request, message, "")
      return
    }
    @musicxml.MusicXmlInvalid(message) => {
      native_converter_error(request, message, "")
      return
    }
    @music.InvalidMusicScore(message) => {
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
    source,
    result.summary(),
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
/// Install the MoonBit converter Worker for native image, CSV, font, MIDI and MML formats.
#export_name("bdf_install_native_converter_worker")
pub fn bdf_install_native_converter_worker() -> Unit {
  let state : NativeConverterState = {
    ready: false,
    streams: Map([]),
    next_stream: 0,
  }
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
