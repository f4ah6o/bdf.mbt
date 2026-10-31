///|
// A candidate's digest covers the exact Go prefix stream, including resource
// values and excluding string-table contents.
priv struct PrefixCandidate {
  cut : PrefixCut
  key : String
}

///|
priv struct PrefixMember {
  object : Int32
  cut : PrefixCut
}

///|
priv struct PrefixGroup {
  members : Array[PrefixMember]
}

///|
fn prefix_candidates(
  resources : @core.ObjectResources,
) -> Array[PrefixCandidate] raise {
  let spans = instruction_spans(resources.object)
  let cuts = prefix_cut_points(spans)
  let hasher = @core.Sha256Stream::new()
  let out : Array[PrefixCandidate] = []
  let mut next = 0
  for i, span in spans {
    if next < cuts.length() && cuts[next].instruction == i {
      out.push({ cut: cuts[next], key: hasher.digest(), })
      next += 1
    }
    hasher.write(resources.object.ops[span.start:span.end])
    let feed = fn(kind : Byte, index : Int32) raise {
      hasher.write(@core.prefix_resource_data(resources, kind, index))
    }
    match span.command {
      ClipPath(index, _)
      | FillPath(index, _)
      | StrokePath(index)
      | FillPathAt(index, _, _, _) => feed(b'p', index)
      FillPathRun(_, glyphs) =>
        for glyph in glyphs {
          feed(b'p', glyph.path)
        }
      FillPaint(index) | StrokePaint(index) => feed(b'g', index)
      Font(index, _) => feed(b'f', index)
      Image(_, _, _, _, _) | ImageSub(_, _, _, _, _, _, _, _, _) => {
        let args = @core.Reader::new(
          resources.object.ops[span.start + 1:span.end].to_owned(),
        )
        feed(b'i', args.varuint())
      }
      Use(_) | UseAt(_, _, _) => {
        let args = @core.Reader::new(
          resources.object.ops[span.start + 1:span.end].to_owned(),
        )
        feed(b'o', args.varuint())
      }
      _ => ()
    }
  }
  out
}

///|
// Match Go's greedy ordering and score: pages join at most one group, and a
// tie keeps the first key encountered in object/instruction order.
fn select_prefix_groups(
  objects : Array[@core.ObjectResources],
  min_bytes : Int32,
) -> Array[PrefixGroup] raise {
  let candidates = objects.map(prefix_candidates)
  let counts : Map[String, Int32] = {}
  for object_candidates in candidates {
    let seen : Map[String, Bool] = {}
    for candidate in object_candidates {
      if !seen.contains(candidate.key) {
        seen[candidate.key] = true
        counts[candidate.key] = counts.get(candidate.key).unwrap_or(0) + 1
      }
    }
  }
  let groups : Map[String, Array[PrefixMember]] = {}
  let keys : Array[String] = []
  for object, object_candidates in candidates {
    for candidate in object_candidates {
      if candidate.cut.offset < min_bytes ||
        counts.get(candidate.key).unwrap_or(0) < 2 {
        continue
      }
      let members = match groups.get(candidate.key) {
        Some(value) => value
        None => {
          let value : Array[PrefixMember] = []
          keys.push(candidate.key)
          groups[candidate.key] = value
          value
        }
      }
      members.push({ object, cut: candidate.cut, })
    }
  }
  let taken : FixedArray[Bool] = FixedArray::make(objects.length(), false)
  let selected : Array[PrefixGroup] = []
  while true {
    let mut best : Array[PrefixMember] = []
    let mut best_saved = 0L
    for key in keys {
      let free = [
        for member in groups[key] if !taken[member.object] => member
      ]
      if free.length() < 2 {
        continue
      }
      let saved = (free.length() - 1).to_int64() * free[0].cut.offset.to_int64()
      if saved > best_saved {
        best = free
        best_saved = saved
      }
    }
    if best.is_empty() {
      break
    }
    for member in best {
      taken[member.object] = true
    }
    selected.push({ members: best, })
  }
  selected.sort_by(fn(a, b) { a.members[0].object.compare(b.members[0].object) })
  selected
}
