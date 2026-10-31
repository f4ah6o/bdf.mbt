///|
fn docx_convert_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GAQ3RYfe9JfasNrIG8dIwODMJCOds7PK0nNK4kPqSxILY7Vq8jN",
  )
  joined.write_string(
    "qQ3Y63fYQOBeJddp7S5ZCQEnT6sPxkzOlQ2Taz113mx+Wuz9+5tF7ssGrsd3v69eH/22STz6zBul",
  )
  joined.write_string(
    "r5/ctgYpzMyQ9d37J2K/yfegAsZND5QT9b+fKDKNKX1d6yQW6nPn9M4pXxaYzpZk3tDFuVIp+Qyj",
  )
  joined.write_string(
    "l+3nJcIz/GcE3N/2dq7ZRK6gzFOPFNvfcbrf+KE0r/xrrc6ki5tF+t0fTbrq7XHSmnnpoyrvb+Fe",
  )
  joined.write_string(
    "xV4BoZUPPrwRig9vuiIuLPbkfcPkd2v1Js91/ci3c4/TCp2/opuvms3yXeH1df/Z1nmFMnMPbq4r",
  )
  joined.write_string(
    "9LaUSlk3mX39OQ8Gd/u/XxPfPZQOQAmbnY0uhRuAPC1g2HAD6fii1JxifT0Q2Xvemu+QAQ/bg7nB",
  )
  joined.write_string(
    "Lvcyo9haAibrcazU1mLvEDLvzZDzOrR4uzozswKb2+399qdzv28w3pnoc8yazTeU2VF9r5GfsQX/",
  )
  joined.write_string(
    "8a98HqcOaRpWt/OI+Vz4GFp9KPLJpslqwkKaHd48y+YcnndJRX2LUqjdAu3JF921izQXL3M80X3B",
  )
  joined.write_string(
    "w7x079KPdxn+JU6KM+zYm9XA432gPse+z+3RwdOrXafXz/nhJRLp0jvz4F1316urY0XFNPJfHu/+",
  )
  joined.write_string(
    "w4nqsf8Xvoo8APL8gB4TBNLl+UUp+in5yaW5wJgHRblrwMGswwY8e99r97xffflCr9CkLxuCyiSl",
  )
  joined.write_string(
    "c5pjY6N9mbal5uTGff+6OdhJz7/qkrN/UPWPrW1/HTqEd/Xlm4umPxB5dZJX9v8fi7vvLbtV5k5j",
  )
  joined.write_string(
    "ky35wzVR/tduM1Opq9tZ3XX8CzZ6ysp31ii7hChHSJq/OPj0Hmvz1CmZEi6HFtQ6sBqmMWe7xIb2",
  )
  joined.write_string(
    "Hzp18qNdv83ifdNecLcwXbFvNjzRt94/fq3GnoQZhWGuAV/MvP9++Hc86GZy9PXdNe5Zx+bYvynW",
  )
  joined.write_string(
    "y2sSlyyaeuH5r3dqnJcNLnmd92gpe8qm5x1+Zln3/Ihtoq/Vf9UHeDMyiTDjzgUw0MDIgD1PoBuA",
  )
  joined.write_string(
    "nlQQBsgwoiQcdI3oUYHQ+JURS8QEeLOygaSZgXAnkGZhBvEASDIAjNMDAAA=",
  )
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX text conversion emits a page and text" {
  let data = docx_convert_fixture()
  assert_true(detect(data))
  let result = convert(data, title="sample")
  assert_eq(result.pages, 1)
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  assert_eq(manifest.views.length(), 1)
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let text = StringBuilder()
  for command in commands {
    match command {
      @render.FillText(value, _, _, _) => text.write_string(value)
      _ => ()
    }
  }
  assert_eq(text.to_string(), "Hello DOCX", msg="DOCX text run")
}

///|
test "DOCX detection rejects non-ZIP input" {
  assert_false(detect(b"not a document"))
}
