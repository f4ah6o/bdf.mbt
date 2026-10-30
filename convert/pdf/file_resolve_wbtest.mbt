///|
fn check_pdf_resolve(
  name : String,
  chunks : Array[String],
  entries : Array[(Int64, PdfObject, Int32, UInt64)],
) -> Unit raise {
  let joined = StringBuilder()
  for chunk in chunks {
    joined.write_string(chunk)
  }
  let encoded = joined.to_string()
  let compressed = @base64.decode(encoded[:])
  let input = @gzip.decompress(compressed[:])
  let file = pdf_open_file(input)
  for (number, expected, length, digest) in entries {
    let loaded = file.load(number, 0)
    assert_eq(
      normalize_pdf_object(loaded.value),
      expected,
      msg="\{name} object \{number}",
    )
    match loaded.stream {
      Some(bytes) => {
        assert_eq(bytes.length(), length, msg="\{name} stream length \{number}")
        let mut hash = 14695981039346656037UL
        for byte in bytes {
          hash = (hash ^ byte.to_uint64()) * 1099511628211UL
        }
        assert_eq(hash, digest, msg="\{name} stream bytes \{number}")
      }
      None => assert_eq(length, -1, msg="\{name} stream absent \{number}")
    }
  }
}
