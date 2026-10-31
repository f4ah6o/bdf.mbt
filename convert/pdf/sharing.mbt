///|
// A page body or child before final hashes and font references are fixed.
priv struct PdfPendingObject {
  resources : @core.ObjectResources
  children : Array[Int32]
  child_bounds : Array[(Float, Float, Float, Float)]
  font_ids : Array[String]
  mut phase : Int32
  mut hash : String
}

///|
fn pdf_pending(
  data : Bytes,
  children : Array[Int32],
  child_bounds : Array[(Float, Float, Float, Float)],
  font_ids : Array[String],
) -> PdfPendingObject raise PdfStreamError {
  let resources = @core.decode_object_resources(data) catch {
    _ => raise InvalidStream("invalid PDF pending object")
  }
  if resources.object.objects.length() != children.length() ||
    children.length() != child_bounds.length() {
    raise InvalidStream("PDF pending child identity mismatch")
  }
  if !font_ids.is_empty() && resources.fonts.length() != font_ids.length() {
    raise InvalidStream("PDF pending font identity mismatch")
  }
  { resources, children, child_bounds, font_ids, phase: 0, hash: "", }
}

///|
fn pdf_child_placeholder(id : Int32) -> String {
  let hasher = @core.Sha256Stream::new()
  hasher.write(@utf8.encode("pdf-pending-child:\{id}"))
  hasher.digest().unsafe_substring(start=0, end=32)
}

///|
fn pdf_share_source(
  pending : PdfPendingObject,
  page : Int32,
) -> @render.PrefixSource raise PdfStreamError {
  if pending.resources.fonts.length() != pending.font_ids.length() {
    raise InvalidStream("PDF font identities unavailable")
  }
  let fonts : Array[@core.Font] = []
  for id in pending.font_ids {
    let identity = if id.has_prefix("local:") {
      "page:\{page}:" + id
    } else {
      id
    }
    fonts.push({
      hash: None,
      family: "pdf-font:" + identity,
      weight: 0,
      style: 0,
    })
  }
  let objects = pending.children.map(fn(id) { pdf_child_placeholder(id) })
  let object = { ..pending.resources.object, objects, }
  {
    resources: { ..pending.resources, object, fonts, },
    child_bounds: pending.child_bounds,
  }
}

///|
fn pdf_rebind_shared(
  rewrite : @render.PrefixRewrite,
  source : PdfPendingObject,
  prefix_id : Int32?,
) -> PdfPendingObject raise PdfStreamError {
  let resources = @core.decode_object_resources(rewrite.data) catch {
    _ => raise InvalidStream("invalid shared PDF object")
  }
  if resources.fonts.length() != rewrite.fonts.length() ||
    resources.object.objects.length() != rewrite.children.length() {
    raise InvalidStream("invalid shared PDF references")
  }
  let font_ids : Array[String] = []
  for i, old in rewrite.fonts {
    if old < 0 ||
      old >= source.resources.fonts.length() ||
      old >= source.font_ids.length() {
      raise InvalidStream("invalid shared PDF font reference")
    }
    resources.fonts[i] = source.resources.fonts[old]
    font_ids.push(source.font_ids[old])
  }
  let children : Array[Int32] = []
  let bounds : Array[(Float, Float, Float, Float)] = []
  for old in rewrite.children {
    if old == -1 {
      let id = match prefix_id {
        Some(value) => value
        None => raise InvalidStream("missing shared PDF prefix")
      }
      children.push(id)
      let (x, y, w, h) = source.resources.object.bbox
      bounds.push(
        (
          Float::from_double(x),
          Float::from_double(y),
          Float::from_double(w),
          Float::from_double(h),
        ),
      )
    } else {
      if old < 0 || old >= source.children.length() {
        raise InvalidStream("invalid shared PDF child reference")
      }
      children.push(source.children[old])
      bounds.push(source.child_bounds[old])
    }
  }
  { resources, children, child_bounds: bounds, font_ids, phase: 0, hash: "", }
}

///|
// Return staged objects and new page bodies without mutating the originals.
fn pdf_plan_shared(
  pending : Array[PdfPendingObject],
  bodies : Array[Int32],
) -> (Array[PdfPendingObject], Array[Int32], Map[Int32, Bool], Int32, Int64) raise {
  let sources : Array[@render.PrefixSource] = []
  for page, body in bodies {
    sources.push(pdf_share_source(pending[body], page))
  }
  let plans = @render.plan_shared_prefixes(sources, 512)
  let staged : Array[PdfPendingObject] = []
  let new_bodies = bodies.copy()
  let replaced : Map[Int32, Bool] = {}
  let mut saved = 0L
  for plan in plans {
    let first = pending[bodies[plan.source]]
    let prefix_id = pending.length() + staged.length()
    staged.push(pdf_rebind_shared(plan.prefix, first, None))
    for member in plan.members {
      let old_id = bodies[member.source]
      let next_id = pending.length() + staged.length()
      staged.push(
        pdf_rebind_shared(member.rest, pending[old_id], Some(prefix_id)),
      )
      new_bodies[member.source] = next_id
      replaced[old_id] = true
      saved += member.saved.to_int64()
    }
  }
  (staged, new_bodies, replaced, plans.length(), saved)
}

///|
fn pdf_finalize_pending(
  pending : Array[PdfPendingObject],
  id : Int32,
  writer : @core.DocumentWriter,
  objects : Map[String, @core.ObjectResources],
) -> String raise PdfStreamError {
  if id < 0 || id >= pending.length() {
    raise InvalidStream("invalid pending PDF object")
  }
  let item = pending[id]
  if item.phase == 2 {
    return item.hash
  }
  if item.phase == 1 {
    raise InvalidStream("cyclic pending PDF object")
  }
  item.phase = 1
  for i, child in item.children {
    item.resources.object.objects[i] = pdf_finalize_pending(
      pending, child, writer, objects,
    )
  }
  let data = @core.encode_object_resources(item.resources) catch {
    _ => raise InvalidStream("PDF object encoding failed")
  }
  let hash = writer.add_part("obj", data) catch {
    _ => raise InvalidStream("PDF BDF object output failed")
  }
  objects[hash] = item.resources
  item.hash = hash
  item.phase = 2
  hash
}
