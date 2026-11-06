///|
// Page placement: how print-scaling and orientation put a page on a sheet.
pub const SCALE_AUTO_FIT : String = "auto-fit"
pub const SCALE_AUTO : String = "auto"
pub const SCALE_FIT : String = "fit"
pub const SCALE_FILL : String = "fill"
pub const SCALE_NONE : String = "none"

pub const ORIENT_AUTO : Int = 0
pub const ORIENT_PORTRAIT : Int = 3
pub const ORIENT_LANDSCAPE : Int = 4
pub const ORIENT_REVERSE_LANDSCAPE : Int = 5
pub const ORIENT_REVERSE_PORTRAIT : Int = 6

///|
pub(all) struct Sheet {
  width : Double
  height : Double
  dpi : Int
}

///|
pub fn Sheet::new(width : Double, height : Double, dpi : Int) -> Sheet {
  { width, height, dpi }
}

///|
pub fn Sheet::pixels(self : Sheet) -> (Int, Int) {
  let scale = self.dpi.to_double() / 72.0
  let w = (self.width * scale + 1.0e-6).floor().to_int()
  let h = (self.height * scale + 1.0e-6).floor().to_int()
  (Int::max(w, 1), Int::max(h, 1))
}

///|
pub(all) struct Place {
  w : Int
  h : Int
  scale : Double
  turns : Int
  x : Double
  y : Double
  mirror_x : Bool
  mirror_y : Bool
}

///|
/// Where a w × h point page goes on a sheet.
pub fn fit(
  w : Double,
  h : Double,
  sheet : Sheet,
  scaling : String,
  orientation : Int,
) -> Place raise RasterError {
  if !(w > 0.0) || !(h > 0.0) || !(sheet.width > 0.0) ||
    !(sheet.height > 0.0) || sheet.dpi <= 0 {
    raise RasterError("raster: an empty page or sheet")
  }
  let turns = if orientation == ORIENT_AUTO {
    if (w > h) != (sheet.width > sheet.height) && w != h &&
      sheet.width != sheet.height {
      3
    } else {
      0
    }
  } else if orientation == ORIENT_PORTRAIT {
    0
  } else if orientation == ORIENT_LANDSCAPE {
    3
  } else if orientation == ORIENT_REVERSE_LANDSCAPE {
    1
  } else if orientation == ORIENT_REVERSE_PORTRAIT {
    2
  } else {
    raise RasterError("raster: orientation " + orientation.to_string())
  }
  let (tw, th) = if turns % 2 == 1 { (h, w) } else { (w, h) }
  let fit_scale = Double::min(sheet.width / tw, sheet.height / th)
  let f = if scaling == SCALE_NONE {
    1.0
  } else if scaling == SCALE_FIT {
    fit_scale
  } else if scaling == SCALE_FILL {
    Double::max(sheet.width / tw, sheet.height / th)
  } else if scaling == SCALE_AUTO || scaling == SCALE_AUTO_FIT || scaling == "" {
    Double::min(1.0, fit_scale)
  } else {
    raise RasterError("raster: print-scaling \"" + scaling + "\"")
  }
  let f = if (f - 1.0).abs() < 1.0e-9 { 1.0 } else { f }
  let dpi = sheet.dpi.to_double() / 72.0
  let (pw, ph) = sheet.pixels()
  let scale = dpi * f
  let x = ((pw.to_double() - tw * scale) / 2.0).round()
  let y = ((ph.to_double() - th * scale) / 2.0).round()
  {
    w: pw,
    h: ph,
    scale,
    turns,
    x,
    y,
    mirror_x: false,
    mirror_y: false,
  }
}

///|
/// The transforms of the back of a sheet, as pwg-raster-document-sheet-back.
pub fn back(sheet_back : String, tumble : Bool) -> (Int, Int) raise RasterError {
  let mut cross_feed = 1
  let mut feed = 1
  if sheet_back == "normal" || sheet_back == "" {
    ()
  } else if sheet_back == "flipped" {
    if tumble {
      cross_feed = -1
    } else {
      feed = -1
    }
  } else if sheet_back == "manual-tumble" {
    if tumble {
      cross_feed = -1
      feed = -1
    }
  } else if sheet_back == "rotated" {
    if !tumble {
      cross_feed = -1
      feed = -1
    }
  } else {
    raise RasterError("raster: pwg-raster-document-sheet-back \"" + sheet_back + "\"")
  }
  (cross_feed, feed)
}

///|
/// Apply the mirrors of the back transforms to a placement.
pub fn mirror(place : Place, cross_feed : Int, feed : Int) -> Place {
  {
    ..place,
    mirror_x: place.mirror_x != (cross_feed < 0),
    mirror_y: place.mirror_y != (feed < 0),
  }
}
