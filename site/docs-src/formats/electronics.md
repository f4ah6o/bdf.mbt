# プリント基板・KiCad

プリント基板を扱う変換器は 2 つある。基板メーカーに渡す製造データ（Gerber と Excellon）を読む `converter/gerber` と、設計に使った KiCad のプロジェクトを読む `converter/kicad` である。どちらも層の抽象図ではなく、基材・銅箔・マスク・シルク・穴といった、基板の実際の見た目で描く。

## 試す

[ビューア](https://shibukawa.github.io/bdf/viewer/)にファイルをドロップするか、サンプルを試せる。基板の製造データなら[基板（Gerber と Excellon、ZIP）](https://shibukawa.github.io/bdf/viewer/?file=samples/board.zip)、KiCad のプロジェクトなら[KiCad プロジェクト（回路図と基板、ZIP）](https://shibukawa.github.io/bdf/viewer/?file=samples/demo.zip)。

## Gerber・Excellon（converter/gerber）

`converter/gerber` はプリント基板の製造データを読む。Gerber は X2 属性つきの拡張 Gerber（RS-274X）で、古いファイルが使う非推奨の命令も読む。アパーチャの定義を別ファイルに持つ RS-274-D は描けない。穴あけデータは Excellon で、KiCad・Altium・Eagle・EasyEDA などの方言を読む。1 枚の基板のファイル一式は基板メーカーに ZIP でまとめて渡すのが普通なので、ZIP に入ったファイルの組を 1 つの基板として変換する。1 つのファイルだけでも変換でき、その層の View になる。

すべての標準アパーチャとマクロのプリミティブ、両方の象限モードの円弧、クリアの極性を持つ領域、ステップ＆リピート、ブロックアパーチャとアパーチャの変換を描く。パッドは、グリフと同じように共有したパスの並びで描く。各ファイルがどの層か（表・裏・内層の銅箔、ソルダーマスク、シルク、ペースト、外形、穴）は、ジョブファイル、X2 属性の `TF.FileFunction`、それも無ければ KiCad・Altium（Protel）・Eagle・EasyEDA などのファイル名の付け方から決める。

ファイルが 2 つ以上あり、銅箔・マスク・シルクのどれかを含むときは、基板の表（`top`）と裏（`bottom`。裏から見るので左右反転）を実物の見た目で描く。基材、マスクの下の銅箔、マスクの開口から見えるパッドの仕上げ、シルク、穴を、基板の外形で切り抜いて重ねる。続けてファイルごとの View を、基板 CAD ツールの配色で暗い背景に描く。

| オプション | 値 | 既定 |
|---|---|---|
| `views` | `all`、`board`、`layers` | `all` — 基板の表と裏、続けてファイルごとの View |
| `mask` | `green`、`red`、`blue`、`black`、`white`、`yellow`、`purple`、`#rrggbb` | ジョブファイルのマスクの色、無ければ `green` |
| `silkscreen` | `white`、`black`、`yellow`、`#rrggbb` | ジョブファイルの色、無ければ `white` |
| `finish` | `gold`、`silver`、`copper` | ジョブファイルの仕上げ、無ければ `gold` |

内部の詳細は [design.md §3.21](../design.md#321-gerberexcellon--bdf-変換器convertergerberの構造) を参照。

## KiCad（converter/kicad）

`converter/kicad` は KiCad 6 以降の回路図（`.kicad_sch`）と基板（`.kicad_pcb`）を読む。KiCad 5 のファイル形式は「KiCad 6 以降で開いて保存し直す」よう案内して断る。入力は回路図や基板のファイル 1 つ、プロジェクトファイル（`.kicad_pro`）、プロジェクトをまとめた ZIP のいずれでもよい。

回路図は、シートのインスタンスをページとする 1 つの View になり、ページの順はページ番号の順である。同じシートを 2 か所で使う階層設計は 2 ページになり、それぞれが自分の部品番号（R101、R201 など）を持つ。シートの箱はそのページへのリンクになる。各ページは、用紙と図枠（KiCad の既定の図枠、またはプロジェクトが指定する `.kicad_wks`。題名欄とプロジェクトのテキスト変数を埋め込んだもの）の上に、KiCad の既定の色とプロジェクトの描画設定で描く。シンボルはユニットと代替のボディスタイル・ピンの形のまま描く。配線・バス・接合点・あらゆる種類のラベル・テキスト・テキストボックス・表・ハッチで塗った図形・画像・実装しない部品（DNP）の印も、KiCad の描き方をそのまま再現する。文字は KiCad 自身の線の字体 NewStroke で描く（CC0 の版を埋め込み、この版にない CJK の文字は TrueType のフォントで代える）。

基板は表から見た View（`front`）と裏から見た（鏡映した）View（`back`）に、KiCad の基板エディタと同じようにすべての層を重ねて描き、加えて層ごとの View も作る。階層の回路図が参照するシートや、プロジェクトが指定する図枠は別ファイルなので、入力自身のディレクトリ、ZIP の中、またはサーバーが入力と一緒に列挙するファイル（`converter.Options.Files`。`bdf generate -with`）から読む。

| オプション | 値 | 既定 |
|---|---|---|
| `views` | `all`、`schematic`、`board` | `all` — プロジェクトの回路図と基板 |
| `layers` | `all`、`board`、`layers` | `all` — 基板の表・裏・層ごとの View |

`-with` は、サーバーやコマンド実行時に入力と一緒に置かれていないファイル（階層回路図のシートや、プロジェクトファイル）を、入力からの相対パスで足すためのオプションである。

内部の詳細は [design.md §3.29](../design.md#329-kicad--bdf-変換器converterkicadの構造) を参照。
