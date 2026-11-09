///|
/// Substitution of old AWS icon sets (mxgraph.aws/aws2/aws3/aws3d) by their
/// current aws4 counterparts (upstream aws_legacy.go). The palette names of
/// the old sets are rewritten to the aws4 style in aws_legacy_table.mbt;
/// names the converter already draws itself (a registered shape or an
/// embedded stencil) and names without a counterpart are left alone.

///|
/// Style keys that drew the old icon; they are dropped even when the
/// target does not set them (upstream awsLegacyIconKeys).
let aws_legacy_icon_keys : Array[String] = [
  "shape", "resIcon", "prIcon", "grIcon", "grStroke", "fillColor",
  "gradientColor", "gradientDirection", "strokeColor", "strokeColor2",
  "strokeWidth", "dashed", "dashPattern", "fixDash", "aspect", "rounded",
  "arcSize", "absoluteArcSize", "glass",
]

///|
/// Whether a shape name belongs to an older AWS icon set.
fn drawio_is_aws_legacy(name : String) -> Bool {
  let low = name.to_lower()
  low.has_prefix("mxgraph.aws.") ||
  low.has_prefix("mxgraph.aws2.") ||
  low.has_prefix("mxgraph.aws3.") ||
  low.has_prefix("mxgraph.aws3d.")
}

///|
/// The index into aws_legacy_targets for a legacy name, -1 for a known
/// name without a counterpart, and None for a name not in the table.
fn drawio_aws_legacy_index(name : String) -> Int? {
  match aws_legacy_shapes.get(name) {
    Some(i) => Some(i)
    None => aws_legacy_shapes.get(name.to_lower())
  }
}

///|
/// rewriteAWSLegacyStyle: the cell's style with the target's keys in place
/// of those that drew the old shape.
fn drawio_aws_legacy_rewrite(
  style : String,
  target_style : String,
  keep_colors : Bool,
) -> String {
  let toks = style.split(";").map(fn(t) { t.to_string() }).collect()
  let mut own_font = false
  for tok in toks {
    if tok.has_prefix("fontColor=") && tok.length() > "fontColor=".length() {
      own_font = true
    }
  }
  let drop = { "shape": true }
  if !keep_colors {
    for key in aws_legacy_icon_keys {
      drop[key] = true
    }
  }
  let add : Array[String] = []
  for kv in target_style.split(";") {
    let kvs = kv.to_string()
    if kvs == "" {
      continue
    }
    let eq = kv.find("=")
    let key = match eq {
      Some(i) => kv[:i].to_string()
      None => kvs
    }
    if key == "fontColor" && own_font {
      continue
    }
    drop[key] = true
    add.push(kvs)
  }
  let out : Array[String] = []
  for i = 0; i < toks.length(); i = i + 1 {
    let tok = toks[i]
    if tok == "" && (i > 0 || style == "") {
      continue
    }
    let eq = tok.find("=")
    match eq {
      Some(ei) =>
        if !drop.contains(tok[:ei].to_string()) {
          out.push(tok)
        }
      None => out.push(tok)
    }
  }
  for kv in add {
    out.push(kv)
  }
  out.join(";")
}

///|
/// substituteAWSLegacy: rewrite the vertices of the model drawn with old
/// AWS shapes and return how many were rewritten.
fn drawio_aws_legacy_substitute(model : DrawioModel, warn : DrawioWarn) -> Int {
  let mut n = 0
  for cell in model.cells {
    if !cell.vertex || !cell.style.contains("aws") {
      continue
    }
    let name = drawio_shape_name(cell.style)
    if !drawio_is_aws_legacy(name) {
      continue
    }
    if drawio_core_shape_kind(name) is Some(_) ||
      drawio_stencil_lookup(name) is Some(_) ||
      drawio_aws4_is_composite(name) {
      continue
    }
    let index = match drawio_aws_legacy_index(name) {
      Some(i) => i
      None => continue
    }
    if index < 0 {
      warn.once(
        "shape:" + name,
        "shape \"" + name + "\" of an older AWS icon set has no current AWS counterpart; drawn as a rectangle",
      )
      continue
    }
    let (target_style, _, _, keep_colors) = aws_legacy_targets[index]
    cell.style = drawio_aws_legacy_rewrite(cell.style, target_style, keep_colors)
    n = n + 1
  }
  if n == 1 {
    warn.once(
      "aws-legacy",
      "1 shape of an older AWS icon set is drawn with its current AWS counterpart",
    )
  } else if n > 1 {
    warn.once(
      "aws-legacy",
      n.to_string() + " shapes of older AWS icon sets are drawn with their current AWS counterparts",
    )
  }
  n
}
