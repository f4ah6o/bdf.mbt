///|
/// The workbook's inferred East Asian script, language, and number locale.
pub(all) struct XlsxLocale {
  script : String
  language : String
  number_locale : String
}

///|
fn xlsx_language_script(language : String) -> String {
  let l = language.to_lower()
  if l.has_prefix("ja") {
    "Jpan"
  } else if l.has_prefix("zh-tw") ||
    l.has_prefix("zh-hk") ||
    l.has_prefix("zh-mo") ||
    l.has_prefix("zh-hant") {
    "Hant"
  } else if l.has_prefix("zh") {
    "Hans"
  } else if l.has_prefix("ko") {
    "Hang"
  } else {
    ""
  }
}

///|
/// Infer a workbook's locale from its metadata, default font and theme.
pub fn XlsxWorkbook::locale(self : XlsxWorkbook) -> XlsxLocale {
  let properties = self.package.core_properties()
  let styles = self.styles()
  let theme = self.package.theme_fonts(self.part)
  let font = if styles.fonts.is_empty() {
    "Calibri"
  } else {
    styles.fonts[0].name
  }
  let mut name = font.to_lower()
  let mut script = "Jpan"
  let mut language = ""
  if !properties.language.is_empty() && properties.language[0] != "" {
    let lang = properties.language[0]
    name = ""
    let candidate = xlsx_language_script(lang)
    if candidate != "" {
      script = candidate
      language = lang
    }
  }
  let families = [
    (
      [
        "游ゴシック", "游明朝", "yu gothic", "yu mincho", "ｍｓ ｐゴシック",
        "ｍｓ ゴシック", "ms pgothic", "ms gothic", "ｍｓ 明朝", "ｍｓ ｐ明朝",
        "ms mincho", "メイリオ", "meiryo", "bizud", "biz ud",
      ],
      "Jpan",
      "ja",
    ),
    (
      [
        "맑은 고딕", "malgun gothic", "굴림", "gulim", "돋움", "dotum", "바탕",
        "batang",
      ],
      "Hang",
      "ko",
    ),
    (
      [
        "等线", "dengxian", "宋体", "simsun", "微软雅黑", "microsoft yahei",
      ],
      "Hans",
      "zh-CN",
    ),
    (
      ["新細明體", "pmingliu", "微軟正黑體", "microsoft jhenghei"],
      "Hant",
      "zh-TW",
    ),
  ]
  for (names, candidate_script, candidate_language) in families {
    for prefix in names {
      if name != "" && name.has_prefix(prefix) {
        script = candidate_script
        language = candidate_language
      }
    }
  }
  if language == "" && theme.resolve("+mn-ea", "") == "" {
    let f = theme.resolve("+mn-ea", "Jpan")
    if f != "" && f.to_lower() == font.to_lower() {
      language = "ja"
    }
  }
  {
    script,
    language,
    number_locale: if language.has_prefix("ja") {
      "ja"
    } else {
      ""
    },
  }
}
