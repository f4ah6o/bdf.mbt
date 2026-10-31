///|
/// An object and its child bounds, for prefix-sharing analysis.
pub(all) struct PrefixSource {
  resources : @core.ObjectResources
  child_bounds : Array[(Float, Float, Float, Float)]
}

///|
/// A rewritten object and its new-to-original font and child references.
/// A child reference of -1 denotes the new shared prefix.
pub(all) struct PrefixRewrite {
  data : Bytes
  fonts : Array[Int32]
  children : Array[Int32]
}

///|
/// One rewritten member of a shared prefix group.
pub(all) struct PrefixPlanMember {
  source : Int32
  saved : Int32
  rest : PrefixRewrite
}

///|
/// A shared prefix, with its originating source and rewritten members.
pub(all) struct PrefixPlan {
  source : Int32
  prefix : PrefixRewrite
  members : Array[PrefixPlanMember]
}

///|
/// Plan sharing without changing the input objects. Resource placeholders in
/// the input remain in the output; use the reference maps to rebind them.
pub fn plan_shared_prefixes(
  sources : Array[PrefixSource],
  min_bytes : Int32,
) -> Array[PrefixPlan] raise {
  let objects = sources.map(fn(source) { source.resources })
  let groups = select_prefix_groups(objects, min_bytes)
  let plans : Array[PrefixPlan] = []
  for group in groups {
    let first = group.members[0]
    let first_source = sources[first.object]
    let prefix_split = split_prefix(
      first_source.resources,
      first_source.child_bounds,
      first.cut,
    )
    let prefix : PrefixRewrite = {
      data: prefix_split.prefix.encode(),
      fonts: prefix_split.prefix_fonts,
      children: prefix_split.prefix_children,
    }
    let members : Array[PrefixPlanMember] = []
    for member in group.members {
      let source = sources[member.object]
      let split = if member.object == first.object {
        prefix_split
      } else {
        split_prefix(source.resources, source.child_bounds, member.cut)
      }
      members.push({
        source: member.object,
        saved: member.cut.offset,
        rest: {
          data: split.rest.encode(),
          fonts: split.rest_fonts,
          children: split.rest_children,
        },
      })
    }
    plans.push({ source: first.object, prefix, members, })
  }
  plans
}
