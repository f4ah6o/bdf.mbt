///|
test "selected page counts agree with bounded set membership" {
  // Exhaustive bounded cases include duplicates, negative pages and overflow.
  for count in 0..<21 {
    for seed in 0..<53 {
      let numbers : Array[Int64] = []
      for offset in 0..<17 {
        numbers.push(((seed * 7 + offset * 11) % 29 - 4).to_int64())
      }
      numbers.push(seed.to_int64())
      numbers.push(seed.to_int64())
      let mut expected = 0
      for page in 1..<(count + 1) {
        if numbers.contains(page.to_int64()) {
          expected += 1
        }
      }
      assert_eq(native_selected_page_count(numbers, count), expected)
    }
  }
}

