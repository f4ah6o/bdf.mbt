///|
test "decoration coordinates round like an exact multiply-add" {
  for i in 1..<1001 {
    let size = i.to_double() / 37.0
    for factor in [-0.3, 0.1] {
      for offset in [-1.0e-12, 0.0, 1.0e-12, 0.75, 2048.0] {
        let origin = -factor * size + offset
        let expected = Float::from_double(
          @core.fused_multiply_add(factor, size, origin),
        )
        assert_eq(grid_fused_float(factor, size, origin), expected)
      }
    }
  }
}
