# フォルダ構成

## コア

| 場所 | 内容 |
|---|---|
| `*.go`, `cmd/bdf` | Go のエンコーダ・デコーダ・コンテナ I/O と CLI |
| `converter/` | 入力形式の登録と共通のオプション、形式の判別、ページ指定 |
| `converter/internal/` | Office 系・CAD の変換器が共有するもの（下記） |
| `raster/imagebdf/` | ページと単体の Object を純 Go で画像に描く（ビューアと同じ描き方）。ソフトウェアのラスタライザと、SVG の画像を描く SVG レンダラ |
| `raster/ebitenginebdf/` | パスだけの Object（数式など）を Ebitengine で描く。Ebitengine に依存するので独自の `go.mod` を持つ別モジュール。`raster/internal/shapes` は Object を塗りと線の図形の並びに展開する共通部分 |
| `image/formula/` | LaTeX・MathML の数式を組んでパスだけの Object にする公開パッケージ。数式フォント（STIX Two Math）を同梱 |
| `vector/pdfbdf/` | 文書を PDF に書き出す。命令列を内容ストリームに、文字を埋め込んだフォントの文字に、グループとソフトマスクを透明グループにする。影は `raster/imagebdf` で描いた画像にする。タグ付き PDF（`MARK` 命令から作る構造木）と PDF/A も書く |
| `text/markdownbdf/` | 文書を Markdown に書き出す。`MARK` 命令の構造をブロックに、フォントを強調とコードに、リンク、画像は本文の隣のファイルに、グラフの表は図の後の表に。PDF のページの柱とページ番号は省く |
| `encoding/parquet/` | 文書が描画とは別に持つ値の表（spec §4.6）の Apache Parquet の Part を読み書きする。書き手（平坦な列、PLAIN、非圧縮）と、BDF と一般的なツールが書くものの読み手。表の CSV・JSON |
| `print/` | プリンタに印刷する: 印刷指示（IPP の属性の名前のチケット）、送る形式の選択（PDF、受けなければ PWG Raster）、用紙の名前（PWG 5101.1）、ジョブを作って文書を流し、終わるまで待つ。`print/ipp` は IPP のメッセージの読み書き（RFC 8010）、クライアント、能力、mDNS の探索（DNS-SD）、`ipps` の証明書の指紋の記録。`print/fakeprinter` はテストのための偽のプリンタ（IPP・9100・LPD・シリアル・CUPS のサーバー、壊れ方の注入。CUPS の ipptool と ippeveprinter で確かめてある）、`print/fakeprinter/readback` は受けたものを絵に戻す。`tools/fakeprinter` はその農場（YAML、画面、API）。`print/raster` は PWG Raster の書き手（`raster/imagebdf` の帯から流す）と用紙への配置。`bdf print`・`bdf printers` が使う。`print/spool` はジョブと文書を 1 つのファイルに（yuruidb を通して）保存し、プリンタへ送り、見届け、送り直し、落ちた後を二重に刷らずに直す。`print/server` は `bdf printd` のプリントサーバー（設定、HTTP の API、トークン、イベント、メトリクス）、`print/server/client` はその Go のクライアント |
| `form/` | 帳票のテンプレートをデータで穴埋めする: データの読み込み、テンプレートの判別、データの JSON Schema、コンパイル済みテンプレート（.bdft）。`form/tag` は Office のテンプレート（Excel・Word・PowerPoint）のタグの読み手。`converter/pdfform` は入力欄のある PDF を、`converter/pdfme` は pdfme のテンプレートを埋める。[帳票を作る](../forms.ja.md)を参照 |
| `thumbnail/` | 文書のサムネイル。文書の種類によるレイアウトと、PNG・JPEG・WebP の書き出し |
| `internal/` | フォントの探索・計測・サブセット化（`fontdb`）、TrueType/OpenType の読み書きとグリフの輪郭（`sfnt`）、CFF の読み取りとサブセット化（`cff`）、OpenType のレイアウトテーブル GSUB・GPOS・GDEF の読み取り（`otlayout`）。数式の木・読み手（LaTeX、MathML、Office Math）・組版（`mathlayout`）と、Office の XML の木（`xmltree`）。変換器と `imagebdf` が共有する |
| `contrib/` | プラットフォームに寄るもの。`otf` は Unix と Windows でフォントファイルをメモリにマップして開き（それ以外では読み込む）、読んだ表とグリフのページだけを常駐させる。`fontdb` が読み込むフォントを開くのに使う |
| `font/woff2/` | TrueType/OpenType ↔ WOFF2（glyf 変換と Brotli） |
| `image/svg/` | SVG を読む公開パッケージ。スタイルシートを適用した要素の木と、属性の値（色・長さ・変換）。描くのは `raster/imagebdf` |
| `image/imgconv/` | 画像の格納方針（そのまま／WebP に変換）。純 Go の libwebp を同梱 |
| `image/barcode/` | QR コードとバーコード（JAN/EAN、UPC-A、Code 39、Code 128、GS1-128、ITF、NW-7）を、矩形のパスとして作る公開パッケージ。帳票のテンプレートの `{{%値 \| qr}}`・`barcode:種類` が使う |
| `fixture/` | テストと `bdf demo` が使うサンプル文書の生成（埋め込みフォント付き） |

## 変換器（入力形式ごとに 1 パッケージ）

| 場所 | 変換する形式 |
|---|---|
| `converter/pdf` | PDF |
| `converter/ai` | Illustrator（.ai）。PDF 変換器の上に |
| `converter/psd` | Photoshop（.psd, .psb） |
| `converter/pptx` | PowerPoint（.pptx） |
| `converter/xlsx` | Excel（.xlsx） |
| `converter/csv` | CSV・TSV（描画は `converter/xlsx`） |
| `converter/parquet` | Apache Parquet（描画は `converter/xlsx`。ファイルそのものを文書の表として持つ） |
| `converter/docx` | Word（.docx） |
| `converter/visio` | Visio（.vsdx） |
| `converter/idml` | InDesign（.idml） |
| `converter/drawio` | draw.io（.drawio / .drawio.svg / .drawio.png） |
| `converter/dxf` | AutoCAD DXF |
| `converter/jww` | Jw_cad（.jww） |
| `converter/sxf` | SXF（.p21, .p2z, .sfc） |
| `converter/cgm` | CGM（.cgm, .cgz） |
| `converter/hpgl` | HP-GL/2 のプロットファイル（.plt。HP-GL、PJL、PCL、HP RTL） |
| `converter/gerber` | Gerber・Excellon（と基板のファイルをまとめた ZIP） |
| `converter/kicad` | KiCad の回路図・基板・プロジェクト（とプロジェクトをまとめた ZIP） |
| `converter/emf` | Windows メタファイル（.emf, .wmf） |
| `converter/tiff` | TIFF（.tif, .tiff） |
| `converter/html` | HTML（.html, .xhtml, .mhtml）。リーダー表示 |
| `converter/markdown` | Markdown（HTML を経由） |
| `converter/epub` | EPUB（リフロー型の本はリーダー表示、固定レイアウトの本は画像のページ） |
| `converter/mml` | MML（.mml。汎用、マビノギ、PPMCK の方言）。楽譜にする |
| `converter/midi` | Standard MIDI File（.mid, .kar, .rmi）。楽譜にする |
| `converter/musicxml` | MusicXML（.musicxml, .mxl） |
| `converter/font` | フォントファイル（.ttf, .otf, .ttc, .woff, .woff2）。文字・グリフ・OpenType フィーチャーのプレビュー |
| `converter/image` | PNG・JPEG・GIF・WebP・AVIF・BMP・ICO・SVG（そのまま格納し、メタデータを読む） |
| `converter/audio` | MP3・M4A・FLAC・Ogg・WAV・AIFF（カバーアート・タグ・歌詞のカード。ファイルそのものも持ち、ビューアが再生する） |
| `converter/all` | すべての入力形式を登録する（副作用のために import する） |

`converter/internal/` には複数の変換器が共有するものが入っています: OOXML のパッケージと XML（`ooxml`）、DrawingML の図形・テキスト・表・グラフ（`ooxml/drawingml`）、テキストレイアウト用のフォント選択・計測・埋め込み（`fontset`。draw.io も使う）、組み立て中の Object（`canvas`。draw.io も使う）、EMF/WMF の再生（`metafile`）、ISO base media file format の箱（`isobmff`。AVIF の画像と M4A の音声）、CAD 図面のページへの描画（`cad`）、行分割の規則（`linebreak`）、場所の決まったフィールドに値を描く部分（`formbox`。PDF フォームと pdfme）、複合ファイル（`cfb`）とパスワード付き Office 文書の復号（`offcrypto`）。PDF 用の Adobe の定義済み CJK CMap（`cjkcmap`）と JPEG 2000・JBIG2 のデコーダ（`jpx`、`jbig2`）。TIFF の読み取りと CCITT の FAX 符号のデコーダ（`tiff`）。Word・HTML・Markdown・EPUB の組版エンジン（`wordproc`: 段落・表・ページ・scroll View）と、それらが共有する HTML・XHTML の読み込み（`webdoc`）。XMP メタデータの Dublin Core（`xmp`）。数式エンジン（`internal/mathlayout`）を文書のフォントで動かし、埋め込みフォントのテキストとして描く部分（`equation`）。MML・MIDI・MusicXML の楽譜の組版と演奏する音楽（`music`。Bravura の SMuFL の字形は `music/smufl`）。

## TypeScript のパッケージ

| 場所 | 内容 |
|---|---|
| `packages/core` | `@bdfkit/core` — デコーダ、コンテナ読み込み、テキスト抽出（依存なし） |
| `packages/render` | `@bdfkit/render` — Canvas レンダラ、ページ/連続/シート描画（scroll View は連続描画）、Worker とそのクライアント（SVG の画像は Worker がデコードできないのでメインスレッドが描く） |
| `cmd/bdfwasm` | ブラウザ内変換用に wasm にした変換器（PDF 用、Office 系用、HTML・Markdown・EPUB 用、画像用、変換器を持たないサムネイル・検索テキスト用のモジュール） |

## デモサイトとそのページ

| 場所 | 内容 |
|---|---|
| `examples/viewer` | フル機能のデモビューア（Worker による描画、読み上げ用のテキスト層、ページめくり） |
| `examples/common` | ビューアとサイトの残りが共有するもの（変換 Worker のクライアント、サイトの esbuild 補助） |
| `examples/miniviewer` | 埋め込み用の小さなビューア（下記のサンプルプロジェクトが使う） |
| `site/` | GitHub Pages で公開するサイト本体: トップページ、サムネイル・検索テキストのページ、ドキュメントの描画（`site/docs.mjs` がこのページを `docs/*.md` から作る） |
| `docs/` | このドキュメント（Markdown） |

## サンプルプロジェクト、CLI、テスト

| 場所 | 内容 |
|---|---|
| `examples/light-server`、`examples/preview-server`、`examples/search`、`examples/secure-reader` | BDF をシステムに組み込む方法ごとの小さな Go サーバー 4 つ。[構成のサンプル](../examples/index.ja.md)を参照 |
| `cmd/bdf` | `bdf` コマンド: `generate`、`fill`、`template`、`thumbnail`、`text`、`render`、`ls`、`manifest`、`disasm`、`extract`、`split`、`join`、`encrypt`、`decrypt`、`demo`。[BDF コマンド](cli.ja.md)を参照 |
| `tools/` | ソースが変わったときに手で実行する生成ツール群: Unicode のデータ、SMuFL の字形パス、draw.io のステンシルと AWS アイコンの対応表、テーブルスタイル、cmap、純 Go の WebP コーデックの生成テーブル |
| `testdata/` | 生成済みサンプル。CI でバイト単位に照合する |
| `test/` | ブラウザの機能テストと、各形式の `testdata/` を作るフィクスチャ生成スクリプト |

各パッケージが何を公開しているかは [API 一覧](../api.md)を、これらのビルド・テスト・再生成の方法は[ビルドとテスト](development.ja.md)を参照してください。
