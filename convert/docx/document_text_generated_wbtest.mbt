///|
test "DOCX document text matches upstream Go 0" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRb0gTYRwH8N/NPXZwuVvdFYiKWe6FWHr2IoJaZe1NDfII7GYgEZtRa6etnWCLsEKJhv0bUU3SJCgKLUoj8Wy1TqIySRaLbbVivdibojba2kbrIHYQrVEPD8+b5/f7wuf3Y40lahpwwKH4EACw+1CHzdHYkH8HXuk1ErMQRUcNGza1NzEjDyii/hO6FpAX2Suf3qE75yVWW5I88uPD56+0l3cL78fF2ab95Gjbo2VW0ynvGndd65kJOn3j9AU0QZKPtcNv0wOxfb7EHvFdYKYWi2TnUuSq5EMkbgt53LIpaz1WcbTtuROfHmS2x0duVWInNWd7hZ4yYI0L8Neu+l0uAEgCwP8JFACYux1CF99o6TJ38x2dQkMPb6uduzcrMTSKcnVDvc6XG9f2DYb93M2tNmJqqiZzMfAm3PrkRTBxXM1VN++4FPd9PCiOrfSUt5+zNlebYrzeZUC+vULIscXfj+Tzi9NS2XVsta6CKn+2vh/T/5z8Unr36ubb02MaS4vOXLPEEL+SSXHe4cnM92+HI/NVFp14eWfQ3rd83Yqc+oCcO6GEa+UqRTa+tMXuAYD7igxT0fDHVqgmiqx/Lau4sTCU+l2v3Jl/j4g1otL8twpU4ASAIQwA4NcAR+FWbi0CAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "H", false),
          ("char", "e", false),
          ("char", "l", false),
          ("char", "l", false),
          ("char", "o", false),
          ("char", ",", false),
          ("char", " ", false),
          ("char", "世", false),
          ("char", "界", false),
          ("char", "🙂", false),
        ],
      ),
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 1" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRb0gTARTA383OHW3nWbsPSooOEkxzm30I+icSEdQNuS+xLciKU5rDc2w7S5ZWUFHq1Bz1YQ2XBAkiDVQquFJr68+hY4kKWaZYIIWCcy6PdU0Lg8hGPh7vy/sDv9+jqZQtJGCAQXIoAOC0vbLaodWsV1f4UFpAp0Rne46UlJ4q1nU+VikK59H7E6vbbFmv/GTN2wCdnhK7KM0sLJIDrJub7uOHi6uIHtNgrsXYOLDXvetEaz8pdrXcRvsJYijd90F0zZmfL53lpyaCO5GP8dA3oij2DOWPT3rcq8a45cqOBpPgxJ7e1ZVFOruzkBtpbZe5OhxoSo6NNRWebAKAGABsjqACAKbWwVlZbYWVqWUrazhNHVutD7+wBHXK1FlDdLvQO3w+P2TD3wd8Z56MXf1iZtV9LXPhxSnCizu/c/H2S927DVbrNU3jYS/jIabzHuQik+W3lJH6UoP5h9iu/9zRdk4o8audzSHDhS68/LWNqPD7xwtGtEMzC8o7xqp3eXImOnr9pisqP1D08mDG1nFvhrSc6M15cyxf2PMo+6GvNTKS2JfTzN8rk9SZ0vJ+vMFU4GA8a3Zzx+j8p5+Zgn1FPPrVvZYNNCXH6hNLeh4AVgCAphAZCX/hN2pRJMn455vJixuPqv7M/87g/x3SFJq63paBDJwAMIgAAPwaANMC1ONOAgAA",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", " ", false),
          ("char", " ", false),
          ("char", "A", false),
          ("char", "&", false),
          ("char", "B", false),
          ("char", " ", false),
          ("char", "😀", false),
          ("char", " ", false),
          ("char", "x", false),
          ("char", "<", false),
          ("char", "y", false),
          ("tab", "\t", false),
          ("break", "\n", false),
          ("break", "\n", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 2" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRa0hTcRQA8HNntwZ3btPdT6U5sQexnFMsehkSQeBYjHQxaxHh1tbYg9oWUxtJiNKYDdbAHBjrgVBWpqON5uZNxyjyljgswpZIUtjNVLrjMoJFTIjWqD9/zpfzgPM7cmnBOhzYwIb8hwHA6Qsag6VKnI2u13XcCQkHnR88fLD+VLXEHxRgIgq9PZMpOl8Sf4Sbpibk/AK6/cfc12U8avRYP4yEX1af4w02jwn1yqvR3Z4dimsBnBno8aIBHo/g35xlXJ90z1bPhN/PxLYgyTSZ4lXSETTc8K7Pk1Gm9R2bHM0v2tijPsnRFf+9EqSb675stReCXLqBnXCKTjgBgAaA/68gAIAWm8VqNlapzS02o8ZkFduNBpVbZkoJOV1DNR8htnjyEuZVTyt6Feb5DvrOlR5XxbbQkPBhLfW5tbWsfHLzfWzJ3Xk3pHU2qUpfDfj6n8TNN/zJvRV1jSplse5p4EFwpHPn0rC3/y3+jXi+QMgeX+/ros5ytZNJYeG+ylG81GCb3U8GNT8d5HdBiEqRe3wckY9IWA4UR3VlRepa/sLWzK7utIw/NjcVKbc12qd7N95a3H6sfnwVETErF/VYg3Y5Ih5+gzJHDiW+tK8JNB2XOsYBoAbJCiAsHP4Y5OpgeSZ/HTW/MXeo4Hf92o/9m1IuRddn0yxgQRsAxBEAgF8DAOW28OVVAgAA",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "f", false),
          ("char", "i", false),
          ("char", "r", false),
          ("char", "s", false),
          ("char", "t", false),
          ("tab", "\t", false),
          ("tab", "\t", false),
          ("break", "\n", false),
          ("page", "", false),
          ("column", "", false),
          ("break", "\n", true),
          ("break", "\n", false),
          ("char", "‑", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 3" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRe0gTARjAv9s8u1p6izuwOKHNggrROyPXix5/REGX7v6w2EwTcdIaO6/0VqbEJajh2lwMDZWQJWipodTAajmrWSDmeo4e66H9keB6t5JVCrEiWqM+Pr5/vgf8fh/HyhNIwACD+FAAQFF5qbmCzoxW2+0NyT5mPjrRu2Xj5sIsxjVAKNJDaEdgdsGB1Jt9ZNkdH6eUh6u/vXj9jvTyTvH5Bc9o1j68Vz+kMukavBrnip2NbnK6y96EunH8qrI9OG17Zbz2odjzNDC8FHkWGfuMZ4QHUc/2x63OWV3EdJQ6oh+pwq60MbnvXd2pyLFkhyRWJgHHzsHuW9PzrQAQBoD/IxAAUGKpEAWeNgglFr60TMys5M2iIyc3Qa2s61/ZKt+RU3BJlUHRLwfqyutre9LyLEZBUBnXhcxDKb7vNZ2XlxcvMax/26QvrF477rfK7+7flv8lDT18ZkbdvOvB8QC1qvt83tyzbZGti9r7Hu11ZX98Qvu97Mybnntdg/OoT2uaG28EOw+2aM/p+JrJsUMPr099vWhI1NpMC6Vljj0tSczJxQWaFE326dWjm7SniBEpdGtCjYwX1U921NpP+KVfvA324FQ/AOxGoryIjIQ/xLEuFHEG/nph/GLsUeL3/M8c/rc4jkUTo20ZyKAKANwIAMCPAQALhOX0QwIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "i", false),
          ("char", "n", false),
          ("char", "s", false),
          ("char", "e", false),
          ("char", "r", false),
          ("char", "t", false),
          ("char", " ", false),
          ("char", "n", false),
          ("char", "e", false),
          ("char", "s", false),
          ("char", "t", false),
          ("char", "e", false),
          ("char", "d", false),
        ],
      ),
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "e", false), ("char", "n", false), ("char", "d", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 4" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRa0iTfRQA8DPddLj39VE2EHHaYlnLoW5GsRJrUIzYWA1EcsIKXSM3tqm7hLi8EEW2nNmarRu2+uCKVVsNBGeb4TBFlgO3aGQrjRloZuHsaUxGMSGyUX/+nC/nAud3BLx0LAnwgIfURwCAEyqJXF1elow901XZY4z/cHO2Q/vZIibDMkQk0Jdw94KJ3Bby+GOS0j8myEmP6uLvPq2Q3AqjJvzUNcWUIjahhyKrvejeY9xZ0+skoYMGE86JIKM5A2/QnoXG51/rXbNB7zbM25hvDSmNPsO5uKEbxkRtTNZV0C6cbMOP3GQc+WJ5QMZcyL7cqWn9HwS8TPyMnl6nB4AoAPx7BSIAiLVqTZOi/GSTWKuQKDVlrQq5vE+k9FJyztnPstjND+8foMUy+ku+YbF2RYnTIgnwdfEsK3+9z5wvXbtbj9JO++Zvg1A0o3+lDxDUT14EHexVrZkwV/yoejAyvFLxklNhOK/qqqNOS3e3v666HqEuzdNQ04T/o+TqMRlaZAoho/sKIf/wrWsccn9oaiC0OOEJcJc/tPSyKsNbXPSaS0juqWIUW729Oe640tFAsd7pYOLPlNKjs2bj0MLeBmqe9ft6t2FXp2U4odSNH+Q0bkX40oCqYNXriIz4fqB5R7nLWcTK8Hub+/hkd6GatYNd5MnckPLbOeJFANBjklKYNBL8ttqsSEix++P4qY2bhxJ/1W9879/JBTxcRjKdBmnQBgCfMQAAPwcAL75lcH0CAAA=",
    ],
    [
      (
        0,
        "center",
        36.000000000000000,
        -12.000000000000000,
        2.0000000000000000,
        4.0000000000000000,
        false,
        true,
        [("char", "o", false), ("char", "n", false), ("char", "e", false)],
      ),
      (
        1,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "t", false), ("char", "w", false), ("char", "o", false)],
      ),
    ],
    [
      (648.00000000000000, 792.00000000000000, 72.000000000000000),
      (648.00000000000000, 792.00000000000000, 144.00000000000000),
    ],
  )
}

///|
test "DOCX document text matches upstream Go 5" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRbUgTcRjAn9u8djDzFrsySihr9ILsrQ8jjOwF/VBH8e9DppWsMqGN3UZ5kkychrXY3Fa7DJZQrT4YIZzgSOJSK9dIzBpNEXMlQUbicEqLtSwtDKI18uHh+fK8wO/3IFqcRQEBBGSGFAD056pM1WrVYnW92pnTp8nG37cXF+2u0Gr8XXJpwRR+d3h+xdm8EE+Zw31IJk7UzY3H4lQPw7HvOoUBrYFsL+9dbyxz9Oi4rYc9ASrZ5m7BAyT5WHZrLOn6eObJ7EkhOhxUYG9Tg19IZaIbF/aP3uDmy1LGxrX15f1W4lGr5uCM/34edjnnSgNbuxwQLSEizoKjTgBIAMDSCHIAqKypZi2M+rSlsoapMrOqWsZ03KM1BzXZJR2nJsHrzW+S1U2XspM41fzA7dywZ9v16FCuV57V//mn/174PJ//mi3ZMsL4mu2FD0Oupq+FysZD5DOkG9QrVh8gFYEOhePSJlTxwvVm3feFCS0fcn9ao2qxWV4qiyZKV6mtM7z9tk+yOdbtixlPRJ7enBv/lrtXOXBte/xig6dePLvDNLJgcPzYZ+lse35BYjty1T6t+6CPGsIR7lh8qtdePLTyzmhqFyBaQiRtrWNdALARA0A0JqLgL3i6EmmGiH8+mbmYflT+Z/53Bv/vD9H4ssW2CERgBQABAwD4NQDRUT0DSgIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        true,
        false,
        [("char", "z", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 6" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRbUgTcRgA8Od2XV5Nvcu7D4GWK4yQ6/SuqL5UGgx6WcRBFC6MELUX9U4uzxSrVRRJspSWRPUhRklRgwiFg25Zx+zKwpLGgrCMMerLFRXcuK1gFRtEa9SfP8+X5wV+zyN40Dk04IBD4XMCwN5DrR1dtTXZ6H+xvjTCFWPxkHtD/R6eC6qUkzGxa7HMArnCuENL0xGBRK0j3999/EyPiwFldlR7xh8kQt4HrraGs+NrAtU7B8do+8a5YWyMIB6SV2ds/4cD+tcm7U1sogp5m55KEqx1H9O2vr4cyDSk206UH/NO9uHhK9z2L8FbFUh/6dBxpbcEBE8RHh1gdg8AgAUA/ydQANDc3aV0irUtnc3dYquk1PSKHVVT/OApjqx/GXJVwnVWvasb0jAzcvjTPBe/uH2f/t4+v8XypZ6YZcaiJe09iYvGq6crbhteRkaKoztOHk3YSx8Ho9S0WnYzQm9seb5Ksvcv9LFnVpfX7UqNJCW2RGrsWb7MfWlbExlH/T/Ds+Ei2fxRXanPXzdjxtZ+G2309auaW940adahOc+jlZtPDwHAvZwHcdDwR5RvdRYI/zpRYWP+UOp3fe5P/Hsxggebm007wAF9AHABAQD4NQBBoZdBIwIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "B", false),
          ("char", "D", false),
          ("char", "F", false),
          ("char", " ", false),
          ("char", "W", false),
          ("char", "o", false),
          ("char", "r", false),
          ("char", "d", false),
          ("char", " ", false),
          ("char", "C", false),
          ("char", "o", false),
          ("char", "n", false),
          ("char", "v", false),
          ("char", "e", false),
          ("char", "r", false),
          ("char", "t", false),
          ("char", "e", false),
          ("char", "r", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 7" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRb0gTARjGn5tensx51g760BVH+UUsPTEkAsuwIXQtj6C6ZRJhg7KdK70DOx1qYZGZF5df2ocYRUVtRCT5YTmLif0RtT/ch/5NKonCIIMrs8AVBtEa9fLyfnnf94Hf84hCRiYDChTSyw5gd6PX11RcND+7x8tz43wO+Sq8cV1FbQkf6nfaC6fI8+bcwkPs8DWm4WFczMuwWr5PfPjIxGRDSdyIjpTsp8OeQa5eOhErMwq29fQxM5dO9ZJ9NH0779zzme63++582hN9YQ7lEy9nRz/Tq6wBMrrp6VljTpqtb18S8NzXqFtBfst06ApLHM/V25RmB0Qhi3rSVbizC4AF4P8ITgB1apPil4v3+utU2dugFDXLvvzRDY2dXE776zDPVvgW1/IjBVoHs1W9e3rzkeGJpGNw7Ot08uK9+LflkbGEsv1k4EvLgUWV1wdWdLhXSv61bZ7soDtS8z7i6i0NLlUvlLaOWzu4NVerBX39rmSVN3T03TI3Nznleiz+eHRZfxCYTLDmm0ymjHwmZ5f3rzarDrdWV+qdlkuq0RwQhSzqzMGbx3oAxACIAmFj8AcoFdWeBvhXQumPqaLO3/e/eujfvogCuWB+bYMNGgCDAICfAwCPUJzDIgIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "1", false),
          ("char", ".", false),
          ("char", " ", false),
          ("char", "T", false),
          ("char", "e", false),
          ("char", "x", false),
          ("char", "t", false),
          ("char", " ", false),
          ("char", "a", false),
          ("char", "n", false),
          ("char", "d", false),
          ("char", " ", false),
          ("char", "p", false),
          ("char", "a", false),
          ("char", "r", false),
          ("char", "a", false),
          ("char", "g", false),
          ("char", "r", false),
          ("char", "a", false),
          ("char", "p", false),
          ("char", "h", false),
          ("char", "s", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 8" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRTYgSARTH37jNNjCuszEDHfLQYSHC2p09WBFlu30ctoEYFiQ3iKhtoR0cbd1xkV1iE4vI1MISsy9mOoQlemgswrJME6wsoTxUltShS1EWhliDFRqRST0e7/I++P/en2W6FlCAAQadgQPALtuEeXqgv1k9j9dr0rQafR3ZbBjaOUiL10lc9w69WGwsmtJmY5SlkGZ7u6pz38rvP1JJ3i+8upp4MDhJRMZuL+VMR5Or/MuNPpmqXfKeQmWCuNN74UXN83Zf6tPuRKmY6UNe1vNfiJXVW2hi67OQv2GqcweXHBjLzWI3z9DbKuJlLXJEc3xecPQAyyzEnrh1O9wAUAWA/yOQADBunxas/MBe67idn7AI/Q7e3Je/2+Oi1YffGK+oh1giwA3PjJCLT+w3P5ek0nYpWDlf3qDPndOkR63LPmTFR5aoMTXH6EbjTvThiHI2sOea0/7Zqz9m2yhHV8QVZY1hXTZ6g9Y7pr7XAr6Z2NrT9w7J5JZNDREv3F8dliJB29cfSnfo6bCJq//Sb5g8qZ0HgHBLP6Ki4A9BOxveQfSXJZ2L7UfJ3/OtzPz7ESyDdjfbKlDBLAC4EACAnwMAO1fTFhMCAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "9", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 9" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRb0gTYRgA8OdmVwfL3cUd9OH8cIF9iDHvDiEoSBTsQ03igoQZpMRUdHh3mCeYZmbFLLOMIUFBsZKKdhDZqPBqVk4jamwQK6JV2z6MYgdrdbFGNYoNojXy5eX58vyB3/MI9qpVFGCAQeUzA0DHga6+AbauGKfC2yyL3Fo0oTY3NO7jOe9d0mxNo1eihXX9Ncs3KSmyKBBVxsj393qGCoge5d1t7Rnfi6ttC4zLcTKw2bOp9Yyfyl07PYP6cfwhcelNbirV8yi7X4tFg7XI23zoK24zHqDaztfnPQVH3nWEHm17Oozdv8Dt+uS9UYNMWKbHlKFqEOxrsBeT1r2TAGAAwMoEEgCcgwOKLLKdsnNQ7JKUuiGxrzbUJLkZojGpEhbmyfb1zVua2HGulXRvqHfO3ZOz8UPyt1eZ+qv0Zd/BW3s+j/qvu4zwjq3IbEvU2+A4fIL3tSxN6Evz/EZiPj2+bDN+prj2l+47Py5+iffQ2URgpJd/3E0fg19Hq593LrC7+bnu2X6WUfX24NmOmP7hoxaZkY77kmMlyznaZj0FAFrJgpgo+Kspd5ordP+cp7KxfCj5p770g/9fimBHVxfTJjDBMABMIwAAvwcAL/Hj6R8CAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "2", false),
          ("char", ".", false),
          ("char", " ", false),
          ("char", "L", false),
          ("char", "i", false),
          ("char", "s", false),
          ("char", "t", false),
          ("char", "s", false),
          ("char", " ", false),
          ("char", "a", false),
          ("char", "n", false),
          ("char", "d", false),
          ("char", " ", false),
          ("char", "t", false),
          ("char", "a", false),
          ("char", "b", false),
          ("char", "l", false),
          ("char", "e", false),
          ("char", "s", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 10" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRb0gTARjGn9u6PFi5yS4Y5YcKF5fWvH2RQIsK60NHcQSLaYgMFUt2m7kTDq/SJRQOTRiGf9AhfTDMimxgdWnKnChmSiZqLSs/xEHRKlZqwigMIhv18vJ+ed/3gd/z8Jx2Aw0KFBJLB6CwosTpybSszfrJ/ckhdhP5tif3wMECK9vZZ9RlvCevz8RTzqWO3KFdUyHeoI3Jq68/ROkBwS8u3FPGrWf1PXmPt5fZ6way/LttV4P0UldDExnU6wcNgZdL9e/ODH12KJGZ4TTi1crEV/3eWD+pHJtv9cftK2U12y7kjVVRj9rYE586u1OJK8mN1aK0GTyXRE37MvJ9AGIA/o9gBFBU6RHdQmaxu6hSKHGJFklwpk30Hh9hDTWLtkDOkCf3kMPsagnPN4dPTpYuFJTbL22tMzNMC3PL2z53vnq58anZl334WcR7OmVuV/DmqdLb4S3sWEd6k/Z+q6l2vEPqbdhn66J2Ptzz4MUNh9RnqrBedEavTcvuj+Wqkt29I1ScXotB7xdVHX0ztfz9mywTszmqiT4aaV+1FM4+GX2e1cxEqSPxH+C5JOruYv7lNgD9AHiO0ND4A7ceW5cA+1daiY/rRY2/73/18L894jly49paAw2qAAQIAPg5AOck1SMuAgAA",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "明", false),
          ("char", "細", false),
          ("char", "書", false),
          ("char", " ", false),
          ("char", "C", false),
          ("char", "e", false),
          ("char", "r", false),
          ("char", "t", false),
          ("char", "i", false),
          ("char", "f", false),
          ("char", "i", false),
          ("char", "c", false),
          ("char", "a", false),
          ("char", "t", false),
          ("char", "e", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 11" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRW4gSYRQH8DNuszs0o7OLAwvNPiwh2y5bu7NQvW1Il5cdiCHZGBe2CBNq2VkpxxArFBQisQzpJbGQHgITKlK6jLdUgjDpIhbhpYKKyKIiS6QUwoHIpP34+F6+c/7wO4dj+9ZQgAEGvQcHgP1Hjcvm6anO63k0q8owBPo6vHObdnGGCd5S45M19HKxPXRk5P41auVxhhvsqx//+fLjZyoh+MTqTSk3c5gM65OjS/zpxFbfxPzZCNW4cuY8GiHJ1OClUsPz7tC9rwekcjGrQSrN/HdyUz2OSnMvLvjafHPJQZ/UP7BhMT+z+0swNIKcUnntolUJHDuAFdyTC24AqAPA6gQ1ABgsZtEkTB80GSyCcUWcsgrLmnxa6WQI7dP5q4SWI2f5c0PSDv8dh8vwUKWsJtcm4vZfOmf+w+jGH8cK+4jSp+cLaPx2dP0umr8RiKb0E3tpfvgVHxnfsLmc2x5Led9kdRU3rnMOvzddF6PmalozFrg4vq42sGj99pYuPnnG3m2RJ+TELa1+GWAcm9vjAICQDEAUFPwldOPwHtI/O+lt7A5V/6mXb/b/k+BYtL/zrQAF2ADAhQAA/B4AZzdV1hQCAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "N", false), ("char", "o", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 12" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRb0gTARjGn5vednC1W9wRREISfihk7vYhFaIaEUXdlAus3CBKTCjx1PKk5QpXGZmowQj6B3X0QYirhKw+nKkxkXIcFXGK1KzWqg8FrbraRjSIBdEa+fLyfnnf94Hf84hCUTEHChQKiwaw51BTS4erIjf7H6+zR/hF5Gt103rPbjev3GPp8g/kNSO75GDJ1C2u9UlEdBSZwR8vP37ixqSwPH9bi7oPMKpvvLS5/sxYZXj1jsERLjU0cI4cYZgJx5Xnqf53+x98btBeGJNlRCyjf2Oc5n1S2zZ3MZytzzSHlh/zPeqiRi/xtUnleglx2n62Ww4shijYqGd95f4+ACaAhRFYAI2dHXKb5NrX1tgpNbXKFQGppUyvGewpdXjiqrc6dMGnn1h1uEHZXHPjal1878NA2p56HxytuitWr6DqJmpj0xsvz/vV4qRzODRtXaqw6Q07vTPW2amq2ZXRZXqlvz39KpFJuKW3b4yI6/yuYfmOGTu5Ncqv3c4/7W7/ovUmg1+dxtzMliM/vUfpU+Zxz5pxG0TBRn0fEIZ6ANwEIAqEhcNfjHxAugDrn1wKH/NF2T/3v3vy/26IAmnNrS2woAtALwEAvwYA+bYjNBgCAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "{", false),
          ("char", "{", false),
          ("char", "n", false),
          ("char", "o", false),
          ("char", "}", false),
          ("char", "}", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 13" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRbWgScRgA8Ofcrg7OvMUdGWRtHwYZ1jy/BA3WbI2ihLhiG24wKtygxHO13UJmkiIRvlR2CVFGaB8MOShQSrDMUooISzKjN62++CEDCwzTQgqFyKT+/Hm+PC/wex5G09VNAQYYdD4cAPbPzxoWlAPN6H46JEnSYvSDMLpVPa2i/bdIXFFCr+YaK4/KHlynjJkk09NVMX9/96lMxVmeK4Rjj1WHCWHybp9e64hv5jeMn4lQ1eBpLxohiETPlTdVd/HQvS8HY29zqX4kX0t/JTZV7qCx3a8u8g1tTW9dY5l8tITdvkTv+ewPyZBTkrMnONMKYDTLsaxTMeUEgAoA/J9AAoBucYGbY5Uzc7pFdtbIDZhYQ39aJbHTYvUzYWwLbFs7OOoJSXeRUs8Rw+tgIHpj5MK36PBNRt6LvTCuL49v9xX0D++bnygOZG2rS44fvu7zH9Xh2o59Wrm9NCHNNyyy3nXPJ6YvT5n21qvzOwdfDsmviSM6BK1bXZkZur5q47Eir/yJvx8JHO8bcyWQliDlHT5nAwChJUBEFPwxtOvwDtNfR+lsbB9K/q5v/dS/V8Fo0GXNtAhEsAQAJxEAgF8DAAd5EVEVAgAA",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "D", false),
          ("char", "a", false),
          ("char", "t", false),
          ("char", "e", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 14" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRb2gScRgH8Oectw5u21l3pNSIRb6J0by9WXvR+kMLxoS4N8UWxRhz1IZ3Y9sNZBHtzVhtc5UU0aCQIkEurbQCr9Q4MSIk+2NglplEFAYmaGKaGR5EJvXjx+/N73m+8HkeRt+gpAADDOoPDgBDU6PGaV1H9V1+2tMi0U3oe6F35+4jnbT1Hom3p9CrkfLaydagk+LCEqNqyB4vvvuSpryshY+7xCedY4Qw6GsbHzjt7bJsPbDipvI283nUTRB+1ZVYfvnjsYeZYfFNJKBF3hZCOWJb9gEq9kcvWcoDhfG5jScGH89i91fp/V+t9lZkoeXMSd7UDIx+DfZisf3QIgBkAeD/BBIARmam+QlWZ5gYmWFHOb7DxBq1oT3cfJtqLiloRPXLfepeDz5vX+0OGRqXzN/SukxXwl/6lFoXJDdfTEpbBGHpdf/wUcejZvpzX9N36cOCcu/zc4a7F7S3GeWrnpumaHis6NLkjT8Ox7df9x/k+q4lLk+duqVZz5wdon/6dnXfsAYqz0o73A5nwcZ7Spticra6skGm5Mx3JqsUj0xBFBT8wdQy8TrcX9upb6wNJX/Xyzfw75kwerSx+q0ABcwCwAoCAPBrAIlsaTgeAgAA",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "{", false),
          ("char", "{", false),
          ("char", "#", false),
          ("char", "p", false),
          ("char", "a", false),
          ("char", "g", false),
          ("char", "e", false),
          ("char", "s", false),
          ("char", " ", false),
          ("char", "|", false),
          ("char", " ", false),
          ("char", "p", false),
          ("char", "a", false),
          ("char", "g", false),
          ("char", "e", false),
          ("char", "s", false),
          ("char", "}", false),
          ("char", "}", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 15" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRbWgScRgA8Ofcrh3ctlvdFcH2YR+EirF57sMqolrklxLGVQQq1Fi3UZnnWjtJ1jsEMbu9XX7pBdkGBSX1oUFbTlM0e0OMSjMzIyohNDQwxTIxFCKT9ufP8+V5gd/zMMqaWgowwKD64QDQe2xANyzrKEXBv7nRTdejH6yKLd375PT0PRJvi6OzgcLyoRbvHUr/3M001aRP/HyfSFIOTuSjd23P5IcJq/pBq1Y16ugS1+0dn6OyN8bM6BxBOJssb7NC7JDrW58tEvBIkXc533eiPW1HbTvfXBYLqpz2bPMp9ZMRbPEK3ZOavtmCXGicOMMbG4BR1mEvTW0aEwCkAWBpAgkArGGYH+Rk/YOsgRvQ8x1GTif1bdM/bK3vfmEVNrjo+Cxu7gteZI6SUqH96nnFruT+qbDdmd9zfPSjiYmwj3cHM/NqDXvw9iOU/nJpdXw8NlG7/dWap7pNOw7MYLfu+1VfQ4kMJ/+s/RWIyq6z5rrOhVTPRoWxeRUz2SAUz4nrJz8NWTSdvaH+xSOn186fzP8IJ1d4V850FbeWNRbD62tjALBQ1iASCv56KqV4le+fA1U3Vg4l/9SXv+f/a2GU6LJSWgISGAGAKQQA4PcAj/7ybSECAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "D", false),
          ("char", "e", false),
          ("char", "l", false),
          ("char", "i", false),
          ("char", "v", false),
          ("char", "e", false),
          ("char", "r", false),
          ("char", "y", false),
          ("char", " ", false),
          ("char", "{", false),
          ("char", "{", false),
          ("char", "s", false),
          ("char", "l", false),
          ("char", "i", false),
          ("char", "p", false),
          ("char", "}", false),
          ("char", "}", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 16" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRUUgTARjH/7d5enC2W+2ih/bgwxJqNSdFkeQo8KkDOQXHORKNZS3xbpRnDDWsBwvFjA6LMou1IIpFZIrF1VZsCmGSYCOk9GqRPShmcLGkkoVBtEZ+fHwv3/f94ff/85wxhwUFCtlFA6g9Xt/YVORYmd0vS00xZz75Plzm2ltT7AwOW2j7HBlKLK89Zh29x0oTMd5s1Fu/a/Of2YioyDMP1LHio0y4OlrQIHRGdiqbq3oG2dStc73kIMM8NV9/k+qe9T37clB9m4jbiOml8a/MNv0Jqe6fuqIsC0sNpzaerH7eQj3uc5YvBu9YibOm8+1yYA14Lo+a7LJ7ugDoAFZHsADwNjfJfrHokN/bLNZLsiMgNm4d3yeNFOR3JMNl1ro9cyG6N7llPbmrk/W+KNxUNTJjn5Si39zp6bZPsvlSybWhDfrC7GvPqFHwXAiVCvf7h9oHKu+m6mqCA4cryn3DFztOBFpd705/cB+4fDX98ed2d27Jo3nNVti2u2JHwi8nVZfNMfUj51X6oXbEFz1zQxtbqGX7JvpNscr4Inguj7rNr7vZAyACgOcIA4u/QJmodBbgPwllP2aKWv7c/+74/33hOTJ3ZW2AAS0AFAIAfg0AQXuO+iICAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "{", false),
          ("char", "{", false),
          ("char", "_", false),
          ("char", "p", false),
          ("char", "a", false),
          ("char", "g", false),
          ("char", "e", false),
          ("char", "}", false),
          ("char", "}", false),
          ("char", " ", false),
          ("char", "/", false),
          ("char", " ", false),
          ("char", "{", false),
          ("char", "{", false),
          ("char", "_", false),
          ("char", "p", false),
          ("char", "a", false),
          ("char", "g", false),
          ("char", "e", false),
          ("char", "s", false),
          ("char", "}", false),
          ("char", "}", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 17" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRb0gTARjGn5tdXs22xZ01ax9OkERs7sz+UMNI6FNXcRDGLCTsEi7ZeXje0VJCIUySs2T5JY0Yg4JYiLkwOLNCKyRGQRiIlVagH5I0uDgsWoVBZCNfXt4v7/s+8Hsegc9axYAChcxyAjih1oYbAyVL03he7hrhcsh3if1791WXcrFB2ln8kYyPp9c3+J70MfUvRgRPltX8bWpunhmWo9rbAfNZ6Wl3ouoBWxe6OLwzWlR5KcnYNzu7yaTb/dBzfdI2ZqRHn2vM1+OjBcSbxdQXt9+6T5oHJq5G06HFutbN56rGmqihHu7wQuyWj2h3XW7RIusg8NnUy47iYx0ALAArI9AARL1RU+TAKUXU5dp6rSQihwtSFX3nWU/r+4TXxc76p07Gr8U3xrhKuj2/LBQ2zij9vQvTabFtrKbw4I2gxK/Vt/FFebdf9bNnP+0W90jNd7oCk8nU4MDjrT5BP1Qm24r3h//rjrxdRyPq97uzF7bPByWbKLxC5s50Pi33mlbO0IYt3XOb5LYPPWqv0hI8nq9OrDnSME1A4LOp6tyfFQaAewAEnnAw+IuzHNSZgfdPPpmPy0XpP/e/e/T/rgg8uXpp7YADTQC6CAD4NQD0dh6JIAIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "T", false),
          ("char", "o", false),
          ("char", ":", false),
          ("char", " ", false),
          ("char", "{", false),
          ("char", "{", false),
          ("char", "c", false),
          ("char", "u", false),
          ("char", "s", false),
          ("char", "t", false),
          ("char", "o", false),
          ("char", "m", false),
          ("char", "e", false),
          ("char", "r", false),
          ("char", "}", false),
          ("char", "}", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 18" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRb0gTARjGn80uj1a7jTsyatIFUsRobl8qiLUFUdFRHKF5FlLh7M/cTZYnmVFJRNGyEw4hHBSHRH9Y+cFjReef7IYQayaFH6K0ggiiYikLOUohDKI16uXl/fK+7wO/5+G5kgUMSJAoLhuAA8cbIs2VnvnZ8cxvN7yLiXfJrZuDdT6vep+2uT8RPeNzzphrpJeJjhm8oyR/6vubzzlmUFSkyT494ztGJWuH2LBwaXC9srZa1piZm1e6CI2iHjmuv5rp+HB0eOqQ/no8XWGZMLPfqHX5AULf+bJbmRPMcPuK07VP2sj+hHf3V/WOy3LR3nlWal0CnislX8Td++IA8gD+j0ADqG9plprEylBTfYvYEJU8rWKkIrtFPs86gs+Ty+zs4aUamzkjPw6mEkL1jUUj8nSu/Mvoj/7A3qsbc2SVTm/YU7NG61KupZaXDav+Iyr9oMx2ocf/NOLmMoazqiYR0wLpqUbf3dCsMBm4daIxuuP9w02jq4xQX/s518HZleUD2z72XjaHtu+vm951Mtv5tvueJzbhvG2OgedKydVUWIwDSAHgOYuVwR+YQkxbEdxf6RQ/ForSv+9/dfrfnvAcsXB+bYUVbQBkCwD8HAB1mz/mHgIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "I", false),
          ("char", "n", false),
          ("char", "v", false),
          ("char", "o", false),
          ("char", "i", false),
          ("char", "c", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "{", false),
          ("char", "{", false),
          ("char", "n", false),
          ("char", "o", false),
          ("char", "}", false),
          ("char", "}", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 19" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRb0gTARjGn5tdXs22xZ01ax9OkERs7sz+UMNI6FNXcRDGLCTsEi7ZeXje0VJCIUySs2T5JY0Yg4JYiLkwOLNCKyRGQRiIlVagH5I0uDgsWoVBZCNfXt4v7/s+8Hsegc9axYAChcxyAjih1oYbAyVL03he7hrhcsh3if1791WXcrFB2ln8kYyPp9c3+J70MfUvRgRPltX8bWpunhmWo9rbAfNZ6Wl3ouoBWxe6OLwzWlR5KcnYNzu7yaTb/dBzfdI2ZqRHn2vM1+OjBcSbxdQXt9+6T5oHJq5G06HFutbN56rGmqihHu7wQuyWj2h3XW7RIusg8NnUy47iYx0ALAArI9AARL1RU+TAKUXU5dp6rSQihwtSFX3nWU/r+4TXxc76p07Gr8U3xrhKuj2/LBQ2zij9vQvTabFtrKbw4I2gxK/Vt/FFebdf9bNnP+0W90jNd7oCk8nU4MDjrT5BP1Qm24r3h//rjrxdRyPq97uzF7bPByWbKLxC5s50Pi33mlbO0IYt3XOb5LYPPWqv0hI8nq9OrDnSME1A4LOp6tyfFQaAewAEnnAw+IuzHNSZgfdPPpmPy0XpP/e/e/T/rgg8uXpp7YADTQC6CAD4NQD0dh6JIAIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "T", false),
          ("char", "o", false),
          ("char", ":", false),
          ("char", " ", false),
          ("char", "{", false),
          ("char", "{", false),
          ("char", "c", false),
          ("char", "u", false),
          ("char", "s", false),
          ("char", "t", false),
          ("char", "o", false),
          ("char", "m", false),
          ("char", "e", false),
          ("char", "r", false),
          ("char", "}", false),
          ("char", "}", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 20" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRW4gSYRQH8DNuszs0o7OLAwvNPiwh2y5bu7NQvW1Il5cdiCHZGBe2CBNq2VkpxxArFBQisQzpJbGQHgITKlK6jLdUgjDpIhbhpYKKyKIiS6QUwoHIpP34+F6+c/7wO4dj+9ZQgAEGvQcHgP1Hjcvm6anO63k0q8owBPo6vHObdnGGCd5S45M19HKxPXRk5P41auVxhhvsqx//+fLjZyoh+MTqTSk3c5gM65OjS/zpxFbfxPzZCNW4cuY8GiHJ1OClUsPz7tC9rwekcjGrQSrN/HdyUz2OSnMvLvjafHPJQZ/UP7BhMT+z+0swNIKcUnntolUJHDuAFdyTC24AqAPA6gQ1ABgsZtEkTB80GSyCcUWcsgrLmnxa6WQI7dP5q4SWI2f5c0PSDv8dh8vwUKWsJtcm4vZfOmf+w+jGH8cK+4jSp+cLaPx2dP0umr8RiKb0E3tpfvgVHxnfsLmc2x5Led9kdRU3rnMOvzddF6PmalozFrg4vq42sGj99pYuPnnG3m2RJ+TELa1+GWAcm9vjAICQDEAUFPwldOPwHtI/O+lt7A5V/6mXb/b/k+BYtL/zrQAF2ADAhQAA/B4AZzdV1hQCAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "N", false), ("char", "o", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 21" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRb0gTARjGn9t1enDmWXf0pX1oIJFI8xZREZQLCqyDOChhVlr5J0y8G7o7NCOUElayytZBfz6IBElx3bAEsdX6c2KEmEEYRFokEYG5Fi7Gqi1iQbRGvry8X973feD3PJJILuFBg0ZuMQAOtjY0+8qcmRmY3FJoCQXUO2P7Vne1S+gf5pjSOeraVHpZi30sxCvPLamIjB///vbTZz4iB9U3d8LjrqOsUfVgVZPnTGRDsKTy3BCfGDirU0Ms+7Co73Ui8KHx0ZfD4emp0WJiJjnxlV0bv0+Fd726Ekx7kk1dK09UPe2g710Vdsf6b9oJf+H5TrV9KSQxn37RU7qvB0AcwOIIHIA6zad65bJ6b50mNyiqs11uLp54bFpCQddsZd86954I6b/xzOlwydc3D8/rOnH5JMMNrqhl9NZvP6fL915ao9B3U9GRI5q23lcyf+vlJjIvetoRG6mpEPhoxer9O5czO6TqhW4jHftxcWyw/r1/blJXzJneJy1t4w6r0ePeFjqU+niss7zmlBlKDtgXZr21hshv7D6QaoMk5tMXhMTtAAATgCQSNh5/cbJBmRy8f/LJfcwW5f7c/+7R/7siiVReZm2DDR0AegkA+DUA3nt9fCACAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "項", false), ("char", "目", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 22" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRbUgTcRgA8Gen1y4ud4vdh0ApP+xLiHp+EU+sFCzKqzgckloiZtIyb2vzhMPw3IegtnzjGrEKal3QC1J2CgWXZmxMymRBCGVpSKSVUWteLBGuwkG0Rv3583x5XuD3PCyTkUkCBhikPxwAGt0tbe2FBWuxJ7rNFKI2oPODldvLG4qo4D0LnreEytP6RldO5A7peBZizRnaydU3n76QY5zEzw2rk0XHiMG6h7mttd6xYmlrTd8Imbje60dHCGLcfPlVomfB/uhrk/p6Omw1zK5MfSPytVFUrXp5QdJrV1o92V11jzuxBxep/bHgrRzDaVN/Ny9kAcsYsee+vHofAGgA8H+CBQCaO9p5J1d4xNncwbU4+AKBa7NOKfsilHkiXjNgFEQ5eHd59KzSb62OHp2jS/zziAJZ2WxuVULx0wPnFr/vaYxv8a1/d+BUIFZ8SA64bbboE3u+iPDuq5mu8IJ3U8N5PH4Td+3eu7lyseStHBt6Yex19E2aImXVwsdLpbP00i5JO2HzVniuVMzoWtfP1ePO8dvi/fqDun1ox3v6w+Hhz8tNpWVP1UC5uPPMzA8iaez2MBPXACCUNBoQEv4oU/14mvqvs6U3pg61/K5P/vC/l8Uy6Lq1NAIIdALADQMAwK8BAEuKMxM3AgAA",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "文", false),
          ("char", "書", false),
          ("char", "グ", false),
          ("char", "リ", false),
          ("char", "ッ", false),
          ("char", "ド", false),
          ("char", "の", false),
          ("char", "文", false),
          ("char", "書", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 23" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRb0gTARjGn9t1enDmWXf0pX1oIJFI8xZREZQLCqyDOChhVlr5J0y8G7o7NCOUElayytZBfz6IBElx3bAEsdX6c2KEmEEYRFokEYG5Fi7Gqi1iQbRGvry8X973feD3PJJILuFBg0ZuMQAOtjY0+8qcmRmY3FJoCQXUO2P7Vne1S+gf5pjSOeraVHpZi30sxCvPLamIjB///vbTZz4iB9U3d8LjrqOsUfVgVZPnTGRDsKTy3BCfGDirU0Ms+7Co73Ui8KHx0ZfD4emp0WJiJjnxlV0bv0+Fd726Ekx7kk1dK09UPe2g710Vdsf6b9oJf+H5TrV9KSQxn37RU7qvB0AcwOIIHIA6zad65bJ6b50mNyiqs11uLp54bFpCQddsZd86954I6b/xzOlwydc3D8/rOnH5JMMNrqhl9NZvP6fL915ao9B3U9GRI5q23lcyf+vlJjIvetoRG6mpEPhoxer9O5czO6TqhW4jHftxcWyw/r1/blJXzJneJy1t4w6r0ePeFjqU+niss7zmlBlKDtgXZr21hshv7D6QaoMk5tMXhMTtAAATgCQSNh5/cbJBmRy8f/LJfcwW5f7c/+7R/7siiVReZm2DDR0AegkA+DUA3nt9fCACAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "項", false), ("char", "目", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 24" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRbUgTcRgA8Od23bzY8iY7IsgPCYsm0nkriAoKYX1qFVdhOUtqmWDizU5PEKMcEUhTs46DKEhGUBjDiISFV1e5WVS4RrFg7LVo68OKrbpaVzGIDaI16s+f58vzAr/nYWzoEhJwwKH66QDgUH9X70AzVYrjz7fU+mk99tq7bWtLh4X2+Iy6pix2NVys4+of3SSdIT9jQJUTP5Lvc6TMCnzitvTMcozw2u+v6mk7K28QGlvPzZKF6xMiNksQDwxT0cJ4pvvhR4cUCwdMSFxd/EKsVe5h0vbIJaHYpva4Vp60PxnG716md+U9N+qR0drJEX5oGTC2Gvylu6ndDQAKAPyfYASAzsEBvo9tPtrXOch2OXlqiO01Lc7P+Gm9603r1LqWvTI6Oh2kGizstc2+D6K4euN69Ai1sMKc+Vy8MzJN7Y4b+r/HuGA22/1uT8Tu5bT6aJ01ycnnD5ujF3b4BNNyt0dKL93/M/VtzZjj6WPi1ZXGRPtcw8TbnGg98+KW6/TBeTWkfD0VrznQ8WnnpnQgtbDvotmJz6n5suW4VesYA4CZsgXRkPBHU+nUVen+Ok91Y+VQ4+/68g/8eymMDdOW0hrQwDAATCIAAL8GANPF2HkfAgAA",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "説", false), ("char", "明", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 25" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRb0gTcRgH8Ofmro5OvcUuGOgLX1xQSPNMiHqhCScEDexe1KWDLFHD7G6S3lCMWBAVs9tVhxYGifQiCMFKqWT5J0+CUWPrxgaxWsWgNw1WdDFG21jsIFqjfvz4vfk9zxc+z8M6qswkYIBB5cEB4OTIAD/aZC+9Uqi1VqWr0U/zHW3tJ5rpuadWvPELei9a2H6u/uUC6QqrrKVKP//zQypNrgqKmFj0v2o+Q8x3rzUMdXlX9ym7j8lLZOa+bwpdIoh1y2w8I30efPGt1/8uukkh77PBH8QefQX1H347oxS6skMX6y50Byaw53fozq9zD+qRq7XXPeJ4DbCOrVhkstE5CQA6APyfYAWAPveoOCw09Q/3uYUBl2gfF3gquOFTaUu7xnH2hlC6l+CSPVIrdXPvrCZdYpCjG5e3DeIaOrK84skxbm/yyo3XYfksd/xQy2015PS1nHoj277LqRkzo8n9i9PUY9Yc23lkOb6+Vnxmu8Xn2YQ38mS6LrI/3Xmgw1aD7wqgkueg62FOH3sU2/FximnL9/BG7rVitcEZc949LQPAgsFBTCT8AZVT8QrgXxuqbCwPtf6uN+7mv+fCOtAtpW8TmGACABQEAODXAIK+SJIiAgAA",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "項", false), ("char", "目", false), ("char", "1", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 26" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRYUgTARTH/7ft5rHVdrn75oxATcQ2tyANorHCD9WtOKqlViJlkpmnTCcshxn4YSVL44iiGGtoBSUYTBjj7DI8hJCrICRCy1oRQcGsrsSiVRhEa9Tj8b689/7w+/85VqtjQIFCbhkBNHQ0tXZW2Jdn+MFm06RjBflipNrlrnc6YgmLsfwtOTSTWeWzTo0ybQ8nOVqrBr/Ov0szEi/4n8XFaecx80jdnTUttWekSqHMOzDGLF4/e54cM5sn6OjsYvh18933h8S5GbmYeLqkfDLb1NukuOPJJSFTu9RyqqCn7l43NX7ZsWshdsNKhEyDvf7ASnBsHvWov3x/PwAVwP8RLAAauzr97XzFkfbGLr6pzW8P8K3FisTLDtqd8ur2bS8ylO2m86uo9dqd0ZMoHEwOe04YauZlbaAwaOrrUKX05yndx4Ktyv2B48we/YY3kfDjl0fdpbaS05tGi5ziOtuHq0bfNs/q6gsbUzd7xXTN8IGheI+z1HBxdm9q2lclREJbSvSEqy9+ay7zJVnZ8ONVMtD8/WB0IljvSXhdntCVa/a1557ThxMLBDg2j8pXrN8iAMYBcCyhYfAHLxvcmIP7V165j9milt/3v1r+t0scS+qX1xpo0A0gRgDAzwEAHtZpBTACAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "数", false),
          ("char", "式", false),
          ("char", " ", false),
          ("char", "(", false),
          ("char", "O", false),
          ("char", "f", false),
          ("char", "f", false),
          ("char", "i", false),
          ("char", "c", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "M", false),
          ("char", "a", false),
          ("char", "t", false),
          ("char", "h", false),
          ("char", ")", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 27" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRb0gTcRgH8O+mpyeX22oHBQ0rkKKW2w4p6oVm4AvralxEcAsiyuyPecq2E8wYVlBxwxaM60UlOhxIIWS5Mri6Fi5RSvqHL8KllFEvSjRZrKNrFAuiNerHj+fN8wc+z8OxBYU0SJDIfxSA/b6GJr/TkY2dT6tMw65FxJv+2uqafYwrMmSl7B+J3onMYq9t5Abd/GyYsxSkTn6b/jRHq0JYnBpUHjPHzP2eBysbeUndGF67JxSj030XZCJmNsct3ZPpzvdHH34+oCQnEuWG19r4F3NF6j6hbH91OZzhtcZTywOesXby3hWXez5y3WY4b7rYIbaVgmOLyZdB+94ggBSA/xOsAOpb/WKL4DzUUt8qNDSLjjahqXyccT9yWWpeZCm2XRwvzR+cXSXJC3ylyXQEUqg7dIa6Oflu9vDALd/QibgeYE5/D1r8sbdLRuStOzevid7RSp5vY0tmzj2xM8r6ioVrlLduR1nth00zvT3KnCd6NToYYJz09PHdZ+2jU3W+sqJLywq1Ulntqv4a78noP9K6t6pjg+pYnVy3oi8x6l5qHRsgmaQOji0mb9u2VHYBuAuAYw1GGn94uXAqj/vXvfIbc4daf9f/+ol/b4ljiaJs2ggj2gFEDADwcwBsoSMfMAIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "二", false),
          ("char", "次", false),
          ("char", "方", false),
          ("char", "程", false),
          ("char", "式", false),
          ("char", " ", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 28" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRX2gSARzHf+d2dXDbbnFHPTRoD6MxJHd7CRK2GlsFHcSBC7bFGEtX7dq5pieIWgYVpZnBIUQ+lPQQiZCl0INpfxSzwjLCUNIkoV4szLoQKaxQiEzajx+/l98fvp/fl2U6OinAAIP2wAFgXre4rB9WNKrjxWhPlO5C3/kmx3bNjdCeuyQuL6HX0/UNq33xW5Q2FWV7OyTz98LHMhXhReFtIPRsZInwzdzv56Ztke3i0AFnkKreuOhCgwTxoPfqm6rjw9GHlYVQLh0bQPK15DdimxRGQ/uyV8T6dI07tfnEzBMTds9N7//s8fYh53ouWQVjN7DMeuyVXT5rBwAJANZGIAFAbdALK/ywZkVt4Be1gsLILw8kx7Vn6K6zRd/UDtgzJyyMl8Wtiv5iNjARy5+kDkuR1z8uO3d/jU/lMs+PGD4dyx5UdVbC5OC1SW/B8tO2yo3Z+Jdxu1uj21l6PGhJScRxJXeeScwP+e8obz9S7c24lrq595pf1KFZj/rChDmdSG1Rbny6ScV/GW3qx+X+nBUAbjb1IzIK/hK0suFtRP9Y0r7YepT8M9/M2P8fwTLoukZbBjIwAcBpBADg9wAWZN8NEwIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "a", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 29" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRbWgSARjHn3O7OnDbLe7oS4P2YTTGSs8vQYP2QlbQQRxswVaMMeaqXTvXthPGtlpQYYopHELkh5Q+iCL0otAH86wUM8IywlDUJKW+WJh0IVJYoRCZ1MPD8+V54f97/gzd1k4CBhi0hhwAZlbmF1eVino1vTzYFaI60Hce9fDotIpyPCDkg0X0dqK2Y7kncofUxkNMd5u08S33sUSKnMC/9fqfqxZwz1Swl500iPuFgRNmH1lxXreiPhx/1H0rXTF9OPu4POvPJMJ9SLYa+4rvkwKo/1jqplCbrLKXdl2YeraOPbRRxz873D2Ivsuyxa91AkNvx14bB08aAUACgP8jEAAwp1vllzilZmlOx81recUat9gXG9NeoTqu5j0TB+DIND87VhL2KHrzKe+hcPYieVoS33y/YT78JTKRSb44o/t0LnVqvL0cIPrtandu84dhmR02cK8iRptmZaT4tH8zLuHnh9hrdHRm4O79oXtPxo8mrQud7HvNT7IgjkZ36isui32E3ysonenCRkN/cLdKvQUAroZ+REbCH4JmNnkL0V+WtC42HyV+zzcy/O9HMDS6rd6WgQzWAeAyAgDwawDqIfz+EwIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "x", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 30" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRfUgTARjGn51enpztrF0htUjIghB1QlZEmkZ/iEdxfev6mIcOluzO1LsYrqygsA6zmJGkVMMgikGsjD5meqkFscwyhKIvJPOPCiw4O6S1CoNojXx5ef953/eB3/PwXEIiCwoU4osG4Kh1uutysqdm02C+uc+WQo4E1hUU7sq1+W9a6MyPZMdwdFaN9cFVVnrSx6cm6N5vbz+Ns92iT35zPRTO3cMEynrSq0qPdy/3Ld3a3Mkal06cJjsZRks9/9JoGnPd+yKEXg33Z5heTw5MMFn6XTJU8uKsL1o6WXVo/oGyh/VUV5ttw2f/Faup0XzyoOyZCZ5Lop6pmXYVgA5gegQLgAqlTq4WcyqrKxTRKcnZHtGd8bhIup+eQj4N+K3lacoQGX4/O/8wLR07cs3pLamNqLL+wxHVmres1JK7Glvst5bt5pRW9uKYmmiU9zZsigiL93qD4zXBuRsHXfsmztm/ewrWLOodahUXfGh/lLd5yao7z1uSK/dndbgua7fdjoa8GyNzVqftFAaIokJh+6l55h2jxT3rv26Tfi58V3xUbw9GjBXguSRqlLmw9gyAMACeMxEs/oLFItNxoP8kFf8YK2r5c/+7+//vD8+RM6bWBAjUA2gzAcCvAQDNsMJGKgIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "S", false),
          ("char", "t", false),
          ("char", "y", false),
          ("char", "l", false),
          ("char", "e", false),
          ("char", "s", false),
          ("char", " ", false),
          ("char", "t", false),
          ("char", "h", false),
          ("char", "a", false),
          ("char", "t", false),
          ("char", " ", false),
          ("char", "s", false),
          ("char", "a", false),
          ("char", "y", false),
          ("char", " ", false),
          ("char", "w", false),
          ("char", "h", false),
          ("char", "a", false),
          ("char", "t", false),
          ("char", " ", false),
          ("char", "a", false),
          ("char", " ", false),
          ("char", "p", false),
          ("char", "a", false),
          ("char", "r", false),
          ("char", "a", false),
          ("char", "g", false),
          ("char", "r", false),
          ("char", "a", false),
          ("char", "p", false),
          ("char", "h", false),
          ("char", " ", false),
          ("char", "i", false),
          ("char", "s", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 31" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRbUgTcRjAn73cutrcafv3IRqUsC9h7sUgQlnFrC8O5AqkrXdxs1qeQ7fJmNQKoZdhCUMSE2z0IYkDiRY2Li25M4paS3Iw26WuSKgbVHS1ZCSFQrVGPjw8X54X+P0e0iqTI8ABh+JQAsDRdmeLx6Bfqt0Js5o1qrAMvXvHrsMmY2REo6wQsBvJxbI27aNh1PqCJUtlYmd+NvsRjVFh78wd5qnpJEHbH2xy2S6NbQtvbrgSRbmbl3uxKEE8LB1M57rnT4x/bmT4JKeTvF6IfyUqxVGMqZvuDy/aFlxnN5y2Pwng968Z6z9FbmklF9Q9Qa+/BEjrKvxlqOJACABEAFgZQQMATT6P100ZHO4mH+Vs9er9VIsusdc1YVTJJ+mLKL/eUImEZpnZ0pOpFtLHrMO61ADf5wjO/lBxWzi3tnNPVSxlER776pqf1wyZGkuqPbVM6gu3r+tDvN3T5TzFljVsnXG1GfqeDdDlU3f1XFAc2fhK/S5z6HvaMpFNytfNE0PfNGdqDt6Oy0OK/vG17P7jtSSvDOBkVbltjcJ+bjpR//6qbfD6kbmdyD85GntDmXunOvKxt+fntudCjuzPZebI6g4++odZIkXwl7rQh7LIwj9vLF4sPKr5Pb+c3P/lkVZMsdSWghQCAHBPAgDwawAkiO+CRwIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "A", false),
          ("char", " ", false),
          ("char", "q", false),
          ("char", "u", false),
          ("char", "o", false),
          ("char", "t", false),
          ("char", "a", false),
          ("char", "t", false),
          ("char", "i", false),
          ("char", "o", false),
          ("char", "n", false),
          ("char", " ", false),
          ("char", "s", false),
          ("char", "e", false),
          ("char", "t", false),
          ("char", " ", false),
          ("char", "i", false),
          ("char", "n", false),
          ("char", " ", false),
          ("char", "t", false),
          ("char", "h", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "Q", false),
          ("char", "u", false),
          ("char", "o", false),
          ("char", "t", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "s", false),
          ("char", "t", false),
          ("char", "y", false),
          ("char", "l", false),
          ("char", "e", false),
          ("char", ":", false),
          ("char", " ", false),
          ("char", "a", false),
          ("char", " ", false),
          ("char", "l", false),
          ("char", "i", false),
          ("char", "n", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "t", false),
          ("char", "h", false),
          ("char", "a", false),
          ("char", "t", false),
          ("char", " ", false),
          ("char", "i", false),
          ("char", "s", false),
          ("char", " ", false),
          ("char", "n", false),
          ("char", "o", false),
          ("char", "t", false),
          ("char", " ", false),
          ("char", "t", false),
          ("char", "h", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "a", false),
          ("char", "u", false),
          ("char", "t", false),
          ("char", "h", false),
          ("char", "o", false),
          ("char", "r", false),
          ("char", "'", false),
          ("char", "s", false),
          ("char", " ", false),
          ("char", "o", false),
          ("char", "w", false),
          ("char", "n", false),
          ("char", ".", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 32" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRbUgTARiA37vt7GDLU+7AyBER/hHJ3RFE/Zh9LEk90KMPmVFeNzPSvJP0FsdCFhF9TE26Aj9+DAscyEU/HAVemuERWKwaQ2h9OUn8Y6ij2bBCCweRjXx5ef+8H/A8L8eazBTggENmWACAb6lvarUXr9WO147scdqKTWuHSvafYuj+x6SlaA67P7mSe8H2/CElvRnnckzJSz+mvixQo6IqfxrSXzINhFbzdHuj6+bobrXw+K0QlQp23sVCBDGWE3if6pg99ywh6B8mjQLk43J4idiZHMH0ilivuuJabryc31Yz4cWf9NGVi/2DNuR6dpdPVjYDx27Co/6iE34ASALAxggkANR5WuVm0X6muc4j1ktysSI2FbxiJYO2miMaXptXHSnNuzJzdAl9EHZlhavK9QqJj70bQc4yu74NlTnwvdE7F1PRRWd7RA29vWYu8e/Y1+C7kXu1y31+wd3ed0yOKwMO35TE956eEQLe77dnPcFA7MWj2pP3PrdxzsM/DWFV6rFpCZWyVpvE8m2FW4NxJ+omV8vy+U6T8FWZ31M53N1TNX/EHh8b7i6dOzDB/CLSlFtaEgcHAGA6TYmgFPzlXG/AksH9z+MyF9cfJf/Mp9P4vy6OxbLW2iig4AWAQQQA4PcA2PLHCDkCAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "T", false),
          ("char", "h", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "s", false),
          ("char", "e", false),
          ("char", "c", false),
          ("char", "o", false),
          ("char", "n", false),
          ("char", "d", false),
          ("char", " ", false),
          ("char", "p", false),
          ("char", "a", false),
          ("char", "r", false),
          ("char", "a", false),
          ("char", "g", false),
          ("char", "r", false),
          ("char", "a", false),
          ("char", "p", false),
          ("char", "h", false),
          ("char", " ", false),
          ("char", "o", false),
          ("char", "f", false),
          ("char", " ", false),
          ("char", "t", false),
          ("char", "h", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "q", false),
          ("char", "u", false),
          ("char", "o", false),
          ("char", "t", false),
          ("char", "a", false),
          ("char", "t", false),
          ("char", "i", false),
          ("char", "o", false),
          ("char", "n", false),
          ("char", ",", false),
          ("char", " ", false),
          ("char", "i", false),
          ("char", "n", false),
          ("char", " ", false),
          ("char", "t", false),
          ("char", "h", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "s", false),
          ("char", "a", false),
          ("char", "m", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "s", false),
          ("char", "t", false),
          ("char", "y", false),
          ("char", "l", false),
          ("char", "e", false),
          ("char", ".", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 33" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRbUgTARjH/5teO9jalJ1t4Ioiiw3ndvYhRTSklw91IPdl4oK0MCtlmytPMGsZGUbiS1xC5AdbL1QmBOZoMfMUl/hCpZWhpoVBgjSpxdZhwUkYRGvkw8Pz5XmB3+9hmYRECiRIxIcSQMmpMkeV1bJam17mqQdpFTHftXdX/qFM2vtYq0z/TNyalJJPGoYeUq7xQTYpIXLm54fQF6rPyXPvHwXGMss1XXZhc0XR5b6dvMnW0kOJd5vbiB6Npj+p453YtHBiIHwkMDsZTJPNLT+PajIiT4nAgenrvFS0XHE+1WMfqSV72+mCr95Og+ySurWOq1kPllGQrxvTDzYCiABYG0ELoLS6iqt0Wo9WllY7y1ycpcbpML/odgVpVeJEyZZcXeHEzfp5/eJ09w3vmMM8kGbjH/D91k/HTmcZ3P7ok/2ui0vue/UZYsjXO6W/sLDRNGNO+VEw7Ddu89ujGwKLhbYd7SnCq+Ri6zV/fmfYZ8k7Nyrq7Yqc7Knbb9u+5dj27ZGGyj3HjUsjDeE3z67qPupozqgStp7NnR3f3nJ4JdtdvLtVUH/3dazUNWzKGm2+4pFSwTIKMmSaGb4DYA4Ay8jkFP5ixgpQxmH/87f4xdij2j/zvzP4f1ssQ6xbbcshRy2A+zIA+DUAbhIQsDgCAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "A", false),
          ("char", "n", false),
          ("char", " ", false),
          ("char", "i", false),
          ("char", "n", false),
          ("char", "t", false),
          ("char", "e", false),
          ("char", "n", false),
          ("char", "s", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "q", false),
          ("char", "u", false),
          ("char", "o", false),
          ("char", "t", false),
          ("char", "a", false),
          ("char", "t", false),
          ("char", "i", false),
          ("char", "o", false),
          ("char", "n", false),
          ("char", ",", false),
          ("char", " ", false),
          ("char", "s", false),
          ("char", "e", false),
          ("char", "t", false),
          ("char", " ", false),
          ("char", "i", false),
          ("char", "n", false),
          ("char", " ", false),
          ("char", "t", false),
          ("char", "h", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "I", false),
          ("char", "n", false),
          ("char", "t", false),
          ("char", "e", false),
          ("char", "n", false),
          ("char", "s", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "Q", false),
          ("char", "u", false),
          ("char", "o", false),
          ("char", "t", false),
          ("char", "e", false),
          ("char", " ", false),
          ("char", "s", false),
          ("char", "t", false),
          ("char", "y", false),
          ("char", "l", false),
          ("char", "e", false),
          ("char", ".", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 34" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRbUgTcRgA8Oe23e5gtVveRR8a0QcLZHm7+1IS5aJX6Gzch2QamNgaLN0p5QmyuLmiOJJ1qyvolbQgKUYKCVcttVACG+MkERZzRQXRaJXFQiwSw0G0Rv7583x5XuD3PDxnNFGAAw6lzwIAjcd8gXYnvRgj+lbrKLMMfRPbWb2tgWV6NdLi+IjemppfcdT+rJ9qnRjlbcb88Z+vc1+oYUEVX92PJ9gjRKx+ZG1z3ZnhjWpFrTJIzfadvYgOEsQT2430bOS9/+nXpvj01Fg5kplLficq80NofO/LK+p83VxzeLVUPx7EH19l3DO9d+2IbI12iZ3LgecwfLLbcaAbAPIAsDSBBABvR7vYJjgPt3k7BF+rSHcKgfIk65YZKvwtdnlNuAyTzcFL6eoTp1KpIc8GpcbdT39S9IxsGmhKdP2QplMryXEnzrruVe1hb3u8+nN/ZcgkTvInH777tTtCczu2ZLfbyy5g5yusVbkPmvQi23cn4Ek6TkfT+98mpE3qdfngOjMSwnwLSk+LS/+cy4QGZiZaXJsbarTakX0Pojfp9ecabYe0BWPBtmuVP3sNAB4VbIiBgr+6YrelRPvPuUobi4eSf+oLf+z/S+I51LyYNoABggDQgwAA/B4AhbpGlS8CAAA=",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "縦", false),
          ("char", "書", false),
          ("char", "き", false),
          ("char", "の", false),
          ("char", "文", false),
          ("char", "書", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 35" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TSb0hTURQA8DN1+mjme7UViCK6igrRvfch+zdNLUFc5CgkZ0SsbaWbb8PcZCqh0GC0ptKI4QrMlAlz1geVhOUy3liGtWkyKZ1lRWUUTWtr6WArZkQ26nK5X+45h3N+HD4vPoEFCCAQexgAcOaCpLaekxt99e78FApPpr+yHikoPE3g3XeZjOyP9B5PeFNduvMOSz5J8bF4f3Po5Scfy04alC8GbRNEDWoV3M+UVl625xl2V7QPsYJ9bdfoQyg6hnXNBfXvqh8sC21ej2M7bX7lSQDN8Y/SbWXPTYZw5Yq0Ne2i4FETcu86fmyp25JO06Z0tCjVG4HPS0KmddlVOgDwA8D/R2ACgEhVr1SQHLFCpCIlcmWumqzlul1ljkIsafnkVW7h3rdTDsP7PdxxMcmYRRtG5PbPA/tXi4p2lXA3sLeQJQnlIVzU35F1o5gztjopjBz1VedYU89TGa7GbcmqXvHZ2z2aTimlrkk8ThCLLotndPhc5rfOfRaZWeLUm3SEotTYd5h6bCnVzT9lCm6OW9gHpkdO9E7o2jabTcKQfodzYebU98Fidb7R9nDKZ/SGu8yzmPBSRkO5TLPoXmAPYBkth6o0Cg1HczBwy5uLGRFZ4BmCflDgw4T2SoFW/iXib0xNy8uhwq/xne1z7P7miqVI3ZtfjW79Eb9GpvTMtH4FgCxalIwWx4I/aOs5GTGIf21BbOL6oszf8WvX8W97Po+eGP2OgzhoAoAgDQDg5wBcD//vhgIAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "英", false),
          ("char", "字", false),
          ("char", "の", false),
          ("char", "W", false),
          ("char", "o", false),
          ("char", "r", false),
          ("char", "d", false),
          ("char", "や", false),
          ("char", "数", false),
          ("char", "字", false),
          ("char", "の", false),
          ("char", "2", false),
          ("char", "0", false),
          ("char", "2", false),
          ("char", "6", false),
          ("char", "は", false),
          ("char", "、", false),
          ("char", "横", false),
          ("char", "に", false),
          ("char", "倒", false),
          ("char", "し", false),
          ("char", "て", false),
          ("char", "組", false),
          ("char", "み", false),
          ("char", "ま", false),
          ("char", "す", false),
          ("char", "。", false),
          ("char", "小", false),
          ("char", "さ", false),
          ("char", "な", false),
          ("char", "「", false),
          ("char", "っ", false),
          ("char", "」", false),
          ("char", "や", false),
          ("char", "「", false),
          ("char", "ゃ", false),
          ("char", "」", false),
          ("char", "も", false),
          ("char", "右", false),
          ("char", "上", false),
          ("char", "に", false),
          ("char", "寄", false),
          ("char", "せ", false),
          ("char", "ま", false),
          ("char", "す", false),
          ("char", "。", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 36" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3SRUUgTARjH/zc7vTjzTnYU4R4sFiTSeQbVQxmRFdWFXIXpBKlhgpmnnJ4kVjgrCC81vPZSkI0eolhmJgidzVIpKqyoFGQuKygfVlhx4rbWIhZEa+THx/fyfd8ffv+/JKYs4kCBQnLRAA7WV9Y05PHx2f68IGNESCffebdt3lKeL3gGrHRukLw6HstUbA9vcbUvRiQ2xTz+ffrTLOeTdfXNHeNp/hHG6xjKri5t863Xc4o7+7n5ax1usp9h7rPd/vn2j1UPvjqNqfFROxEIj80xa8x7pLF78qIeKw1Xu7JOOh43U4OXhKIvnhs24mzG+Ra1aQkkMY16peWWaQBMAAsjWAFUNDaodXLe4bqKRrmyVuWb5Br7WF/PaYF1vS/u3oQdvTudrceUz3S2MvT6ctsu8UrrWsm9buWFmehgy3V+b4Ctj0wpz4LBqpl9kw6vkpruzyycVnxdh1b7u/YM6Palmsf4sLgk+ja07JzzySNmojynoOzuig5z1l145uVt16nAcDj07Yetd/hAyYn9RZG5DX0Tq7SsrfzPjZDENGr59qM3NQA9ACSRsHD4C5OISSfB/ZNO8mOiqPXP/e8e/b8nkkimxtcWWNAMoJMAgF8DAIGE9BQeAgAA",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [("char", "傍", false), ("char", "点", false)],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX document text matches upstream Go 37" {
  check_docx_document_text(
    [
      "H4sIAAAAAAAA/3TRbUjUcBgA8Gdns8XKLW4fAg/zg5EhzU0iekdSsbqQhUXqERnXQanztJthSlohHN7WC0dFFuTOKKhBlMIRq3N1q7AUpfBDZGaQJc5SYyGjSwgPouuoP3+eL88L/J6Hc6YsogADDJIfDgAHj3lqfLn0QpQGt6ZFmaXoB6VwW/4BlpHDdjzHQLuG55fXO57dpWqHohyZYjb/eD81TUX4oDDarb5kjxJKeW9mVVl7ZH1wzb5zPdTcrbMX0R6C0Mjrb+ekT0cezx5SR4b1LOSdNfCdWGs+QtVdbzqC82VW1an0k+V9TdjDq0zJjHzbgfjTzrcKjcuAcy7GXgdyKgIAYALA/wl2AHA3+AQvn3vY627gPbUC3cjXZA2wJU8ZMv+VkrmyMtIl3+vuFe/7Ry/lZVQ/fxISJ7MLioqvba5zlI6v6Aud0GIF7OmfbaSpS26qlDYu+/IqRA3ZtHHPmQ0fre0S3d9u3cHrd+zOKJz+FrjRsqWzc53avPd49ueOqMtr1E08SN85qBetSkVaUM9IbGJmaL9SrYzFwl+mihWXy5DFF+F+/+RsqyIuGV/dduXrWFyIXNArQwCgxYWIjYI/xkQ9nmT+62jJjYlD7b/r41//96o4J5q6kLaBDZoA4CYCAPBrALKRJo01AgAA",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        false,
        true,
        [
          ("char", "を", false),
          ("char", "付", false),
          ("char", "け", false),
          ("char", "た", false),
          ("char", "言", false),
          ("char", "葉", false),
          ("char", "と", false),
          ("char", "、", false),
        ],
      ),
    ],
    [(612.00000000000000, 792.00000000000000, 72.000000000000000)],
  )
}

///|
test "DOCX styled text matches upstream Go 0" {
  check_docx_styled_text(
    [
      "H4sIAAAAAAAA/4SUC0yTVxSA71+oloGAtMpQJBBwhCFYFHAOeQ6zxApBwsPyCINSgpS+2wwYpcXVKKUVhk7FKWNzzGHXFmVTXoJCy3iIxabpsAxtIUQeCoxK11YZS2sIXePcn5M/N7n3nOT77jk3CWNnjwIIgAC2nyMAIIeGL6bvDTb/+Q8jnXvRTnCNMD4qJjsE3Xgb6Rg4B/9eubqV6ikTo0jy3iRXO90XpifzC6i7xDrGxK2OoZATLkJst3fR8aq74XUBqWdbUfofBefhrS4uPa4Naj1/uvDeUm7HuLLPD/rD8OClS5CuC95xZKy+bvW4oYizk4UdKEN0XkYnLjY2e0KnnWvYjJItIAmzGaHgBWbwAAA6AMB/I3gBAHBMOoNM3PuGJJ+MYxLxJEZwCbH4DdWIhSpGK0zZoJqEpVHY8Z6f3vxKMe4rTfbb1H+nXNJD88sJe3yrgHBDmm+3Z8HILczN9SGE0W+4+QfFkUQXPPaf2jzCPy2OyHu8E11RPzIdxYmlj+9bs5sPFVXKdzT0DrINhd2HK6pTCvRQ1ERaFQdX86pdIIEsPELK5zouAEDzTh7kBo81SXxNNqnP25UryaNyPsOmpn43lvx0+f1m/3st1FoDsnP2g0gWvG1hWHyJXMDZH/jNA9+YH7Qe5fGy1jYkfvfuyxH2guvnfaK+7GlyC9UGfJ1A+zD8Yj54JAsqOSiY6nRSH755BSsa7J57SMzCZOa8XEa3mFQV291HVbKEAR6aMDUZ3qI4cHJf9Szx53gvrSpmWJYqUMdKJv6UY/5Ku7rt79fZYazn2RHXp3WF2OGz6ufyF1Q0YyJ3TZCPP1dqf+aX184WBW0HM7p6AQDh0LsUbN1QQGeUFuPpZgH82vuJOrTTbzlNQ6uZHbui/ISzUAIimMMtARJmZ2No1aQT+VBk0e8+H39E4ePW2HqJm6acJpVRKQ2xfPUzz1gCSR/qLYnzY3tmuSs49ek+KxlxRbj3toRkPnVJ",
      "JA8t93iNlqWmw4iFt5Xa+3hxYKXhink1bQzTU6T9pm7XsWPubh6/BmOa5o/Ig0xl6KA8xZhv7cJJeRbC+4BqB7P6KI4H2CjY4gxffbQd5uz/JMV3bXEF359wrMxhNFp8ac82mBE1+NMZh1dcqoSH1XxCUE7NDAia9IdOKDNYESZR+9IupnFO7bCUrojMJbCiTy3WNrOWL86UOqwG3vH5NuBqtIjsWElFXiOFOxpzKl4kP+q6tl1TTpOuPLPoVfUXAG8IgGiYWS8EQ4ENwdbT5Ggj/F+PgG2iddt6rZ+3RN//jp5tLev7R66XscQ56K1tb1vAmnDreq4lLsDe0jRJGPgm86Y9sAdwCIAVOwAA+GcANUEcuBAFAAA=",
    ],
    [
      (
        0,
        "center",
        36.000000000000000,
        5.0000000000000000,
        12.000000000000000,
        {
          fonts: ["Base", "Times New Roman", "", "Times New Roman"],
          themes: ["", "", "", ""],
          hint: "",
          toggles: 2,
          specified: 0,
          size: 10.000000000000000,
          color: 255U,
          auto_color: true,
          shading: 0U,
          has_shading: false,
          underline_color: 0U,
          has_underline_color: false,
          highlight: "",
          underline: "none",
          vertical_align: "",
          position: 0.0000000000000000,
          spacing: 0.0000000000000000,
          scale: 1.0000000000000000,
          emphasis: "",
          languages: ["en-US", "", ""],
          web_hidden: false,
          rtl: false,
          tcy: false,
          tcy_fit: false,
        },
        [
          (
            "char",
            "H",
            false,
            {
              fonts: ["Base", "Times New Roman", "", "Times New Roman"],
              themes: ["", "", "", ""],
              hint: "",
              toggles: 2,
              specified: 0,
              size: 10.000000000000000,
              color: 255U,
              auto_color: true,
              shading: 0U,
              has_shading: false,
              underline_color: 0U,
              has_underline_color: false,
              highlight: "",
              underline: "none",
              vertical_align: "",
              position: 0.0000000000000000,
              spacing: 0.0000000000000000,
              scale: 1.0000000000000000,
              emphasis: "",
              languages: ["en-US", "", ""],
              web_hidden: false,
              rtl: false,
              tcy: false,
              tcy_fit: false,
            },
          ),
          (
            "char",
            "i",
            false,
            {
              fonts: ["Base", "Times New Roman", "", "Times New Roman"],
              themes: ["", "", "", ""],
              hint: "",
              toggles: 2,
              specified: 0,
              size: 10.000000000000000,
              color: 255U,
              auto_color: true,
              shading: 0U,
              has_shading: false,
              underline_color: 0U,
              has_underline_color: false,
              highlight: "",
              underline: "none",
              vertical_align: "",
              position: 0.0000000000000000,
              spacing: 0.0000000000000000,
              scale: 1.0000000000000000,
              emphasis: "",
              languages: ["en-US", "", ""],
              web_hidden: false,
              rtl: false,
              tcy: false,
              tcy_fit: false,
            },
          ),
          (
            "tab",
            "\t",
            false,
            {
              fonts: ["Base", "Times New Roman", "", "Times New Roman"],
              themes: ["", "", "", ""],
              hint: "",
              toggles: 2,
              specified: 0,
              size: 10.000000000000000,
              color: 255U,
              auto_color: true,
              shading: 0U,
              has_shading: false,
              underline_color: 0U,
              has_underline_color: false,
              highlight: "",
              underline: "none",
              vertical_align: "",
              position: 0.0000000000000000,
              spacing: 0.0000000000000000,
              scale: 1.0000000000000000,
              emphasis: "",
              languages: ["en-US", "", ""],
              web_hidden: false,
              rtl: false,
              tcy: false,
              tcy_fit: false,
            },
          ),
          (
            "char",
            "A",
            false,
            {
              fonts: ["Base", "Times New Roman", "", "Times New Roman"],
              themes: ["", "", "", ""],
              hint: "",
              toggles: 3,
              specified: 0,
              size: 14.000000000000000,
              color: 255U,
              auto_color: true,
              shading: 0U,
              has_shading: false,
              underline_color: 0U,
              has_underline_color: false,
              highlight: "",
              underline: "none",
              vertical_align: "",
              position: 0.0000000000000000,
              spacing: 0.0000000000000000,
              scale: 1.0000000000000000,
              emphasis: "",
              languages: ["en-US", "", ""],
              web_hidden: false,
              rtl: false,
              tcy: false,
              tcy_fit: false,
            },
          ),
          (
            "break",
            "\n",
            false,
            {
              fonts: ["Base", "Times New Roman", "", "Times New Roman"],
              themes: ["", "", "", ""],
              hint: "",
              toggles: 3,
              specified: 0,
              size: 14.000000000000000,
              color: 255U,
              auto_color: true,
              shading: 0U,
              has_shading: false,
              underline_color: 0U,
              has_underline_color: false,
              highlight: "",
              underline: "none",
              vertical_align: "",
              position: 0.0000000000000000,
              spacing: 0.0000000000000000,
              scale: 1.0000000000000000,
              emphasis: "",
              languages: ["en-US", "", ""],
              web_hidden: false,
              rtl: false,
              tcy: false,
              tcy_fit: false,
            },
          ),
        ],
      ),
      (
        0,
        "left",
        0.0000000000000000,
        5.0000000000000000,
        0.0000000000000000,
        {
          fonts: ["Base", "Times New Roman", "", "Times New Roman"],
          themes: ["", "", "", ""],
          hint: "",
          toggles: 0,
          specified: 0,
          size: 10.000000000000000,
          color: 255U,
          auto_color: true,
          shading: 0U,
          has_shading: false,
          underline_color: 0U,
          has_underline_color: false,
          highlight: "",
          underline: "none",
          vertical_align: "",
          position: 0.0000000000000000,
          spacing: 0.0000000000000000,
          scale: 1.0000000000000000,
          emphasis: "",
          languages: ["en-US", "", ""],
          web_hidden: false,
          rtl: false,
          tcy: false,
          tcy_fit: false,
        },
        [],
      ),
    ],
  )
}

///|
test "DOCX styled text matches upstream Go 1" {
  check_docx_styled_text(
    [
      "H4sIAAAAAAAA/4TTe0xTdxQH8FNKWx7F8ujWMVB0Y9koIFCFugwafGxg2ZCNQqibVoQis7zv7aDKKJs4R1faiJ2FjeADZ7I2FIFFIozH2jK2jlIkxIlYwSXoFKGYkq5TGQvXkHaNw5uT+8+9v5N8zu970lLw7lTwAA9wfbwBgFfGL0CiNq+8pSMJ67TRZMK0ehcrcV9M9NnLAd7h9wnnx5f8SoMHNdQikzbNF289+ujW7Dy1t7AeNXd0G2I+pqi5fRsPZ9X2xtWHZcg6qbaLdQpCJ4XS79t8wyadyR9YyO6eHNeF4m7ahxcpkdYfCd3s6431S1n2w9VBn3J/OeLR8010quXs98G4E+vkYrTCB9JSSB5jkvC9EgCwAsD/EzYAQI4QQYsLo55KcotzhIX8InRzRWHBU5URUyXeVnMcqj/cMkvEu4KT2k+OTb6q/yCU+HNXZVt/WSgvdqIjT6DS5+Ij5v+uyc/O3iSIRVT+r0fuKGo9HbjlOMkoPaF56+BEUHRVo3GGVb0dmWQs42e3tn5merlZ+6vYnt/3dtVXnDwbjmXOrK3OkT++UteGwzzqknJrDQBMr+kJcHicJfGy9lR8DPkL3oyClE8nEtVKz4aTWQfeRS7SwmQt1wd7u5Ku7FBalEuznZWMrG37PNWpTHrGQF6XKm5h/5iEOjPgM1tnYJZL6KR5WvFN5bU3zyVraPR/7lVU2qiI8HZuyR1+0ATxkeyvo5V/ZpYw7LX8T9rGr73BbZrqYWrop7YrFNYH+8uGLrRYKTzd3YatZNuQ0IcnFhxDzpBRwbaeF6PsFss7k6LlkaCIJk1Nhs6CodN9BuU/AAARtxbaz4FGUFEBH1khX5Ab2fpE8hDvu2Gz8f5PukvpvpzRY4svHPx2TjpM2316oq8XbSVxE0S7N4b0hyzv7DyfEnpvJCyv3RjYtjeyWtrsb9BwDHep8uMBqgdeplGvPV//lvzKJlOY1lwlpnjujFtiXhJkKtkjnNym",
      "QDXTfPlIY5Pow9LS9e+h+nTOoaIoU/zCjVvZrU8+6mD/HmF46fMteAY/djTkQE9NnWhufQJDxn6ie6xQJXmWzXnRcvTx5UZ/CSs58RBr4Y7QLn/4MHxq6v09/dpz3Kuv1S+ewWMhmDYndF8FgBZsHjg3Kjgm4hx4b5cJ/WdPXQ86J2vD6v9Y6Z67Ha69nC8sYLUNVqdwz0ymawNnod/qWay+dHvGLaelEIgrH93BHQg4gAY8AMC/AwAxqjclswQAAA==",
    ],
    [
      (
        0,
        "left",
        0.0000000000000000,
        0.0000000000000000,
        0.0000000000000000,
        {
          fonts: ["Parent", "Times New Roman", "", "Times New Roman"],
          themes: ["", "", "", ""],
          hint: "",
          toggles: 1,
          specified: 0,
          size: 10.000000000000000,
          color: 255U,
          auto_color: true,
          shading: 0U,
          has_shading: false,
          underline_color: 0U,
          has_underline_color: false,
          highlight: "",
          underline: "single",
          vertical_align: "",
          position: 0.0000000000000000,
          spacing: 0.0000000000000000,
          scale: 1.0000000000000000,
          emphasis: "",
          languages: ["", "", ""],
          web_hidden: false,
          rtl: false,
          tcy: false,
          tcy_fit: false,
        },
        [
          (
            "char",
            "X",
            false,
            {
              fonts: ["Direct", "Times New Roman", "", "Times New Roman"],
              themes: ["", "", "", ""],
              hint: "",
              toggles: 2,
              specified: 0,
              size: 10.000000000000000,
              color: 255U,
              auto_color: true,
              shading: 0U,
              has_shading: false,
              underline_color: 0U,
              has_underline_color: false,
              highlight: "",
              underline: "none",
              vertical_align: "",
              position: 0.0000000000000000,
              spacing: 0.0000000000000000,
              scale: 1.0000000000000000,
              emphasis: "",
              languages: ["", "ja-JP", ""],
              web_hidden: false,
              rtl: false,
              tcy: false,
              tcy_fit: false,
            },
          ),
          (
            "char",
            "Y",
            false,
            {
              fonts: ["Parent", "Times New Roman", "", "Times New Roman"],
              themes: ["", "", "", ""],
              hint: "",
              toggles: 1,
              specified: 0,
              size: 10.000000000000000,
              color: 255U,
              auto_color: true,
              shading: 0U,
              has_shading: false,
              underline_color: 0U,
              has_underline_color: false,
              highlight: "",
              underline: "single",
              vertical_align: "",
              position: 0.0000000000000000,
              spacing: 0.0000000000000000,
              scale: 1.0000000000000000,
              emphasis: "",
              languages: ["", "", ""],
              web_hidden: false,
              rtl: false,
              tcy: false,
              tcy_fit: false,
            },
          ),
          (
            "page",
            "",
            false,
            {
              fonts: ["Parent", "Times New Roman", "", "Times New Roman"],
              themes: ["", "", "", ""],
              hint: "",
              toggles: 1,
              specified: 0,
              size: 10.000000000000000,
              color: 255U,
              auto_color: true,
              shading: 0U,
              has_shading: false,
              underline_color: 0U,
              has_underline_color: false,
              highlight: "",
              underline: "single",
              vertical_align: "",
              position: 0.0000000000000000,
              spacing: 0.0000000000000000,
              scale: 1.0000000000000000,
              emphasis: "",
              languages: ["", "", ""],
              web_hidden: false,
              rtl: false,
              tcy: false,
              tcy_fit: false,
            },
          ),
        ],
      ),
    ],
  )
}

///|
test "DOCX document text rejects unsupported settings" {
  reject_docx_document_text([
    "H4sIAAAAAAAA/4ySXUhTYRjHnzM9neWWR9kuktSJ1IWpO0cvjMYcUd3YKmZgqaCx5kmP7JyzznnXWYq1i8ASM5CyDzIkLLJFREIXlhWOvsMwvMhmZR9SlmSimAiy2HTtOJJ6eXhf3q/f8/yf57FZ4+L1oAY1xA4NAOwVGadEGUNzc39hYh+txUd8Wy2bKvLojts6TfY3/NLgfPKB1Ic39PzLPltS3FT93LvvP/S9XCt6e6vnWR5L+sruZdSWHu8taM0qaenWz1w5cQrvJsn7SRffzDSP1jz4ae8JDPrXYsOzL6bJ3Km7eM+21+da50tna71rGsqe1KnvnKd3TnR0pWKNiSePIM8qsFkJ9aum7PImAJgCgOUlpAOAwy0hgaMWlFQJDjfH8Mjo4ZyLqvKu+Wmt94NvdVpGguDZUpTvHisXsU/rW7qYFCv+a6Y9IQt9nSMNQXR5PLdooLDE3S4NpBzsrts8eFNXn9a5a+zCBnZ8B8Em+0jZsDL4aNIQGPCO+tGZgDZteO76tCYn0KZqX2c+29QwWfw05/TVkd3vM4e0E/mo3/v86GOsojIObFZCPbTHUNwIAJ8BYPmq6KKSlGJAhmNBs2yKnGV4OCcvmeTCzBqEXCaKkhw1DGeXjIKL4T2cc78gcnYkGQWxmpIFscolCg5Gkli+mnNS+TRdQHF2ls+0mGXTPqHqUGh1URYzFdlSUVeWhfA3dvEfDwOA/L/hSwxCLF8thcMnYDZoFgUBUYu45Mov2xMBgAjjMJUeokBl8TUxDpb0bOxHZYrTI+/D5v9np8SylHp1EUzY2rA/LCUlFqBUuBRQovprkmxWfEXoOh7igcAAOlUAAL8HAN5svp/BAwAA",
  ])
}

///|
test "DOCX document text rejects unsupported numbering" {
  reject_docx_document_text([
    "H4sIAAAAAAAA/4SSb0gTfxzHP5vebwN1Uzzkh5mIWCDS3S1CaMzVg57UxPYgRS2LOc9tsrtbdye3NP8Eocs0SZRQMJyBJYKQgx6sLJkFYmGQBqYWaaRQLMulDEEWu1y7Rtnx4Y77831936/PfYyGuHgUlKCE2CMBAC6wpJ3DsfC5faZA5SMSkfcjJ/THKzTEwIPUhLxPyODcTsrFjGejKP3SZ0yOC9Rvv/v8BR2nuvi3Y95pjU09UvY4q6b02nh+V27xDQ+6NdTRjXjU6ifJtxe22j9aJ76avItzkzmypeCL7+pDgUeI99R8b9dOabCmeV9D2VSd8mEfUbQ+MJwha1V1NvHOJDAaFMpXbXnlbQAQAIC/K2QCgLmW4xkK/2lSxZhrKZLmMSdl37XSjPqIxOZl0Wp8Oeme/6mvre5K8lJOdtHgfI/P/8Z48//S0PLssYrcso4DBldx4Vo32TJQftq1Ir/f4z4z3T9bkn62x32k87W3dfNq04dgp986sWHqe97QoqpuKNlGsMW0/f3XF3vHGr9p1i/fSfMoPAurJy3Ou25Ofu6gDpvaSBedZurdmy4AWN3TKTXqJLUBAVwhnaCNPMtyUnaa0woF2Vaed2hxnDNbScrEYYyDpJ2UvZphKRPPYQxrwQWGrXKwjJnkOBttoez4YYLIxymTjc7W6wRtJVN1KXx14HodHrnFo1vp48T4R4fplUYAEPaMj0bj07VUJcnaaIuYXwHBkI5lGB7f5aWcXytUAYBC5MnkKESJ0t+fELPDb1Mbu1Da48zI92JN/nNWYllS4dQIRqxbsl8sKSUWIDVEI2vFKpH/uUtGA/Jf+H08xINSBjAkBwD4MQBblINAxAMAAA==",
  ])
}

///|
test "DOCX document text rejects unsupported footnotes" {
  reject_docx_document_text([
    "H4sIAAAAAAAA/4SSb0gTYRzHf1PnFtPN4b0wEhHphSLtmUFSY65eSEGLGpmikcacp5vsuWfdPXJLMw1ESzRRwihCLCoSQ1ChF8uVbAZRUVC+6J+mRVmWFRkyBDO8XLtG2fHjjvvzfJ7v53c/mzU2jgE1qCH60ADAYZ51C8iwcm57mKcNGBOUU/35lh2lOcbeG8ma7FnlpfEl/ZHUOwMM9yhgS4qdr1uc/PiZ8eMuOjHku5fj0vWX3EqvLj7lz+3KKjw9zCxcbT+jHNbpbif1PF9oe+sc/Wr3vRgPblS8DD34rts0P6L07X56rmupOFTduKG+5G6t+uZ5494vvX2pihZtRwP1JoLNqlI/bs0+2AoA8wDwb4U0AHDUCJRg9MukgjhqMMtRgxe7V61yBgLGhMZpyco/nXhtbizQWnsicyvOT9012BmYe2brTClenn6yvTSrzrqf7issnTlEmyeu9yRt+TRWpuo7YJrJbPd/SMfB2eAEaWp4E+qYc45+s/vu42YtV1+0qOxOKegdblIVDCLLTn12+eWpole5Q+snXe8vKM6u69D4RuIlpWP6HxdbAODdmkrJESW5DIhwctksmsLP0r3YzQkmMS/DSanHhJDgcLLYLhiIh+W82F1JeGyngoHwVUgkfIWHJw5WEFxcFXajzUZjLsJ2F5dhMYumclJxdOXqQRYzCt+iyFaWWCn+tj7u9XEAENeMz0TiVxJCOUJZQcqvgtCymSeEolWevmxmjxYAVBJPEcNAhCj/+5qoHf4Y2uiF8h6nhb+XKvjfUYlmyYWTwxipuhW/WXJKNEBuyITXSlUY8/cu2azK+JX3cRAHagXAlRgAgJ8DAHWIDmjDAwAA",
  ])
}

///|
test "DOCX document text rejects unsupported endnotes" {
  reject_docx_document_text([
    "H4sIAAAAAAAA/4ySfUgTYRjAn3POrVbO4VFQ4leBlLj3DFKc8ygIIg0ZlTiLkrmdX+3u1t3ZXfblH9GHaIVWUH+IlAliRTmImM1yElREQQ0Jy1Ap7IPK0HQVZuxy7Rx9HQ933N37/p7n97yPpUAVjYMWtBB56QCglKOcPDIG7w0P82J9xAL1UOc6cs32TKL1erwu/a36vH/asCvhzhWceeSzxKnG93598e4D7qWbhMEuz/3MKn1nSU9ytfWYN6tpRdFxNz7Z3nhK7dbrb8W1DEw2vKq8PWbzPPP3LceeBx5M6DPGb6o9+U/PNk1bA9V1S/eX3K3Vdp8jCj+2diRgR2JPHBSkhWAp0Ggf16dvrQeAcQD4s0IiANhreIGl0U8TB2uvoSlGMEq0c9bq2nwfEVc3XDxvCrwjQ8l02uLiN7pDEwMxzd0nc1N6vM2W3t7PSeT34cJ72/D+vEU1GWn9ht1ubq3/6ubJgQ0pTM7lTe7s922MdZ8UaBzzT1VcWq9qR08GzxiW3PhS9DrJ2r86xpMvlZd9G172yVfWNlRemt1lIC/uzMEKVYkaoVYvG43mtqw8DAAv/2oUHzZSuoAIR2fMoin0LVminQxvEvNSKwXBZUKIt1dStI03si6KkWhnOcvRNoE3slwFElnO4eJYO8XzVUwF7USrCCIL0bYqJpU0i6Yy1rEn+HQh0oxCryicilTJ5ed0MCMHAED83/IpxsGwAsXL5WsgMGPmWFZAszjDjtGNsQCgkXFYFA5hoPLsdREJ5oxs5EZlixND6+Xo++egRLKUvvEhjBynsV8sJSUSoDScC9gS9dsmWQrUMcHf0RANGgzgQhQAwI8BAJTxotDAAwAA",
  ])
}

///|
test "DOCX document text rejects unsupported styles" {
  reject_docx_document_text([
    "H4sIAAAAAAAA/4STfUxydRTHzxV5pNkDkrRWD7nnMcucyUVTV4RMm80mvZAzE2cqAgrCvZe41wH5njrDJJezNvrDudYsJWXqqqn5EmIrxdzMP/J16OY/WWajCGtm4zoGsbK7s3t37/2d7+98zvf8ZFJGLA9YwILoKx4Aqo1qPYkKgve+b/PYLuHdTK+jUJL/aqZw+LPE+PQfmB9sXXBf469M8PANlyyB4Wv64+DklDePDVD7U7OrmVqOQ75wu6HcOp87kPby29M8/4htkDnN4SwmDO34+441S2eK2d2t5RRkL+D5lZPh+4I5W/y9feCiPNDQfqtF/vXrrLn3hS/8PDzKR3rY/W2U+SbIpHGszd70il4A8AHAfyMkAoCykaQIDFURykZMjVMCM6YHE7x5KTaJQt9umzE9TopMeckaijKIUJRUatSYghQQBjVuxvR1hBFTUKSAMNajJsKoMhgJpZoktXg9pkezhMJcFFNo8WSJ2CSqJVSW4NOASsRo6BUNbyVh0OU/OYoftQKA6dryk8LlXxkRUglCXJmyTpuSf+goDZtyFFNmaCvkF02+s7n7kLsk5cZXnzc7F40p1TnbU3W6MbeK8djpeZdGobijyyHH7knNeBoff+/+x7vj1vt6Jp6q3b4lbLWvH0vaC8jdrEvGSfZ4x8YDQ65v2gKahWda3yqt8yOS/TJru7L/zxmbE6F5HAaTrwsAvNfycMM8JGXRq8kgR6Xn+d4uYcLKL45n2TXdck+y+xP3b5V33AHk3cEPV9PmW77zjjSde3//q+rBNZt9zlGj/qhzu5Adt6Rde9j4YtHEK192V1hdeZ/eO7jTnF1stzh1BYFJ/33Fe467qvaf03qk4peeMDf+5LRZrKmr0wePcEtOti6K+J5suW68w3uInFk6nY9+rJzJJM03aRbuj/2kDQCWaBYkhgdhmsixi4+i+8dpiU6MNDwxtJ6O5XBTIu2NFojscFIol443kP+bkmitSEJuSIaO",
    "kph/cUgmZd4I/oyFWGAiAEkMAIC/BwCFA5RyOQQAAA==",
  ])
}
