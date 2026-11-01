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

///|
fn docx_header_variant_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GB4vyM+dv33Li5WRgYGPWYGBmGgaLRzfl5Jal5JfEhlQWpxrF5F",
  )
  joined.write_string(
    "bs7RSbv9DhuItJXPO/QpStWvu0XA61LjNEGJU8wyN9U7W/M/FXr//mbhe5Vx6mmGpC3/T38/XbT3",
  )
  joined.write_string(
    "TvThMgnP6usfKiML2/yqlsbe/zD9rHPhaUnVAq6e8hsfmIXit4V/fSYwIYLPOuvHhKAdwk1PGsRW",
  )
  joined.write_string(
    "fGGMDbOS111S07OXQyF+ofvGFaukFfd6vwiaeIzv3jXtNwnZQtHvP381UVmkeO6d+uMTWRYtCVta",
  )
  joined.write_string(
    "ppRuLH7FvNRC8NQcm6qMC41pNw8cdT20oobP4um8T6dd1k6wdfbpT9jsvefnipZPRdnFm/7senbI",
  )
  joined.write_string(
    "735p1CNL+22tL1SFnqpvX2ajLbZldu32ZIcAief77ZO1/inWfzz/5/X+Z92Py/PvMwaghNrORpfC",
  )
  joined.write_string(
    "DUCeFjDkuIF0fFFqTrG+HojsPW/Nd8iAh+3B3GCXe5lRbC0Bk/U4VmprsXcImfdmyHkdWrxdnZlZ",
  )
  joined.write_string(
    "gc3t9n7707nfNxjvTPQ5Zs3mG8rsqL7XyM/Ygv/4Vz6PU4c0DavbecR8LnwMrT4U+WTTZDVhIc0O",
  )
  joined.write_string(
    "b55lcw7Pu6SivkUp1G6B9uSL7tpFmouXOZ7ovuBhXrp36ce7DP8SJ8UZduzNauDxPlCfY9/n9ujg",
  )
  joined.write_string(
    "6dWu0+vn/PASiXTpnXnwrrvr1dWxomIa+S+Pd//hRPVYpFf+o71AngwTEAPp8vyiFH2I71Lyk0tz",
  )
  joined.write_string(
    "gSkDlCTAPt16cS/XIQOBAx/vLufYfnuLqMuRLd66O7rsDkyMsd/g6yTkev+eAgeXa4yV3PG//w6/",
  )
  joined.write_string(
    "PfXbYoO05X1pXQXvoIQlSwP35rHO8f9axHyG/QoX+2LPA802U44mlS9hdN7zMTbftrvjG9MugTfT",
  )
  joined.write_string(
    "ivWtpS6qH5vUN/vYDkFnmdjTuqe4tx35bBJb/D3T4WPqpmahB3yrmMqqIn4dN/O97L2qZ0/fksMu",
  )
  joined.write_string(
    "TeUtXTEiF7eKLPo5a7OK04Hlv7/++fsnvN6+vv7ru8/rl4v5o3p7w941c6cDeXuAWADm7YzUxJTU",
  )
  joined.write_string(
    "IkOQf2XP+vIdUhBgfbB3ucLm7SHix0xa83o+MlQxBC2z5+RJcVi9XXzXz0kzp1de5o9/f4Tdcm2j",
  )
  joined.write_string(
    "yJxZYiyXJN54bW66/rluT5PHzQmmegJaPxKbHOV/rY3W6S7yWXlbRMfyuN8pE70XvllOLlo3RW7M",
  )
  joined.write_string(
    "jnGb91Tshhuf8rKQXXsnP9+21yM/jCn2VlKrduT9AqP86fIZOkX6r1ed2l243eZ6PaonRNKfhE4B",
  )
  joined.write_string(
    "8nZhesII4omDXOCUuds/sKh8rpzLsV132/gX8Adc2yF6bYvK0Ze3b7/75Phpsv3fH7yzfyl096c8",
  )
  joined.write_string(
    "uLRlwYRnL2x02eLOv6xhV705aXO0iskH58ZCi6/V263Cns5Ycpt3jeVyv+yZ4Txhs2ZM8PrWJ5Oj",
  )
  joined.write_string(
    "p6xf1f9G6Likq1f5jS9bc/OtIvwNpmwLeeglp3Z+knyGbNH614tOtb/csEfuH6oPZrp83w/ywU5M",
  )
  joined.write_string(
    "HxhDfOAISnGsF/Yu59i8faWei9fkdSL8C9g5zmZwn1U50xKWn3/pbPP5D/+/HDbXyXKdZjmpMfhy",
  )
  joined.write_string(
    "k5PU4vkvkx983SO/foGK9ae8zha2Og2DG877Syenh55SuZuWcMqyNOq0RWLBpSMtIXnvTxx8KvRz",
  )
  joined.write_string(
    "8fYTdoUygUty2l3n3/62qHk2Z06kt+i6lOroiXIvbIrWZ6/7lHdLd/5beVQf6MxaF+0GLBTmAPOP",
  )
  joined.write_string(
    "IMwHyDmnd9JBYGHK0/bexnWq9ekw3hmrtu7u8ZQREO5hPyG1vfeK2sTHa3uWH881N1Np27Hj3+v1",
  )
  joined.write_string(
    "9TK7Px91D3avPpAwx/doiomY4I07mcmnQ/bkh203FmQNClt9K9LjKGNTRIr5Z7OLevdNEzST2KUn",
  )
  joined.write_string(
    "mYmKTvRfwlPJ2sul/Pxg0dqCGxpJnUtzZLP69doFfjQsm/axokZfOnWNxa0H9TkxgTNkph1nYxNu",
  )
  joined.write_string(
    "iRKMVwo5xj6xsDl6Of/dy+WMux1udrfufDNJL0n+r39at+B1/nnvX4VyOsW5a97e8i58N4Pl2upl",
  )
  joined.write_string(
    "TEsZ4xcyPNl5aPv2Nqe3WUKCam7LmeZ/2WT96hd768GCzvX/jiXyf2uqk8kwCjm8601x/L5ao3PV",
  )
  joined.write_string(
    "s498nPL9XNqc+2ct7JnOr5Jv+/ynzkoh41TXuaLXHTHF10xFxK8u3Blic2SvzpzFk2WOVc2abJPr",
  )
  joined.write_string(
    "Pe//6jfcAd6MTCLMuGsxGGhgZMBep6EbgF6gIwwwY0Qp3tE1oheYCI38TPiLT3ST0MsghElszJgl",
  )
  joined.write_string(
    "Erpu9MyP0H2aGbMoQNeNnvEQuntZMLMhum70RI/Q7c+KJQsEeLOygaTZgXAvUNsRMA8Ajx1OWpcI",
  )
  joined.write_string("AAA=")
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX first and even headers are selected" {
  let result = convert(docx_header_variant_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  assert_eq(result.pages, 2)
  let text = StringBuilder()
  for page in manifest.views[0].pages {
    let resources = @core.decode_object_resources(
      @core.open_single(result.bdf).part(page.layers[0].object),
    )
    for command in @render.compile_object(resources.object) {
      match command {
        @render.FillText(value, _, _, _) => {
          text.write_string(value)
          text.write_string(" ")
        }
        _ => ()
      }
    }
  }
  let value = text.to_string()
  assert_true(value.contains("FirstHeader"), msg="DOCX first header")
  assert_true(value.contains("EvenHeader"), msg="DOCX even header")
}

///|
fn docx_anchor_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GBo2hMfu+h74o+fQN4DRgYGYSAd7ZyfV5KaVxIfUlmQWhyrV5Gb",
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
    "b3J8/1d9VJ++i4zLXwb05WdmBgZBmE+R/Th3sm/+bQOetve/RZveaQsr37RSLtN33CDbJnrj2m6l",
  )
  joined.write_string(
    "y9sYah2DXqfsr5siu/2cHverZp+oJ86T12+ptpA8G2fg8jTn6PVy7XMXvK5r3A7983394ePV55KE",
  )
  joined.write_string(
    "tgneilzzQ1K5foX9m7ZNhZ9uLvDt4TCb5nz095QaToHUfrcj1s8vXop73STYeefCwQdOj5snSyiL",
  )
  joined.write_string(
    "Gkh1XX0lLLFQZ77hPzE/4SMbGGKSv19+5iPynkHv/wntn3xMqUufNxir3GkqyF2t8k6/eK4F41aP",
  )
  joined.write_string(
    "Jb5vpvbvWbZTPrb4XP786ROme2ca1WqueRMrcXZFz/UfL5SsQ+eU2D4XPab7ftGpK+tzHu1/oGgR",
  )
  joined.write_string(
    "XKhv9aT4SP+23hmvSj9Wup7nW7fv3LuWnU12dxl0t83+7zj/mIjN0ppjKls/pO5dqHLuyc+ry/Jc",
  )
  joined.write_string(
    "brI+rFYVfxanEvjeo0nnXorM1k/sS0v7Tplxq85SNhPlvz8rl+1gqcSeZYftYyKmtBw9kbiQpefS",
  )
  joined.write_string(
    "AdelHUa2fUE/3z2XN3tyepNeF6+p8RTbm7d/n1XhZa0Rb9yn5i6uaD7TuenVry/P5GK9KjdsXr9x",
  )
  joined.write_string(
    "bnmijtX15p9bDtwuXfufCTVSA/lvMTkAea5ALAqL1NzUlMxE/czcxPRUQ72CvPTXPB+Knz+d9Cgp",
  )
  joined.write_string(
    "IeHB1y8FnEyXehTOHGRRUZ/Cfp85yGaeXp+iaPGk+jn2Bw4cOHPiRMGn+0u+OxSy+YfbTy/14/Rl",
  )
  joined.write_string(
    "CPBmZBJhxl1swkADIwP2QhTdAPTSBGEASASpbEHXiJ5bERqZmfDnXXST0HMDwqS3TFjyBrp29HBH",
  )
  joined.write_string("aD/EgiMWArxZ2UBKWIHQDWizKSuIBwCn/xU8kQYAAA==")
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX anchored images use page offsets" {
  let result = convert(docx_anchor_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut placed = false
  for command in commands {
    match command {
      @render.Image(_, x, y, w, h) =>
        if x == 100.0 && y == 200.0 && w == 72.0 && h == 72.0 {
          placed = true
        }
      _ => ()
    }
  }
  assert_true(placed, msg="DOCX anchored image")
}

///|
fn docx_crop_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GDQ3Rsfu+h74o+fQN4DRgYGYSAd7ZyfV5KaVxIfUlmQWhyrV5Gb",
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
    "b3J8/1d9VJ8ufCHvmQ/0pQszA4MgzKfIfpw7yTev2UCg9bst66d9kkITtVwdzAKX6GmF/rVsMGSO",
  )
  joined.write_string(
    "MNqWaq368mW2s0dGeKDZM97keuPzj3Oq37h86T1WpFq8KeaIitPJkKOpkyevP//3cZvLtcDIwIUq",
  )
  joined.write_string(
    "z560TMvpbl/jr32UT9ZLvLJpS+b8ydcs5zJFXEtyf+uUOcUuXPty4HPnyw7rfZb2JmWs1b/AGXH0",
  )
  joined.write_string(
    "o3DJFG+jxC+6c05dqGP70X2392Snx3uGc9aX5tx1/LD8zsEHLIbbFUJii9t2f97bJ9PcZGUvfbso",
  )
  joined.write_string(
    "1/Ph+70hVzVrSiN8Is4t3XtFc3qTt4yKXKwEv/WzJ5UzVTbK61rHmohI+ko7l56+6fNuxWLXZ7v5",
  )
  joined.write_string(
    "97kHcq37HtOxQfvFiSU3pkY8PbIn5LVgCm+1+zOliZNLZforflRL6AX8COdN6z1whvnMmoMPRM9t",
  )
  joined.write_string(
    "W7v+q1nF9bPH/a+0X98es1Yof6N/9Prrs1NeKOZULD32v/TU/jUJtjmGezLvmupMLV61+xjTa01u",
  )
  joined.write_string(
    "54sr5Xyu81//Hv+HCTV2ojfM5HUG8jyBWBQWO7mpKZmJ+pm5iemphnoFeemveT4UP3866VFSQsKD",
  )
  joined.write_string(
    "r18KOJku+SicYVT6HzczlGcJi02sjLPWM5X/FvUPGA4HsouxtZafqZ9uo8Gomfah5Gtx5PMpF1gY",
  )
  joined.write_string(
    "ArwZmUSYcReBMNDAyIC9QEQ3AL1kQBgAEkEqJ9A1ouc8hEZmJvz5EN0k9JSNMOktE5Z0jq4dPegR",
  )
  joined.write_string("2rtZcEREgDcrG0gJKxC6AW1mZAXxAHTtOZ5dBgAA")
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX image source rectangles are cropped" {
  let result = convert(docx_crop_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut cropped = false
  for command in commands {
    match command {
      @render.ImageSub(_, sx, _, sw, _, _, _, _, _) =>
        if sx == 1.0 && sw == 1.0 {
          cropped = true
        }
      _ => ()
    }
  }
  assert_true(cropped, msg="DOCX image crop")
}

///|
fn docx_image_transform_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GDI9kyMXfQ98cdPIO8BIwODMJCOds7PK0nNK4kPqSxILY7Vq8jN",
  )
  joined.write_string(
    "qZ3o68dsyNP6fY7SKbGzKQmNAq98xP/oNLpaNkytSFuk5jdlydK9tn7csSG6p3/sPX++T/z03PKk",
  )
  joined.write_string(
    "bs3bDnv3ZFtrTigxmLYsrm7tvVnumkWMRg+YEvW/z3hatCNyzTfBzQkzivSfBz2aHBR5/oXidkWl",
  )
  joined.write_string(
    "jUZtTxZ+MPbVaoo73PJq32u5KXwhE7yCs/gtdeIKWnq1H5Uef/pYgTN22qOfGWsi97ZIzL0aEBEe",
  )
  joined.write_string(
    "bZSueTbf6fSTg5PTpT/rSi/ZNSNg6mvG6zs9Lkum195dc23mjwf7fa4t+NEScu/g5nX7nI1Osez9",
  )
  joined.write_string(
    "eGbLf/b4Gzo9i69WPMrePqPp2JyfHve2qh9tXrq/9+pDh8P8ASghtbPRpXADkKcFDCluIB1flJpT",
  )
  joined.write_string(
    "rK8HInvPW/MdMuBhezA32OVeZhRbS8BkPY6V2lrsHULmvRlyXocWb1dnZlZgc7u93/507vcNxjsT",
  )
  joined.write_string(
    "fY5Zs/mGMjuq7zXyM7bgP/6Vz+PUIU3D6nYeMZ8LH0OrD0U+2TRZTVhIs8ObZ9mcw/MuqahvUQq1",
  )
  joined.write_string(
    "W6A9+aK7dpHm4mWOJ7oveJiX7l368S7Dv8RJcYYde7MaeLwP1OfY97k9Onh6tev0+jk/vEQiXXpn",
  )
  joined.write_string(
    "Hrzr7np1dayomEb+y+PdfzhRPbY6IyYY5DEFoMdkgHR5flGKPsR3KfnJpbnA1ABKBlCfbuRiMgT6",
  )
  joined.write_string(
    "9O5yjZt75zUpFdmKC8a4yits2Rn3cda0bV379rKKs7IfV/lz33/X3cP+j/w0dx/gEvPlbopgf3xD",
  )
  joined.write_string(
    "a8cc/s+8HTETeP0aPQ9ONnrzK7J8Eaf32ScXj+poHYo8GOF1x2vmVw+5YmGlwr08ipU6pT5hblfC",
  )
  joined.write_string(
    "t6hMz9097eXlhn+nRdwXK8ie5TryU/KlvDVP8+Ut/L+edZ7u53pZ83adgpq3a6P64w97Y0wm6p7Y",
  )
  joined.write_string(
    "Nzm+/6s+qk/95J/3TgX6cgEzA4MgzKfIfpwb7Jt/24Bn7/twiV3rS5pSXvTc2MtytEwiIOE2f0DK",
  )
  joined.write_string(
    "LbEF+gGv5ry53r/p8bG7CzWqFnpOrHo/cQo/f3p2l71HYHV499lYTa6SU9tvfd364+/rj5/3aiRN",
  )
  joined.write_string(
    "Wjf1mPWao6yLKzLsZI+t+vrq5iJvVuUdEb1bJYK4RB1CmKMk39c4HN95bvLUTudXiV+usH3iSk5h",
  )
  joined.write_string(
    "yk6InhZ/wOvtESbhe82XJ8mEM6xP7C8ucpwizxCjzRVVy9CYvzT9EGvLPeaHu/20beKeWz0WkJpZ",
  )
  joined.write_string(
    "YV54QbGr7Xndp7eq9c5mU85OnXU3IDN9y+GTR4tPvQ58HlVz902Z6vqw2LiaDL5NrzzbHFdPrZ7i",
  )
  joined.write_string(
    "acYeNv/3vLmTLz4MlJ68elN8QOu3llzdF9W7zzt82KXjbmgTuK/g3QmxJ8G6385EpQnKitc93q5W",
  )
  joined.write_string(
    "NK9aL0JBPn7T3JCNH8xDDvNUpc6tfOBq8Oc655pZLVdrEkzNZjzjuD7RLeRl5qzsF/X/dI/92WR+",
  )
  joined.write_string(
    "+21fa8/VA//+1ZlznmS1V/mY+elP1uYDMU675C/p2vycsmfvUbbdqtzCLw+xn856+C3f9D8DahwG",
  )
  joined.write_string(
    "8t9icgDyXIFYFBaHuakpmYn6mbmJ6amGegV56a95PhQ/fzrpUVJCwoOvXwo4mS71KJw5yKKiPoX9",
  )
  joined.write_string(
    "PnOQzTy9PkXR4kn1c+wPHDhw5sSJgk/3l3x3KGTzD7efXurH6Qu0kpFJhBl3KQkDDYwM2MtMdAPQ",
  )
  joined.write_string(
    "Cw+EASARpKIEXSN65kRoZGbCn1XRTUJP/AiT3jJhyQro2tHDHaF9IwuOWAjwZmUDKWEFQjegzSqs",
  )
  joined.write_string("IB4AadrWLoAGAAA=")
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX images are rotated and flipped" {
  let result = convert(docx_image_transform_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut transform = false
  let mut flipped = false
  let mut image = false
  for command in commands {
    match command {
      @render.Transform(_, _, _, _, _, _) => transform = true
      @render.Scale(x, y) => if x == -1.0 && y == 1.0 { flipped = true }
      @render.Image(_, _, _, _, _) => image = true
      _ => ()
    }
  }
  assert_true(transform, msg="DOCX image rotation")
  assert_true(flipped, msg="DOCX image flip")
  assert_true(image, msg="DOCX image")
}

///|
fn docx_table_shade_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GDo9UyMPekvteE1kLeOkYFBGEhHO+fnlaTmlcSHVBakFsfqVeTm",
  )
  joined.write_string(
    "1Abs9TtsIHCvkuu0dpeshICTp9UHYybnyobJtZ46bzY/Lfb+/c0i92UD1+O731evj37bJB595o3S",
  )
  joined.write_string(
    "109uW4MUZmbI+u79E7Hf5HtQAeOmB8qJ+t9PFJnGlL6udRIL9blzeueULwtMZ0syb+jiXKmUfIbR",
  )
  joined.write_string(
    "y/bzEuEZ/jMC7m97O9dsIldQ5qlHiu3vON1v/FCaV/61VmfSxc0i/e6PJl319jhpzbz0UZX3t3Cv",
  )
  joined.write_string(
    "Yq+A0MoHH94IxYc3XREXFnvyvmHyu7V6k+e6fuTbucdphc5f0c1XzWb5rvD6uv9s67xCmbkHN9cV",
  )
  joined.write_string(
    "eltKpaybzL7+nAeDu/3fr4nvHkoHoITNzkaXwg1AnhYwbLiBdHxRak6xvh6I7D1vzXfIgIftwdxg",
  )
  joined.write_string(
    "l3uZUWwtAZP1OFZqa7F3CJn3Zsh5HVq8XZ2ZWYHN7fZ++9O53zcY70z0OWbN5hvK7Ki+18jP2IL/",
  )
  joined.write_string(
    "+Fc+j1OHNA2r23nEfC58DK0+FPlk02Q1YSHNDm+eZXMOz7ukor5FKdRugfbki+7aRZqLlzme6L7g",
  )
  joined.write_string(
    "YV66d+nHuwz/EifFGXbszWrg8T5Qn2Pf5/bo4OnVrtPr5/zwEol06Z158K6769XVsaJiGvkvj3f/",
  )
  joined.write_string(
    "4UT1mOiX4yuFgZ7iZ2JgEASKlucXpein5CeX5gJjHhzlgb7+RxQE9v7Wlnqnlxt89lbO7sDJX1OS",
  )
  joined.write_string(
    "Fv1j4JoyicGZYe3r9dOnXXvlaHnmenV+W+Phj86r38y11j9osuLGU43HbUyT3UxefH1astN9Jv8R",
  )
  joined.write_string(
    "g0UHPrDN3el+/Nsjg2s8L2Y/U0vZ2Pzx640FiizRyW9eHjD9aL3hjssa9uWeHSuFK1iOr2E+tbef",
  )
  joined.write_string(
    "ecuh1Hnxyb5LHHNzbjJa+9uVZBXy+23SFLl4v/nUscxzvoGhlX0f7Bn+LeXL22Zyc7nlZ+buRXFa",
  )
  joined.write_string(
    "VxcE28zOU7xxUiWx2prZ+E1atvira9/V/77Lt/LbfvC+d5XfYaMAm/pltl2b1jxy7/kq8Hh17dY3",
  )
  joined.write_string(
    "WUeVCzdKHThWNVXDr0sxJ5NdseFe0dHfor6v137+8OtOxe9T37gDvBmZRJhxZxwYaGBkwJ6N0A1A",
  )
  joined.write_string(
    "T10IA2QYUdIaukb02ENo/MqIJS4DvFnZQNLMQLgTSJszg3gAKMyxjgYEAAA=",
  )
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX table cell shading is drawn" {
  let result = convert(docx_table_shade_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut yellow = false
  let mut fill = false
  let mut text = false
  for command in commands {
    match command {
      @render.FillColor(0xffff00ff) => yellow = true
      @render.FillRect(_, _, _, _) => fill = true
      @render.FillText("A", _, _, _) => text = true
      _ => ()
    }
  }
  assert_true(yellow, msg="DOCX table shade colour")
  assert_true(fill, msg="DOCX table shade")
  assert_true(text, msg="DOCX table text")
}

///|
fn docx_table_border_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GBQ8EqMPekvteE1kLeOkYFBGEhHO+fnlaTmlcSHVBakFsfqVeTm",
  )
  joined.write_string(
    "1Abs9TtsIHCvkuu0dpeshICTp9UHYybnyobJtZ46bzY/Lfb+/c0i92UD1+O731evj37bJB595o3S",
  )
  joined.write_string(
    "109uW4MUZmbI+u79E7Hf5HtQAeOmB8qJ+t9PFJnGlL6udRIL9blzeueULwtMZ0syb+jiXKmUfIbR",
  )
  joined.write_string(
    "y/bzEuEZ/jMC7m97O9dsIldQ5qlHiu3vON1v/FCaV/61VmfSxc0i/e6PJl319jhpzbz0UZX3t3Cv",
  )
  joined.write_string(
    "Yq+A0MoHH94IxYc3XREXFnvyvmHyu7V6k+e6fuTbucdphc5f0c1XzWb5rvD6uv9s67xCmbkHN9cV",
  )
  joined.write_string(
    "eltKpaybzL7+nAeDu/3fr4nvHkoHoITNzkaXwg1AnhYwbLiBdHxRak6xvh6I7D1vzXfIgIftwdxg",
  )
  joined.write_string(
    "l3uZUWwtAZP1OFZqa7F3CJn3Zsh5HVq8XZ2ZWYHN7fZ++9O53zcY70z0OWbN5hvK7Ki+18jP2IL/",
  )
  joined.write_string(
    "+Fc+j1OHNA2r23nEfC58DK0+FPlk02Q1YSHNDm+eZXMOz7ukor5FKdRugfbki+7aRZqLlzme6L7g",
  )
  joined.write_string(
    "YV66d+nHuwz/EifFGXbszWrg8T5Qn2Pf5/bo4OnVrtPr5/zwEol06Z158K6769XVsaJiGvkvj3f/",
  )
  joined.write_string(
    "4UT1GOemhyclgZ56D8SCQNHy/KIU/ZT85NJcYMyDojw0MNb/sIJI7fdwkz35F5bNujlFL8tovo/P",
  )
  joined.write_string(
    "FfkDGtmzGbYzbsnbf8878/KJw38fyJ176FD7x9Tqd+A5/gTLk997Uk55ZbDfLvz0tfKWrMez5g1r",
  )
  joined.write_string(
    "LySIqoc/Pblx5+rlq1h/5k7hlTSKiPed80WxR3Rp3LdTHPvbAyPnxB6QFNxQKjv3wNbFzCv3uDMu",
  )
  joined.write_string(
    "zjx4g9k0acMSx1PGW67POByp//Iqb66O9Rn9BZs1X9k8Sz0psdDX939j0+zFPh9rX84LFP6r+k/g",
  )
  joined.write_string(
    "gELn/sKmY8u8mtiOcx4utVrbc1twl2CvocqpZ5lyZ5LNjxc2Lntyrdt1S7iRDs/d47qSJ7oXpQTu",
  )
  joined.write_string(
    "O/7rX8C5OKUHvhZ3eA0e1c1UyHvxa8PWk4euZZdGLn/5bbVc7PzJefFX/zAGeDMyiTDjzj4w0MDI",
  )
  joined.write_string(
    "gD0zoRuAnsYQBsgwoqQ4dI3ocYjQ+JURS4wGeLOygaSZgXAnkLZlBvEAOL13gQwEAAA=",
  )
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX table cell borders are stroked" {
  let result = convert(docx_table_border_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut blue = false
  let mut stroke = false
  for command in commands {
    match command {
      @render.StrokeColor(0x0000ffff) => blue = true
      @render.StrokeRect(_, _, _, _) => stroke = true
      _ => ()
    }
  }
  assert_true(blue, msg="DOCX table border colour")
  assert_true(stroke, msg="DOCX table border")
}

///|
fn docx_text_box_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GD46ZUYe9JfasNrIG8dIwODMJCOds7PK0nNK4kPqSxILY7Vq8jN",
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
    "w4nqsYNTNmcZAj2VyMTAIAgULc8vStFPyU8uzQXGPCjKeycd9DuiIND23s718N2luWGbM7fddek1",
  )
  joined.write_string(
    "F558lT2hcZtKq6KB1/Xl4rvM3r46evqDf/vPf0Yb7HuqTtgt/czl49vl62eUacGRumvWnv229995",
  )
  joined.write_string(
    "PJsoeZDNYJNa+suTC3febPdi+H/hUoIY57HwhWq2i9ZqfN0zfdZP3ojMpLWsyyWPXSk1aRC+xjj9",
  )
  joined.write_string(
    "njuz7QWj8+9Xpp2aIJn8/7BgX6voA6nfJZp6Lv/ZV4qWP1h4lJfdd2Gu6HRh1U9df8Tf3zDW9hTu",
  )
  joined.write_string(
    "r2Eq9Fvte3Dph8/Kgbe8ZjpKzlyyvsCmd+W8a+4GEs9L7nacZe4JepM5SXOX5i3NuNKLre7heiWp",
  )
  joined.write_string(
    "+/L4p06XiVcXvi27f9OEdcs0TufuuRXwNfD+20XLpvPqnzm6nqPwzdFvm46uXHdc1ZZR6YWqfIp1",
  )
  joined.write_string(
    "+MsUq98XKx1KKmXOmgd4MzKJMOPOVjDQwMiAPZOhG4Ce9hAGyDCipER0jehxi9D4lRFLTAd4s7KB",
  )
  joined.write_string("pJmBcCeQDmUG8QBN72nxJAQAAA==")
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX text boxes are flattened into text" {
  let result = convert(docx_text_box_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut found = false
  for command in commands {
    match command {
      @render.FillText(value, _, _, _) =>
        if value.contains("Boxed") {
          found = true
        }
      _ => ()
    }
  }
  assert_true(found, msg="DOCX text box")
}

///|
fn docx_paragraph_shade_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GAI8E6MPekvteE1kLeOkYFBGEhHO+fnlaTmlcSHVBakFsfqVeTm",
  )
  joined.write_string(
    "1Abs9TtsIHCvkuu0dpeshICTp9UHYybnyobJtZ46bzY/Lfb+/c0i92UD1+O731evj37bJB595o3S",
  )
  joined.write_string(
    "109uW4MUZmbI+u79E7Hf5HtQAeOmB8qJ+t9PFJnGlL6udRIL9blzeueULwtMZ0syb+jiXKmUfIbR",
  )
  joined.write_string(
    "y/bzEuEZ/jMC7m97O9dsIldQ5qlHiu3vON1v/FCaV/61VmfSxc0i/e6PJl319jhpzbz0UZX3t3Cv",
  )
  joined.write_string(
    "Yq+A0MoHH94IxYc3XREXFnvyvmHyu7V6k+e6fuTbucdphc5f0c1XzWb5rvD6uv9s67xCmbkHN9cV",
  )
  joined.write_string(
    "eltKpaybzL7+nAeDu/3fr4nvHkoHoITNzkaXwg1AnhYwbLiBdHxRak6xvh6I7D1vzXfIgIftwdxg",
  )
  joined.write_string(
    "l3uZUWwtAZP1OFZqa7F3CJn3Zsh5HVq8XZ2ZWYHN7fZ++9O53zcY70z0OWbN5hvK7Ki+18jP2IL/",
  )
  joined.write_string(
    "+Fc+j1OHNA2r23nEfC58DK0+FPlk02Q1YSHNDm+eZXMOz7ukor5FKdRugfbki+7aRZqLlzme6L7g",
  )
  joined.write_string(
    "YV66d+nHuwz/EifFGXbszWrg8T5Qn2Pf5/bo4OnVrtPr5/zwEol06Z158K6769XVsaJiGvkvj3f/",
  )
  joined.write_string(
    "4UT1mMO6OK1XQF4O0GOCQLo8vyhFPyU/uTQXGPOgKHcNOJh3WIFn73ttge9TTU4t0/IKenspeqnn",
  )
  joined.write_string(
    "bbsGNiElRrcHeq/31fEFivGZnX//MefynPo5qfetlnHWnO5vbzJ+Wx0wWT7639fKSrvCaQFVqroV",
  )
  joined.write_string(
    "dz+1+/25Y2tavHbBfuu3Eyc2+3+9U9QskaUYlL9l8ksGx+pHbB1+SgctuiQXcQlWzRUyLQib4vpR",
  )
  joined.write_string(
    "a84cm/cnPrG92vhkwuHqmCCjrrNfDSJvf+Keu+jBouwj9vOZy/K9OY0Fw63sr9mu22RQ92cSv2+l",
  )
  joined.write_string(
    "zumubXOynb9PD576V+xgqNsqJZZV4atV/BYflL3HIHinb62cWdnczNfq22KP/PO/Kx/gzcgkwow7",
  )
  joined.write_string(
    "P8BAAyMD9tyBbgB6okEYIMOIkoTQNaJHCkLjV0YsURTgzcoGkmYGwp1Amo8ZxAMAbkfnmt0DAAA=",
  )
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX paragraph shading is drawn" {
  let result = convert(docx_paragraph_shade_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut yellow = false
  let mut fill = false
  let mut text = false
  for command in commands {
    match command {
      @render.FillColor(0xffff00ff) => yellow = true
      @render.FillRect(_, _, _, _) => fill = true
      @render.FillText("A", _, _, _) => text = true
      _ => ()
    }
  }
  assert_true(yellow, msg="DOCX paragraph shade colour")
  assert_true(fill, msg="DOCX paragraph shade")
  assert_true(text, msg="DOCX paragraph text")
}

///|
fn docx_paragraph_border_fixture() -> Bytes raise {
  let joined = StringBuilder()
  joined.write_string(
    "H4sIAAAAAAAA/wvwZmYRYWBg4GA46JMYe9JfasNrIG8dIwODMJCOds7PK0nNK4kPqSxILY7Vq8jN",
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
    "w4nqMYO45g9fgbwuoMcEgXR5flGKfkp+cmkuMOZBUe4acDCv2YBn73vtCe+zNZKCWzlCyx+YZV7a",
  )
  joined.write_string(
    "xn9iksgEjx6h7Wv+/pLUUGa3rnv/9KZf5Z/S2qKtimUvVN+Ua6pcyzaZm69SU3/1PLuHkmZ+SP89",
  )
  joined.write_string(
    "rx03OY6/WinD3fzr0ZrlLbI1Om6cuhcDOARLs+d2WcusSX/Xc1DzkZFJ0pGEtoZbx07wxuhvMqkV",
  )
  joined.write_string(
    "9SuV09r2x7F49ieD9n6D5ebCYn0csUZiH/Ua26W4e23ZOEvnfmIMnJoU2v3/evGCVyaOJsL8VYcW",
  )
  joined.write_string(
    "X/2Scanm3s2J5TfSI+f5vdO9H8/3M8eG815owpSCBJt4lYXZUbdOpR5a++5tZer0h9fqku6G5OyP",
  )
  joined.write_string(
    "+MsY4M3IJMKMO2vAQAMjA/aMgm4AevpBGCDDiJKa0DWixw9C41dGLLEV4M3KBpJmBsKdQFqSGcQD",
  )
  joined.write_string("APKNC5roAwAA")
  @gzip.decompress(@base64.decode(joined.to_string()[:])[:])
}

///|
test "DOCX paragraph borders are stroked" {
  let result = convert(docx_paragraph_border_fixture())
  let split = @core.single_to_split(result.bdf)
  let manifest = @core.parse_manifest(@utf8.decode(split.manifest))
  let body_hash = manifest.views[0].pages[0].layers[0].object
  let resources = @core.decode_object_resources(
    @core.open_single(result.bdf).part(body_hash),
  )
  let commands = @render.compile_object(resources.object)
  let mut red = false
  let mut stroke = false
  for command in commands {
    match command {
      @render.StrokeColor(0xff0000ff) => red = true
      @render.StrokeRect(_, _, _, _) => stroke = true
      _ => ()
    }
  }
  assert_true(red, msg="DOCX paragraph border colour")
  assert_true(stroke, msg="DOCX paragraph border")
}
