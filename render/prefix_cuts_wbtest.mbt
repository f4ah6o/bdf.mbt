///|
fn check_prefix_cuts(
  object : Bytes,
  expected_spans : Array[(Int32, Int32)],
  expected_cuts : Array[(Int32, Int32)],
) -> Unit raise {
  let source = @core.decode_object(object)
  let spans = instruction_spans(source)
  assert_eq(spans.map(fn(span) { (span.start, span.end) }), expected_spans)
  let cuts = prefix_cut_points(spans)
  assert_eq(cuts.map(fn(cut) { (cut.instruction, cut.offset) }), expected_cuts)
  // The existing public compiler continues to decode the same instruction count.
  assert_eq(compile_object(source).length(), spans.length())
}
