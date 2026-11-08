# 変換と出力

変換器どうしが共有する仕組みと、変換した文書から作るもの。どの形式でも同じように働くので、形式ごとのページではなくここにまとめます。

## 数式

Word の Office Math、PowerPoint と Excel の数式（代替として保存された画像ではなく Office Math から組む）、HTML と EPUB の MathML（KaTeX・MathJax・Wikipedia が独自の描画の横に置く MathML も含む）、Markdown と draw.io のラベル（`math=1`）の LaTeX を、1 つの数式エンジンで組みます。OpenType MATH のフォント（STIX Two Math、Cambria Math、Latin Modern Math など）の定数と異体字を使い、分数、根号、添字と極限、大型演算子、大きな異体字と部品の組み立てで伸びる括弧と根号、行列、揃えた数式、アクセントを扱います。検索とコピーでは `x=(−b±√(b^2−4ac))/(2a)` のような線形表記になります（ハイフンマイナスで打っても見つかります）。詳細は[design.md §3.23](../design.md#323-数式internalmathlayoutconverterinternalequationformula)を参照してください。

同じエンジンは公開パッケージ `image/formula` から単体でも使えます。LaTeX か MathML の数式をパスだけの Object にし、画像、Ebitengine の画面、ブラウザの Canvas に描けます（[描画する](../rendering.ja.md#数式を描く)）。

## 楽譜と演奏

MML・MIDI・MusicXML は変換器が五線譜に組みます。View はその音楽を Standard MIDI File として、演奏の時刻とページの上の位置を結ぶ cue と一緒に持ちます（[spec §4.4](../spec.md#44-演奏play)）。デモビューアは Web Audio API で演奏します（General MIDI の音色の系統ごとのオシレーター、合成した打楽器、チップチューンの MML の矩形波）。演奏している段にカーソルを示し、それに合わせてページをめくり・スクロールします。段をクリックすると、そこから演奏します。詳細は[design.md §3.27](../design.md#327-楽譜と演奏convertermmlconvertermidiconvertermusicxmlconverterinternalmusic)を参照してください。

音声ファイルの View も同じ `play` で鳴りますが、Standard MIDI File の代わりにファイルそのものを持ちます。ビューアはそれをブラウザの `<audio>` 要素に渡すので、変換器もビューアも音をデコードしません。cue はミリ秒で、カードの上の行を指します。歌詞が時刻を持っていればその行（ID3 の `SYLT`、歌詞のフィールドに入った LRC のテキスト）、なければ章です。ビューアは歌っている行を示し、行をクリックするとそこから鳴らします。詳細は[design.md §3.31](../design.md#331-音声ファイル--bdf-変換器converteraudio)を参照してください。

## メタデータ

manifest に Dublin Core のメタデータ（題名・作成者・主題・言語・作成日時など）を持てます。PDF の文書情報、PowerPoint・Excel・Word のコアプロパティ、Visio の文書プロパティ、Photoshop の文書の XMP メタデータ、HTML の meta 要素、Markdown の front matter、EPUB のパッケージ文書、画像の XMP・EXIF・IPTC、音声ファイルのタグ（ID3、iTunes 形式の MP4 メタデータ、Vorbis コメント、RIFF INFO）などから引き継ぎます。

## サーバー側のサムネイルと検索用テキスト

`imagebdf` はビューアと同じ命令を純 Go で実行し、任意のページ（シートや scroll View なら任意の範囲）を画像に描きます。アンチエイリアスつきのパス、線、クリップ、グラデーションとパターン、画像、埋め込みフォント（WOFF2 を展開する）と名前で参照するフォント（システムのフォントを探す）のテキスト、グループ、ソフトマスク、影、SVG の画像を描きます。`thumbnail` は文書の種類からレイアウトを選びます。Word・HTML・Markdown・楽譜・縦長のページは 1 ページ目の左上の正方形（音声ファイルのカードも。その正方形はカバーアートです）、Excel・CSV は A1 から始まる範囲、スライド・図面・画像・EPUB の表紙は 1 ページ目の全体で、PNG・JPEG・WebP で書き出します。`Document.SearchText` は検索エンジン向けにメタデータとページごとのテキストを返します。`text/markdownbdf`（`bdf markdown`）は、`MARK` が持つ構造から文書を Markdown に書き出し、画像をその隣に置きます。文書は描画とは別に値の表（グラフのデータ、CSV・Parquet の行、Excel のシートのセル。[spec §4.6](../spec.md)）を Apache Parquet の Part として持つこともでき、`bdf tables` がその一覧を、`bdf table` が 1 つを CSV・JSON・Parquet で書き出し、`bdf markdown` はグラフの表を図の後に書きます。どちらも暗号化されないので、暗号化した文書については頼まれない限り（`-allow-plaintext`）書き出しません。詳細は[design.md §3.25](../design.md#325-サーバー側のサムネイルと検索用テキストimagebdfthumbnailsearchtext)を参照してください。

[サムネイル](https://shibukawa.github.io/bdf/thumbnail/)と[検索テキスト](https://shibukawa.github.io/bdf/text/)のページを試してみてください。ドロップしたファイルに対して、この同じコードを WebAssembly にしたもので実際に動かせます。
