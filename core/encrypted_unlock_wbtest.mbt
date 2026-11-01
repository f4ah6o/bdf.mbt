///|
fn encrypted_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "YmRmAAEAAQAgAAAAAAAAAOoBAAAAAAAAAAAAAAAAAAB7ImJkZiI6MSwiZW5jcnlwdGlvbiI6eyJj",
  )
  joined.write_string(
    "aXBoZXIiOiJBMjU2R0NNIiwia2V5cyI6W3sidHlwZSI6InBhc3N3b3JkIiwia2RmIjoiUEJLREYy",
  )
  joined.write_string(
    "LVNIQTI1NiIsIml0ZXIiOjEwMDAsInNhbHQiOiJIQmc3K0E0VE55ZmpaalBFUkNKc1RRPT0iLCJr",
  )
  joined.write_string(
    "ZXkiOiJtcE5VSXBJcTNqYjAyZ3FEY2xYd1FZUDFKTzE0VjkwSTQ5QWRHVEtTc0djWWcrWm9zSlgw",
  )
  joined.write_string(
    "NFE9PSJ9XSwibWFuaWZlc3QiOnsicGFydCI6IjZlMGVlYWQ5ODBjNzc4MGRhODE2YTZjYTdkYTA5",
  )
  joined.write_string(
    "MzM1IiwiZW5jIjoiZGVmbGF0ZS1yYXcifX0sInBhcnRzIjpbeyJoIjoiNmUwZWVhZDk4MGM3Nzgw",
  )
  joined.write_string(
    "ZGE4MTZhNmNhN2RhMDkzMzUiLCJ0Ijoic2VhbGVkIiwiZW5jIjoiaWRlbnRpdHkiLCJsZW4iOjI0",
  )
  joined.write_string(
    "NSwic2l6ZSI6MjQ1LCJvZmYiOjB9LHsiaCI6ImVmOWZjNjIwYjExYWZiZmVjMTA2NTI5MjE2MDRm",
  )
  joined.write_string(
    "NTZmIiwidCI6InNlYWxlZCIsImVuYyI6ImlkZW50aXR5IiwibGVuIjo1OSwic2l6ZSI6NTksIm9m",
  )
  joined.write_string(
    "ZiI6MjQ1fV19Xg6BbbGUWtWSx7EVcdt9QBuypVLS2IKsc9EXPmglQspdqD2jTkMmbV03KjHuQnuo",
  )
  joined.write_string(
    "aQq0I/62cmTbkpyf3XbWDTRvIus1PSdlNItGVogJsozE0d6Yb4FL477r9IZaCyUEvnSsxyicYKg/",
  )
  joined.write_string(
    "veYzBqLtioQt2ntNPjVEWEPl28ZOtCPbdzZY01GrlmCCGucdZtGFpysI+vRtubYUdQlDsvbupcFI",
  )
  joined.write_string(
    "pZy8NAvTh5RTM2vyOONtYPziRKc6WSnQ1TyjmduKPukm7C77zpmlmA97hz3ABOE1IhzZY6YaXkCH",
  )
  joined.write_string(
    "T1bnmaCCRD9ULbk1DKO3t89uKeP1FlS67xdJgUl65OQ5mCnXKFRW3F6duVNb27j7C89UyXVnyU83",
  )
  joined.write_string("Hd54aTvi8EK/dtm+yzt6lcjc9yqM2dwS7SV+6w==")
  @base64.decode(joined.to_string()[:]) catch {
    _ => raise BadFormat("fixture")
  }
}

///|
test "password unlock opens an encrypted BDF" {
  let document = open_encrypted_with_password(encrypted_fixture(), "password") catch {
    _ => abort("unlock failed")
  }
  assert_eq(document.manifest.views.length(), 1)
  assert_eq(document.manifest.views[0].pages.length(), 1)
}
