///|
test "incremental PDF cross references match upstream Go" {
  check_pdf_xrefs(
    "incremental",
    [
      "H4sIAAAAAAAA/4yPvU7DMBSF9/sUZ7EEA9iOY7JUXUqzMDQqiAUxGHJbBRkbOS5/T48IahsUBrxY+nSOvnNFc1mf6fOKRBceEz9zyM6ThkJ8eKLZDPLm44UhFy47H7eQjdtyjwIKa8znxKH9DhaTwk9OLuIuZCjIq67tcXc/6phR59b5HeMk+vZ0lHhPvCGFktTh4cJaY7HBgRUFhh/hyCo9YbowR5aT6zynQX3dfTJKyHWMGXp/V59dyoNf24qEWK7qvwYHfpsMNtB7qVHq31LZJH6FttVvvTElCbFc1fQ1AIL4RlWrAQAA",
    ],
    Some(PdfRef(1L, 0L)),
    [
      (0L, XRefFree(65535L)),
      (1L, XRefOffset(22L, 0L)),
      (2L, XRefOffset(71L, 0L)),
      (3L, XRefOffset(300L, 0L)),
    ],
  )
}

///|
test "incremental PDF resolves newest object" {
  check_pdf_resolve(
    "incremental",
    [
      "H4sIAAAAAAAA/4yPvU7DMBSF9/sUZ7EEA9iOY7JUXUqzMDQqiAUxGHJbBRkbOS5/T48IahsUBrxY+nSOvnNFc1mf6fOKRBceEz9zyM6ThkJ8eKLZDPLm44UhFy47H7eQjdtyjwIKa8znxKH9DhaTwk9OLuIuZCjIq67tcXc/6phR59b5HeMk+vZ0lHhPvCGFktTh4cJaY7HBgRUFhh/hyCo9YbowR5aT6zynQX3dfTJKyHWMGXp/V59dyoNf24qEWK7qvwYHfpsMNtB7qVHq31LZJH6FttVvvTElCbFc1fQ1AIL4RlWrAQAA",
    ],
    [
      (
        3L,
        PdfDict([(b"\x56\x61\x6c\x75\x65", PdfString(b"\x6e\x65\x77"))]),
        -1,
        0UL,
      ),
    ],
  )
}
