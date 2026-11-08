# 対応形式

BDF は、入力ごとに `converter/` 以下の別パッケージが変換を担います。プログラムが扱えるのは、リンクした形式だけです。

```go
import (
	"github.com/shibukawa/bdf/converter"
	_ "github.com/shibukawa/bdf/converter/pdf" // すべての形式なら converter/all
)

res, err := converter.ConvertFile("in.pdf", "", &converter.Options{}) // "" で形式を判別
```

形式は可能な限り入力の中身から判別します。Markdown はどんなテキストにも見えるので `.md`・`.markdown` 拡張子から決めます。パスワード付きの入力は `Options.Password` で開きます。`res.Protected` が「パスワードが要った」ことを示したら、出力も同じパスワードで暗号化します（[パスワードと保護モード](../architecture/protection.ja.md#パスワード付きの入力と暗号化)を参照）。

## カテゴリ別

| カテゴリ | 形式 | ページ |
|---|---|---|
| 文書 | PDF、Illustrator（.ai） | [PDF・Illustrator](pdf.ja.md) |
| ワープロ | Word（.docx）、HTML、Markdown | [Word・HTML・Markdown](document.ja.md) |
| プレゼンテーション | PowerPoint（.pptx） | [PowerPoint](presentation.ja.md) |
| ページレイアウト | InDesign（.idml） | [InDesign](layout.ja.md) |
| 表計算 | Excel（.xlsx）、CSV・TSV、Apache Parquet | [Excel・CSV・Parquet](spreadsheet.ja.md) |
| 図 | Visio（.vsdx）、draw.io | [Visio・draw.io](diagram.ja.md) |
| CAD の図面とプロット | AutoCAD DXF、Jw_cad（.jww）、SXF、CGM、HP-GL/2 | [CAD の図面とプロット](cad.ja.md) |
| 電子回路 | Gerber・Excellon（プリント基板）、KiCad | [プリント基板・KiCad](electronics.ja.md) |
| 本 | EPUB | [EPUB](ebook.ja.md) |
| 音楽 | MML、MIDI、MusicXML | [楽譜](music.ja.md) |
| 音声 | MP3、AAC（M4A、ADTS）、FLAC、Ogg Vorbis・Opus、WAV、AIFF | [音声ファイル](audio.ja.md) |
| フォント | TrueType・OpenType・WOFF・WOFF2 | [フォントファイル](font.ja.md) |
| 画像・デザイン | PNG・JPEG・GIF・WebP・AVIF・BMP・ICO・SVG、Photoshop、TIFF、Windows メタファイル | [画像・Photoshop](image.ja.md) |

## すべての入力形式

| 形式 | パッケージ | 拡張子 |
|---|---|---|
| PDF | `converter/pdf` | .pdf |
| Illustrator | `converter/ai` | .ai |
| Photoshop | `converter/psd` | .psd, .psb |
| PowerPoint | `converter/pptx` | .pptx, .pptm, .ppsx, .ppsm, .potx, .potm |
| Excel | `converter/xlsx` | .xlsx, .xlsm, .xltx, .xltm |
| CSV・TSV | `converter/csv` | .csv, .tsv, .tab |
| Apache Parquet | `converter/parquet` | .parquet, .parq, .pqt |
| Word | `converter/docx` | .docx, .docm, .dotx, .dotm |
| Visio | `converter/visio` | .vsdx, .vsdm, .vstx, .vstm |
| InDesign | `converter/idml` | .idml |
| draw.io | `converter/drawio` | .drawio, .dio, .drawio.svg, .drawio.png |
| AutoCAD DXF | `converter/dxf` | .dxf |
| Jw_cad | `converter/jww` | .jww |
| SXF | `converter/sxf` | .p21, .p2z, .sfc |
| CGM | `converter/cgm` | .cgm, .cgz |
| HP-GL/2 | `converter/hpgl` | .plt, .hpgl, .hgl, .hpg, .hp2, .rtl |
| Gerber・Excellon | `converter/gerber` | .gbr など、.drl、.xln、または基板の ZIP |
| KiCad | `converter/kicad` | .kicad_sch, .kicad_pcb, .kicad_pro、またはプロジェクトの ZIP |
| Windows メタファイル | `converter/emf` | .emf, .wmf |
| TIFF | `converter/tiff` | .tif, .tiff |
| HTML | `converter/html` | .html, .xhtml, .mhtml |
| Markdown | `converter/markdown` | .md, .markdown, .mdown, .mkd, .mdx |
| EPUB | `converter/epub` | .epub |
| MML | `converter/mml` | .mml |
| MIDI | `converter/midi` | .mid, .midi, .smf, .kar, .rmi |
| MusicXML | `converter/musicxml` | .musicxml, .mxl |
| フォントファイル | `converter/font` | .ttf, .otf, .ttc, .otc, .woff, .woff2 |
| 画像 | `converter/image` | .png, .jpg, .gif, .webp, .avif, .bmp, .ico, .svg |
| 音声ファイル | `converter/audio` | .mp3, .m4a, .m4b, .aac, .flac, .ogg, .oga, .opus, .wav, .aif, .aiff |

各パッケージの `-param` オプションは `go run ./cmd/bdf generate -h` の一覧と、それぞれの形式のページに載せています。各変換器が書き出すコンテナ形式は[フォーマット仕様](../spec.md)を、その作りになっている理由は[設計メモ](../design.md)を参照してください。
