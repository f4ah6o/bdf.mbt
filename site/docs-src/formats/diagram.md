# Visio・draw.io

Visio と draw.io（diagrams.net）の図は、線で結んだ図形を、作図ツール自身がページに分けて管理しているものです。BDF はこの構造を崩さず、ファイルの中の 1 ページを BDF の 1 ページにし、ビューアはタブで切り替えます。PDF に書き出したときのように 1 本のページの連なりに敷き直すことはしません。

## 試してみる

[ビューア](https://shibukawa.github.io/bdf/viewer/)にファイルをドロップするか、サンプルを試してください。Visio の図面（[shapes.vsdx](https://shibukawa.github.io/bdf/viewer/?file=samples/shapes.vsdx)）、3 ページの draw.io の図（[multipage.drawio](https://shibukawa.github.io/bdf/viewer/?file=samples/multipage.drawio)）、[AWS の構成図](https://shibukawa.github.io/bdf/viewer/?file=samples/aws.drawio)、[ラベルに数式のある図](https://shibukawa.github.io/bdf/viewer/?file=samples/math.drawio)などです。

## Visio（.vsdx）

`converter/visio` は Visio 2013 以降のパッケージ（.vsdx、.vsdm、.vstx、.vstm）を、1 つの ShapeSheet モデルに読みます。Visio 2003〜2010 の XML 図面（.vdx、.vtx）と、バイナリの .vsd 形式は読みません。

前景ページごとに 1 ページを作り、大きさはそのページ自身の用紙幅と縮尺から決めます。背景ページ（Visio の図面は背景ページを連鎖させられます）は共有の背景レイヤーになり、それを使うすべてのページで 1 回だけ描いて使い回します。図形は持たないセルをマスターとそのスタイルから継承し、動的テーマが決めるセルはテーマと図形のクイックスタイルから解決します。色、線・塗りのスキーム、コネクタとして扱われる図形が使うコネクタ専用のスキームも同様です。ジオメトリの各行、塗りのパターン、グラデーション、線種、45 種すべての矢印を描き、Visio がファイルには保存せずコネクタのルーティングから求める線の飛び越しも同じ手順で計算します。テキストは PowerPoint の変換器と同じ DrawingML のテキストエンジンでレイアウトし、フォントはサブセットの WOFF2 として埋め込みます。

`converter/visio` に `-param` オプションはありません。

詳細は[design.md §3.8](../design.md#38-visio--bdf-変換器convertervisioの構造)を参照してください。

## draw.io

`converter/drawio` は draw.io 自身の SVG や PDF の書き出しを経由せず、図の mxGraphModel XML から直接 BDF の命令を作ります。読むのは `.drawio` ファイル（draw.io が圧縮したページも）と、図を埋め込んだ `.drawio.svg` / `.drawio.png` の書き出しです。

ページごとに BDF の 1 ページを作るので、ビューアは表計算ソフトのシートと同じようにタブでページを切り替えます。draw.io のレイヤーはページのレイヤー Object に、ページへのリンクは `#view=` リンクになります。セルの配置、エッジの経路（直交・エルボーなどの mxGraph のエッジスタイルと図形の外周）、図形・矢印・ステンシル、HTML ラベルの折り返しと書式は draw.io（mxGraph）自身の描画処理をそのまま移植したものです。draw.io は計算したエッジの経路をファイルに保存しないため、これがそのまま描画の見た目を決めます。ステンシルライブラリ（flowchart、basic、arrows、AWS、BPMN、ネットワーク図など）は draw.io 自身のステンシル XML から埋め込み、フォントは PowerPoint と同じ方法でサブセットを埋め込みます。AWS の図は現行の AWS アイコンで描き、古い世代のアイコンで描かれた図も現行の対応するアイコンに置き換えて描きます。数式の組版を有効にすると（`math=1`）、ラベルの LaTeX を Word や PowerPoint の数式と同じエンジンで組みます。手書き風の表示（`sketch=1`）は、手書き風にはせず通常の描画にします。

| オプション | 値 | 既定 |
|---|---|---|
| `-param border=` | 各ページの図のまわりの余白（ピクセル） | `10`（`0` で余白なし） |

詳細は[design.md §3.11](../design.md#311-drawio--bdf-変換器converterdrawioの構造)を参照してください。

### draw.io のラベルの数式

「その他 → 数式組版」をオンにした図（モデルに `math="1"`）では、draw.io が MathJax に渡すのと同じ区切りの LaTeX を組みます。`$$ … $$` と `\[ … \]` は独立した行、`\( … \)` は行の中です。バッククォートの AsciiMath は組まずに警告を出します。

```xml
<mxGraphModel math="1">
  <root>
    <mxCell id="2" value="解は \(x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}\)" style="rounded=1;whiteSpace=wrap;html=1;" vertex="1" parent="1">
      <mxGeometry x="40" y="40" width="260" height="60" as="geometry"/>
    </mxCell>
  </root>
</mxGraphModel>
```

サンプルは [`converter/drawio/testdata/math.drawio`](https://github.com/shibukawa/bdf/blob/main/converter/drawio/testdata/math.drawio) です。組み方は [Word・HTML・Markdown の数式](document.ja.md#数式)と同じです。
