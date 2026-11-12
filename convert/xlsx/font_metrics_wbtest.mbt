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
