///|
// Byte ranges refer to the original object op stream. Commands carry resolved
// strings and child hashes; use the source bytes for original resource indices.
priv struct InstructionSpan {
  start : Int32
  end : Int32
  command : Command
}

///|
priv struct PrefixCut {
  instruction : Int32
  offset : Int32
}

///|
fn instruction_spans(object : @core.ObjectPart) -> Array[InstructionSpan] raise {
  let spans : Array[InstructionSpan] = []
  ignore(compile_object_with_spans(object, Some(spans)))
  spans
}

///|
// A cut follows a complete instruction, outside saved/group/mask state, and
// cannot separate a MARK from the instruction it describes. A top-level clip,
// filter or shadow prevents all subsequent cuts, matching Go's stateReplay.
fn prefix_cut_points(spans : Array[InstructionSpan]) -> Array[PrefixCut] {
  let cuts : Array[PrefixCut] = []
  let mut depth = 0
  let mut unsafe_state = false
  let mut previous_mark = false
  for i, span in spans {
    if i > 0 && depth == 0 && !unsafe_state && !previous_mark {
      cuts.push({ instruction: i, offset: span.start, })
    }
    if depth == 0 {
      match span.command {
        ClipPath(_, _)
        | ClipRect(_, _, _, _)
        | Shadow(_, _, _, _)
        | Filter(_) => unsafe_state = true
        _ => ()
      }
    }
    previous_mark = span.command is Mark(_, _)
    match span.command {
      Save | GroupBegin(_, _, _, _, _, _) | MaskBegin(_, _, _) => depth += 1
      Restore | GroupEnd | MaskEnd => depth -= 1
      _ => ()
    }
  }
  cuts
}
