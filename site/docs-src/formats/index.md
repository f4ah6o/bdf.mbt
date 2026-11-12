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
| 図 | Visio（.vsdx）、draw.io、Mermaid（.mmd）、Excalidraw（.excalidraw） | [Visio・draw.io・Mermaid・Excalidraw](diagram.md) |
| CAD の図面とプロット | AutoCAD DXF、Jw_cad（.jww）、SXF、CGM、HP-GL/2 | [CAD の図面とプロット](cad.ja.md) |
| 紙の文書 | DocuWorks(`.xdw`)・バインダー(`.xbd`) | [DocuWorks](xdw.ja.md) |
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
| DocuWorks | `converter/xdw` | .xdw, .xbd |
| InDesign | `converter/idml` | .idml |
| draw.io | `converter/drawio` | .drawio, .dio, .drawio.svg, .drawio.png |
| Mermaid | `plugin/adapters/mermaid`（プラグイン） | .mmd, .mermaid |
| Excalidraw | `plugin/adapters/excalidraw`（プラグイン） | .excalidraw, .excalidraw.json |
| AutoCAD DXF | `converter/dxf` | .dxf |
| Jw_cad | `converter/jww` | .jww |
| SXF | `converter/sxf` | .p21, .p2z, .sfc |
| CGM | `converter/cgm` | .cgm, .cgz |
| HP-GL/2 | `converter/hpgl` | .plt, .hpgl, .hgl, .hpg, .hp2, .rtl |
| Windows メタファイル | `converter/emf` | .emf, .wmf |
| TIFF | `converter/tiff` | .tif, .tiff |
| HTML | `converter/html` | .html, .xhtml, .mhtml |
| Markdown | `converter/markdown` | .md, .markdown, .mdown, .mkd, .mdx |
| フォントファイル | `converter/font` | .ttf, .otf, .ttc, .otc, .woff, .woff2 |
| 画像 | `converter/image` | .png, .jpg, .gif, .webp, .avif, .bmp, .ico, .svg |
| 音声ファイル | `converter/audio` | .mp3, .m4a, .m4b, .aac, .flac, .ogg, .oga, .opus, .wav, .aif, .aiff |

Mermaid と Excalidraw は `converter/*` の MoonBit パッケージではなく、JavaScript のプラグイン API のアダプタです。`bdf.mbt/workers/plugin` の既成の Worker が両方を登録し、このサイトのビューアも図の 2 つだけを登録したプラグイン Worker を使います。Mermaid は静的なフローチャートの一部、Excalidraw は基本図形・矢印・プレーンテキストだけで、Mermaid 本体や Excalidraw の描画エンジンとの互換性はありません。読める範囲と対象外は[図の形式](diagram.md)に書いています。

プリント基板（Gerber・Excellon、KiCad）、楽譜（MML・MIDI・MusicXML）、EPUB は、この移植の対象から外しました。変換器のソースとフィクスチャはリポジトリに残していますが、保守対象ではなく、公開する変換器の一覧にも含めていません。音声ファイルの再生と、プリント基板以外の CAD（DXF・Jw_cad・SXF・CGM・HP-GL/2）は引き続き対象です。

各パッケージの `-param` オプションは `go run ./cmd/bdf generate -h` の一覧と、それぞれの形式のページに載せています。各変換器が書き出すコンテナ形式は[フォーマット仕様](../spec.md)を、その作りになっている理由は[設計メモ](../design.md)を参照してください。
