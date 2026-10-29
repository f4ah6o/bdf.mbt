///|
/// A writing system and its sample text in an overview.
pub(all) struct SampleScript {
  name : String
  code : String
  lang : String
  text : String
  specimen : String
  charset : Array[String]
  rtl : Bool
}

///|
fn sample_scripts() -> Array[SampleScript] {
  [
    {
      name: "Latin",
      code: "Latn",
      lang: "en",
      text: "The quick brown fox jumps over the lazy dog.",
      specimen: "Aa",
      charset: [
        "ABCDEFGHIJKLM", "NOPQRSTUVWXYZ", "abcdefghijklm", "nopqrstuvwxyz", "0123456789",
      ],
      rtl: false,
    },
    {
      name: "Japanese",
      code: "Jpan",
      lang: "ja",
      text: "色は匂へど散りぬるを 我が世誰ぞ常ならむ いろはにほへと",
      specimen: "あ永",
      charset: [
        "あいうえおかきくけこ", "アイウエオカキクケコ", "永東京春夏秋冬日本語",
      ],
      rtl: false,
    },
    {
      name: "Chinese (Simplified)",
      code: "Hans",
      lang: "zh-Hans",
      text: "天地玄黄，宇宙洪荒。日月盈昃，辰宿列张。",
      specimen: "永",
      charset: ["天地玄黄宇宙洪荒", "日月盈昃辰宿列张"],
      rtl: false,
    },
    {
      name: "Chinese (Traditional)",
      code: "Hant",
      lang: "zh-Hant",
      text: "天地玄黃，宇宙洪荒。日月盈昃，辰宿列張。",
      specimen: "永",
      charset: ["天地玄黃宇宙洪荒", "日月盈昃辰宿列張"],
      rtl: false,
    },
    {
      name: "Korean",
      code: "Kore",
      lang: "ko",
      text: "다람쥐 헌 쳇바퀴에 타고파",
      specimen: "가",
      charset: ["가나다라마바사", "아자차카타파하"],
      rtl: false,
    },
    {
      name: "Cyrillic",
      code: "Cyrl",
      lang: "ru",
      text: "Съешь же ещё этих мягких французских булок, да выпей чаю.",
      specimen: "Жж",
      charset: [
        "АБВГДЕЖЗИЙКЛМНОП", "абвгдежзийклмноп",
      ],
      rtl: false,
    },
    {
      name: "Greek",
      code: "Grek",
      lang: "el",
      text: "Τάχιστη αλώπηξ βαφής ψημένη γη, δρασκελίζει υπέρ νωθρού κυνός.",
      specimen: "Ωω",
      charset: ["ΑΒΓΔΕΖΗΘΙΚΛΜ", "αβγδεζηθικλμ"],
      rtl: false,
    },
    {
      name: "Arabic",
      code: "Arab",
      lang: "ar",
      text: "نص حكيم له سر قاطع وذو شأن عظيم مكتوب على ثوب أخضر ومغلف بجلد أزرق",
      specimen: "ع",
      charset: [
        "ا ب ت ث ج ح خ د ذ ر ز", "س ش ص ض ط ظ ع غ ف ق",
      ],
      rtl: true,
    },
    {
      name: "Hebrew",
      code: "Hebr",
      lang: "he",
      text: "דג סקרן שט בים מאוכזב ולפתע מצא חברה",
      specimen: "א",
      charset: ["אבגדהוזחטיכלמנסעפצקרשת"],
      rtl: true,
    },
    {
      name: "Thai",
      code: "Thai",
      lang: "th",
      text: "เป็นมนุษย์สุดประเสริฐเลิศคุณค่า กว่าบรรดาฝูงสัตว์เดรัจฉาน",
      specimen: "ก",
      charset: [
        "กขคงจฉชซญดตถทนบปผพฟมยรลวศสหอฮ",
      ],
      rtl: false,
    },
    {
      name: "Devanagari",
      code: "Deva",
      lang: "hi",
      text: "ऋषियों को सताने वाले दुष्ट राक्षसों के राजा रावण का सर्वनाश करने वाले विष्णुवतार भगवान श्रीराम",
      specimen: "क",
      charset: [
        "अआइईउऊएऐओऔ", "कखगघङचछजझञ",
      ],
      rtl: false,
    },
    {
      name: "Bengali",
      code: "Beng",
      lang: "bn",
      text: "আমার সোনার বাংলা, আমি তোমায় ভালোবাসি",
      specimen: "ক",
      charset: [
        "অআইঈউঊএঐওঔ", "কখগঘঙচছজঝঞ",
      ],
      rtl: false,
    },
    {
      name: "Tamil",
      code: "Taml",
      lang: "ta",
      text: "யாமறிந்த மொழிகளிலே தமிழ்மொழி போல் இனிதாவது எங்கும் காணோம்",
      specimen: "க",
      charset: [
        "அஆஇஈஉஊஎஏஐஒஓஔ", "கஙசஞடணதநபமயரலவ",
      ],
      rtl: false,
    },
    {
      name: "Armenian",
      code: "Armn",
      lang: "hy",
      text: "Բել դղյակի ձախ ժամն օֆ ազգությանը ցպահանջ չճշտած վնաս էր եւ փառք։",
      specimen: "Աա",
      charset: [
        "ԱԲԳԴԵԶԷԸԹԺԻԼԽԾԿ", "աբգդեզէըթժիլխծկ",
      ],
      rtl: false,
    },
    {
      name: "Georgian",
      code: "Geor",
      lang: "ka",
      text: "აბგდევზთიკლმნოპჟრსტუფქღყშჩცძწჭხჯჰ",
      specimen: "ა",
      charset: [
        "აბგდევზთიკლმნოპჟ", "რსტუფქღყშჩცძწჭხჯჰ",
      ],
      rtl: false,
    },
  ]
}
