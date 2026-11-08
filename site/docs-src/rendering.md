# 描画する

変換した文書と、LaTeX・MathML で書いた数式を、3 つの描画先に描く方法です。

| 描くもの | Go の `image.Image` | Ebitengine | ブラウザの Canvas |
|---|---|---|---|
| 文書のページ | [`raster/imagebdf`](#文書を-imageimage-に描く) | [`imagebdf` で描いた画像を `ebiten.Image` にする](#文書を-ebitengine-で描く) | [`@bdfkit/viewer`、`@bdfkit/render`](#文書をブラウザの-canvas-に描く) |
| 数式 | [`formula` → `imagebdf.Object`](#数式を-imageimage-に描く) | [`formula` → `raster/ebitenginebdf`](#数式を-ebitengine-で描く)（ベクターのまま） | [`formula` → 1 ページの BDF → `@bdfkit/render`](#数式をブラウザの-canvas-に描く) |

描き手はどれも同じ命令列（[spec §7](spec.md)）を実行します。

- **`raster/imagebdf`** — 純 Go のソフトウェアラスタライザ。文書のページ、範囲、単体の Object を `*image.RGBA` に描く
- **`raster/ebitenginebdf`** — パスだけの Object を Ebitengine の `vector` パッケージで描く。Ebitengine に依存するので別モジュール
- **`@bdfkit/render`** — ブラウザの Canvas 2D に描く TypeScript のパッケージ。`@bdfkit/viewer` はその上のビューア

## 文書を描く

### 文書を image.Image に描く

```go
import (
	"image/png"

	"github.com/shibukawa/bdf"
	"github.com/shibukawa/bdf/raster/imagebdf"
)

r, err := bdf.OpenSingleFile("report.bdf") // 変換した結果なら res.Doc をそのまま使う
if err != nil {
	return err
}
defer r.Close()
doc, err := r.ToDocument()
if err != nil {
	return err
}

ren := imagebdf.New(doc, nil)
img, err := ren.Page(doc.Views[0], 0, 2) // 1 ページ目を 1 単位 2 画素で。*image.RGBA
if err != nil {
	return err
}
err = png.Encode(w, img)
```

- `Page` は fixed・flow View のページ、`Region` はページの一部、scroll View の連続した範囲、シートの範囲を描きます。
- 名前で参照するフォント（HTML・Markdown・EPUB）と、埋め込みフォントにない字は `Options` の `FontFS`・`FontDirs` とシステムのフォントから探します。
- 描けなかったものは `ren.Warnings()` に入ります。サムネイルなら [`thumbnail`](api.md#go-サムネイルとページの画像thumbnailimagebdf) が切り抜き方まで決めます。

コマンドなら `bdf render -page 1 -scale 2 report.bdf page1.png` です。

### ラスタライズの品質と速度

`imagebdf.Options.Antialias` で図形・文字・幾何クリップの境界のアンチエイリアスを明示的に選べます。`Page`、`PageDPI`、`PageSize`、`Region`、`Object`、`SVGImage` に適用され、dpi や倍率による自動切り替えはありません。

| モード | 描画 |
|---|---|
| `imagebdf.AntialiasDefault`（ゼロ値） | 解像度によらず、従来どおりアンチエイリアスを使う |
| `imagebdf.AntialiasOn` | 同じアンチエイリアスを明示的に使う |
| `imagebdf.AntialiasOff` | 各行の画素中心を 1 回判定し、整数画素の区間を塗る。境界の被覆率計算を省いて速度を優先する |

高解像度の印刷用画像なら `AntialiasOff` を選び、最終出力サイズで小さい文字や細い罫線を比較できます。

```go
ren := imagebdf.New(doc, &imagebdf.Options{Antialias: imagebdf.AntialiasOff})
img, err := ren.PageDPI(doc.Views[0], 0, 600)
```

CLI では `bdf render -antialias=off -scale 8.333333 report.bdf print.png`（600 dpi）です。`-antialias=default|on|off` は `render` で指定でき、`thumbnail` と変換時に生成するプレビューは従来のアンチエイリアスを使います。Go のサムネイルは `thumbnail.Options.Raster.Antialias` で明示的に選べます。

キャンバス全体を舐めるパス（背景、広い面の塗り、大きなクリップの積、大きなパスの走査、描き終えたページの画像への変換）は、マシンのコア数まで最大 8 本の goroutine に行の帯で分けて進めます。`Pages` では worker の数で分配します。画素は 1 本で描いたときと同じです。

### モノクロの出力

黒で印刷するなら、`PageMono`・`RegionMono`・`PagesMono` に `Mono` を渡すと、RGBA の代わりに 4 分の 1 以下の大きさの画像を速く作れます。

| `Mono` | 画像 | 画素 |
|---|---|---|
| `imagebdf.Gray` | `*image.Gray` | 各画素を白の上に置いた輝度（`image/color` のグレー変換と同じ Rec. 601 の重み）を丸めたもの |
| `imagebdf.Bilevel` | 黒と白（黒が先）の `*image.Paletted`。`image/png` は 1 画素 1 bit で書く | グレー値が 128 未満なら黒 |

```go
ren := imagebdf.New(doc, &imagebdf.Options{Antialias: imagebdf.AntialiasOff})
img, err := ren.PageMono(doc.Views[0], 0, 600.0/72, imagebdf.Bilevel) // *image.Paletted
```

ページは `Page` と同じに描いて最後に変換するので、境界はアンチエイリアスの設定で決まります。`AntialiasOff` なら 2 値画像は描画そのもので、アンチエイリアスありなら境界の被覆率を半分で切ります（ディザはしません）。画像は RGBA のものと別に完成画像のキャッシュに入ります。CLI では `bdf render -mono=gray|bilevel` で、1 ページでも `-pages` のバッチでも、PNG か TIFF（8 bit または 1 bit）、JPEG（グレーで）、WebP（カラーで）に書けます。

元の半透明、ブレンド、画像の補間、ソフトマスク、ぼかしは引き続き適用します。効果の元になる図形は選択したモードで描くため、その画素も変わることがあります。1 画素より細い線も従来どおり 1 画素幅と薄い alpha で描くため、境界のアンチエイリアスを切っても、すべての出力画素が不透明になるわけではありません。低解像度では段差や細部の欠落が見えることがあるので、固定の dpi 閾値に頼らず出力用途に応じて選んでください。Go で未知の `AntialiasMode` 値を渡した場合は AA を有効にしてレンダラの警告に記録し、CLI は未知の値をエラーにします。

### 帯に分けて描く

600 dpi のページは 3500 万画素で、キャンバスだけで 560 MiB（1 画素 16 バイト）、RGBA の画像でさらに 140 MiB を使います。`PageRows` はページを上から行の帯に分けて描き、描けた帯からコールバックに渡すので、帯 1 つ分のメモリでページをファイルに書けます。

```go
f, _ := os.Create("print.png")
w := bufio.NewWriter(f)
width, height, _ := imagebdf.PagePixels(v, 0, 600.0/72)
enc, _ := rowenc.NewPNG(w, width, height, rowenc.Bilevel, &rowenc.Options{DPI: 600})
err := ren.PageRows(v, 0, 600.0/72, imagebdf.Bilevel, func(y0 int, rows image.Image) error {
	return enc.WriteRows(rows) // y0 行目からの行の *image.Paletted
})
// 続けて enc.Close()、w.Flush()、f.Close()
```

コールバックは帯の最初の行番号と、その行の画像（`Bounds()` はページのその行で、`Min.Y` が `y0`）を受け取ります。`Mono` が 0 なら `*image.RGBA`、それ以外は `Mono` の画像です。画像は後の帯で使い回すので、取っておくならコピーしてください。2 つ目以降の帯は最大 8 本まで並列に描き（worker ごとに描くものをデコードします）、コールバックは順に呼びます。`PagesRows` は選んだページを順に同じように描きます。画素は `Page`・`PageMono` と同じです。各帯はページ全体の変換行列のまま、その帯の行と、ページの影が届くだけ上下の余白を足したキャンバスに描き（影が余白を越える帯は、越えた分の余白で描き直します）、帯をまたぐ文字列はまとめてラスタライズして次の帯のために取っておきます。

`Options.BandRows` が帯の行数です（既定は `DefaultBandRows` の 128 行。A4 の 600 dpi でキャンバス 10 MiB）。ページの命令列は帯ごとに流し直しますが、最初の帯で各描画命令の範囲を記録し、以降の帯では範囲外の命令を飛ばすので、帯で描いても全体を一度に描くのとほぼ同じ速さです。2 つ目以降の帯は worker ごとのキャンバスで並列に描きます。`Options.BandWorkers` が同時に描く帯の数で、0 ならマシンのスレッド数（最大 8。キャンバスの合計が `MaxBandCanvases` の 96 MiB に収まる範囲）、1 なら帯 1 つ分のメモリで順に描きます。worker は文字マスクを共有し、描く画像はそれぞれデコードするので、大きな画像のページは worker の数だけデコード済みの複製を持ちます。ぼかしの大きい影のあるページは、影が届く分（600 dpi で数百行）だけ帯が高くなります。帯のグループ・ソフトマスク・クリップはページ分ではなく帯分のメモリを使い、画像は完成画像のキャッシュには入れません。

キャンバスは全体でも帯でも遅延初期化です。背景色を書かずに背景として始まり、描画が届いた所から 64 画素のブロック単位で書きます。描かれなかった所（ページの大半）は書きも読みもせず、画像への変換が背景を書くので、文字のページは背景を全面に塗る場合に比べてメモリを舐める量がごく小さくなります。

`image/rowenc` は届いた行から PNG と TIFF を書くパッケージで、3 種類の画像（`RGBA`・`Gray`・`Bilevel`）を扱います。PNG は zlib で圧縮して 1 MiB ごとの IDAT に、TIFF は非圧縮の 1 ストリップでディレクトリを先に書くので、どちらもシークしません。PNG の行は固定の行数（約 256 KiB 分）のチャンクごとに goroutine でフィルタと圧縮をします（`Options.Threads`。0 はマシンのスレッド数で最大 8）。ストリームはチャンクのストリームを sync flush で区切って並べたもので 1 本として復号でき、goroutine の数によらず同じファイルになります。zlib レベル 9 の 600 dpi グレーのページは 1 本で圧縮する場合の 4 分の 1 の時間で済みます。`bdf render -compression=fast|normal|best` でレベル（1・6・9）を選べ、既定は印刷や変換の中間ファイル向けの `fast` です。レベル 1 と 6 はほぼ同じ大きさで、レベル 9 はその 2 分の 1〜3 分の 1 になる代わりに 1.5〜2 倍の時間がかかります。RGBA の PNG は、まだ来ていない行が不透明か分からないので、ページが不透明でも RGBA のカラータイプで書きます（`image/png` は不透明なら RGB で書きます）。どちらもデコードすると全体を描いた画素になり、帯で書いたページのファイルは全体を一度に書いたファイルとバイト単位で同じです。

`PlaceRows` は、ページを用紙の画像の上に置いて帯で描きます。印刷のためのもので、`Place` が用紙の画素数、倍率、四分の一回転の回数、置く位置、左右・上下の鏡映（両面の裏面を裏返して受けるプリンタのため）を決め、用紙のページの外は背景です。影のずれはページと一緒に回り、鏡映されます。用紙と同じ大きさで回さず原点に置けば、`PageRows` と同じ画素です。`print/raster` はこの帯から PWG Raster を書き、`bdf print` が PDF を受けないプリンタに使います。

CLI は出力が PNG か TIFF（`.png`、`.tif`）なら既定で帯に分けて描きます。`bdf render -mono=bilevel -scale 8.333333 report.bdf print.tif` は 600 dpi のページを約 70 MiB で書きます（全体を一度に描くと 1.1 GiB）。`-band=N` で帯の行数を、`-workers` で同時に描く帯の数を変え、`-band=0` なら全体を一度に描きます。JPEG・WebP の出力も全体を一度に描きます。

### 再描画のキャッシュとページ並列化

同じ `Renderer` を使い続けると、`Page`・`PageDPI`・`PageSize`・`Region`・`Renderer.Object` の完成画像と、文字列全体の被覆率を再利用します。画像は独立したコピーを返すため、呼び出し側で画素を書き換えてもキャッシュは変わりません。初回は画像の保持用コピーが増えます。返却画像を一度しか使わない場合は `ImageCacheBytes: -1` で無効にできます。

`Options.ImageCacheBytes` は既定64MiB、`TextCacheBytes` は既定32MiB。0は既定値、負数は無効、正数はバイト単位の上限です。LRUで古い項目を除き、配列・キー・項目の見積もり容量を計上します。デコード済みフォント、作業用画像、Goのallocatorの管理領域は別です。文字キャッシュは塗り色・透明度・影を保存せず、被覆率だけを再利用するので、それらの描画状態は各回適用されます。

`Options.CanvasCacheBytes`（既定 64MiB、負数は保持しない）は、次の描画のために取っておく作業用キャンバス（描く画像と開いているグループの 1 画素 16 バイト）の上限で、同じだけ大きなマスクの被覆率も塗りから塗りへ取っておきます。600 dpi のページのキャンバスは数百 MB あり、ページごとに作り直すと OS へ返して再び割り当てる分だけ余計にかかります。`Page` で順に描くならこの上限内で再利用し（ページ 1 枚分、たとえば `1 << 30` を指定）、`Pages` は上限によらずバッチの間は worker ごとにキャンバスを 1 枚保持して、終わったら上限まで減らします。

ページのレイアウト・領域・画素サイズ・背景・AA方式は画像キーに含みます。Partのバイト列や `FontFS` を変更したら `ren.Invalidate()` を呼んでください。警告、デコード済み資源、両キャッシュ、ページworkerも解放します。`FontDirs` とシステムフォントは従来どおりプロセス共通の索引・読込キャッシュを使うため、差し替えるフォントには `FontFS` を使います。単独の `imagebdf.Object` は1回用です。Objectを再利用するには文書へ追加し、`ren.Object(hash, scale)` を呼びます。

複数ページには `Pages` / `PagesDPI` が使えます。ページ番号は0始まり、`nil` は全ページ。独立workerで描き、callbackは指定順に呼び出します。

```go
err := ren.PagesDPI(ctx, doc.Views[0], nil, 300, 0,
    func(page int, img *image.RGBA) error {
        return savePage(page, img)
    })
```

worker数0は自動（最大4）、1〜16は上限指定です。大きなページでは同時に描く基本canvasの合計32M画素を目安に数を減らし、それより大きい1ページは単独で描きます（A4 の 600 dpi はこれに当たり、代わりにページ内のパスを goroutine に分けます）。workerは呼び出し間で再利用し、文字マスクの容量上限と作業画像の保持枠を共有・分配します。layerやcallbackで保持する出力画像の容量は別です。キャンセルやcallbackエラーは描画・バッチの区切りで反映し、開始済み描画の終了を待って戻ります。callback内も含め、呼び出しが戻るまでRenderer・文書・フォント資源を変更しないでください。複数workerで使う `FontFS` は並行読み取りに対応する必要があります。

CLIでは `bdf render -pages=all -workers=4 -antialias=off report.bdf 'page-{page}.png'`。`-pages=1-3,5` も使え、出力名の `{page}` を1始まりのページ番号へ置換します。`-page` とは併用できず、シートは対象外です。CLIは完成画像を1回で書き出すため、その保持用キャッシュを省き、文字マスクを再利用します。

### 文書を Ebitengine で描く

文書のページはテキスト、画像、グラデーション、クリップを含むので、`imagebdf` で画像にしてから `ebiten.Image` にします。

```go
import (
	"github.com/hajimehoshi/ebiten/v2"

	"github.com/shibukawa/bdf/raster/imagebdf"
)

// 起動時、またはページを切り替えるとき
v := doc.Views[0]
scale := float64(screenHeight) / float64(v.Pages[0].H) // 画面の高さに合わせる
img, err := imagebdf.New(doc, nil).Page(v, 0, scale)
if err != nil {
	return err
}
page := ebiten.NewImageFromImage(img)

// Draw の中
var op ebiten.DrawImageOptions
op.GeoM.Translate(20, 20)
screen.DrawImage(page, &op)
```

画像なので、拡大するとぼけます。表示する大きさが変わったら、その倍率で描き直してください。

### 文書をブラウザの Canvas に描く

ページの配置、スクロール、ズーム、テキストの選択まで要るなら `@bdfkit/viewer` を使います（[フロントエンドに組み込む](integrating-to-frontend.ja.md)）。自分の canvas に 1 ページだけ描くなら `@bdfkit/render` の `PageRenderer` です。

```ts
import { BdfDocument, fetchSingle } from "@bdfkit/core";
import { PageRenderer } from "@bdfkit/render";

const doc = await BdfDocument.open(await fetchSingle("/documents/report.bdf"));
const renderer = new PageRenderer(doc, {}, document.fonts);

const page = doc.manifest.views[0].pages![0];
const scale = devicePixelRatio; // 1 単位あたりのデバイスピクセル
const canvas = document.querySelector<HTMLCanvasElement>("#page")!;
canvas.width = Math.ceil(page.w * scale);
canvas.height = Math.ceil(page.h * scale);
canvas.style.width = `${page.w}px`;
await renderer.renderPage(canvas.getContext("2d")!, page, { scale });
```

メインスレッドを止めたくない場合は、Worker で描く `BdfWorkerClient` を使います（[API 一覧](api.md#typescript-bdfkitrender)）。

## 数式を描く

`github.com/shibukawa/bdf/image/formula` は、LaTeX か MathML の数式を組み、**パスだけの Object**（グリフの輪郭、分数や根号の線）にします。フォントを参照しないので、パスを描ける描き手ならどれでも描けます。変換器が Word・PowerPoint・Excel・HTML・EPUB・Markdown・draw.io の数式を組むのと同じエンジンです。

```go
import (
	"github.com/shibukawa/bdf"
	"github.com/shibukawa/bdf/image/formula"
)

ts, err := formula.New(nil) // 同梱の STIX Two Math で組む
if err != nil {
	return err
}

f := formula.ParseTeX(`x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}`)
l := ts.Layout(f, formula.Style{
	Size:    24,                 // 文字の大きさ。結果の座標も同じ単位
	Display: true,               // ディスプレイスタイル（独立した行の数式）
	Color:   bdf.RGB(0, 0, 0),   // 省略すると黒。\textcolor などが上書きする
})

obj := l.Object() // *bdf.Object。原点はベースラインの左端、y は下向き
```

| 名前 | 内容 |
|---|---|
| `formula.New(*Options) (*Typesetter, error)` | 組版器。`Options.Math` は数式フォント（MATH 表を持つ TrueType・OpenType。省略すると同梱の STIX Two Math）、`Options.Text` は数式フォントにない字（`\text{}` の中の日本語など）のためのフォント。並行して使える |
| `formula.ParseTeX(src) *Formula` | LaTeX の数式モード（amsmath・amssymb の命令）。失敗しない。知らない命令はテキストとして残す |
| `formula.ParseMathML(src) (*Formula, error)` | `src` の最初の `math` 要素（Presentation MathML）。`display="block"` は `Formula.Display()` でわかり、`Layout` もディスプレイスタイルで組む |
| `(*Formula).Text()` / `(*Layout).Text()` | 線形表記（`x=(−b±√(b^2−4ac))/(2a)`）。代替テキスト、検索、コピー用 |
| `(*Typesetter).Layout(f, Style) *Layout` | 組む。`Style` は `Size`、`Display`、`Color`、`Bold` |
| `(*Layout).Width()` / `Height()` / `Depth()` | 送り幅、ベースラインから上、ベースラインから下。行の中に置くときに使う |
| `(*Layout).Ink()` | 実際に描く範囲（斜体のはみ出しやアクセントで箱より広いことがある） |
| `(*Layout).Object()` | パスだけの Object。境界は `Ink()` |
| `(*Layout).Draw(obj, x, y)` | 既存の Object に、ベースラインの左端を (x, y) にして描き足す |
| `(*Layout).Document(margin)` | 余白つきの 1 ページの文書。ページのテキストは線形表記 |

同梱の STIX Two Math は SIL Open Font License 1.1 で、`formula` を import したプログラムはこのフォントを含みます（[フォントとライセンス](licenses.ja.md)）。

どのフォントにもない字は描かれません（幅だけ空きます）。日本語などを使うときは `Options.Text` にフォントを渡してください。

### 数式を image.Image に描く

```go
import "github.com/shibukawa/bdf/raster/imagebdf"

img, err := imagebdf.Object(obj, 2, nil) // 1 単位 2 画素。*image.RGBA、背景は透明
if err != nil {
	return err
}
// img.Bounds() は原点（ベースラインの左端）からの画素。
// 行のベースラインが (x, y) なら、画像の左上は (x+Min.X, y+Min.Y) に置く
b := img.Bounds()
draw.Draw(dst, b.Add(image.Pt(x, y)), img, b.Min, draw.Over)
```

背景を塗るなら `&imagebdf.Options{Background: color.White}` を渡します。

### 数式を Ebitengine で描く

`raster/ebitenginebdf` は Object をパスのまま描くので、どの大きさでも輪郭がぼけません。

```sh
go get github.com/shibukawa/bdf/raster/ebitenginebdf
```

```go
import (
	"github.com/hajimehoshi/ebiten/v2"

	"github.com/shibukawa/bdf"
	"github.com/shibukawa/bdf/image/formula"
	"github.com/shibukawa/bdf/raster/ebitenginebdf"
)

// 起動時に 1 度だけ組んでコンパイルする
ts, _ := formula.New(nil)
l := ts.Layout(formula.ParseTeX(`e^{i\pi} + 1 = 0`), formula.Style{Size: 48, Color: bdf.RGB(255, 255, 255)})
drawing, err := ebitenginebdf.Compile(l.Object())
if err != nil {
	return err
}

// Draw の中
func (g *Game) Draw(screen *ebiten.Image) {
	var opts ebitenginebdf.DrawOptions
	opts.GeoM.Scale(g.zoom, g.zoom)  // 拡大・回転しても輪郭は滑らか
	opts.GeoM.Translate(40, 120)     // Object の原点（ベースラインの左端）を置く場所
	opts.ColorScale.ScaleAlpha(0.8)  // 色と透明度を掛ける
	opts.AntiAlias = true
	drawing.Draw(screen, &opts)
}
```

- `Compile` は Object を `vector.Path` にします。毎フレーム呼ぶのは `Draw` だけです。同じ `GeoM` で描き続ける間は、変換したパスも使い回します。
- 描けるのは単色のパスの塗りと線だけです。テキスト、画像、グラデーション、クリップ、グループ、マスク、破線を含む Object は `*ebitenginebdf.UnsupportedError` になります。数式の Object は常に描けます。
- ゲームの文字色に合わせるなら、白で組んでおいて `ColorScale` で色を付けます。
- パスの描画は画像の描画より重いので、たくさんの数式を大きさを変えずに出すなら、`imagebdf.Object` で画像にして `ebiten.NewImageFromImage` に渡すほうが軽くなります。

動くサンプルは [`raster/ebitenginebdf/example`](https://github.com/shibukawa/bdf/tree/main/raster/ebitenginebdf/example) にあります（文書のページと数式を並べて描きます）。

```sh
cd raster/ebitenginebdf
go run ./example
```

### 数式をブラウザの Canvas に描く

サーバーで数式を 1 ページの BDF にして返し、ブラウザは文書と同じ方法で描きます。数式 1 つで 2〜3 KB ほどです。

```go
// GET /formula?tex=...
func handler(w http.ResponseWriter, r *http.Request) {
	l := ts.Layout(formula.ParseTeX(r.URL.Query().Get("tex")), formula.Style{Size: 20, Display: true})
	w.Header().Set("Content-Type", "application/octet-stream")
	l.Document(8).WriteSingle(w) // 余白 8 単位のページ
}
```

```ts
import { BdfDocument, fetchSingle } from "@bdfkit/core";
import { PageRenderer } from "@bdfkit/render";

const tex = String.raw`x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}`;
const doc = await BdfDocument.open(await fetchSingle(`/formula?tex=${encodeURIComponent(tex)}`));
const page = doc.manifest.views[0].pages![0];
const scale = devicePixelRatio;
const canvas = document.querySelector<HTMLCanvasElement>("#formula")!;
canvas.width = Math.ceil(page.w * scale);
canvas.height = Math.ceil(page.h * scale);
canvas.style.width = `${page.w}px`;
await new PageRenderer(doc, {}, document.fonts).renderPage(canvas.getContext("2d")!, page, { scale });
```

ページは白い紙に描かれます。ページのテキストは線形表記なので、`@bdfkit/viewer` で開けば検索、コピー、読み上げもできます。

## 文書の中の数式

Word・PowerPoint・Excel の Office Math、HTML・EPUB の MathML、Markdown・draw.io の LaTeX は、変換器が同じエンジンで組んで文書に入れます。こちらはパスではなく、埋め込んだ数式フォントのテキストとして描きます（文書全体でグリフを共有するため）。書き方のサンプルは[対応形式](formats/index.ja.md)の各ページ、仕組みは[変換と出力 → 数式](architecture/conversion.ja.md#数式)にあります。
