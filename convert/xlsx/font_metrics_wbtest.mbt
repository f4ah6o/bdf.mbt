///|
/// Fixtures: regenerate with `go run ./cmd/metricsfont` after copying
/// compat/xlsx/generate-metrics-fixtures.go into an upstream checkout of
/// a5e4d7a6 as cmd/metricsfont/main.go without its build tag, and paste the
/// printed base64 values here. The faces are built with upstream's own
/// sfnt.Build (the reference container writer) and validated inside that
/// program with sfnt.Parse (digit advances and mapped-character counts);
/// the current values were also cross-checked once, outside the generator,
/// with golang.org/x/image/font/sfnt. The digits measure 500/1000 em
/// and every other character 600/1000 em, so at the workbooks' default
/// size 11 the maximum digit width is 8 with the whole-pixel ppem ordinary
/// fonts use, and 7 with the unrounded Calibri/Carlito ppem. The
/// digit-less variant leaves the digits unmapped, so measuring them
/// falls back to the estimated 0.55 em.
///
/// The workbooks all carry left-aligned strings in columns A, B and C with
/// indent 0, 1 and 2 and one fixed-height row. metrics and calibri also
/// set column A width 10; metrics and defaults declare the default font
/// "Metrics Fixture", calibri declares "Calibri", and defaults replaces
/// the explicit column with sheetFormatPr defaultColWidth 8.5.
let metrics_fixture_font = "AAEAAAAKAIAAAwAgT1MvMlzOVTIAAACsAAAAYGNtYXAADACxAAABDAAAACxnbHlmAAAAAAAAATgAAAAQaGVhZGL8Qz0AAAFIAAAANmhoZWEHCgOBAAABgAAAACRobXR421YAAAAAAaQAAAGAbG9jYQAAAAAAAAMkAAAAwm1heHAAYQAAAAAD6AAAACBuYW1lDYMeXwAABAgAAAC8cG9zdP+fADIAAATEAAAAIAAEAfQBkAAFAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAAAAAAAAAAAABNRlRSAEAAIAB+AyD/OAAAAyAAyAAAAAAAAAAAArwCvAAgACAAAQAAAAEAAwABAAAADAAEACAAAAAEAAQAAQAAAH7//wAAACD////hAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAAQAARiUbX18PPPUAAAPoAAAAAAAAAAAAAAAAAAAAAAAA/zgD6AMgAAAACAACAAAAAAAAAAEAAAMg/zgAAAPoAAAAAAPoAAEAAAAAAAAAAAAAAAAAAABgAfQAAAD6AAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAAAAYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABAA2AAMAAQQJAAEAHgAAAAMAAQQJAAIADgAeAAMAAQQJAAQALgAsAAMAAQQJAAYALABaAE0AZQB0AHIAaQBjAHMAIABGAGkAeAB0AHUAcgBlAFIAZQBnAHUAbABhAHIATQBlAHQAcgBpAGMAcwAgAEYAaQB4AHQAdQByAGUAIABSAGUAZwB1AGwAYQByAE0AZQB0AHIAaQBjAHMARgBpAHgAdAB1AHIAZQAtAFIAZQBnAHUAbABhAHIAAwAAAAAAAP+cADIAAAAAAAAAAAAAAAAAAAAAAAAAAA=="

///|
let metrics_fixture_nodigits_font = "AAEAAAAKAIAAAwAgT1MvMlzOVTIAAACsAAAAYGNtYXAAqgBrAAABDAAAADRnbHlmAAAAAAAAAUAAAAAQaGVhZGL8Qz0AAAFQAAAANmhoZWEHCgOBAAABiAAAACRobXR421YAAAAAAawAAAGAbG9jYQAAAAAAAAMsAAAAwm1heHAAYQAAAAAD8AAAACBuYW1lDYMeXwAABBAAAAC8cG9zdP+fADIAAATMAAAAIAAEAfQBkAAFAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMAAAAAAAAAAAAAAABNRlRSAEAAIAB+AyD/OAAAAyAAyAAAAAAAAAAAArwCvAAgACAAAQAAAAEAAwABAAAADAAEACgAAAAGAAQAAQACAC8Afv//AAAAIAA6////4f/hAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAABAABE6RujXw889QAAA+gAAAAAAAAAAAAAAAAAAAAAAAD/OAPoAyAAAAAIAAIAAAAAAAAAAQAAAyD/OAAAA+gAAAAAA+gAAQAAAAAAAAAAAAAAAAAAAGAB9AAAAPoAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAAB9AAAAfQAAAH0AAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAACWAAAAlgAAAJYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAABgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEADYAAwABBAkAAQAeAAAAAwABBAkAAgAOAB4AAwABBAkABAAuACwAAwABBAkABgAsAFoATQBlAHQAcgBpAGMAcwAgAEYAaQB4AHQAdQByAGUAUgBlAGcAdQBsAGEAcgBNAGUAdAByAGkAYwBzACAARgBpAHgAdAB1AHIAZQAgAFIAZQBnAHUAbABhAHIATQBlAHQAcgBpAGMAcwBGAGkAeAB0AHUAcgBlAC0AUgBlAGcAdQBsAGEAcgADAAAAAAAA/5wAMgAAAAAAAAAAAAAAAAAAAAAAAAAA"

///|
let metrics_fixture_workbook = "UEsDBBQACAAIAAAAAAAAAAAAAAAAAAAAAAAPAAAAeGwvd29ya2Jvb2sueG1sjM1BjoMwDAXQqyAfAMMsZoGA1dxgThDANFHiOLJTwfGrlnbf1f+Lr/fHQzQuIrE5OWWbwNdaBkRbPbGzVgrlk9Muyq5aK3pDK0puM09UOeFP1/0iu5DhEgb9xpB9Dyv9yXpnyvVClJKrQbL5UAzm8fVg72yyY5rg/9l7aHQI2wTaA84jfoZ4iMZFJM6PAQBQSwcIVZtbDo8AAADWAAAAUEsDBBQACAAIAAAAAAAAAAAAAAAAAAAAAAAaAAAAeGwvX3JlbHMvd29ya2Jvb2sueG1sLnJlbHOyCUrNSSzJzM8rzsgsKLZD4Sp4ptgqFQWXVOakFisphFQWpNoqVegXw/iJRempJbZKEL5eRW6Okj42/YYIreX5RdnFGampJQjdcKFifbCMIcwgfWSTiu0AAwBQSwcIkb46UVoAAACoAAAAUEsDBBQACAAIAAAAAAAAAAAAAAAAAAAAAAANAAAAeGwvc3R5bGVzLnhtbLSPva6DMAyFX8XyC+Ry7xoi3QWpQyeWrhE4JZKTIGIq4OmriJ+xWyf7+Bx9OtZZVqZ2IBKjXYqSoUtzlBor3A9GRxsIXpZrvJNMvsvQ+EXmiVAZnbfdqqqiVEEcIxvdEfPDXcg/NHpxEOfQBLn1Nf4glOS+qk8m2HHk9Z/9MwY669lTwpAmv6UopSSTEwQf+yNXai3uK/DfC66OV41WWVamdiAS8x4AUEsHCI1pLEynAAAAXgEAAFBLAwQUAAgACAAAAAAAAAAAAAAAAAAAAAAAGAAAAHhsL3dvcmtzaGVldHMvc2hlZXQxLnhtbHTPy2pDIRAG4FeReYBMTKGLokIvi+676NoaGyVeDjNTPI9fjgmlhWaj+PN/DmNGpzOnGEWttTS2kESWB0QOKVbPu77Ettby2al64V2nE/JC0R8nqgUP+/09Vp8bOBN64XmqmpsFDar6dd4jHyVZ0HtQ4Yul1/drAOgMXtz88cWLd4b6UDRhEgt3P+o15tOW6G3Y1njUoMRCbiW3+CYEzmR2Rpw3KM7g9sBwLT9pUGzhFvn4hzxfyOEGCX8JUh/O4K9FcHQ6c4pR3PcAUEsHCHW8UhTLAAAAawEAAFBLAQIUABQACAAIAAAAAABVm1sOjwAAANYAAAAPAAAAAAAAAAAAAAAAAAAAAAB4bC93b3JrYm9vay54bWxQSwECFAAUAAgACAAAAAAAkb46UVoAAACoAAAAGgAAAAAAAAAAAAAAAADMAAAAeGwvX3JlbHMvd29ya2Jvb2sueG1sLnJlbHNQSwECFAAUAAgACAAAAAAAjWksTKcAAABeAQAADQAAAAAAAAAAAAAAAABuAQAAeGwvc3R5bGVzLnhtbFBLAQIUABQACAAIAAAAAAB1vFIUywAAAGsBAAAYAAAAAAAAAAAAAAAAAFACAAB4bC93b3Jrc2hlZXRzL3NoZWV0MS54bWxQSwUGAAAAAAQABAAGAQAAYQMAAAAA"

///|
let calibri_fixture_workbook = "UEsDBBQACAAIAAAAAAAAAAAAAAAAAAAAAAAPAAAAeGwvd29ya2Jvb2sueG1sjM1BjoMwDAXQqyAfAMMsZoGA1dxgThDANFHiOLJTwfGrlnbf1f+Lr/fHQzQuIrE5OWWbwNdaBkRbPbGzVgrlk9Muyq5aK3pDK0puM09UOeFP1/0iu5DhEgb9xpB9Dyv9yXpnyvVClJKrQbL5UAzm8fVg72yyY5rg/9l7aHQI2wTaA84jfoZ4iMZFJM6PAQBQSwcIVZtbDo8AAADWAAAAUEsDBBQACAAIAAAAAAAAAAAAAAAAAAAAAAAaAAAAeGwvX3JlbHMvd29ya2Jvb2sueG1sLnJlbHOyCUrNSSzJzM8rzsgsKLZD4Sp4ptgqFQWXVOakFisphFQWpNoqVegXw/iJRempJbZKEL5eRW6Okj42/YYIreX5RdnFGampJQjdcKFifbCMIcwgfWSTiu0AAwBQSwcIkb46UVoAAACoAAAAUEsDBBQACAAIAAAAAAAAAAAAAAAAAAAAAAANAAAAeGwvc3R5bGVzLnhtbLSPzYrDMAyEX8XoBbzZvTqGpVDoOZde3URuDLIcYqUkefpi8nPsrSd7RqPhk8myEDY9oljjE0tWbZpYaqhgM6xhF1G9HNVwcRQeYwBtTV43q6qK0mV1f7I1LRLd/Vn1B9bMXvEUr1FuXQ0/oEpy++pPQ+WGgZZ/Ck+OeGC5Q6o+jWFNLAWO0AuowN2eK1iz/0r571mu91Ot0VkWwqZHFPseAFBLBwgMNgbnogAAAFYBAABQSwMEFAAIAAgAAAAAAAAAAAAAAAAAAAAAABgAAAB4bC93b3Jrc2hlZXRzL3NoZWV0MS54bWx0z8tqQyEQBuBXkXmATEyhi6JCL4vuu+jaGhslXg4zUzyPX44JpYVmo/jzfw5jRqczpxhFrbU0tpBElgdEDilWz7u+xLbW8tmpeuFdpxPyQtEfJ6oFD/v9PVafGzgTeuF5qpqbBQ2q+nXeIx8lWdB7UOGLpdf3awDoDF7c/PHFi3eG+lA0YRILdz/qNebTluht2NZ41KDEQm4lt/gmBM5kdkacNyjO4PbAcC0/aVBs4Rb5+Ic8X8jhBgl/CVIfzuCvRXB0OnOKUdz3AFBLBwh1vFIUywAAAGsBAABQSwECFAAUAAgACAAAAAAAVZtbDo8AAADWAAAADwAAAAAAAAAAAAAAAAAAAAAAeGwvd29ya2Jvb2sueG1sUEsBAhQAFAAIAAgAAAAAAJG+OlFaAAAAqAAAABoAAAAAAAAAAAAAAAAAzAAAAHhsL19yZWxzL3dvcmtib29rLnhtbC5yZWxzUEsBAhQAFAAIAAgAAAAAAAw2BueiAAAAVgEAAA0AAAAAAAAAAAAAAAAAbgEAAHhsL3N0eWxlcy54bWxQSwECFAAUAAgACAAAAAAAdbxSFMsAAABrAQAAGAAAAAAAAAAAAAAAAABLAgAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1sUEsFBgAAAAAEAAQABgEAAFwDAAAAAA=="

///|
let defaults_fixture_workbook = "UEsDBBQACAAIAAAAAAAAAAAAAAAAAAAAAAAPAAAAeGwvd29ya2Jvb2sueG1sjM1BjoMwDAXQqyAfAMMsZoGA1dxgThDANFHiOLJTwfGrlnbf1f+Lr/fHQzQuIrE5OWWbwNdaBkRbPbGzVgrlk9Muyq5aK3pDK0puM09UOeFP1/0iu5DhEgb9xpB9Dyv9yXpnyvVClJKrQbL5UAzm8fVg72yyY5rg/9l7aHQI2wTaA84jfoZ4iMZFJM6PAQBQSwcIVZtbDo8AAADWAAAAUEsDBBQACAAIAAAAAAAAAAAAAAAAAAAAAAAaAAAAeGwvX3JlbHMvd29ya2Jvb2sueG1sLnJlbHOyCUrNSSzJzM8rzsgsKLZD4Sp4ptgqFQWXVOakFisphFQWpNoqVegXw/iJRempJbZKEL5eRW6Okj42/YYIreX5RdnFGampJQjdcKFifbCMIcwgfWSTiu0AAwBQSwcIkb46UVoAAACoAAAAUEsDBBQACAAIAAAAAAAAAAAAAAAAAAAAAAANAAAAeGwvc3R5bGVzLnhtbLSPva6DMAyFX8XyC+Ry7xoi3QWpQyeWrhE4JZKTIGIq4OmriJ+xWyf7+Bx9OtZZVqZ2IBKjXYqSoUtzlBor3A9GRxsIXpZrvJNMvsvQ+EXmiVAZnbfdqqqiVEEcIxvdEfPDXcg/NHpxEOfQBLn1Nf4glOS+qk8m2HHk9Z/9MwY669lTwpAmv6UopSSTEwQf+yNXai3uK/DfC66OV41WWVamdiAS8x4AUEsHCI1pLEynAAAAXgEAAFBLAwQUAAgACAAAAAAAAAAAAAAAAAAAAAAAGAAAAHhsL3dvcmtzaGVldHMvc2hlZXQxLnhtbHTPQU7rMBDG8atYc4BM0qc+IWRbgiLEEsGCtUnc2qqdiWamSo+PEgoCiS79+f9bjJ2Jj5JiVHOuZRQHSXW6RZQ+xRqkoSmO51r2xDWoNMQHlIljGFZUC27a9j/WkEfwdt0e1/SZzRD34VR0R+UtD5oc3DRb+FpfaH6K+ZDUQbcFvNiHoMFbptmwgw7M8v2vBdOfRKl+A/C2X4q7Dow6yGPJY3xVBm+zeKs+WFRvcXlgf4nvOzDi4Bp5/4PsPsnmCul/E2SavcUfh+BMfJQUo/qPAQBQSwcIxnJqI9MAAABpAQAAUEsBAhQAFAAIAAgAAAAAAFWbWw6PAAAA1gAAAA8AAAAAAAAAAAAAAAAAAAAAAHhsL3dvcmtib29rLnhtbFBLAQIUABQACAAIAAAAAACRvjpRWgAAAKgAAAAaAAAAAAAAAAAAAAAAAMwAAAB4bC9fcmVscy93b3JrYm9vay54bWwucmVsc1BLAQIUABQACAAIAAAAAACNaSxMpwAAAF4BAAANAAAAAAAAAAAAAAAAAG4BAAB4bC9zdHlsZXMueG1sUEsBAhQAFAAIAAgAAAAAAMZyaiPTAAAAaQEAABgAAAAAAAAAAAAAAAAAUAIAAHhsL3dvcmtzaGVldHMvc2hlZXQxLnhtbFBLBQYAAAAABAAEAAYBAABpAwAAAAA="

///|
/// The no-font conversions of the three workbooks as produced by the
/// estimate-only path of the tree this slice starts from (61f195b3,
/// recorded by running the identical calls on that tree); this slice must
/// keep them byte for byte.
let metrics_no_font_bdf = "YmRmAAEAAAAgAAAAAAAAAIUBAAAAAAAAAQAAAAAAAACNkc2SmzAQhN+lz4ojhASSbklOOefo4iDQYCuxhQvkLBsX754S/slhsz+3oRrN191zQet72IJhOE2U1ukcQ4LFKYHhSMnBXjAN57EjWMyHaQbDjiKNLg0jbN7waTd85psCC8PvQE8T7PaC4GEx7YlSAYZfIT6+wZDCgWAFl5qhGw75xbZgSmxUw7ZFwaRuGoZxeLopJW/YVhhWyI1QWdqNwR9CpAk2jWfKG1NeiR93YkZM2TxnHBZVSzVvJQlujO6FF0YaXgtRub7oTc+z+URz+h49zbBwVEspdKtLksqbytedNkIbV5WOZOewNAzJtSvkRdyTG3OJzrVKV8YbWZdKkuxU6Z0olas7rqX2uGcs1hrOx3hdFt0xZ/mSYzyf8jilMcQdFvYQv74lfnspNv/pKF/rn+38SzZ+9bD/mP8cc60BDBQ7WARPMYX0DIYDRVghK4Yp/KHbOPQ9LM9m9x+5yxUxtD9fBRRS3AHruAKErO6Id095RQQ/v55BPSKoG6DUemmWv1BBUjEVABUWFRYsFQIVABUGFQYAAAIAAAACAQEAAABhFQAVFhUWLBUCFQAVBhUGAAACAAAAAgEBAAAAYhUAFRYVFiwVAhUAFQYVBgAAAgAAAAIBAQAAAGMVAhlMSAZzY2hlbWEVBgAVDCUCGAFBJQBMHAAAABUMJQIYAUIlAEwcAAAAFQwlAhgBQyUATBwAAAAWAhkcGTwmCBwVDBklAAYZGAFBFQAWAhY4FjgmCAAAJkAcFQwZJQAGGRgBQhUAFgIWOBY4JkAAACZ4HBUMGSUABhkYAUMVABYCFjgWOCZ4AAAWqAEWAgAoA2JkZgCWAAAAUEFSMUJPQkoBAAAAAAAAAAAAAAAAAABFAAAARQYCQTEBYQJCMQFiAkMxAWMAAAEBHSJNZXRyaWNzIEZpeHR1cmUiLCBzYW5zLXNlcmlmkAEAAAA+cQIAGgAAADBBEP8AAAAwAQAAwD8AANRBmpnBQHECAjADAAB2QgAA1EGamcFAcQIEMAUAAOpCAADUQZqZwUBCVFhUAQADAAAAAgFhAAABAgFiAAACAgFj"

///|
let calibri_no_font_bdf = "YmRmAAEAAAAgAAAAAAAAAIYBAAAAAAAAAQAAAAAAAACNkc2SmzAQhN+lz4ojCQmEbklOOefo4iDQ2FaChQvkLBsX754S/slhsz+3oRrN191zQet3sIJhOE2U1ukcQ4LFKYHhSMnBXjAN57EjWMz9NINhT5FGl4YRNm/4tB8+843AwvA70NMEu70geFhMB6IkwPArxMc3GFLoCVZyZRi6oc8vtoJpudEN2wrBlGkahnF4uikFb9hW1kyojdRZ2o/B9yHSBJvGM+WNKa/EjzsxI6ZsnjMOix2XvpS7UlRty1Wpail8y2VVedUJXlfZfKI5fY+eZlg4qpSSpjUFKe3r0ledqaWpXVk4Up3D0jAk166QF3FPbswlOtdqU9a+VlWhFalOF97JQruq40YZj3tGsdZwPsbrsuiOOcuXHOP5lMcpjSHusbCH+PUt8dtLsflPR/la/2znX7Lxq4fDx/znmGsNYKDYwSJ4iimkZzD0FGGlKhmm8Idu47DbwfJs9vCRu1wRQ/vzVYAo1B2wjitAqvKOePeUV0Tw8+sZ9COCvgEKw5dm+QtQQVIxFQAVFhUWLBUCFQAVBhUGAAACAAAAAgEBAAAAYRUAFRYVFiwVAhUAFQYVBgAAAgAAAAIBAQAAAGIVABUWFRYsFQIVABUGFQYAAAIAAAACAQEAAABjFQIZTEgGc2NoZW1hFQYAFQwlAhgBQSUATBwAAAAVDCUCGAFCJQBMHAAAABUMJQIYAUMlAEwcAAAAFgIZHBk8JggcFQwZJQAGGRgBQRUAFgIWOBY4JggAACZAHBUMGSUABhkYAUIVABYCFjgWOCZAAAAmeBwVDBklAAYZGAFDFQAWAhY4FjgmeAAAFqgBFgIAKANiZGYAlgAAAFBBUjFCT0JKAQAAAAAAAAAAAAAAAAAARQAAAEUGAkExAWECQjEBYgJDMQFjAAABARUiQ2FsaWJyaSIsIHNhbnMtc2VyaWaQAQAAAD5xAgAaAAAAMEEQ/wAAADABAADAPwAA1EGamcFAcQICMAMAAHZCAADUQZqZwUBxAgQwBQAA6kIAANRBmpnBQEJUWFQBAAMAAAACAWEAAAECAWIAAAICAWM="

///|
let defaults_no_font_bdf = "YmRmAAEAAAAgAAAAAAAAAH8BAAAAAAAAAQAAAAAAAACNkc2SmzAQhN+lz8pGCAFCtySnnHN0cRDSYCvBwgVyll0X774lWHsP+3sbaaT+umcuaF0HnTEMp4niWp2Dj9A4RTAcKRroC6bhPFqCxtxPMxj2FGg0cRihk8K3/fCd32VYGP57up+gdxd4B43pQBQzMPzz4XYGQ/Q9QQsuFYMd+vRjlwkm5Z0omoZhHO63O5bzhu1EzbL1fj961/tAE3Qcz5SEYlLCnysoKU/JM2ccGl0pbFGSqHhXU2uMq6pMmZorWXFr2zx5jjTH38HRDA1DlZRCtSonWbi6dJVVtVC1KXND0hosDUM07Qp5lfJkxjQ7Y9pClbWrZZUXkqQtcmdEXpjKciWVwzVgtqY/H8MmFswxZfmRYjycUjnF0Yc9FnZr/vyo+et1s3ljRmlJL7bTk2R883D4mv8Ucx0DGChYaHhHIfr4AIaeArSQJcPkH+m5HLoOmiezh6/sZUMM7d93AZkUV8BargAhyyvi01VuCO/m9zMUtwjFMyBXammWJ1BBUjEVABUWFRYsFQIVABUGFQYAAAIAAAACAQEAAABhFQAVFhUWLBUCFQAVBhUGAAACAAAAAgEBAAAAYhUAFRYVFiwVAhUAFQYVBgAAAgAAAAIBAQAAAGMVAhlMSAZzY2hlbWEVBgAVDCUCGAFBJQBMHAAAABUMJQIYAUIlAEwcAAAAFQwlAhgBQyUATBwAAAAWAhkcGTwmCBwVDBklAAYZGAFBFQAWAhY4FjgmCAAAJkAcFQwZJQAGGRgBQhUAFgIWOBY4JkAAACZ4HBUMGSUABhkYAUMVABYCFjgWOCZ4AAAWqAEWAgAoA2JkZgCWAAAAUEFSMUJPQkoBAAAAAAAAAAAAAAAAAABFAAAARQYCQTEBYQJCMQFiAkMxAWMAAAEBHSJNZXRyaWNzIEZpeHR1cmUiLCBzYW5zLXNlcmlmkAEAAAA+cQIAGgAAADBBEP8AAAAwAQAAwD8AANRBmpnBQHECAjADAABVQgAA1EGamcFAcQIEMAUAANJCAADUQZqZwUBCVFhUAQADAAAAAgFhAAABAgFiAAACAgFj"

///|
fn fixture_workbook(data : String) -> Bytes {
  @base64.decode(data[:]) catch {
    _ => b""
  }
}

///|
fn fixture_face(data : String) -> @sfnt.Font {
  try! @sfnt.parse(fixture_workbook(data))
}

///|
fn fixture_styles(name : String, size : Double) -> XlsxStyles {
  {
    fonts: [
      {
        name,
        size,
        bold: false,
        italic: false,
        underline: "",
        strike: false,
        color: { kind: 0, rgb: 0, index: 0, tint: 0.0, },
        vertical: "",
        scheme: "",
        family: 0,
      },
    ],
    number_formats: Map([]),
    cell_formats: [],
    palette: [],
    fills: [],
    borders: [],
  }
}

///|
fn sheet_first_view_columns(bdf : Bytes) -> Array[@core.SheetRun] {
  let doc = @core.open_single(bdf) catch { _ => return [] }
  for view in doc.manifest.views {
    if view.kind == "sheet" {
      return view.cols.copy()
    }
  }
  []
}

///|
fn sheet_first_view_rows(bdf : Bytes) -> Array[@core.SheetRun] {
  let doc = @core.open_single(bdf) catch { _ => return [] }
  for view in doc.manifest.views {
    if view.kind == "sheet" {
      return view.rows.copy()
    }
  }
  []
}

///|
fn sheet_row_size(runs : Array[@core.SheetRun], index : Int32) -> Double {
  let mut start = 0
  for run in runs {
    if index < start + run.count {
      return run.size
    }
    start += run.count
  }
  -1.0
}

///|
fn synthetic_baselines(bdf : Bytes) -> Array[Double] raise {
  let result : Array[Double] = []
  let doc = @core.open_single(bdf)
  for part in doc.manifest.parts {
    if part.kind == "obj" {
      let resources = @core.decode_object_resources(doc.part(part.hash))
      for command in @render.compile_object(resources.object) {
        match command {
          FillText(_, _, y, _) => result.push(y)
          _ => ()
        }
      }
    }
  }
  result
}

///|
/// The x position of one label's FillText, failing when it is absent.
fn text_position(
  positions : Map[String, Double],
  label : String,
) -> Double raise {
  match positions.get(label) {
    Some(x) => x
    None => fail("missing '" + label + "' text")
  }
}

///|
fn text_positions(bdf : Bytes) -> Map[String, Double] raise {
  let result : Map[String, Double] = Map([])
  let doc = @core.open_single(bdf) catch { _ => return result }
  for part in doc.manifest.parts {
    if part.kind != "obj" {
      continue
    }
    let resources = @core.decode_object_resources(doc.part(part.hash)) catch {
      _ => continue
    }
    for command in @render.compile_object(resources.object) {
      match command {
        FillText(text, x, _, _) => result[text] = x
        _ => ()
      }
    }
  }
  result
}

///|
test "XLSX default-font MDW" {
  let face = fixture_face(metrics_fixture_font)
  let theme = @ooxml.default_theme_fonts()
  let no_face : @sfnt.Font? = None
  let measured : @sfnt.Font? = Some(face)
  // Upstream rounds ties away from zero (Go math.Round); assert the
  // package's rounding agrees before the measurements rely on it.
  assert_eq(8.5.round(), 9.0)
  assert_eq(7.5.round(), 8.0)
  assert_eq(
    xlsx_default_font_mdw(
      fixture_styles("Metrics Fixture", 11.0),
      theme,
      "Jpan",
      no_face,
    ),
    7.0,
  )
  // whole-pixel ppem: round(11*96/72) = 15, mdw = round(0.5*15) = 8
  assert_eq(
    xlsx_default_font_mdw(
      fixture_styles("Metrics Fixture", 11.0),
      theme,
      "Jpan",
      measured,
    ),
    8.0,
  )
  // Calibri and Carlito keep the unrounded ppem: mdw = round(0.5*44/3) = 7
  assert_eq(
    xlsx_default_font_mdw(
      fixture_styles("Calibri", 11.0),
      theme,
      "Jpan",
      measured,
    ),
    7.0,
  )
  assert_eq(
    xlsx_default_font_mdw(
      fixture_styles("Carlito", 11.0),
      theme,
      "Jpan",
      measured,
    ),
    7.0,
  )
  // fractional size: round(12.5*96/72) = 17, mdw = round(0.5*17) = 9,
  // while Calibri stays unrounded: mdw = round(0.5*50/3) = 8.
  assert_eq(
    xlsx_default_font_mdw(
      fixture_styles("Metrics Fixture", 12.5),
      theme,
      "Jpan",
      measured,
    ),
    9.0,
  )
  assert_eq(
    xlsx_default_font_mdw(
      fixture_styles("Calibri", 12.5),
      theme,
      "Jpan",
      measured,
    ),
    8.0,
  )
  // size propagation: round(9*96/72) = 12, mdw = round(0.5*12) = 6
  assert_eq(
    xlsx_default_font_mdw(
      fixture_styles("Metrics Fixture", 9.0),
      theme,
      "Jpan",
      measured,
    ),
    6.0,
  )
  // no stylesheet fonts: the Calibri 11 default
  let empty : XlsxStyles = {
    fonts: [],
    number_formats: Map([]),
    cell_formats: [],
    palette: [],
    fills: [],
    borders: [],
  }
  assert_eq(xlsx_default_font_mdw(empty, theme, "Jpan", measured), 7.0)
  // minor-scheme fonts resolve their Latin family through the theme
  let themed : @ooxml.OoxmlThemeFonts = {
    major: {
      latin: "Calibri Light",
      east_asian: "",
      complex: "",
      scripts: Map([]),
    },
    minor: {
      latin: "Metrics Fixture",
      east_asian: "",
      complex: "",
      scripts: Map([]),
    },
  }
  let scheme_font = {
    ..fixture_styles("", 11.0).fonts[0],
    name: "",
    scheme: "minor",
  }
  let scheme_styles = { ..fixture_styles("", 11.0), fonts: [scheme_font], }
  assert_eq(xlsx_default_font_mdw(scheme_styles, themed, "Jpan", measured), 8.0)
  // digits the face does not map measure with the estimated 0.55 em:
  // mdw = round(0.55*15) = 8
  let lacking_digits : @sfnt.Font? = Some(
    fixture_face(metrics_fixture_nodigits_font),
  )
  assert_eq(
    xlsx_default_font_mdw(
      fixture_styles("Metrics Fixture", 11.0),
      theme,
      "Jpan",
      lacking_digits,
    ),
    8.0,
  )
  assert_eq(
    xlsx_default_font_mdw(
      fixture_styles("Calibri", 11.0),
      theme,
      "Jpan",
      lacking_digits,
    ),
    8.0,
  )
}

///|
test "XLSX with-font column geometry uses the measured MDW" {
  let face = fixture_workbook(metrics_fixture_font)
  let metrics = convert_plain_with_font(
    fixture_workbook(metrics_fixture_workbook),
    face,
  )
  // Column A (width 10 characters) at MDW 8: trunc((256·10+16)/256·8) px.
  // The default columns (baseColW 8) extend to the axis's last size
  // exception at ceil((8·8+5)/8)·8 = 72 px.
  assert_eq(sheet_first_view_columns(metrics.bdf), [
    { count: 1, size: 60.0, },
    { count: 11, size: 54.0, },
  ])
  let calibri = convert_plain_with_font(
    fixture_workbook(calibri_fixture_workbook),
    face,
  )
  // The same face under a declared Calibri default keeps the unrounded
  // Calibri ppem: MDW 7, the estimated values.
  assert_eq(sheet_first_view_columns(calibri.bdf), [
    { count: 1, size: 52.5, },
    { count: 11, size: 48.0, },
  ])
}

///|
test "XLSX measured default row preserves explicit heights" {
  // The synthetic face has OS/2 ascent 800 and descent 200 at 1000 upem.
  // With size 11 the row default is ceil((11/0.75)-0.05)+2 pixels.
  let workbook = fixture_workbook(metrics_fixture_workbook)
  let with_font = convert_plain_with_font(
    workbook,
    fixture_workbook(metrics_fixture_font),
  )
  let no_font = convert_plain_no_fonts(workbook)
  assert_eq(sheet_first_view_rows(with_font.bdf), [
    { count: 1, size: 30.0, },
    { count: 29, size: 12.75, },
  ])
  assert_eq(sheet_first_view_rows(no_font.bdf), [
    { count: 1, size: 30.0, },
    { count: 29, size: 14.25, },
  ])
  // A worksheet-specified defaultRowHeight wins over font metrics.
  let explicit = convert_plain_with_font(
    fixture_workbook(defaults_fixture_workbook),
    fixture_workbook(metrics_fixture_font),
  )
  assert_eq(sheet_first_view_rows(explicit.bdf), [
    { count: 1, size: 30.0, },
    { count: 29, size: 15.0, },
  ])
}

///|
test "XLSX wrapped and unwrapped rows share measured line metrics" {
  let workbook = fixture_workbook(row_metrics_workbook)
  let with_font = convert_plain_with_font(
    workbook,
    fixture_workbook(metrics_fixture_font),
  )
  let rows = sheet_first_view_rows(with_font.bdf)
  assert_eq(sheet_row_size(rows, 0), 12.75)
  assert_eq(sheet_row_size(rows, 1), 12.75)
  assert_true(sheet_row_size(rows, 2) > 12.75)
  assert_eq(sheet_row_size(rows, 3), 30.0)
  assert_eq(sheet_row_size(rows, 4), 12.75)
  // The six measured wrapped lines must use the same 11pt line advance as
  // the row fitter, including the 2.2pt descent. A negative descent used to
  // shift baselines down and make successive lines only 8.8pt apart.
  let baselines = synthetic_baselines(with_font.bdf)
  assert_eq(baselines.length(), 9)
  assert_true((baselines[0] - 9.8).abs() < 0.001)
  assert_true((baselines[3] - baselines[2] - 11.0).abs() < 0.001)
  assert_true((baselines[7] - baselines[2] - 55.0).abs() < 0.001)
  let no_font = convert_plain_no_fonts(workbook)
  let estimated = sheet_first_view_rows(no_font.bdf)
  assert_eq(sheet_row_size(estimated, 0), 14.25)
  assert_eq(sheet_row_size(estimated, 1), 14.25)
  assert_eq(sheet_row_size(estimated, 3), 30.0)
}

///|
test "XLSX varying rich runs retain renderer's fallback row metrics" {
  let result = convert_plain_with_font(
    fixture_workbook(rich_row_metrics_workbook),
    fixture_workbook(metrics_fixture_font),
  )
  let rows = sheet_first_view_rows(result.bdf)
  // The current renderer wraps varying-size rich runs using fallback widths
  // and 0.9+0.25em line metrics. Compute its required height independently
  // from the declared runs and column width, even when a face is available.
  let lines = @sheet.wrap_rich_text(
    [
      { text: "aa ", size: 11.0, vertical: "", },
      { text: "bb bb bb bb", size: 16.0, vertical: "", },
    ],
    26.25,
    11.0,
  )
  assert_true(lines.length() > 1)
  let mut line_height = 0.0
  for line in lines {
    line_height += 0.9 * line.size + 0.25 * line.size
  }
  let expected = ((line_height / 0.75 - 0.05).ceil() + 2.0) * 0.75
  assert_eq(sheet_row_size(rows, 0), expected)
}

///|
test "XLSX wrapping falls back when a face lacks a character" {
  let face = fixture_face(metrics_fixture_nodigits_font)
  assert_true(face.glyph('5'.to_int()) is None)
  for size in [8.0, 11.0, 24.0] {
    assert_eq(
      xlsx_fitted_advance('5', false, size, Some(face)),
      @sheet.sized_fallback_advance('5', false, size),
    )
    assert_eq(
      xlsx_fitted_advance('5', true, size, None),
      @sheet.sized_fallback_advance('5', true, size),
    )
  }
}

///|
test "property: measured default rows are monotone and explicit defaults win" {
  let face = Some(fixture_face(metrics_fixture_font))
  let geometry : XlsxSheetGeometry = {
    default_column_width: 0.0,
    base_column_width: 8.0,
    default_row_height: 0.0,
    zero_height: false,
    show_grid: true,
    show_zero: true,
    right_to_left: false,
    frozen_columns: 0,
    frozen_rows: 0,
    columns: [],
    merges: [],
    auto_filter: None,
  }
  @quickcheck.check(
    (sample : Byte) => {
      let small = (sample.to_int() % 60 + 1).to_double()
      let large = small + (sample.to_int() % 10 + 1).to_double()
      let small_height = xlsx_default_font_line_height(small, face)
      let large_height = xlsx_default_font_line_height(large, face)
      let fitted : Map[Int32, Double] = Map([])
      let a = xlsx_row_runs([], geometry, 7, small_height, fitted)
      let b = xlsx_row_runs([], geometry, 7, large_height, fitted)
      let explicit = { ..geometry, default_row_height: 27.0, }
      let c = xlsx_row_runs([], explicit, 7, small_height, fitted)
      let d = xlsx_row_runs([], explicit, 7, large_height, fitted)
      a.length() == 1 &&
      b.length() == 1 &&
      a[0].count == 7 &&
      b[0].count == 7 &&
      a[0].size <= b[0].size &&
      c.length() == 1 &&
      d.length() == 1 &&
      c[0].size == 27.0 &&
      d[0].size == 27.0
    },
    seed=20261113,
    count=256,
  )
}

///|
test "XLSX default-column axis carries the measured width" {
  let with_font = convert_plain_with_font(
    fixture_workbook(defaults_fixture_workbook),
    fixture_workbook(metrics_fixture_font),
  )
  // defaultColWidth 8.5: trunc((256·8.5+16)/256·8) = 68 px, over the
  // sheet extent's twelve visible columns.
  assert_eq(sheet_first_view_columns(with_font.bdf), [
    { count: 12, size: 51.0, },
  ])
  let without = convert_plain_no_fonts(
    fixture_workbook(defaults_fixture_workbook),
  )
  // at the estimated MDW 7: trunc((256·8.5+18)/256·7) = 59 px.
  assert_eq(sheet_first_view_columns(without.bdf), [{ count: 12, size: 44.25, }])
}

///|
test "XLSX with-font indent step uses the measured MDW" {
  let without = try! text_positions(
    convert_plain_no_fonts(fixture_workbook(metrics_fixture_workbook)).bdf,
  )
  let with_font = try! text_positions(
    convert_plain_with_font(
      fixture_workbook(metrics_fixture_workbook),
      fixture_workbook(metrics_fixture_font),
    ).bdf,
  )
  // Column A measures 7.5 pt and each default column 6 pt wider; one
  // indent level grows by (8+3)·0.75 - 7.5 pt. The indent levels sit in
  // columns B (one) and C (two), behind column A and one default column.
  assert_eq(text_position(with_font, "a") - text_position(without, "a"), 0.0)
  assert_eq(
    text_position(with_font, "b") - text_position(without, "b"),
    60.0 - 52.5 + ((8.0 + 3.0) * 0.75 - 7.5),
  )
  assert_eq(
    text_position(with_font, "c") - text_position(without, "c"),
    60.0 - 52.5 + (54.0 - 48.0) + 2.0 * ((8.0 + 3.0) * 0.75 - 7.5),
  )
  let calibri_without = try! text_positions(
    convert_plain_no_fonts(fixture_workbook(calibri_fixture_workbook)).bdf,
  )
  let calibri_with = try! text_positions(
    convert_plain_with_font(
      fixture_workbook(calibri_fixture_workbook),
      fixture_workbook(metrics_fixture_font),
    ).bdf,
  )
  // A Calibri-declared workbook measures MDW 7 with this face: the indent
  // step and column widths stay at the estimated values.
  assert_eq(
    text_position(calibri_with, "a"),
    text_position(calibri_without, "a"),
  )
  assert_eq(
    text_position(calibri_with, "b"),
    text_position(calibri_without, "b"),
  )
  assert_eq(
    text_position(calibri_with, "c"),
    text_position(calibri_without, "c"),
  )
}

///|
test "XLSX with-font rejects unreadable font bytes" {
  let workbook = fixture_workbook(metrics_fixture_workbook)
  for font in [b"", b"not a font, really"] {
    let error = try {
      let _ = convert_plain_with_font(workbook, font)
      ""
    } catch {
      InvalidXlsxInput(message) => message
      @sfnt.InvalidFont(message) => message
      _ => "unexpected error"
    }
    assert_true(error != "")
  }
}

///|
test "XLSX no-font conversion is unchanged" {
  let metrics = convert_plain_no_fonts(
    fixture_workbook(metrics_fixture_workbook),
  )
  assert_eq(metrics.bdf, fixture_workbook(metrics_no_font_bdf))
  let calibri = convert_plain_no_fonts(
    fixture_workbook(calibri_fixture_workbook),
  )
  assert_eq(calibri.bdf, fixture_workbook(calibri_no_font_bdf))
  let defaults = convert_plain_no_fonts(
    fixture_workbook(defaults_fixture_workbook),
  )
  assert_eq(defaults.bdf, fixture_workbook(defaults_no_font_bdf))
}

///|
/// Synthetic workbook with normal, wrapped and explicit-height rows.
let row_metrics_workbook = "UEsDBBQAAAAIADd+bV1Vm1sOiQAAANYAAAAPAAAAeGwvd29ya2Jvb2sueG1sjY9BDoJADEWvQnoACy5cTICVN/AEIxRnAp1O2iF6fFFk7+r/5v+85rdP0fkuMlcvXpJ1EErJDtGGQOztJJnSlkyi7Mt26gMtK/nRAlHhBc91fUH2McFOcPoPQ6YpDnSVYWVKZYcoLb5ESRZiNujb7wf7aZU8Uwe3j2+gUhfHDrQB7Fs8inhs6d9QSwMEFAAAAAgAN35tXZG+OlFXAAAAqAAAABoAAAB4bC9fcmVscy93b3JrYm9vay54bWwucmVsc7MJSs1JLMnMzyvOyCwotrNB5ip4ptgqFQWXVOakFisphFQWpNoqVegXw/iJRempJbZKEL5eRW6Okj42/YYIreX5RdnFGampJQjdcKFifTBlCDNIH9VhAFBLAwQUAAAACAA3fm1djnjTYJEAAADxAAAADQAAAHhsL3N0eWxlcy54bWx9T70OwiAQfpULL4B1piQuTRycdOhK6qEkQJtyKPXphWKNk8vd93O/ItBi8XxHJCn06CnAMEZPLWtYFaTwyiE8lG3ZCWk2Q4DOJIozMi5FeFWraQrjtWNNQYoBre31d+Q+j0wafHSdo+O1ZTsGpbJC/s8ENU12OVhz8w6389RG4Tmr6YJp1csZSefw2Z7Rz5NvUEsDBBQAAAAIADd+bV2bTjAz0QAAAN0BAAAYAAAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1slZHBbsMgDIZfBfkB6jRpd5gI0qQdeu+hZ5SwghogAlfp49chGtupUpEw/Lb+T8bIJaZbtsaQePgp5B4s0fyJmAdrvM67OJvAlZ+YvCaW6Yp5TkaPxeQnbJvmA712AZQc4pRLFN6FHvYgvH6Uc3Ej2R6OIIZ7pugvm94DKombrQC/NWklU1xEWqsMWy9fTKAeXJhcMGdKnHfsIKUlEgNWgQNvNlZ3W90tiFy6eJvRVUb3msFL1PACeABhmdA1v4M4GXddM39vPbzfLf6bHdYfVU9QSwECFAMUAAAACAA3fm1dVZtbDokAAADWAAAADwAAAAAAAAAAAAAAgAEAAAAAeGwvd29ya2Jvb2sueG1sUEsBAhQDFAAAAAgAN35tXZG+OlFXAAAAqAAAABoAAAAAAAAAAAAAAIABtgAAAHhsL19yZWxzL3dvcmtib29rLnhtbC5yZWxzUEsBAhQDFAAAAAgAN35tXY5402CRAAAA8QAAAA0AAAAAAAAAAAAAAIABRQEAAHhsL3N0eWxlcy54bWxQSwECFAMUAAAACAA3fm1dm04wM9EAAADdAQAAGAAAAAAAAAAAAAAAgAEBAgAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1sUEsFBgAAAAAEAAQABgEAAAgDAAAAAA=="

///|
/// Synthetic workbook with wrapping runs of different font sizes.
let rich_row_metrics_workbook = "UEsDBBQAAAAIAAx/bV1Vm1sOiQAAANYAAAAPAAAAeGwvd29ya2Jvb2sueG1sjY9BDoJADEWvQnoACy5cTICVN/AEIxRnAp1O2iF6fFFk7+r/5v+85rdP0fkuMlcvXpJ1EErJDtGGQOztJJnSlkyi7Mt26gMtK/nRAlHhBc91fUH2McFOcPoPQ6YpDnSVYWVKZYcoLb5ESRZiNujb7wf7aZU8Uwe3j2+gUhfHDrQB7Fs8inhs6d9QSwMEFAAAAAgADH9tXZG+OlFXAAAAqAAAABoAAAB4bC9fcmVscy93b3JrYm9vay54bWwucmVsc7MJSs1JLMnMzyvOyCwotrNB5ip4ptgqFQWXVOakFisphFQWpNoqVegXw/iJRempJbZKEL5eRW6Okj42/YYIreX5RdnFGampJQjdcKFifTBlCDNIH9VhAFBLAwQUAAAACAAMf21djnjTYJEAAADxAAAADQAAAHhsL3N0eWxlcy54bWx9T70OwiAQfpULL4B1piQuTRycdOhK6qEkQJtyKPXphWKNk8vd93O/ItBi8XxHJCn06CnAMEZPLWtYFaTwyiE8lG3ZCWk2Q4DOJIozMi5FeFWraQrjtWNNQYoBre31d+Q+j0wafHSdo+O1ZTsGpbJC/s8ENU12OVhz8w6389RG4Tmr6YJp1csZSefw2Z7Rz5NvUEsDBBQAAAAIAAx/bV3Tgquc0QAAAFoBAAAYAAAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1sbVDRagMhEPwV2Q/oJoXmIahQ6AcU+tDnjbE96amHu82Ffn1Xj4Y8FJbRcXbGVbvW9sVTjGKueS7sYBJZjogcppiJH+oSiyoftWUSpe0TeWmRzsOUZ3zc7Q6YKRXwNtSZB5qcioM9mEzXsa7pLJODJzDhm6Xm943vAb3FzTYCX0jI21ZX07qqYX3zrAk8csRBKnMq8U2aqkl9TetVgX/MhWbt2kLH2XjVkRcK0YGOzbFdIngiY1F60z/2w53dn07mr24O7Ldi6KSuineD4+07/S9QSwECFAMUAAAACAAMf21dVZtbDokAAADWAAAADwAAAAAAAAAAAAAAgAEAAAAAeGwvd29ya2Jvb2sueG1sUEsBAhQDFAAAAAgADH9tXZG+OlFXAAAAqAAAABoAAAAAAAAAAAAAAIABtgAAAHhsL19yZWxzL3dvcmtib29rLnhtbC5yZWxzUEsBAhQDFAAAAAgADH9tXY5402CRAAAA8QAAAA0AAAAAAAAAAAAAAIABRQEAAHhsL3N0eWxlcy54bWxQSwECFAMUAAAACAAMf21d04KrnNEAAABaAQAAGAAAAAAAAAAAAAAAgAEBAgAAeGwvd29ya3NoZWV0cy9zaGVldDEueG1sUEsFBgAAAAAEAAQABgEAAAgDAAAAAA=="
