///|
fn encrypted_ecdh_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "YmRmAAEAAQAgAAAAAAAAAHQBAAAAAAAAAQAAAAAAAACMkEFzmzAQhf/LXsFTA5IAzfjg2jhuqeM4",
  )
  joined.write_string(
    "ids0nRxAWsU4WCZIgRIP/71D3Pbs25Nm3/t23wlyqYB7LqAWdVfZ4qiBn0AU1Q5r4DD1KbuarcCF",
  )
  joined.write_string(
    "F+wM8F8nsF2FwAGF3A3fgx+W6XwxulsO0+CCqBvgcDM6v7B6AQ6fl9/JfPlj1qS0dULyKO8eHsax",
  )
  joined.write_string(
    "3RQi3gdy//i7TOjrKk2u1mlZJOuDiOafHH1PqsV2v7o+tN6cJW9kEcfPB6lN86aDeHNDVpNhBeyA",
  )
  joined.write_string(
    "gw2jLp5unPFep1+M8x687ppvzXNyfd+t/XjLwq8/j9vWdM6to81sw249w6btZAL9kwuHTBcKjR1u",
  )
  joined.write_string(
    "r7LaAgflC4JKESpkiAoF+sqjYR4pygj1SQQfnQEHiarMLI7qrIW+dz/856Z2l8UMNINZifJ/ZiFR",
  )
  joined.write_string(
    "28J24EKJGrhPmAumeMe/8qgU8HHvnhlhTIMgGzOqcqRM5kJ5KkRGQxb5OXrZZQwa/0MM6qgUcJ+w",
  )
  joined.write_string(
    "/qn/MwAmJ73kw8swEi3+7vbACTCKmyZjJruUDqDJdAZyVUNOb1mf+2o1dwm42DQeMzSTWX9ksE9y",
  )
  joined.write_string(
    "Zu+Njdm9eWPz+lqDh/Z0UPq2vpumX7btIqxRyatmdooHH6ebZYoIlYWewySvqMGGiVefs5+zHBPh",
  )
  joined.write_string(
    "E33UimHpevu7LYZy77daTj+02/nTCrRhYrSO45YNZbNbIN3azYXAFxdNGUWKW5GsNQ1R0RWMsZDr",
  )
  joined.write_string(
    "if1t77WQTt3kQeoaWo2TvLZKEcoA9/xUnaj94xsRNahbY+ezPZR85MXShmihzBmqa9+NpxdtOfhn",
  )
  joined.write_string(
    "/wiS4+Ka/45C3uZ844cwa0/y0tXdxnEhgzwlAgVt735kA2q/yflFkbPgl9xNPBM3jWqb3Nf0GMVB",
  )
  joined.write_string("P8ZGU/mmW9616+hwuMeJs5CLhBcu6InwvA==")
  @base64.decode(joined.to_string()[:]) catch {
    _ => raise BadFormat("fixture")
  }
}

///|
test "ECDH unlock opens an encrypted BDF" {
  let private_key = unlock_hex(
    "21bdb245c5a19ec1f5571ab6dba2440bf9caf0490e27fe075023376c848cb81c",
  )
  let document = open_encrypted_with_ecdh(encrypted_ecdh_fixture(), private_key) catch {
    _ => abort("ECDH unlock failed")
  }
  assert_eq(document.manifest.views.length(), 1)
  assert_eq(document.manifest.views[0].pages.length(), 1)
}
