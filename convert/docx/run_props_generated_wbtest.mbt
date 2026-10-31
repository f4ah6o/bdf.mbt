///|
test "DOCX run properties match upstream Go 0" {
  check_docx_run_props(["<rPr/>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 1" {
  check_docx_run_props(
    [
      "<rPr><b/><i val=\"false\"/><caps val=\"on\"/><smallCaps/><strike val=\"0\"/><dstrike/><vanish val=\"off\"/><outline/><shadow/><emboss/><imprint/></rPr>",
    ],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 1965,
      specified: 2047,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 2" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Alpha\" hAnsi=\"Beta\" eastAsia=\"Gamma\" cs=\"Delta\" hint=\"eastAsia\" asciiTheme=\"majorAscii\" hAnsiTheme=\"minorHAnsi\" eastAsiaTheme=\"minorEastAsia\" cstheme=\"majorBidi\"/><sz val=\"22\"/><position val=\"3\"/><spacing val=\"40\"/><w val=\"85\"/><vertAlign val=\"superscript\"/><u/><highlight val=\"yellow\"/><em val=\"dot\"/><lang val=\"en-US\" eastAsia=\"ja-JP\" bidi=\"ar-SA\"/><rtl/><webHidden/><eastAsianLayout vert=\"1\" vertCompress=\"true\"/></rPr>",
    ],
    {
      fonts: ["Alpha", "Beta", "Gamma", "Delta"],
      themes: ["majorAscii", "minorHAnsi", "minorEastAsia", "majorBidi"],
      hint: "eastAsia",
      toggles: 0,
      specified: 0,
      size: 11.000000000000000,
      color: 255U,
      auto_color: true,
      shading: 0U,
      has_shading: false,
      underline_color: 0U,
      has_underline_color: false,
      highlight: "yellow",
      underline: "single",
      vertical_align: "superscript",
      position: 1.5000000000000000,
      spacing: 2.0000000000000000,
      scale: 0.84999999999999998,
      emphasis: "dot",
      languages: ["en-US", "ja-JP", "ar-SA"],
      web_hidden: true,
      rtl: true,
      tcy: true,
      tcy_fit: true,
    },
  )
}

///|
test "DOCX run properties match upstream Go 3" {
  check_docx_run_props(
    [
      "<rPr><b/><i/><sz val=\"20\"/><rFonts asciiTheme=\"minorAscii\" hAnsiTheme=\"minorHAnsi\"/><lang val=\"en\"/><w val=\"120\"/></rPr>",
      "<rPr><b val=\"0\"/><i val=\"garbage\"/><sz val=\"0\"/><rFonts ascii=\"Local\" eastAsia=\"日本語\" hAnsi=\"\"/><lang eastAsia=\"ja\"/><w val=\"0\"/><position val=\"-5\"/></rPr>",
    ],
    {
      fonts: ["Local", "", "日本語", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 3,
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
      position: -2.5000000000000000,
      spacing: 0.0000000000000000,
      scale: 1.2000000000000000,
      emphasis: "",
      languages: ["en", "ja", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 4" {
  check_docx_run_props(
    [
      "<rPr><sz val=\"bad\"/><w val=\"bad\"/><spacing val=\"2cm\"/><u val=\"double\"/><eastAsianLayout vert=\"bad\" vertCompress=\"on\" combine=\"false\"/></rPr>",
      "<rPr><spacing val=\"garbage\"/><u val=\"none\"/><lang bidi=\"he-IL\"/><webHidden val=\"off\"/></rPr>",
    ],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      languages: ["", "", "he-IL"],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: true,
    },
  )
}

///|
test "DOCX run properties match upstream Go 5" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 6" {
  check_docx_run_props(["<rPr><i></i></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 2,
    specified: 2,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 7" {
  check_docx_run_props(["<rPr><u val=\"single\"></u></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
  })
}

///|
test "DOCX run properties match upstream Go 8" {
  check_docx_run_props(["<rPr><u val=\"double\"></u></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
    underline: "double",
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
  })
}

///|
test "DOCX run properties match upstream Go 9" {
  check_docx_run_props(["<rPr><strike></strike></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 16,
    specified: 16,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 10" {
  check_docx_run_props(["<rPr><highlight val=\"yellow\"></highlight></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
    highlight: "yellow",
    underline: "none",
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
  })
}

///|
test "DOCX run properties match upstream Go 11" {
  check_docx_run_props(["<rPr><smallCaps></smallCaps></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 8,
    specified: 8,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 12" {
  check_docx_run_props(
    ["<rPr><vertAlign val=\"superscript\"></vertAlign></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      vertical_align: "superscript",
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
  )
}

///|
test "DOCX run properties match upstream Go 13" {
  check_docx_run_props(
    ["<rPr><vertAlign val=\"subscript\"></vertAlign></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      vertical_align: "subscript",
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
  )
}

///|
test "DOCX run properties match upstream Go 14" {
  check_docx_run_props(["<rPr><em val=\"dot\"></em></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
    emphasis: "dot",
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 15" {
  check_docx_run_props(["<rPr><b></b><sz val=\"24\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
    size: 12.000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 16" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 17" {
  check_docx_run_props(
    ["<rPr><vertAlign val=\"superscript\"></vertAlign></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      vertical_align: "superscript",
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
  )
}

///|
test "DOCX run properties match upstream Go 18" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 19" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 20" {
  check_docx_run_props(["<rPr><b></b><sz val=\"32\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
    size: 16.000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 21" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 22" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 23" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 24" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 25" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 26" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 27" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 28" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 29" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 30" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 31" {
  check_docx_run_props(["<rPr><b></b><sz val=\"24\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
    size: 12.000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 32" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 33" {
  check_docx_run_props(
    ["<rPr><vertAlign val=\"superscript\"></vertAlign></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      vertical_align: "superscript",
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
  )
}

///|
test "DOCX run properties match upstream Go 34" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 35" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 36" {
  check_docx_run_props(["<rPr><b></b><sz val=\"28\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 37" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 38" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 39" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 40" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 41" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 42" {
  check_docx_run_props(["<rPr><b></b><sz val=\"24\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
    size: 12.000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 43" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 44" {
  check_docx_run_props(
    ["<rPr><vertAlign val=\"superscript\"></vertAlign></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      vertical_align: "superscript",
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
  )
}

///|
test "DOCX run properties match upstream Go 45" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 46" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 47" {
  check_docx_run_props(["<rPr><b></b><sz val=\"28\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 48" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 49" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 50" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 51" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 52" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 53" {
  check_docx_run_props(["<rPr><b></b><sz val=\"24\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
    size: 12.000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 54" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 55" {
  check_docx_run_props(
    ["<rPr><vertAlign val=\"superscript\"></vertAlign></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      vertical_align: "superscript",
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
  )
}

///|
test "DOCX run properties match upstream Go 56" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 57" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 58" {
  check_docx_run_props(["<rPr><b></b><sz val=\"28\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 59" {
  check_docx_run_props(["<rPr><b></b><sz val=\"24\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
    size: 12.000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 60" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 61" {
  check_docx_run_props(
    ["<rPr><vertAlign val=\"superscript\"></vertAlign></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      vertical_align: "superscript",
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
  )
}

///|
test "DOCX run properties match upstream Go 62" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 63" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 64" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 65" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 66" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 67" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 68" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 69" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 70" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 71" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 72" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 73" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 74" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 75" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 76" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 77" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 78" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 79" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 80" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 81" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 82" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 83" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 84" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 85" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 86" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 87" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 88" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 89" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 90" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 91" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 92" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 93" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 94" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 95" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 96" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 97" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 98" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 99" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 100" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 101" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 102" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 103" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 104" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 105" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 106" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 107" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 108" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 109" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 110" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 111" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 112" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 113" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 114" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 115" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 116" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 117" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 118" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 119" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 120" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 121" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 122" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 123" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 124" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 125" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 126" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 127" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 128" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 129" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 130" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 131" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 132" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 133" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 134" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 135" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 136" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 137" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 138" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 139" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 140" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 141" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 142" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 143" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 144" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 145" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 146" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 147" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 148" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 149" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 150" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 151" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 152" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 153" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 154" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 155" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 156" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 157" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 158" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 159" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 160" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 161" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 162" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 163" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 164" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 165" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 166" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 167" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 168" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 169" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 170" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 171" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 172" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 173" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 174" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 175" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 176" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 177" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 178" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 179" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 180" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 181" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 182" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 183" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 184" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 185" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 186" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 187" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 188" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 189" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 190" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 191" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 192" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 193" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 194" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 195" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 196" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 197" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 198" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 199" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 200" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 201" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 202" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 203" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 204" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 205" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 206" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 207" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 208" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 209" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 210" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 211" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 212" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 213" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 214" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 215" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 216" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 217" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 218" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 219" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 220" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 221" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 222" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 223" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 224" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 225" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 226" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 227" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 228" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 229" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 230" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 231" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 232" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 233" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 234" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 235" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 236" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 237" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 238" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 239" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 240" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 241" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 242" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 243" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 244" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 245" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 246" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 247" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 248" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 249" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 250" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 251" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 252" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 253" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 254" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 255" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 256" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 257" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 258" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 259" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 260" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 261" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 262" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 263" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 264" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 265" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 266" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 267" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 268" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 269" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 270" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 271" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 272" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 273" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 274" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 275" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 276" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 277" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 278" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 279" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 280" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 281" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 282" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 283" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 284" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 285" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 286" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 287" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 288" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 289" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 290" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 291" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 292" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 293" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 294" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 295" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 296" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 297" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 298" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 299" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 300" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 301" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 302" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 303" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 304" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 305" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 306" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts><i></i></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
      themes: ["", "", "", ""],
      hint: "",
      toggles: 2,
      specified: 2,
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 307" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 308" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 309" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Cambria Math\" hAnsi=\"Cambria Math\"></rFonts></rPr>",
    ],
    {
      fonts: ["Cambria Math", "Cambria Math", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 310" {
  check_docx_run_props(["<rPr><b></b><sz val=\"24\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
    size: 12.000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 311" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 312" {
  check_docx_run_props(
    ["<rPr><vertAlign val=\"superscript\"></vertAlign></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      vertical_align: "superscript",
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
  )
}

///|
test "DOCX run properties match upstream Go 313" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 314" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 315" {
  check_docx_run_props(["<rPr><b></b><sz val=\"28\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 316" {
  check_docx_run_props(["<rPr><b></b><sz val=\"24\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
    size: 12.000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 317" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 318" {
  check_docx_run_props(
    ["<rPr><vertAlign val=\"superscript\"></vertAlign></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      vertical_align: "superscript",
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
  )
}

///|
test "DOCX run properties match upstream Go 319" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 320" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 321" {
  check_docx_run_props(
    [
      "<rPr><rFonts ascii=\"Courier New\" hAnsi=\"Courier New\"></rFonts><sz val=\"20\"></sz></rPr>",
    ],
    {
      fonts: ["Courier New", "Courier New", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: false,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 322" {
  check_docx_run_props(["<rPr><em val=\"comma\"></em></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
    emphasis: "comma",
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 323" {
  check_docx_run_props(["<rPr><u val=\"single\"></u></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
  })
}

///|
test "DOCX run properties match upstream Go 324" {
  check_docx_run_props(
    ["<rPr><eastAsianLayout id=\"1\" vert=\"1\"></eastAsianLayout></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: true,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 325" {
  check_docx_run_props(
    ["<rPr><eastAsianLayout id=\"1\" vert=\"1\"></eastAsianLayout></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: true,
      tcy_fit: false,
    },
  )
}

///|
test "DOCX run properties match upstream Go 326" {
  check_docx_run_props(
    [
      "<rPr><eastAsianLayout id=\"2\" vert=\"1\" vertCompress=\"1\"></eastAsianLayout></rPr>",
    ],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      languages: ["", "", ""],
      web_hidden: false,
      rtl: false,
      tcy: true,
      tcy_fit: true,
    },
  )
}

///|
test "DOCX run properties match upstream Go 327" {
  check_docx_run_props(["<rPr><b></b><sz val=\"24\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
    size: 12.000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 328" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 329" {
  check_docx_run_props(
    ["<rPr><vertAlign val=\"superscript\"></vertAlign></rPr>"],
    {
      fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
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
      vertical_align: "superscript",
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
  )
}

///|
test "DOCX run properties match upstream Go 330" {
  check_docx_run_props(["<rPr><b></b></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 1,
    specified: 1,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}

///|
test "DOCX run properties match upstream Go 331" {
  check_docx_run_props(["<rPr><sz val=\"18\"></sz></rPr>"], {
    fonts: ["Times New Roman", "Times New Roman", "", "Times New Roman"],
    themes: ["", "", "", ""],
    hint: "",
    toggles: 0,
    specified: 0,
    size: 9.0000000000000000,
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
    languages: ["", "", ""],
    web_hidden: false,
    rtl: false,
    tcy: false,
    tcy_fit: false,
  })
}
