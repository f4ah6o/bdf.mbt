///|
fn check_shared_budget(
  parent_data : Bytes,
  second_data : Bytes,
  child_data : Bytes,
  hash : String,
  seed : Int32,
  first_fails : Bool,
  second_fails : Bool,
  third_fails : Bool,
  first_text : String,
  second_text : String,
) -> Unit raise {
  let parent = @core.decode_object_resources(parent_data)
  let second_parent = @core.decode_object_resources(second_data)
  let child = @core.decode_object_resources(child_data)
  let budget = TextExtractionBudget::new()
  budget.reused = seed
  let resolve : (String) -> @core.ObjectResources? raise = fn(value) {
    if value == hash {
      Some(child)
    } else {
      None
    }
  }
  let first = Some(extract_text_with_budget(parent, resolve, budget)) catch {
    InvalidOperands(message) => {
      assert_eq(message, "objects are drawn too many times")
      None
    }
    error => raise error
  }
  assert_eq(first is None, first_fails)
  if first is Some(result) {
    assert_eq(join_text(result.runs), first_text)
  }
  let second = Some(extract_text_with_budget(second_parent, resolve, budget)) catch {
    InvalidOperands(message) => {
      assert_eq(message, "objects are drawn too many times")
      None
    }
    error => raise error
  }
  assert_eq(second is None, second_fails)
  if second is Some(result) {
    assert_eq(join_text(result.runs), second_text)
  }
  let third = Some(extract_text_with_budget(second_parent, resolve, budget)) catch {
    InvalidOperands(message) => {
      assert_eq(message, "objects are drawn too many times")
      None
    }
    error => raise error
  }
  assert_eq(third is None, third_fails)
  let fresh = extract_text(parent, resolve)
  assert_eq(join_text(fresh.runs), first_text)
}
