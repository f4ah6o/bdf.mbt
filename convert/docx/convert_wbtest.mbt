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

///|
fn docx_table_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GC4tS0+9qS/1IbXQN46RgYGYSAd7ZyfV5KaVxIfUlmQWhyrV5Gb",
  )
  joined.write_string(
    "Uxuw1++wgcC9Sq7T2l2yEgJOnlYfjJmcKxsm13rqvNn8tNj79zeL3JcNXI/vfl+9Pvptk3j0mTdK",
  )
  joined.write_string(
    "Xz+5bQ1SmJkh67v3T8R+k+9BBYybHign6n8/UWQaU/q61kks1OfO6Z1TviwwnS3JvKGLc6VS8hlG",
  )
  joined.write_string(
    "L9vPS4Rn+M8IuL/t7VyziVxBmaceKba/43S/8UNpXvnXWp1JFzeL9Ls/mnTV2+OkNfPSR1Xe38K9",
  )
  joined.write_string(
    "ir0CQisffHgjFB/edEVcWOzJ+4bJ79bqTZ7r+pFv5x6nFTp/RTdfNZvlu8Lr6/6zrfMKZeYe3FxX",
  )
  joined.write_string(
    "6G0plbJuMvv6cx4M7vZ/vya+eygdgBI2OxtdCjcAeVrAsOEG0vFFqTnF+nogsve8Nd8hAx62B3OD",
  )
  joined.write_string(
    "Xe5lRrG1BEzW41iprcXeIWTemyHndWjxdnVmZgU2t9v77U/nft9gvDPR55g1m28os6P6XiM/Ywv+",
  )
  joined.write_string(
    "41/5PE4d0jSsbucR87nwMbT6UOSTTZPVhIU0O7x5ls05PO+SivoWpVC7BdqTL7prF2kuXuZ4ovuC",
  )
  joined.write_string(
    "h3np3qUf7zL8S5wUZ9ixN6uBx/tAfY59n9ujg6dXu06vn/PDSyTSpXfmwbvurldXx4qKaeS/PN79",
  )
  joined.write_string(
    "hxPVY3xr0jNYgJ56BMSCQNHy/KIU/ZT85NJcYMyDorw08CAwynn2fhYNfacTq5mx6ppfA4u6isoD",
  )
  joined.write_string(
    "5ksq3tqqhVMkTv2ourRsqVNPt6y9/e+b5/59yCz5plj74uC1lN0nPdV02S9Gh07efr39tOxJJiPt",
  )
  joined.write_string(
    "GWza2UWTGmVmdf8N4Hzw3i3qTBK79KqFarKLVmvw7pnc1sprkZn8juOeQc/C8BIG/Tnses4dTG6X",
  )
  joined.write_string(
    "lc7nr0jcq+qbc7PJolcu2na3+/3ujysX7Wefy7vYT+cU51/m+LMGf0M76zbVbMkz0czLU7935Nvk",
  )
  joined.write_string(
    "0pWT5i+//9d/uWfLvzOyKsefrzy3cvp6kzvbNE5V3F746tHvqvBz3BZfj9S4CMYcOe3yce+rAt5o",
  )
  joined.write_string(
    "B5bNx6LkpufcKru4+DTry1/WZ80DvBmZRJhx5xQYaGBkwJ5v0A1AT04IA2QYURIXukb06EJo/MqI",
  )
  joined.write_string("JfICvFnZQNLMQLgTSGswg3gAS3fStPcDAAA=")
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX table rows become tabbed paragraphs" {
  let data = docx_table_fixture()
  let document = docx_document_text(data)
  assert_eq(document.paragraphs.length(), 1)
  let paragraph = document.paragraphs[0]
  assert_eq(paragraph.props.tabs.length(), 2)
  assert_eq(paragraph.props.tabs[0].position, 100.0)
  assert_eq(paragraph.props.tabs[1].position, 250.0)
  let kinds = StringBuilder()
  let text = StringBuilder()
  for item in paragraph.items {
    kinds.write_string(item.kind)
    kinds.write_string(",")
    text.write_string(item.text)
  }
  assert_eq(text.to_string(), "A\tB\n")
  assert_eq(kinds.to_string(), "char,tab,char,break,")
}

///|
test "DOCX table conversion places cells on tab stops" {
  let result = convert(docx_table_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut a_x = -1.0
  let mut b_x = -1.0
  for command in commands {
    match command {
      @render.FillText("A", x, _, _) => a_x = x
      @render.FillText("B", x, _, _) => b_x = x
      _ => ()
    }
  }
  assert_eq((a_x, b_x), (72.0, 172.0), msg="DOCX table tab stops")
}

///|
fn docx_image_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GDI3R4fu+h74o+fQN4DRgYGYSAd7ZyfV5KaVxIfUlmQWhyrV5Gb",
  )
  joined.write_string(
    "UzvR14/ZkKf1+xylU2JnUxIaBV75iP/RaXS1bJhakbZIzW/KkqV7bf24Y0N0T//Ye/58n/jpueVJ",
  )
  joined.write_string(
    "3Zq3HfbuybbWnFBiMG1ZXN3ae7PcNYsYjR4wJep/n/G0aEfkmm+CmxNmFOk/D3o0OSjy/AvF7YpK",
  )
  joined.write_string(
    "G43aniz8YOyr1RR3uOXVvtdyU/hCJngFZ/Fb6sQVtPRqPyo9/vSxAmfstEc/M9ZE7m2RmHs1ICI8",
  )
  joined.write_string(
    "2ihd82y+0+knByenS3/WlV6ya0bA1NeM13d6XJZMr7275trMHw/2+1xb8KMl5N7Bzev2ORudYtn7",
  )
  joined.write_string(
    "8cyW/+zxN3R6Fl+teJS9fUbTsTk/Pe5tVT/avHR/79WHDof5A1BCamejS+EGIE8LGFLcQDq+KDWn",
  )
  joined.write_string(
    "WF8PRPaet+Y7ZMDD9mBusMu9zCi2loDJehwrtbXYO4TMezPkvA4t3q7OzKzA5nZ7v/3p3O8bjHcm",
  )
  joined.write_string(
    "+hyzZvMNZXZU32vkZ2zBf/wrn8epQ5qG1e08Yj4XPoZWH4p8smmymrCQZoc3z7I5h+ddUlHfohRq",
  )
  joined.write_string(
    "t0B78kV37SLNxcscT3Rf8DAv3bv0412Gf4mT4gw79mY18HgfqM+x73N7dPD0atfp9XN+eIlEuvTO",
  )
  joined.write_string(
    "PHjX3fXq6lhRMY38l8e7/3Ciemx1RkwwyGMKQI/JAOny/KIUfYjvUvKTS3OBqQGUDKA+3cjFZAj0",
  )
  joined.write_string(
    "6d3lGjf3zmtSKrIVF4xxlVfYsjPu46xp27r27WUVZ2U/rvLnvv+uu4f9H/lp7j7AJebL3RTB/viG",
  )
  joined.write_string(
    "1o45/J95O2Im8Po1eh6cbPTmV2T5Ik7vs08uHtXROhR5MMLrjtfMrx5yxcJKhXt5FCt1Sn3C3K6E",
  )
  joined.write_string(
    "b1GZnrt72svLDf9Oi7gvVpA9y3Xkp+RLeWue5stb+H896zzdz/Wy5u06BTVv10b1xx/2xphM1D2x",
  )
  joined.write_string(
    "b3J8/1d9VJ/ynVHcmwT0pR4zA4MgzKfIfpw7yTfvkIFA63db1ye1kg4LFwUKmXGs7PaaekvuQKFa",
  )
  joined.write_string(
    "p+r/k2a8X75sZW68IJr0eM/Jnv0z063vyyzxqLtgtS7UUWyzpWeAYWzxVbEnv7O/71Hr/BxyNSSj",
  )
  joined.write_string(
    "ldVykfLsT5rvN0dt3uvydLJDgN5r7kuV+UYMx62mXDm7xVG0qHfbpF8Ct8SqcrOTTZ2fOzFrJljO",
  )
  joined.write_string(
    "39+wJGaiYPK7h1emfRM+oFtW7dXn8ouhwGriwzeMTjeefhdz79jLvnB2m/Gdeee/HtmosYK//LFV",
  )
  joined.write_string(
    "nozm4Z3hu+yOre/s7j29s3SC2mOvgtbmI8391w/zsVbGLnlpE6NrHWcyxfJslLfv8ZsueSuXp8ot",
  )
  joined.write_string(
    "69/nv0jozpsdAhu1Xh1J09Bew510/1Uoy8FcyZhth+31fKIOpUTNmNFwUHQOr1XKv+SCzFvn7y/p",
  )
  joined.write_string(
    "f5+zMWbZQZ/5pY7rr71MUBPbEyz9r0r2XoCJpLdOvnU9r/bbvdOuRyQYpyVmWH1r/rjg4a9Lp+1R",
  )
  joined.write_string(
    "IySQ/xaTA5DnCsSisAjJTU3JTNTPzE1MTzXUK8hLf83zofj500mPkhISHnz9UsDJdKlH4cxBFhX1",
  )
  joined.write_string(
    "Kez3mYNs5un1KYoWT6qfY3/gwIEzJ04UfLq/5LtDIZt/uP30Uj9OX4YAb0YmEWbcRR4MNDAyYC8A",
  )
  joined.write_string(
    "0Q1ALwkQBoBEkMoFdI3oOQ2hkZkJf75DNwk9JSNMesuEJV2ja0cPd4T2OhYcsRDgzcoGUsIKhG5A",
  )
  joined.write_string("mz+ygHgAEjKIJk0GAAA=")
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX inline images are embedded" {
  let result = convert(docx_image_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut images = 0
  let mut size = (0.0, 0.0)
  for command in commands {
    match command {
      @render.Image(_, x, y, w, h) => {
        images += 1
        size = (w, h)
      }
      _ => ()
    }
  }
  assert_eq(images, 1, msg="DOCX image command")
  assert_eq(size, (72.0, 72.0), msg="DOCX image size")
}
