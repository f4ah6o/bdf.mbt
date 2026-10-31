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

///|
fn docx_numbering_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GBo2REfmxIXcPYvkGfMxMAgDKSjnfPzSlLzSuJDKgtSi2P1KnJz",
  )
  joined.write_string(
    "1k4863fYQKDlvU3r0+ypFgUOHKovG+crF2jwb7CYfeRQ/SerpbXVZrknGUV3FGxJ3zdzYuz68nNd",
  )
  joined.write_string(
    "umpGB80/bVqzxGG9c/qfCyeun00uVGZN/SB748HGidUqO/P0X521U+JsszUtOmN5T8u1yoU9pK1j",
  )
  joined.write_string(
    "3lQ7FfaZ/ZkBgl+seVasW/Uq6uUD418xTyydt321/WZwU0eurKZWZtKFSSLl7o/vXPXouCjFO7N0",
  )
  joined.write_string(
    "69e726c9uhJgVPnhQobS2hsKV2+2Rf7c+eCI7efTKpcXVjROmX9go3dty5WVei9OGkb+kytOS39R",
  )
  joined.write_string(
    "vbjw4fMtM5rclOqK0k+7Fib8ebVetq4of8aMP/8Vvb9c5yj98fmbcABKaO1sdCncAORpMTIwcAPp",
  )
  joined.write_string(
    "+KLUnGJ9PRDZe96a75ABD9uDucEu9zKj2FoCJutxrNTWYu8QMu/NkPM6tHi7OjOzApvb7f32p3O/",
  )
  joined.write_string(
    "bzDemehzzJrNN5TZUX2vkZ+xBf/xr3wepw5pGla384j5XPgYWn0o8smmyWrCQpod3jzL5hyed0lF",
  )
  joined.write_string(
    "fYtSqN0C7ckX3bWLNBcvczzRfcHDvHTv0o93Gf4lTooz7Nib1cDjfaA+x77P7dHB06tdp9fP+eEl",
  )
  joined.write_string(
    "EunSO/PgXXfXq6tjRcU08l8e7/7Dieox31v1TiCPKQI9JgOky/OLUvQhvkvJTy7NBaYIUFKA+nQj",
  )
  joined.write_string(
    "1yEDAbYHd5dzbL99hU/p0pJujtildg4+63M37GxREf39LU2Ilf347sf/+/bnzStL4+e5aCG0Qdsr",
  )
  joined.write_string(
    "wePW1zY3xuvv9tgydHsGrk9z10g4ytF754r4nNBTMy0k5SPdNLhmBH1yP7d43oVVERb9U/SbucOW",
  )
  joined.write_string(
    "2rRNrF76PsslburTee3+zE+mn7wV55Dxmytie9Wf42WHE0zmzYnTCfr1selyUr5E0daeVQZJQh/i",
  )
  joined.write_string(
    "RCOZ9bL/XfXZx4DqU+G2g7m3gLxUoE+FYD7NK81NSi3KzEsHeTI2YHfeYQOeO79FmRp7tj7hc010",
  )
  joined.write_string(
    "OSem4L38C7NIpy+LxxRFzbJf35fOZb+kp1Jx3Fpux72YJAHlZ4+EMzOkWZlOqj1/ueJh9v7avwyB",
  )
  joined.write_string(
    "qxTTnZSufGhmNft7uurVCxn+GZX+G1in5l0qWFX6YonOt5aLU9R4Pc7ULpfxfWoo/3TKJumiTRFc",
  )
  joined.write_string(
    "2skT8r32ns6wcTw/71lAltm2unmLfxi/ncO2dU2LocHTnXcF+6ZrJy9OXMF6M/5w7mPmkoxak4de",
  )
  joined.write_string(
    "G4v6p7Nvz5otOZ1745flm821N16xdP5t/+zc3d4rZ9vSZtb88v/PjRoSmZ7LLzIAQ4EJmPUFYSGB",
  )
  joined.write_string(
    "HNtbA0/nHVYQ2PNdW+cd77anYRNFrbd72IasmvKNmUOgh0Wnqfful9fd8R+XXo/7ZrjZunna4Y+3",
  )
  joined.write_string(
    "Z62ZrphVwKtZZnlyyWOFLcG8P3/Z2L73FJtoeZDH4uaE3T1PbtjJtkUx7I98aeDNpXfN2dnKJT5Y",
  )
  joined.write_string(
    "qlJdt9v6wyXVd1wHjXxyA0oaFGoY9JJ92K5dMDofvzL11kQzzziHO8ffLP8geOxJXpnelpe+Zlds",
  )
  joined.write_string(
    "jXlPcsbuMN+YdLTj4nGmWg0fxtuT+QTdJdSLJH+a79785MGR+XWBRXPS91r9VzlYsnuRzuqS3wvf",
  )
  joined.write_string(
    "Bf3dtF7Me/29SA+NJv8K036WtVZ3bnErNN2tUl6vbW1f+HXx69aX36rf6gd4MzKJMOMuK2GggZEB",
  )
  joined.write_string(
    "e8mJbgB68YEwQI8RpTBB14iePREa2ZnwZ1Z0k9CTP8Kkj0zYMgO6fvREg9D/mxlLEgrwZmUDSbMC",
  )
  joined.write_string("oTNQmxYriAcAFmctQ4MGAAA=")
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX numbered paragraphs get decimal prefixes" {
  let document = docx_document_text(docx_numbering_fixture())
  assert_eq(document.paragraphs.length(), 2)
  let first = document.paragraphs[0]
  assert_eq(first.items[0].text, "1.")
  assert_eq(first.items[1].kind, "tab")
  let second = document.paragraphs[1]
  assert_eq(second.items[0].text, "2.")
}

///|
fn docx_story_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GA4uiM+9sB7Y09WRgaGdUwMDMJA0Wjn/LyS1LyS+JDKgtTiWL2K",
  )
  joined.write_string(
    "3Jytk3b7HTYQaSufd+hTlKqfpICTp1WBZONCmwMTaydFHLGb1h99a/vxTC/2kBdMi//G74uf9vrq",
  )
  joined.write_string(
    "ud6k7om6P930TntxfZnV87VW+f41/6NrReYckJY4maz8/UTR1birr2sdxCzf7Jzo7PXQT/Mas9WD",
  )
  joined.write_string(
    "SUy/1pSIyC6p6dnLteD+QvfS2FBzr8n+L4InLuO7eY3/xsE0n0eF09c/VxR0n/aozsxvjZsTx+Kr",
  )
  joined.write_string(
    "Ezat23avZrGIu9PMyez8/GYflKSXWHnPmDKf8fgd77qZGbxd4R0vJWPKVvJ3uUlekp4++el70/Sy",
  )
  joined.write_string(
    "oOuRvcv/XBFTykw55//u2KclFhvqCjOPNyQY6P2vOxZTM/G+4NL6h+ePxteU/sh7qx6AEmo7G10K",
  )
  joined.write_string(
    "NwB5WsCQ4wbS8UWpOcX6eiCy97w13yEDHrYHc4Nd7mVGsbUETNbjWKmtxd4hZN6bIed1aPF2dWZm",
  )
  joined.write_string(
    "BTa32/vtT+d+32C8M9HnmDWbbyizo/peIz9jC/7jX/k8Th3SNKxu5xHzufAxtPpQ5JNNk9WEhTQ7",
  )
  joined.write_string(
    "vHmWzTk875KK+halULsF2pMvumsXaS5e5nii+4KHeenepR/vMvxLnBRn2LE3q4HH+0B9jn2f26OD",
  )
  joined.write_string(
    "p1e7Tq+f88NLJNKld+bBu+6uV1fHiopp5L883v2HE9VjcTZrVfYAeXOAHpMB0uX5RSn6EN+l5CeX",
  )
  joined.write_string(
    "5gJTBihJgH269sJ+rkMGAsc/3l3Osf32Fj6lpFuuLuEX2S0mvZbPKVbsXJSfHzBBTEZGpl7mZ43i",
  )
  joined.write_string(
    "7Fd2Xx652ZXkiIpE8jWtSbt80+3gzy2z1zu0dFxLOD9NxEbDIfScmfsrw2XmC9/GCHBudHSUXhzt",
  )
  joined.write_string(
    "LVnizdzWI3uzZOVNfonLX3pLVujfmBDz5GfQr42MT4+IsC8+IH9G7sjLhy/EZ7/edXlLaq3siWP6",
  )
  joined.write_string(
    "nDeFpD55utwP8HmWLR7Z5FD3/v2/m+tnPt7x/978fXNqsn6yoPpa4CxP9UQgbysQC8B8nZGamJJa",
  )
  joined.write_string(
    "ZAjyruzZg1zgON3tH1hUPlfO5ditu238C/gDru3gvbZF5ejL27fffZr4YbL93w+8s38pnJY6eWBp",
  )
  joined.write_string(
    "pqOi78X1JtIVtsc/y05Jcb+XO/HCAX5WtupX3/M+rjll6LldOqLIb+41I12JOSaGilPfyFruiAmb",
  )
  joined.write_string(
    "91XupnqfcNeUdxteZt++V1Kg3aibu/LQ1Bz5FzZF61/HPD1cErHvlj1apB3cemcCuvPT8vNL4M63",
  )
  joined.write_string(
    "5Ws24GF9sHd5x57pF/hCWzly5iywdWB55q5UluK+dG+t8DT/bfP+3Pl2f8Ns/q48H768UF62zCeZ",
  )
  joined.write_string(
    "i48e/G0aMz/BpHLWn3MtfHUrLpRP/5bxTEVNfrJZe7Pp0hsRqx93Hcw+KqiZbuz9QXP9phvNqV2H",
  )
  joined.write_string(
    "lFc9e7fhdnWsfc4Hacfpt5McuVZKzxD2yj4dM+Vyxaz9ZfWort8eHFmpCkxuYsASSBDmeuTE1hvo",
  )
  joined.write_string(
    "63/YgGfvZ+1VdyK3ZR0IWTu35QILu8qR4/wnpJb3XjkycbLhsfXHM817H+v1xf/58+j5GnP7PI19",
  )
  joined.write_string(
    "jYtc47uP5uhxfdDNer07qqY2Lz98UYdn5Vq2LwHdyi4bM/OutXsl7y5/EHyQyy6sPeqLZqvXqRvf",
  )
  joined.write_string(
    "HoTMSWQ4b9r8JCTJY66NwkuHG049fxqkUyzn3/devkZcXXKXG1vvRl2buWwzXDjYpt5weZPbsegh",
  )
  joined.write_string(
    "Y/mK/p88lgF8Kyuf7N56JrLP5NhGuYW++cor2Zc23jvI8FFtQcInww3FvG5v21W4Vq1Zx7r3Rbpi",
  )
  joined.write_string(
    "cbOjz3XTnOVtF2r/GHWbb9M4rZo/R/7pn7yjPzs/rNJ4nfDg91MXxdtfXzKVzxDaxS134M9qP7Ws",
  )
  joined.write_string(
    "jwF9BVKFTUUmtd+0z1dPmi6f+48hwJuRSYQZd7kOAw2MDNhLeXQD0Is4hAFmjCgFHrpG9CIEoZGf",
  )
  joined.write_string(
    "CX+Bgm4SerZEmMTKjJlJMdyBlisQuo8wY+YRdN3oqRKhu4kFSxoN8GZlA0mzAWE9UNs1VhAPAPdY",
  )
  joined.write_string("7atrBwAA")
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX headers and footers are rendered on each page" {
  let result = convert(docx_story_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
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
  let value = text.to_string()
  assert_true(value.contains("Body"), msg="DOCX body")
  assert_true(value.contains("Header"), msg="DOCX header")
  assert_true(value.contains("Footer"), msg="DOCX footer")
}
