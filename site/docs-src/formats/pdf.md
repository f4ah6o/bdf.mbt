# PDF・Illustrator

PDF のページは文書のモデルではなく描画命令の並びなので、BDF も PDF ビューアと同じ読み方をします。段落や表を推測して復元するのではなく、内容ストリームを BDF 自身の命令セットに置き換えるだけです。Illustrator の `.ai` はこの延長にあります。Illustrator 9 以降の `.ai` は PDF に Illustrator 独自のデータを添えたものなので、BDF は同じ PDF 変換器で読み、アートボードをページとして扱います。

## 試してみる

[ビューア](https://shibukawa.github.io/bdf/viewer/)にファイルをドロップするか、サンプルを試してください。[PDF](https://shibukawa.github.io/bdf/viewer/?file=samples/demo.pdf)、[reportlab で作った 3 ページの PDF](https://shibukawa.github.io/bdf/viewer/?file=samples/reportlab-master.pdf)、[3 つのアートボードを持つ Illustrator ファイル](https://shibukawa.github.io/bdf/viewer/?file=samples/artboards.ai)です。

## PDF（`converter/pdf`）

`converter/pdf` は埋め込みフォント（TrueType、CFF、OpenType、Type1）を、実際に使うグリフだけの WOFF2 に組み直します。組み直す前に OS/2 の埋め込み許諾（`fsType`）を確認し、元の著作権表示は引き継ぎます。繰り返し使われるフォーム XObject は共有オブジェクトになり、テキストは検索可能な run になり、各ページの先頭にある共通部分（繰り返すヘッダー・ロゴ・フッターなど）はページごとに格納せず 1 つの共有オブジェクトに切り出します。ソフトマスク（フェード、ドロップシャドウ、Chrome の CSS `mask-image` の裏にあるマスク）はビットマップに焼き込まず、ビューアが描きます。ブラウザが自分では扱えない JPEG 2000 と JBIG2 の画像は、BDF 自前の純 Go デコーダを通します。埋め込まれていない CJK フォントの文字は Adobe の定義済み CMap（Shift_JIS、EUC、UCS-2 など）で読み、縦書き（`WMode 1`）は縦の行として配置します。オプショナルコンテンツ（レイヤー）は、ビューアが文書を最初に開いたときに見える状態に固定し、非表示のレイヤーは描きません。タグ付き PDF の構造ツリーは、BDF の読み上げ用 MARK（見出し、段落、リスト、セルの結合を持つ表、代替テキスト付きの図、言語）になります。

PDF の各ページは既定で BDF の 1 ページ（`fixed` View）になります。`-kind flow` を指定すると、Word と同じ flow View になり、ビューアはページ表示だけでなく連続スクロールとしても見せられます。

| オプション | 値 | 既定 |
|---|---|---|
| `-kind` / `-param kind=` | `fixed`、`flow` | `fixed` |
| `-param box=` | `crop`、`media`、`bleed`、`trim`、`art` | `crop` |
| `-no-share` / `-param no-share=` | `true`: ページ共通の先頭部分を共有オブジェクトにしない | 共有する |

詳細は[design.md §3.1](../design.md#31-pdf--bdf-変換器converterpdfの構造)を参照してください。

## Illustrator .ai（`converter/ai`）

「PDF 互換ファイルを作成」（Illustrator 9 以降は既定でオン）で保存した Illustrator ファイルは、PDF に Illustrator 独自のデータを添えたものです。この独自データは非公開のストリームに入っていて、PDF 部分からは参照されません。`converter/ai` は上の PDF 変換器で PDF 部分を描き、独自データはまったく読みません。PDF の各ページが 1 つのアートボードで、BDF はページが持つより大きいメディアボックスやブリードボックスではなく、トリムボックス（裁ち落としを除いたアートボードそのもの）に切り抜きます。Illustrator のレイヤーは通常の PDF のオプショナルコンテンツと同じ形で保存されているので、非表示のレイヤーは普通の PDF と同じ理由で描かれません。

「PDF 互換ファイルを作成」をオフにして保存したファイルには、その旨を伝える 1 ページだけの PDF しか入っていません。Illustrator 8 以前の PostScript ベースの `.ai` には PDF がそもそもありません。どちらも、描くには Illustrator 独自のネイティブ形式を読む必要があるため、変換せずにエラーとして報告します。

| オプション | 値 | 既定 |
|---|---|---|
| `-param box=` | `trim`、`bleed`、`media`、`crop`、`art` | `trim`（裁ち落としを除いたアートボード） |

詳細は[design.md §3.17](../design.md#317-illustrator--bdf-変換器converterai)を参照してください。
