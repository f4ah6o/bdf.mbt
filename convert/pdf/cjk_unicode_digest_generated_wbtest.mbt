///|
// Every CID in each upstream collection's supported range.
test "Adobe CID Unicode digests match upstream Go" {
  assert_eq(pdf_cjk_unicode_digest("Adobe-Japan1"), 5822597715544731684UL)
  assert_eq(pdf_cjk_unicode_digest("Adobe-Japan2"), 4672666043832224992UL)
  assert_eq(pdf_cjk_unicode_digest("Adobe-GB1"), 11723534139671591045UL)
  assert_eq(pdf_cjk_unicode_digest("Adobe-CNS1"), 9292261959366688353UL)
  assert_eq(pdf_cjk_unicode_digest("Adobe-Korea1"), 4699879273741746832UL)
}
