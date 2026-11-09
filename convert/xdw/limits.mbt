///|
/// Resource limits for untrusted files.
///
/// A `.xdw` carries its own sizes and counts: how large a compressed block
/// becomes once expanded, how many pixels a picture has, how many points a
/// line has. A crafted file can claim far more than it holds, so the reader
/// checks every count against the bytes that are really there and the caps
/// below. The defaults sit far above anything a real document needs (the
/// public samples use a few percent of them).

///|
pub(all) struct Limits {
  /// Working memory for opening the document or drawing one page:
  /// expanded blocks and decoded pictures together, in bytes.
  max_bytes : Int64
  /// One compressed block expanded, in bytes.
  max_expand : Int64
  /// A compressed block may expand to at most this times its stored size.
  max_ratio : Int64
  /// Most pages read; a document with more is refused.
  max_pages : Int
}

///|
pub fn Limits::default() -> Limits {
  {
    max_bytes: 768L << 20,
    max_expand: 256L << 20,
    max_ratio: 1000L,
    max_pages: 20000,
  }
}

///|
/// The largest expanded size accepted in one call for `stored` bytes.
fn Limits::expand_cap(self : Limits, stored : Int64) -> Int64 {
  let shifted = stored * self.max_ratio
  let with_slack = if shifted > 0L {
    (shifted + (64L << 10))
  } else {
    (64L << 10)
  }
  if with_slack < self.max_expand {
    with_slack
  } else {
    self.max_expand
  }
}

///|
/// Whether `out_len` is within the limits for `stored` compressed bytes.
fn limits_expand_ok(limits : Limits, stored : Int64, out_len : Int64) -> Bool {
  out_len >= 0L && out_len <= limits.expand_cap(stored) &&
  out_len <= limits.max_bytes
}
