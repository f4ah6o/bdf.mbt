///|
fn unlock_rejected(f : () -> Unit raise) -> Bool {
  try {
    f()
    false
  } catch {
    _ => true
  }
}

///|
test "password key slots stay within the upstream iteration budget" {
  let budget = UnlockBudget::new()
  assert_true(unlock_rejected(() => budget.password("PBKDF2-SHA256", 0)))
  assert_true(unlock_rejected(() => budget.password("PBKDF2-SHA256", -1)))
  assert_true(
    unlock_rejected(() => budget.password("PBKDF2-SHA256", MAX_ITERATIONS + 1)),
  )
  assert_true(unlock_rejected(() => budget.password("scrypt", 1)))
  budget.password("PBKDF2-SHA256", MAX_ITERATIONS / 2)
  budget.password("PBKDF2-SHA256", MAX_ITERATIONS / 2)
  assert_true(
    unlock_rejected(() => budget.password("PBKDF2-SHA256", 1)),
  )
}

///|
test "ecdh key slots are capped at the upstream slot count" {
  let budget = UnlockBudget::new()
  assert_true(unlock_rejected(() => budget.ecdh("HKDF-SHA256", "P-384")))
  assert_true(unlock_rejected(() => budget.ecdh("scrypt", "P-256")))
  for _ in 0..<MAX_ECDH_SLOTS {
    budget.ecdh("HKDF-SHA256", "P-256")
  }
  assert_true(unlock_rejected(() => budget.ecdh("HKDF-SHA256", "P-256")))
}

///|
test "the encryption limits match upstream" {
  assert_eq(MAX_ITERATIONS, 10000000)
  assert_eq(MAX_ECDH_SLOTS, 16)
}
