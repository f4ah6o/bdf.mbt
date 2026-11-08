# PowerPoint

PowerPoint のスライドは DrawingML でできている。図形やテキストの run、表が、レイアウトとマスターから継承した位置や書式のもとに配置されるので、スライドごとの見た目は 1 枚のビットマップ画像ではない。BDF はこの DrawingML を直接読む。Office の PDF 書き出しを経由しないので、マスターとレイアウトの共有、段落や箇条書きの構造が BDF ファイルにそのまま残る。

## 試す

ファイルを[ビューア](https://shibukawa.github.io/bdf/viewer/)にドロップするか、サンプルを試せる: [PowerPoint のデッキ](https://shibukawa.github.io/bdf/viewer/?file=samples/features.pptx)、[数式のスライド](https://shibukawa.github.io/bdf/viewer/?file=samples/math.pptx)。

## PowerPoint（.pptx）

`converter/pptx` は OPC の zip パッケージ（.pptx、.pptm、.ppsx、.ppsm、.potx、.potm）を読み、DrawingML を BDF の描画命令に直接落とす。XML は型付きの構造体ではなく汎用の要素木として読む。DrawingML には省略可能な要素と多段の継承が多いためだ。OPC パッケージと要素木の読み込み（`converter/internal/ooxml`）は Excel・Word・Visio の変換器と共有し、DrawingML の描画そのもの（`converter/internal/ooxml/drawingml`）は Excel の図形やグラフとも共有する。

読み込むもの:
- スライドマスター、レイアウト、スライド。各スライドは最大 4 レイヤーのページになる: `background`（スライド → レイアウト → マスターの順で最初に見つかった背景）、`master` レイヤー 2 枚（マスター自身の図形、続いてレイアウトの図形）、`body`（スライド自身の図形）。同じマスターとレイアウトを使うスライドは同じマスター・レイアウトの Object になるので、1 回だけ格納される。
- プレースホルダーの継承: スライドのプレースホルダーは、対応するレイアウトのプレースホルダー（`idx`、次に種類で対応付け）から位置・形状・塗り・線・効果・テキストスタイルを継承し、レイアウトのものはさらにマスターから継承する。
- ECMA-376 が定義する 187 種のプリセット図形、カスタムジオメトリ、グラデーション・画像・パターンの塗り、線の端・結合・破線・矢印、影。
- テキストのレイアウトは BDF 自身が行う（ブラウザには任せない）: 和文の禁則に従う行分割、インデントと箇条書き（Wingdings・Symbol の記号も含む）、タブ、行間・段落間隔、揃え、自動調整、段組み、縦書き（`vert`、`vert270`、`eaVert`）。
- 表（PowerPoint の組み込みテーブルスタイル付き）とグラフ（縦棒・横棒、折れ線、面、円・ドーナツ、散布図。キャッシュされた値から描く）、SmartArt 自身の描画パート、埋め込まれた EMF/WMF の図（画像として格納せず、元の GDI の描画命令として再生する）。
- Office Math で書かれた数式（同じファイルが一緒に保存しているフォールバック画像は無視する）は、Word・Excel・HTML と同じ数式エンジンで組む。
- フォントは Word・Excel と同じ手順で解決する: 実際のフォント → 計量互換の代替 → 汎用フォントの順で探し、実際に使った文字だけを WOFF2 のサブセットとして埋め込む。

レイアウト: スライドの順に 1 スライド 1 ページになる。非表示のスライドは既定で除く（指定すれば含める）。タイトルは見出しに、箇条書きのレベルは入れ子のリストに、表と図形・画像・グラフは代替テキスト付きの表と図として読み上げ用のテキスト層に載る。グラフのデータは文書の表としても持ち、図がその id を指す（[spec §4.6](../spec.md#46-データ表tables)、`bdf tables`）。テンプレートの既定の言語タグのままでは誤読されるところは、文字種から言語を推定して直す。

オプション（`-param`。`bdf generate -h` の内容）:

| オプション | 値 | 既定 |
|---|---|---|
| `-param hidden=` | `true` | 非表示スライドを除く |
| `-param data=` | `none` | グラフのデータを文書の表として持つ（[bdf tables](../architecture/cli.ja.md#tables-table)） |

`-hidden` は `-param hidden=true` の短縮形（Excel の `-hidden` も非表示シートに同じことをする）。`-pages` で変換するスライドを選べ、フォント関連の一般オプション `-font-dir`、`-fonts system`、`-no-subset`、`-no-woff2`、`-no-system-fonts`、`-ignore-fstype` は Word・Excel と同じように PowerPoint にも効く。

詳細は [design.md §3.4](../design.md#34-powerpoint--bdf-変換器converterpptxの構造) を参照。

### テンプレートとして穴埋めする

図形や表の文字に `{{名前}}` のタグを書いたプレゼンテーションは、帳票のテンプレートとしてデータで穴埋めできる（`bdf fill`、`pptx.Fill`）。スライドが固定のページになり、値を入れた文字の収まりは PowerPoint の自動調整の規則で決め直し、行が増えて収まらなくなった表は複製したスライドに続く。書き方は[帳票を作る](../forms.ja.md#powerpoint-のテンプレート)を参照。

### 数式

PowerPoint の「挿入 → 数式」で入れた数式は、段落の中の Office Math（`a14:m` の中の `m:oMath`）として保存されています。同じファイルが持つフォールバックの画像ではなく、この Office Math から組むので、拡大しても輪郭がぼけず、検索とコピーでは線形表記のテキストになります。

```xml
<a14:m>
  <m:oMath>
    <m:sSup><m:e><m:r><m:t>e</m:t></m:r></m:e><m:sup><m:r><m:t>iπ</m:t></m:r></m:sup></m:sSup>
    <m:r><m:t>+1=0</m:t></m:r>
  </m:oMath>
</a14:m>
```

サンプルは [`converter/pptx/testdata/math.pptx`](https://github.com/shibukawa/bdf/blob/main/converter/pptx/testdata/math.pptx) です。組み方は [Word・HTML・Markdown の数式](document.ja.md#数式)と同じです。
