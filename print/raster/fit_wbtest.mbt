///|
test "fit pages on A4" {
  let a4 = Sheet::new(595.276, 841.89, 300)
  assert_eq(a4.pixels(), (2480, 3507))
  let dpi = 300.0 / 72.0
  let centre = fn(sheet : Int, page : Double, scale : Double) -> Double {
    ((sheet.to_double() - page * scale) / 2.0).round()
  }
  let fit_a5 = Double::min(595.276 / 419.528, 841.89 / 595.276)
  let fit_land = Double::min(595.276 / 841.89, 841.89 / 595.276)
  let cases : Array[(String, Double, Double, String, Int, Int, Double, Double, Double)] = [
    ("A4 on A4", 595.276, 841.89, SCALE_AUTO_FIT, ORIENT_AUTO, 0, 1.0, 595.276, 841.89),
    ("A5 on A4, not enlarged", 419.528, 595.276, SCALE_AUTO_FIT, ORIENT_AUTO, 0, 1.0, 419.528, 595.276),
    ("A5 on A4, fit", 419.528, 595.276, SCALE_FIT, ORIENT_AUTO, 0, fit_a5, 419.528, 595.276),
    ("A5 on A4, fill", 419.528, 595.276, SCALE_FILL, ORIENT_AUTO, 0, Double::max(595.276 / 419.528, 841.89 / 595.276), 419.528, 595.276),
    ("A4 landscape on A4", 841.89, 595.276, SCALE_AUTO_FIT, ORIENT_AUTO, 3, 1.0, 595.276, 841.89),
    ("A4 landscape as portrait", 841.89, 595.276, SCALE_AUTO_FIT, ORIENT_PORTRAIT, 0, fit_land, 841.89, 595.276),
    ("A3 on A4, shrunk", 841.89, 1190.55, SCALE_AUTO, ORIENT_AUTO, 0, 595.276 / 841.89, 841.89, 1190.55),
    ("reverse landscape", 841.89, 595.276, SCALE_NONE, ORIENT_REVERSE_LANDSCAPE, 1, 1.0, 595.276, 841.89),
    ("a half turn", 595.276, 841.89, SCALE_NONE, ORIENT_REVERSE_PORTRAIT, 2, 1.0, 595.276, 841.89),
  ]
  for entry in cases {
    let (name, w, h, scaling, orientation, turns, f, tw, th) = entry
    let place = fit(w, h, a4, scaling, orientation)
    let scale = dpi * f
    assert_true(
      place.w == 2480 &&
      place.h == 3507 &&
      place.turns == turns &&
      (place.scale - scale).abs() <= 1.0e-6 &&
      place.x == centre(2480, tw, scale) &&
      place.y == centre(3507, th, scale),
      msg=name,
    )
  }
  let origin = fit(595.276, 841.89, a4, SCALE_AUTO_FIT, ORIENT_AUTO)
  assert_eq(origin.x, 0.0)
  assert_eq(origin.y, 0.0)
  let empty = try {
    ignore(fit(0.0, 1.0, a4, SCALE_FIT, ORIENT_AUTO))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(empty, msg="an empty page")
  let unknown = try {
    ignore(fit(1.0, 1.0, a4, "stretch", ORIENT_AUTO))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(unknown, msg="an unknown scaling")
}

///|
test "sheet back transforms" {
  let cases : Array[(String, Bool, Int, Int)] = [
    ("normal", false, 1, 1),
    ("normal", true, 1, 1),
    ("flipped", false, 1, -1),
    ("flipped", true, -1, 1),
    ("rotated", false, -1, -1),
    ("rotated", true, 1, 1),
    ("manual-tumble", false, 1, 1),
    ("manual-tumble", true, -1, -1),
  ]
  for entry in cases {
    let (back_name, tumble, cross, feed) = entry
    let (got_cross, got_feed) = back(back_name, tumble)
    assert_true(got_cross == cross && got_feed == feed, msg=back_name)
  }
  let unknown = try {
    ignore(back("sideways", false))
    false
  } catch {
    RasterError(_) => true
  }
  assert_true(unknown, msg="an unknown sheet back")
  let place : Place = {
    ..fit(595.276, 841.89, Sheet::new(595.276, 841.89, 300), SCALE_NONE, ORIENT_PORTRAIT),
  }
  let mirrored = mirror(place, -1, 1)
  assert_true(mirrored.mirror_x && !mirrored.mirror_y)
  let twice = mirror(mirrored, -1, 1)
  assert_true(!twice.mirror_x && !twice.mirror_y)
}
