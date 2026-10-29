///|
// Match Go's fused arithmetic in spreadsheet color calculations.
fn xlsx_fma(a : Double, b : Double, c : Double) -> Double {
  @core.fused_multiply_add(a, b, c)
}
