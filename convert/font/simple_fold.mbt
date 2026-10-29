///|
fn specimen_fold(code : Int32) -> Int32 {
  let mut lo = 0
  let mut hi = specimen_simple_folds.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let (from, _) = specimen_simple_folds[mid]
    if from < code {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo < specimen_simple_folds.length() && specimen_simple_folds[lo].0 == code {
    specimen_simple_folds[lo].1
  } else {
    code
  }
}

///|
fn specimen_equal_fold(a : String, b : String) -> Bool {
  let left : Array[Char] = [ for c in a => c ]
  let right : Array[Char] = [ for c in b => c ]
  if left.length() != right.length() {
    return false
  }
  for i in 0..<left.length() {
    if specimen_fold(left[i].to_int()) != specimen_fold(right[i].to_int()) {
      return false
    }
  }
  true
}
