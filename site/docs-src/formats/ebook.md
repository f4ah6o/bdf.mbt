# EPUB

EPUB は XHTML と CSS と画像を ZIP に入れたものなので、リフロー型の本は HTML の変換器とほぼ同じリーダー表示で組める。違うのは、本が読む順のある複数の文書（spine）からなること、読み手が求めるのは Web ページの帯ではなく本のページであること。加えて、日本語の本の多くが縦書きであること、マンガや写真集は文字を組まない固定レイアウトで作られていること——この 4 点である。`converter/epub` は EPUB 3 と EPUB 2 のどちらも読む。

## 試す

[ビューア](https://shibukawa.github.io/bdf/viewer/)にファイルをドロップするか、サンプルを試せる。[リフロー型の本](https://shibukawa.github.io/bdf/viewer/?file=samples/basic.epub)、[縦書きの日本語の本](https://shibukawa.github.io/bdf/viewer/?file=samples/vertical.epub)、[固定レイアウトの本](https://shibukawa.github.io/bdf/viewer/?file=samples/fixed.epub)。

## EPUB（converter/epub）

### リフロー型の本

`META-INF/container.xml` が指すパッケージ文書から、メタデータ・manifest・読む順（spine）を読む。文書は spine の順で処理し、リンクでだけ行く注のような `linear="no"` の文書は後ろに回す。それぞれの文書は Word のセクションと同じ「次のページから」のセクションになる。EPUB の XHTML は標準の HTML パーサーにかけると壊れる（空要素の `<a id="p5"/>` が後ろの段落を取り込んでしまうなど）ので、XML として読み、HTML の変換器と同じ形の木を作る。章をまたぐリンクは正しいページに解決され、画像は ZIP から直接読み込む。EPUB は外部の画像を許していないので、ネットワークからは取得しない。

本自身の CSS はほとんど読まない。レイアウト・色・書体はリーダー表示の既定のスタイルシートのままにする。例外は、本の読み方に関わる少数のプロパティだけで、`writing-mode`（後述）、縦中横、傍点、行揃え、`display: none`、そして画像の表示サイズ（全面の挿絵や、出版社が使う外字の画像に効く）である。MathML の数式は、Word や HTML と同じく BDF の数式エンジンで組む。

### 縦書きの日本語

章の書字方向は body の（無ければ html の）`writing-mode` から決める（出版社がよく使う `-epub-`・`-webkit-` 付きの書き方も読む）。それが無ければ Kindle の `primary-writing-mode`、それも無ければ言語と `page-progression-direction` の組み合わせから決める。縦書きの章は、Word の縦書きのセクションと同じ組み方になる。漢字・仮名は正立させ、句読点は縦書き用の字形にし、欧文は回転させ、短い横組みの文字列は縦中横にし、傍点を打つ。縦書きの日本語や右から読むマンガによくある右綴じの本は、`direction: "rtl"` の View になる（[spec §4.1](../spec.md#41-view-の種類)）。

### 固定レイアウトの本

`pre-paginated`（または Kindle の `fixed-layout`）が指定され、すべての文書が絵 1 つだけのページ（`img`、インラインの `svg`、SVG 文書、または spine に直接置かれた画像）である本は、組版エンジンを使わずに、画像 1 枚を 1 ページとして変換する。ページの大きさは文書の viewport のメタデータ（無ければ画像自身の大きさ、または SVG の viewBox）から決め、画像は縦横比を保って中央に配置する。文字を組んだページと画像だけのページが混ざる本は、警告を出してリフロー型として組み直す（そうした本によくある絶対配置の CSS までは解釈しない）。

### 数式

本文の XHTML の `math` 要素（MathML）は、HTML と同じ数式エンジンが組む。縦書きの章では、数式は横に組んだまま行の中に置く。

```html
<p>ピタゴラスの定理は <math><msup><mi>a</mi><mn>2</mn></msup><mo>+</mo><msup><mi>b</mi><mn>2</mn></msup><mo>=</mo><msup><mi>c</mi><mn>2</mn></msup></math> である。</p>
```

組み方は [Word・HTML・Markdown の数式](document.ja.md#数式)を参照。

### オプション

| オプション | 値 | 既定 |
|---|---|---|
| `views` | `pages`（本のページ）、`scroll`（横書きの 1 本の長い列）、`both` | `pages` |
| `paper` | `a5`、`a4`、`a6`、`b5`、`b6`、`letter`、または `幅x高さ`（mm） | `a5` |
| `size` | 文字の大きさ（ポイント） | `12` |
| `font` | 本文のフォントファミリー | インストール済みのゴシック体 |
| `mono` | コードのフォントファミリー | インストール済みの等幅フォント |
| `width` | scroll View の幅（ポイント） | 本文の全角 36 文字分 |

暗号化（DRM）された本は変換しない。内部の詳細は [design.md §3.24](../design.md#324-epub--bdf-変換器converterepubの構造) を参照。
