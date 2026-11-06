///|
pub(all) struct Media {
  size_name : String
  x : Int
  y : Int
  source : String
  typ : String
  color : String
  left : Int
  right : Int
  top : Int
  bottom : Int
}

///|
pub(all) struct Printer {
  mut uri : String
  mut uris : Array[String]
  mut auth : Array[String]
  mut security : Array[String]
  mut name : String
  mut info : String
  mut make_model : String
  mut location : String
  mut uuid : String
  mut device_id : String
  mut state : Int
  mut reasons : Array[String]
  mut state_message : String
  mut accepting_jobs : Bool
  mut versions : Array[String]
  mut operations : Array[Int]
  mut config_change_time : Int
  mut formats : Array[String]
  mut default_format : String
  mut pdf_versions : Array[String]
  mut media : Array[String]
  mut media_ready : Array[String]
  mut media_default : String
  mut media_sources : Array[String]
  mut media_types : Array[String]
  mut media_col : Bool
  mut media_col_db : Array[Media]
  mut sides : Array[String]
  mut sides_default : String
  mut color_modes : Array[String]
  mut color_mode_default : String
  mut qualities : Array[Int]
  mut quality_default : Int
  mut resolutions : Array[(Int, Int, Int)]
  mut resolution_default : (Int, Int, Int)?
  mut copies : (Int, Int)
  mut page_ranges : Bool
  mut scaling : Array[String]
  mut scaling_default : String
  mut number_up : Array[Int]
  mut orientations : Array[Int]
  mut document_handling : Array[String]
  mut finishings : Array[Int]
  mut finishings_default : Array[Int]
  mut output_bins : Array[String]
  mut output_bin_default : String
  mut pwg_raster_resolutions : Array[(Int, Int, Int)]
  mut pwg_raster_types : Array[String]
  mut pwg_raster_sheet_back : String
  mut urf : Array[String]
  mut pclm : Bool
  mut pclm_strip_height : Int
  mut pclm_back_side : String
  mut pclm_resolutions : Array[(Int, Int, Int)]
  mut pclm_compression : Array[String]
  mut job_password : Int
  mut job_password_encryption : Array[String]
  mut job_account_id : Bool
  mut job_accounting_user_id : Bool
  mut identify_actions : Array[String]
  mut job_creation_attrs : Array[String]
  mut attrs : Array[Attribute]
}

///|
pub fn parse_media(members : Array[Attribute]) -> Media {
  let get = fn(name : String) -> Attribute? { find_attr(members, name) }
  let text = fn(name : String) -> String {
    match get(name) {
      Some(attribute) => attribute.text()
      None => ""
    }
  }
  let number = fn(name : String) -> Int {
    match get(name) {
      Some(attribute) => attribute.int().unwrap_or(0)
      None => 0
    }
  }
  let mut x = 0
  let mut y = 0
  match get("media-size") {
    Some(attribute) =>
      match attribute.collections() {
        size => if size.length() > 0 {
          match find_attr(size[0], "x-dimension") {
            Some(dimension) => x = dimension.int().unwrap_or(0)
            None => ()
          }
          match find_attr(size[0], "y-dimension") {
            Some(dimension) => y = dimension.int().unwrap_or(0)
            None => ()
          }
        }
      }
    None => ()
  }
  {
    size_name: text("media-size-name"),
    x,
    y,
    source: text("media-source"),
    typ: text("media-type"),
    color: text("media-color"),
    left: number("media-left-margin"),
    right: number("media-right-margin"),
    top: number("media-top-margin"),
    bottom: number("media-bottom-margin"),
  }
}

///|
pub fn parse_printer(message : Message) -> Printer {
  let printer : Printer = {
    uri: "",
    uris: [],
    auth: [],
    security: [],
    name: "",
    info: "",
    make_model: "",
    location: "",
    uuid: "",
    device_id: "",
    state: 0,
    reasons: [],
    state_message: "",
    accepting_jobs: false,
    versions: [],
    operations: [],
    config_change_time: 0,
    formats: [],
    default_format: "",
    pdf_versions: [],
    media: [],
    media_ready: [],
    media_default: "",
    media_sources: [],
    media_types: [],
    media_col: false,
    media_col_db: [],
    sides: [],
    sides_default: "",
    color_modes: [],
    color_mode_default: "",
    qualities: [],
    quality_default: 0,
    resolutions: [],
    resolution_default: None,
    copies: (1, 1),
    page_ranges: false,
    scaling: [],
    scaling_default: "",
    number_up: [],
    orientations: [],
    document_handling: [],
    finishings: [],
    finishings_default: [],
    output_bins: [],
    output_bin_default: "",
    pwg_raster_resolutions: [],
    pwg_raster_types: [],
    pwg_raster_sheet_back: "",
    urf: [],
    pclm: false,
    pclm_strip_height: 0,
    pclm_back_side: "",
    pclm_resolutions: [],
    pclm_compression: [],
    job_password: 0,
    job_password_encryption: [],
    job_account_id: false,
    job_accounting_user_id: false,
    identify_actions: [],
    job_creation_attrs: [],
    attrs: [],
  }
  let group = match message.group(TAG_PRINTER) {
    Some(value) => value
    None => return printer
  }
  printer.attrs = group.attrs
  let strings = fn(name : String) -> Array[String] {
    match group.get(name) {
      Some(attribute) => attribute.strings()
      None => []
    }
  }
  let text = fn(name : String) -> String {
    match group.get(name) {
      Some(attribute) => attribute.text()
      None => ""
    }
  }
  let int = fn(name : String) -> Int {
    match group.get(name) {
      Some(attribute) => attribute.int().unwrap_or(0)
      None => 0
    }
  }
  let ints = fn(name : String) -> Array[Int] {
    match group.get(name) {
      Some(attribute) => attribute.ints()
      None => []
    }
  }
  let bool = fn(name : String) -> Bool {
    match group.get(name) {
      Some(attribute) => attribute.bool().unwrap_or(false)
      None => false
    }
  }
  let resolutions = fn(name : String) -> Array[(Int, Int, Int)] {
    match group.get(name) {
      Some(attribute) => attribute.resolutions()
      None => []
    }
  }
  printer.uris = strings("printer-uri-supported")
  printer.auth = strings("uri-authentication-supported")
  printer.security = strings("uri-security-supported")
  printer.name = text("printer-name")
  printer.info = text("printer-info")
  printer.make_model = text("printer-make-and-model")
  printer.location = text("printer-location")
  printer.uuid = text("printer-uuid")
  printer.device_id = text("printer-device-id")
  printer.state = int("printer-state")
  printer.reasons = strings("printer-state-reasons")
  printer.state_message = text("printer-state-message")
  printer.accepting_jobs = bool("printer-is-accepting-jobs")
  printer.versions = strings("ipp-versions-supported")
  printer.operations = ints("operations-supported")
  printer.config_change_time = int("printer-config-change-time")
  printer.formats = strings("document-format-supported")
  printer.default_format = text("document-format-default")
  printer.pdf_versions = strings("pdf-versions-supported")
  printer.media = strings("media-supported")
  printer.media_ready = strings("media-ready")
  printer.media_default = text("media-default")
  printer.media_sources = strings("media-source-supported")
  printer.media_types = strings("media-type-supported")
  printer.media_col = strings("media-col-supported").length() > 0
  match group.get("media-col-database") {
    Some(attribute) =>
      for members in attribute.collections() {
        printer.media_col_db.push(parse_media(members))
      }
    None => ()
  }
  printer.sides = strings("sides-supported")
  printer.sides_default = text("sides-default")
  printer.color_modes = strings("print-color-mode-supported")
  printer.color_mode_default = text("print-color-mode-default")
  printer.qualities = ints("print-quality-supported")
  printer.quality_default = int("print-quality-default")
  printer.resolutions = resolutions("printer-resolution-supported")
  let default_resolutions = resolutions("printer-resolution-default")
  if default_resolutions.length() > 0 {
    printer.resolution_default = Some(default_resolutions[0])
  }
  match group.get("copies-supported") {
    Some(attribute) =>
      match attribute.ranges() {
        ranges => if ranges.length() > 0 {
          printer.copies = ranges[0]
        }
      }
    None => ()
  }
  printer.page_ranges = bool("page-ranges-supported")
  printer.scaling = strings("print-scaling-supported")
  printer.scaling_default = text("print-scaling-default")
  printer.number_up = ints("number-up-supported")
  match group.get("number-up-supported") {
    Some(attribute) =>
      for range in attribute.ranges() {
        let mut n = range.0
        while n <= range.1 && n <= 16 {
          printer.number_up.push(n)
          n += 1
        }
      }
    None => ()
  }
  printer.orientations = ints("orientation-requested-supported")
  printer.document_handling = strings("multiple-document-handling-supported")
  printer.finishings = ints("finishings-supported")
  printer.finishings_default = ints("finishings-default")
  printer.output_bins = strings("output-bin-supported")
  printer.output_bin_default = text("output-bin-default")
  printer.pwg_raster_resolutions = resolutions("pwg-raster-document-resolution-supported")
  printer.pwg_raster_types = strings("pwg-raster-document-type-supported")
  printer.pwg_raster_sheet_back = text("pwg-raster-document-sheet-back")
  printer.urf = strings("urf-supported")
  printer.pclm = group.get("pclm-strip-height-preferred") is Some(_)
  printer.pclm_strip_height = int("pclm-strip-height-preferred")
  printer.pclm_back_side = text("pclm-raster-back-side")
  printer.pclm_resolutions = resolutions("pclm-source-resolution-supported")
  printer.pclm_compression = strings("pclm-compression-method-preferred")
  printer.job_password = int("job-password-supported")
  printer.job_password_encryption = strings("job-password-encryption-supported")
  printer.job_account_id = group.get("job-account-id-supported") is Some(_)
  printer.job_accounting_user_id = group.get("job-accounting-user-id-supported") is Some(_)
  printer.identify_actions = strings("identify-actions-supported")
  printer.job_creation_attrs = strings("job-creation-attributes-supported")
  printer
}

///|
pub fn Printer::supports(self : Printer, format : String) -> Bool {
  for item in self.formats {
    if item.to_lower() == format.to_lower() {
      return true
    }
  }
  false
}

///|
pub fn Printer::supports_op(self : Printer, op : Int) -> Bool {
  for item in self.operations {
    if item == op {
      return true
    }
  }
  false
}

///|
pub fn Printer::has(self : Printer, name : String) -> Attribute? {
  find_attr(self.attrs, name)
}

///|
fn join_strings(values : Array[String], separator : String) -> String {
  values.join(separator)
}

///|
fn resolution_text(resolution : (Int, Int, Int)) -> String {
  let (x, y, units) = resolution
  let suffix = if units == 4 { "dpcm" } else if units == 3 { "dpi" } else { "units-" + units.to_string() }
  x.to_string() + "x" + y.to_string() + suffix
}

///|
fn ints_text(values : Array[Int]) -> String {
  values.map(fn(value) { value.to_string() }).join(", ")
}

///|
fn resolutions_text(values : Array[(Int, Int, Int)]) -> String {
  values.map(fn(value) { resolution_text(value) }).join(", ")
}

///|
/// The printer for people: name, model, state, formats and capabilities.
pub fn Printer::summary(self : Printer) -> Array[String] {
  let lines : Array[String] = []
  let add = fn(key : String, value : String) -> Unit {
    if value != "" {
      lines.push(key + ": " + value)
    }
  }
  add("name", self.name)
  add("model", self.make_model)
  add("info", self.info)
  add("location", self.location)
  add("uri", join_strings(self.uris, ", "))
  let mut state = printer_state_name(self.state)
  if self.reasons.length() > 0 &&
    !(self.reasons.length() == 1 && self.reasons[0] == "none") {
    state += " (" + join_strings(self.reasons, ", ") + ")"
  }
  if !self.accepting_jobs {
    state += ", not accepting jobs"
  }
  add("state", state)
  add("ipp", join_strings(self.versions, ", "))
  add("auth", join_strings(self.auth, ", "))
  add("formats", join_strings(self.formats, ", "))
  add("media", join_strings(self.media, ", "))
  add("media-ready", join_strings(self.media_ready, ", "))
  add("media-default", self.media_default)
  add("sources", join_strings(self.media_sources, ", "))
  add("types", join_strings(self.media_types, ", "))
  add("sides", join_strings(self.sides, ", "))
  add("color", join_strings(self.color_modes, ", "))
  add("quality", ints_text(self.qualities))
  add("resolution", resolutions_text(self.resolutions))
  if self.copies != (1, 1) {
    add("copies", self.copies.0.to_string() + "-" + self.copies.1.to_string())
  }
  if self.page_ranges {
    add("page-ranges", "yes")
  }
  add("scaling", join_strings(self.scaling, ", "))
  add("finishings", ints_text(self.finishings))
  add("output-bins", join_strings(self.output_bins, ", "))
  add(
    "pwg-raster",
    (resolutions_text(self.pwg_raster_resolutions) +
      " " +
      join_strings(self.pwg_raster_types, ", ") +
      " " +
      self.pwg_raster_sheet_back).trim().to_owned(),
  )
  add("urf", join_strings(self.urf, ","))
  if self.job_password > 0 {
    add("job-password", "up to " + self.job_password.to_string() + " characters")
  }
  if self.job_account_id {
    add("job-account-id", "yes")
  }
  lines
}

///|
pub fn Printer::sorted_formats(self : Printer) -> Array[String] {
  let out = self.formats.copy()
  out.sort()
  out
}
