///|
// Generated from shibukawa/bdf internal/fontdb/resolve.go (MIT).
let ja_gothic : Array[String] = [
  "Noto Sans CJK JP", "Noto Sans JP", "Source Han Sans JP", "IPAexGothic", "IPAPGothic",
  "IPAGothic", "TakaoPGothic", "VL PGothic", "M PLUS 1p", "Hiragino Sans", "Yu Gothic",
  "Meiryo", "WenQuanYi Zen Hei",
]

///|
let ja_gothic_mono : Array[String] = [
  "IPAGothic", "TakaoGothic", "VL Gothic", "Noto Sans Mono CJK JP", "MS Gothic",
  "Noto Sans CJK JP", "IPAexGothic", "WenQuanYi Zen Hei Mono",
]

///|
let ja_mincho : Array[String] = [
  "Noto Serif CJK JP", "Noto Serif JP", "Source Han Serif JP", "IPAexMincho", "IPAPMincho",
  "IPAMincho", "TakaoPMincho", "Hiragino Mincho ProN", "Yu Mincho",
]

///|
let ja_mincho_mono : Array[String] = [
  "IPAMincho", "TakaoMincho", "MS Mincho", "Noto Serif CJK JP", "IPAexMincho",
]

///|
let zh_hans : Array[String] = [
  "Noto Sans CJK SC", "Noto Sans SC", "Source Han Sans SC", "WenQuanYi Zen Hei",
  "WenQuanYi Micro Hei", "Microsoft YaHei", "PingFang SC",
]

///|
let zh_hans_serif : Array[String] = [
  "Noto Serif CJK SC", "Noto Serif SC", "Source Han Serif SC", "AR PL UMing CN",
  "SimSun",
]

///|
let zh_hant : Array[String] = [
  "Noto Sans CJK TC", "Noto Sans TC", "Source Han Sans TC", "WenQuanYi Zen Hei",
  "Microsoft JhengHei", "PingFang TC",
]

///|
let zh_hant_serif : Array[String] = [
  "Noto Serif CJK TC", "Noto Serif TC", "AR PL UMing TW", "PMingLiU",
]

///|
let ko_gothic : Array[String] = [
  "Noto Sans CJK KR", "Noto Sans KR", "Source Han Sans KR", "NanumGothic", "UnDotum",
  "Malgun Gothic",
]

///|
let ko_serif : Array[String] = [
  "Noto Serif CJK KR", "Noto Serif KR", "NanumMyeongjo", "UnBatang", "Batang",
]

///|
let generic_symbols : Array[String] = [
  "DejaVu Sans", "Noto Sans Symbols", "Noto Sans Symbols2", "Segoe UI Symbol", "OpenSymbol",
  "FreeSerif", "FreeSans", "Arial Unicode MS", "Noto Color Emoji", "Unifont",
]

///|
let math_families : Array[String] = [
  "Cambria Math", "STIX Two Math", "XITS Math", "STIX Math", "Latin Modern Math",
  "Libertinus Math", "TeX Gyre Termes Math", "TeX Gyre Pagella Math", "TeX Gyre Bonum Math",
  "TeX Gyre Schola Math", "DejaVu Math TeX Gyre", "New Computer Modern Math", "Noto Sans Math",
  "Fira Math", "Asana Math", "Garamond-Math",
]

///|
fn substitutes(name : String) -> Array[String] {
  match name {
    "calibri" => ["Carlito"]
    "calibrilight" => ["Carlito"]
    "cambria" => ["Caladea"]
    "cambriamath" => ["Caladea"]
    "arial" => ["Liberation Sans", "Arimo", "Helvetica", "Helvetica Neue"]
    "helvetica" => ["Liberation Sans", "Arimo", "Arial", "Helvetica Neue"]
    "helveticaneue" => ["Liberation Sans", "Arimo", "Helvetica", "Arial"]
    "arialnarrow" => ["Liberation Sans Narrow"]
    "timesnewroman" => ["Liberation Serif", "Tinos", "Times"]
    "times" => ["Liberation Serif", "Tinos", "Times New Roman"]
    "couriernew" => ["Liberation Mono", "Cousine", "Courier"]
    "courier" => ["Liberation Mono", "Cousine", "Courier New"]
    "georgia" => ["Gelasio"]
    "symbol" => ["OpenSymbol", "Standard Symbols PS"]
    "wingdings" => ["OpenSymbol"]
    "segoeuisymbol" =>
      ["Noto Sans Symbols", "Noto Sans Symbols2", "DejaVu Sans"]
    "segoeuiemoji" => ["Noto Color Emoji"]
    "meiryo" => ja_gothic
    "メイリオ" => ja_gothic
    "meiryoui" => ja_gothic
    "yugothic" => ja_gothic
    "游ゴシック" => ja_gothic
    "yugothicui" => ja_gothic
    "yugothicmedium" => ja_gothic
    "游ゴシックmedium" => ja_gothic
    "游ゴシックlight" => ja_gothic
    "mspgothic" => ja_gothic
    "mspゴシック" => ja_gothic
    "msuigothic" => ja_gothic
    "hiraginosans" => ja_gothic
    "ヒラギノ角ゴpron" => ja_gothic
    "ヒラギノ角ゴシック" => ja_gothic
    "msgothic" => ja_gothic_mono
    "msゴシック" => ja_gothic_mono
    "yumincho" => ja_mincho
    "游明朝" => ja_mincho
    "mspmincho" => ja_mincho
    "msp明朝" => ja_mincho
    "msmincho" => ja_mincho_mono
    "ms明朝" => ja_mincho_mono
    "hiraginomincho" => ja_mincho
    "ヒラギノ明朝pron" => ja_mincho
    "microsoftyahei" => zh_hans
    "微软雅黑" => zh_hans
    "simsun" => zh_hans_serif
    "宋体" => zh_hans_serif
    "simhei" => zh_hans
    "黑体" => zh_hans
    "dengxian" => zh_hans
    "等线" => zh_hans
    "microsoftjhenghei" => zh_hant
    "微軟正黑體" => zh_hant
    "pmingliu" => zh_hant_serif
    "新細明體" => zh_hant_serif
    "mingliu" => zh_hant_serif
    "malgungothic" => ko_gothic
    "맑은고딕" => ko_gothic
    "gulim" => ko_gothic
    "굴림" => ko_gothic
    "dotum" => ko_gothic
    "돋움" => ko_gothic
    "batang" => ko_serif
    "바탕" => ko_serif
    _ => []
  }
}

///|
fn generic_latin(name : String) -> Array[String] {
  match name {
    "sans-serif" =>
      [
        "Liberation Sans", "Arimo", "Arial", "Helvetica", "Carlito", "DejaVu Sans",
        "FreeSans", "Noto Sans", "Open Sans", "Roboto",
      ]
    "serif" =>
      [
        "Liberation Serif", "Tinos", "Times New Roman", "Times", "Caladea", "DejaVu Serif",
        "FreeSerif", "Noto Serif",
      ]
    "monospace" =>
      [
        "Liberation Mono", "Cousine", "Courier New", "DejaVu Sans Mono", "FreeMono",
        "Noto Sans Mono",
      ]
    _ => []
  }
}
