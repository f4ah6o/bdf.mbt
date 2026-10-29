///|
test "manifest exposes Parquet table metadata without losing large integers" {
  let input =
    #|{"bdf":1,"parts":[],"tables":[{"id":"data","title":"Names","part":"0123456789abcdef0123456789abcdef","rows":9223372036854775807,"columns":[{"name":"name","type":"string"},{"name":"count","type":"integer"}],"view":"sheet1","page":2}]}
  let manifest = parse_manifest(input)
  assert_eq(manifest.tables.length(), 1)
  let table = manifest.tables[0]
  assert_eq(table.id, "data")
  assert_eq(table.title, "Names")
  assert_eq(table.rows, 9223372036854775807L)
  assert_eq(table.view, "sheet1")
  assert_eq(table.page, 2L)
  assert_eq(table.columns, [
    { name: "name", kind: "string", },
    { name: "count", kind: "integer", },
  ])
}

///|
test "manifest rejects invalid table references and duplicate identifiers" {
  for
    input in [
      (
        #|{"bdf":1,"parts":[],"tables":[null]}
      ),
      (
        #|{"bdf":1,"parts":[],"tables":[{"id":"data","part":"bad"}]}
      ),
      (
        #|{"bdf":1,"parts":[],"tables":[{"id":"data","part":"0123456789abcdef0123456789abcdef","rows":-1}]}
      ),
      (
        #|{"bdf":1,"parts":[],"tables":[{"id":"data","part":"0123456789abcdef0123456789abcdef"},{"id":"data","part":"0123456789abcdef0123456789abcdef"}]}
      ),
    ] {
    let rejected = try {
      ignore(parse_manifest(input))
      false
    } catch {
      _ => true
    }
    assert_true(rejected)
  }
}
