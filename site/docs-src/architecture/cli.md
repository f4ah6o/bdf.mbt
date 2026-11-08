# bdf コマンド

```
bdf generate [flags] <input> <out.bdf | dir/>
                                   文書や図面を変換する（フラグと形式一覧は bdf generate -h）
bdf fill [flags] <template.xlsx | .docx | .pptx | .pdf | .json | .txt | .bdft> <out.bdf | out.txt | dir/>
                                   帳票のテンプレートをデータで穴埋めする: タグを書いた Office の文書、
                                   入力欄のある PDF、pdfme のテンプレート、テキストのテンプレート（フラグは bdf fill -h）
bdf template compile [flags] <template> <out.bdft>
bdf template schema [-json-schema] <template> [out.json]
                                   テンプレートを検査してコンパイル済みにする、タグが引く名前を書き出す
bdf pdf [flags] <file.bdf | dir> <out.pdf>
                                   ページを PDF に書き出す（フラグは bdf pdf -h）
bdf markdown [flags] <file.bdf | dir> <outdir>
                                   文書を Markdown にして、画像と一緒にディレクトリに書き出す
                                   （フラグは bdf markdown -h）
bdf print [flags] -printer <url | name> <file.bdf | dir | input>
                                   IPP のプリンタや CUPS のキューに、ドライバなしで印刷する
                                   （-server: プリントサーバーのキューに置く）
bdf printers [flags]               ネットワークの IPP プリンタ、CUPS のキュー（-cups）、
                                   1 台のプリンタができること（-url）、プリントサーバーの
                                   キューとプリンタ（-server）を一覧する
bdf printd -config <printd.yaml>   プリントサーバーを前面で動かす
bdf jobs [flags] [show | cancel | hold | release | retry | move | priority | password | accounting]
                                   プリントサーバーのジョブを一覧し、操作する
bdf thumbnail [flags] <file.bdf | dir | input> <out.png | .jpg | .webp>
                                   サムネイルを描く: 1 ページ目の上部、またはスライド全体
                                   （変換する入力なら 1 ページ目だけを変換する）
bdf text [flags] <file.bdf | dir> [out.json]
                                   検索用に、メタデータとページごとのテキストを書き出す
bdf render [flags] <file.bdf | dir> <out.png | .jpg | .webp>
                                   1 ページを描く（bdf thumbnail -h, text -h, render -h でフラグ一覧）
bdf ls <file.bdf | dir>            View と Part の一覧
bdf manifest <file.bdf | dir>      manifest を JSON で出力
bdf disasm <file.bdf | dir> <hash> Object Part を逆アセンブル
bdf extract <file.bdf | dir> <hash> <out>
bdf split <file.bdf> <dir>         分割形式で書き出す
bdf join <dir> <file.bdf>          1 ファイル形式で書き出す
bdf encrypt [-password-file f] <file.bdf | dir> <out.bdf | dir/>
                                   パスワードで文書を暗号化する
bdf decrypt [-password-file f] <file.bdf | dir> <out.bdf | dir/>
                                   暗号化を解いて書き出す
bdf sign -key key.pem -cert chain.pem [flags] <file.bdf | dir> [out.bdf]
                                   文書に署名を足す（CMS、X.509。前の署名の後に）
bdf verify [-roots roots.pem] <file.bdf | dir>
                                   文書の署名を確かめる
bdf demo <file.bdf | dir/>         フィクスチャ文書を書き出す（dir/ は末尾がスラッシュ）
bdf conformance [-testdata dir] <dir>
                                   他の読み手のための適合テストを書き出す（conformance パッケージ）
```

暗号化された文書は `$BDF_PASSWORD` のパスワードで読みます。`split` と `join` はパスワードなしで使え、文書の署名を保ちます。

## generate

1 つの入力を BDF に変換します。形式は入力の中身から判別するか、`-format` で明示します。出力は 1 ファイル、または末尾が `/` のディレクトリで分割形式になります。`-pages 1-3,5,8-` でページ・スライド・シート・アートボードを選び、`-thumbnail` と `-text` は出力と一緒にプレビューを書き出します（暗号化した出力には `-allow-plaintext` のときだけ）。`-dc 要素名=値` は Dublin Core の要素を上書きします（`-dc 要素名=` で削除）。入力形式ごとの `-param` オプションは[対応形式](../formats/index.ja.md)を、現在の完全な一覧は `bdf generate -h` を参照してください。

```sh
bdf generate report.pptx report.bdf              # 1 ファイル形式
bdf generate report.pptx out/                    # 分割形式
bdf generate -pages 1-3 book.pdf book.bdf         # 最初の 3 ページだけ
bdf generate -password-file pw.txt secret.xlsx out.bdf  # パスワード付きの入力
```

## fill, template

帳票のテンプレート（文字のところにタグを書いた Excel のブック、Word の文書、PowerPoint のプレゼンテーション、入力欄のある PDF、pdfme のテンプレート、帳票の行をタグつきで書いたテキストファイル）をデータで穴埋めします。形式は中身から判定します。書き方は[帳票を作る](../forms.ja.md)を参照してください。

```sh
bdf fill -data order.yaml -data items=lines.csv invoice.xlsx invoice.bdf   # 穴埋めして、印刷のページの文書に
bdf fill -data order.yaml notice.docx notice.bdf                           # Word の文書はページに、PowerPoint はスライドに
bdf fill -each orders.csv invoice.xlsx 'out/{{no}}.bdf'                    # レコードごとに 1 つずつ
bdf template compile -sample sample.yaml invoice.xlsx invoice.bdft         # 検査して、コンパイル済みテンプレートに
bdf template schema invoice.bdft                                           # タグが引く名前を JSON で
bdf template schema -json-schema invoice.xlsx                              # データの JSON Schema（入力フォームを作る元）
bdf fill -data applicant.json application.pdf application.bdf              # 入力欄のある PDF: 欄の場所に値を描く
bdf fill -data invoice.json pdfme-template.json invoice.bdf                # pdfme のテンプレート: pdfme の生成器と同じ規則で埋める
bdf fill -data order.json slip.txt slip.bdf                                # テキストのテンプレート: 行と桁の格子に文字を並べる
bdf fill -data order.json -param encoding=shift_jis slip.txt slip.txt      # テキストのテンプレートの帳票をプレーンテキストで
```

`-data` は JSON・YAML のオブジェクト（`file`）か、名前を付けた値（`name=file`。CSV・TSV やブックのシートはオブジェクトのリスト）で、繰り返し指定できます。`-strict` はデータにない名前のタグをエラーにし、`-files` はデータが名前で指す画像のディレクトリを決めます。フォントと画像のフラグ（`-font-dir`、`-no-system-fonts`、`-fonts`、`-images` など）と `-param`・`-pages` は `generate` と同じ意味です（`-pages` は、Excel ではシート、PowerPoint ではテンプレートのスライド、Word とテキストのテンプレートではできた帳票のページを選びます）。出力先が `.txt` で終わると、テキストのテンプレートの帳票をプレーンテキストで書きます。`-param encoding=`・`newline=crlf`・`paper=preprinted` が使えます（[テキストのテンプレート](../forms.ja.md#テキストのテンプレート)）。`.bdft` は BDF の文書なので、`ls`・`thumbnail`・`render` でそのまま開けます。

## pdf

文書のページを PDF に書き出します。文字は埋め込んだフォントの文字として、図形はベクタとして入ります（[PDF にする](../forms.ja.md#pdf-にする)）。

```sh
bdf pdf invoice.bdf invoice.pdf
bdf pdf -view print1 book.bdf sheet1.pdf            # ビューを選ぶ（繰り返せる）
bdf pdf -skip background -skip master slip.bdf slip.pdf   # レイヤーを役割で省く
bdf pdf -tagged report.bdf report.pdf               # タグ付き PDF: 文書の構造を持ち、スクリーンリーダーで読める
bdf pdf -pdfa 2a invoice.bdf invoice.pdf            # 保存用の PDF/A（2b、2u、2a、3b、3u、3a）
bdf pdf -sign-key alice.key -sign-cert alice-chain.pem -sign-field party_a.sign contract.bdf contract.pdf
                                                    # 署名した PDF（PAdES）。署名欄の絵の上に署名を見せる
```

`-sign-key` と `-sign-cert` は、PAdES の形でファイルに署名します（ファイルの署名以外のバイトに対する CMS の署名、`/SubFilter /ETSI.CAdES.detached`）。鍵と証明書は `bdf sign` と同じ形です。Acrobat などの PDF の読み手が検証できます。`-sign-field` は帳票の署名欄の絵（`{{%sign | signature}}`、PDF フォームの署名欄、pdfme の `signature`）の名前で、署名はその箱の上、手書きのサインに重ねて見えます。省くとどのページにも見えない署名になります。`-tsa` はタイムスタンプを足し（B-T）、`-certify 1|2|3` はその後に許す変更を決めた認証署名にします。`-sign-name`・`-sign-reason`・`-sign-location` は、署名が署名した人について言うことです。`-tagged` や `-pdfa` と一緒に使えます。`.bdf` の署名（`bdf sign`）は PDF に移りません。PDF に書き出す人が PDF に署名します。

既定では、ページのあるビュー（`fixed`・`flow`）をすべて書き出し、ページのない文書は全体を 1 ページにします。`-font-dir` と `-no-system-fonts` は、文書が名前で参照するフォントを探す場所です。`-ignore-fstype` は、埋め込みを許可していないシステムのフォントも埋め込みます（権利があるときだけ。既定ではその文字をアウトラインで描きます）。`-no-compression` はストリームを圧縮せずに書きます（中身を読むため）。暗号化した文書には `-allow-plaintext` が必要です（PDF は暗号化されません）。

## markdown

文書を Markdown としてディレクトリに書き出します。`<outdir>/<name>.md`（入力のファイル名）と、その隣にハッシュを名前にした画像ファイルが入ります。文書の `MARK` 命令が持つ構造（見出し、段落、リスト、見出しセル付きの表、代替テキスト付きの図。[spec §7.8](../spec.md)）が GitHub Flavored Markdown のブロックになり、太字・斜体のフォントは強調に、等幅フォントはコードに（等幅の行が続けばフェンスのコードブロックに）、`LINK` はリンクに、Dublin Core のメタデータは YAML の front matter になります。

```sh
bdf generate paper.pdf paper.bdf && bdf markdown paper.bdf paper/   # paper/paper.md と画像
bdf markdown -view sheet1 book.bdf out/                            # ビューを選ぶ（繰り返せる）
bdf markdown -keep-running report.bdf out/                         # 柱・フッター・ページ番号を残す
bdf markdown -skip none slides.bdf out/                            # マスター・背景・ヘッダー・フッターのレイヤーも残す
bdf markdown -internal-links book.bdf out/                         # 文書内へのリンク（#page=N）を残す
bdf markdown -tables files book.bdf out/                           # 表をすべて CSV ファイルにして隣に置く（シートも）
```

既定では、scroll ビューがあればそれを書き出します（Word・HTML・Markdown・EPUB の文書。同じ本文をページなしで組み直したもので、ページで途切れません）。なければ全ビューを書き、シートはシート名の見出しの下の 1 つの表になります。ヘッダー・フッター・マスター・背景のレイヤーは省きます（`-skip` で役割を選ぶ。`-skip none` で全部残す）。PDF のページが本文の中に持つ柱・フッター・ページ番号も省きます。2 ページ以上の上下の余白の同じ位置にある短い文字列と、余白に単独で置かれたページ番号がそれです（`-keep-running` で残す）。文書内へのリンクは Markdown に行き先がないので、`-internal-links` を付けなければ文字だけになります。構造タグのない PDF は、行の間隔とフォントから段落と見出しを推定します。引用・コード・リストの記号の種類は MARK の payload の語（[spec §7.8](../spec.md)）から取ります。Word・HTML・Markdown・EPUB・PowerPoint・タグ付き PDF の変換器がこれを書き、語のない文書では等幅フォントからコードを、描かれた記号からリストの種類を推定します。代替テキストのある図は、読み上げと同じくその文で書きます（画像があれば画像の alt に）。グラフは種類と題がその文になり、その後にデータの表が続きます（下の `tables` を参照）。表は 100 行までなら GitHub Flavored Markdown の表としてその場に、それより長ければ隣の CSV ファイルにしてリンクします（`-tables files` でシートの表も含めてすべてを CSV ファイルに、`-tables none` で書きません）。下線・取り消し線は描かれているだけで印がないので区別しません。暗号化した文書には `-allow-plaintext` が必要です（Markdown は平文です）。Go からは `text/markdownbdf` が同じことをします。

## tables, table

文書は、描画とは別に値の表を持てます（[spec §4.6](../spec.md)）。PowerPoint・Excel・Word のグラフのデータ、CSV ファイルの行、Parquet ファイルそのもの、Excel のブックの各シートの使用範囲（`sheet1`、`sheet2` …。列名は列の文字）とテーブル（`table-1` …。列名は見出し行）がそれです。表は Apache Parquet の Part で、manifest に列と型（`string`、`number`、`integer`、`boolean`、`date`、`datetime`、`other`）、題、表が属する図のビューとページとともに並びます。`bdf tables` がその一覧を書き、`bdf table` が 1 つを CSV・JSON・Parquet の Part そのもので書き出します。

```sh
bdf tables deck.bdf                                # chart-1: 4 rows × 4 columns (slides, page 3) …
bdf tables -json book.bdf                          # manifest の tables メンバー
bdf table deck.bdf chart-1                         # CSV を標準出力に
bdf table -format json -rows 10 book.bdf sheet1    # 先頭の行を JSON で
bdf table -format parquet book.bdf table-1 t.parquet   # Part をそのまま
```

変換器は Excel・CSV・Parquet の表を既定で 1 表あたり 1,048,576 行・64 MiB まで持ちます（Excel のセルの範囲は 16,777,216 セルまで）。`-param data=all` で上限を外し、`-param data=none` で持ちません。PowerPoint・Word の `data=none` はグラフの表を持たず、図の代替テキストが値を説明します。暗号化した文書には `-allow-plaintext` が必要です。Go からは `Reader.Table` が表の項目とバイト列を返し、`encoding/parquet` がそれを読み書きします。ブラウザでは preview モジュールの `tables` と `table` が同じことをします。

## print, printers

文書を IPP のプリンタに印刷します。OS のドライバは使いません。プリンタが PDF を受けるなら文書を PDF にして（図形はベクタのまま、文字はプリンタの解像度で）送り、PDF を受けず PostScript を受けるなら PostScript にし、どちらも受けないなら PWG Raster（IPP Everywhere の必須の形式）、Apple Raster（AirPrint）か PCLm（Mopria）にこちらで描いて送ります。macOS と Linux の CUPS のキュー（`ipp://localhost:631/printers/<名前>`）も同じように印刷できます。Windows は Windows Ready Print 以降、プリンタ自身が IPP で話すので、プリンタの URL を直接指定します。

```sh
bdf printers                                         # ネットワークの IPP プリンタ（mDNS）と、この機械の USB の IPP 機
bdf printers -url ipp://192.0.2.10/ipp/print         # 1 台ができること: 用紙、両面、色、解像度、形式 …
bdf printers -cups local                             # この機械の CUPS のキュー

bdf print -printer ipp://192.0.2.10/ipp/print invoice.bdf
bdf print -printer "Canon MF Series" -sides long -media b5 -copies 3 -mono invoice.bdf   # 名前で探す
bdf print -printer ipps://mfp.example.local/ipp/print -pages 1-3 report.xlsx            # 変換してから（Excel は印刷のページ）
bdf print -printer ipp://localhost:631/printers/office -format pwg-raster -mono -bilevel -resolution 300 slip.bdf
bdf print -printer ipp://192.0.2.10/ipp/print -skip background slip.bdf                 # 印刷済みの用紙に追い刷り
bdf print -printer socket://192.0.2.30:9100 -sides long -media a4 invoice.bdf          # IPP の無いプリンタに PostScript
bdf print -printer "lpd://192.0.2.31/lp1?format=pdf" invoice.bdf                       # LPD で PDF（PJL の見出し付き）

bdf print -profile list                                                                 # ラベル・レシート・連帳の機種
bdf print -printer "socket://192.0.2.40:9100?profile=zd421-203" -media 104x150mm label.bdf      # ZPL のラベル
bdf print -printer "serial:///dev/ttyUSB0?lang=escpos&baud=19200" -drawer 1 receipt.bdf          # ESC/POS のレシート、ドロワを開ける
bdf print -printer "winspool:///EPSON%20TM-T88VII%20Receipt?profile=tm-t88" receipt.bdf          # Windows のドライバのキュー経由
bdf print -printer "usb:///dev/usb/lp0?profile=vp-f2000" -perforation-skip 12.7 slip.bdf         # 連帳に ESC/P
bdf print -printer ipp://localhost:631/printers/zebra -profile zd421-300 label.bdf               # CUPS の raw キュー
```

- **用紙**: `-media` は PWG の名前（`iso_a4_210x297mm`）か短い名前（`a4`、`a3`、`b4`・`b5` は JIS、`letter`、`legal`、`hagaki`、`chou3`、`kaku2` …）。省くと、1 ページ目の大きさの用紙をプリンタの持つものから選びます（セットされている用紙が先）。
- **形式**: `-format auto`（既定）は PDF、受けなければ PostScript、それも受けなければ PWG Raster、Apple Raster、PCLm（`-format pdf|ps|pwg-raster|urf|pclm` で指定）。PostScript は Level 3 で、文字はグリフのアウトラインの Type 3 のフォント、PostScript が描けないもの（透明、合成、影、フィルタ）はそれが描かれる矩形だけを絵にし、ほかはベクタのままです。ラスタは白黒なら 600 dpi のグレー、カラーなら 300 dpi の sRGB（プリンタの持つ解像度から）で、`-bilevel` は白黒の 2 値。両面の裏面は、プリンタの求めるとおり（`pwg-raster-document-sheet-back`、`urf-supported` の `DM`、`pclm-raster-back-side`）に向きを変えて描きます。`-raster-if-lossy` は、PDF が文書の描画を省くとき（`FILTER`、Canvas 固有の合成）に PWG Raster にします。
- **IPP の無いプリンタ**: `socket://host:9100`（生のポート）と `lpd://host/queue` には PostScript を、`?format=pdf` なら PDF を PJL の見出しを付けて流します（`?pjl=false` で外し、`?pjl=true` で PostScript にも付ける）。用紙・部数・両面・用紙の種類は、PostScript ではファイルの中（`setpagedevice`）で、PDF では PJL で頼み、それ以外（トレイ、排紙先、後処理）は受けないものとして警告します。こうしたプリンタはジョブの状態を返さないので、プリンタが文書を受けたところで終わります。
- **ラベル・レシート・連帳**には、そのプリンタの言語で送ります: ZPL（Zebra）、SBPL（SATO）、TPCL（東芝テック）、ESC/POS（Epson TM と互換機）、ESC/P（Epson VP と互換のドットインパクト）。URL の `lang=`（か `format=`）で言語を、`profile=` で機種（`-profile list`。ドット数と幅）を指定し、`dpi=` と `width=`（ドット数か `104mm`、`4in`）で上書きします。届け方は `socket://` と `lpd://`、`serial:///dev/ttyUSB0`（Windows は `serial://COM3`。`baud`、`bits`、`parity`、`stop`、`flow=rtscts|xonxoff`。SPP の Bluetooth プリンタは OS のシリアルポートとして見えます）、`usb:///dev/usb/lp0`（Linux と BSD の装置ファイル。macOS には無いので、そのプリンタの CUPS のキューへ）、`winspool:///<キュー>`（Windows。メーカーのドライバのキューがデータをそのまま渡す `RAW`）、CUPS の raw キューに `-format zpl|sbpl|tpcl|escpos|escp` か `-profile`。ページはプリンタのドットで白黒に描きます。文字と線は半分で切り、画像はディザ、QR コードとバーコードはモジュールをドットの整数倍に揃える（203 dpi でも読める）。ラベルの長さは `-media`（`104x150mm`、`4x6in`）かページの高さ、レシートと連帳はページの高さ（幅に縮めた分だけ縮む）。ラベルプリンタは、帳票の QR コードとバーコードをプリンタのバーコード命令で刷ります（`-no-printer-barcodes` で描く）。`-darkness`（-100〜100）、`-speed`（mm/秒）、`-media-tracking continuous|gap|mark`、`-label-gap`（mm。TPCL）、`-cut none|page|job`（レシートの既定はページごと）、`-drawer 1|2`（終わりにドロワを開ける）、`-perforation-skip`（mm。ESC/P）。[テキストのテンプレート](../forms.ja.md#テキストのテンプレート)で作った帳票は、ESC/P ではテキストモードで印字します。行と桁の格子の文字を、プリンタのフォントで（ドットインパクトはドットより速く、複写の下の紙まで濃く刷れる）。ピッチ・行送り・用紙長・ミシン目スキップはテンプレートのもので、漢字は漢字モードで送ります。`-print-mode text` で ESC/POS でも同じく（Font A を格子に合わせて送る）、`-print-mode raster` でドットで刷ります。`-skip background` で、用紙に印刷済みの罫線と項目名を刷りません。
- **プリンタが受けないこと**は警告して省きます。`-strict` ならエラーです。部数をプリンタが作れないときは文書の側で繰り返します（奇数ページの両面は部の間に白紙を入れます）。
- **待ち方**: 既定ではジョブが終わるまで（`-wait 10m`）待ちます。`-wait 0` は送ったところで終わります。Ctrl-C はプリンタのジョブを取り消します。
- **終了コード**: 0 印刷した、1 取り消し・中止・その他、2 使い方、3 プリンタに届かない（証明書やパスワードを拒まれた）、4 プリンタがジョブを拒んだ（`-strict` で受けない項目）、5 プリンタが止まっている、6 `-wait` のうちに終わらない。
- **TLS**: `ipps://` のプリンタの証明書は、システムのルートで検証できればそれで、できなければ最初に接続したときの指紋をユーザーの設定ディレクトリの `bdf/printers.json` に記録し、以後は同じことを求めます（CUPS と同じ。`-trust-store` で場所を変え、`-insecure` で検証しない）。Basic 認証は `-username` と `$BDF_PRINTER_PASSWORD`（または `-password-file`）。
- **暗号化した文書**は `$BDF_PASSWORD` で開き、TLS のない接続には `-allow-plaintext` がなければ送りません。
- **プリントサーバーへ**: `-server`（`-printer` が無ければ `$BDF_SERVER`）は、文書をそのまま [`bdf printd`](../print-server.ja.md) のキュー（`-queue`。既定はサーバーの唯一のキュー）へ送り、変換と印刷はサーバーが行います。ジョブの id を出して終わり、`-wait` で終わるまで見届けます。終了コードは同じ意味です（5 は受け付けないキュー、3 はサーバーに届かない・トークンを拒まれた）。チケットのフラグも同じで、`-priority` と `-hold` はスプールでの順番と保留になります。トークンは `$BDF_TOKEN` か `-token-file`、`-user` はトークンの無いサーバーや代理のできるトークンに、ジョブの利用者を名乗ります。`bdf printers -server` はサーバーのキューとプリンタを一覧します。

## printd, jobs

`bdf printd` は[プリントサーバー](../print-server.ja.md)を動かします。1 つのファイルのスプール、設定ファイルのキューとプリンタ、HTTP の API です。`ipp:` があればキューを OS がドライバなしで追加できる IPP プリンタとしても見せて DNS-SD で広告し、`upstreams:` があれば拠点の代理として別のサーバーのキューのジョブを取りに行きます。SIGINT か SIGTERM（Windows は Ctrl-C か Ctrl-Break）まで前面で動き、常駐は OS のサービス管理に任せます。

```sh
bdf printd -config printd.yaml                 # 動かす（ログは標準エラーに JSON。人が読むなら -log text）
bdf printd -config printd.yaml -check          # スプールを開かずに、各プリンタにできることを聞く
bdf printd -config printd.yaml -compact        # 止めたスプールのファイルを、消したジョブの分を詰めて書き直す
bdf printd -config printd.yaml -listen 127.0.0.1:9631
bdf printd -config printd.yaml -dns-sd example.com             # IPP プリンタの DNS-SD のレコードを DNS のゾーン向けに
bdf printd -config printd.yaml -airprint-profile print.example.com > printers.mobileconfig   # 別のサブネットの iPhone・iPad 向け

bdf jobs                                       # 終わっていないジョブ（$BDF_SERVER か -server）
bdf jobs -all -queue office                    # 終わったものも
bdf jobs show 42
bdf jobs cancel 42                             # hold、release、retry も
bdf jobs move 42 warehouse
bdf jobs priority 42 90
bdf jobs password 42                           # 暗号化した文書のパスワード（$BDF_PASSWORD か -password-file）
bdf jobs accounting -from 2026-10-01 -to 2026-10-31 -csv -o october.csv
```

manage の役割の無いトークンは自分のジョブだけを見て操作します。`-user` はその利用者のジョブを一覧し、代理のできるトークンではその利用者として振る舞います。`-json` で JSON を書きます。

## thumbnail, text, render

ブラウザなしで `.bdf` を見る 3 つの方法です。サーバーが使うのと同じ Go のコード（`imagebdf`、`thumbnail`、`Document.SearchText`）を使います。

```sh
bdf thumbnail -size 256 out.bdf thumb.png    # -mode auto|crop|fit, -view, -sheet-dpi, -font-dir, -no-system-fonts
bdf thumbnail -size 256 book.pdf thumb.png   # generate が変換できる入力なら 1 ページ目だけを変換する
bdf text out.bdf text.json                   # メタデータとページごとのテキストを JSON で（既定は標準出力）
bdf render -page 2 -scale 2 out.bdf page2.png  # シートは -width/-height も（A1 から）
bdf render -antialias=off -scale 8.333333 out.bdf print.png  # 600 dpi。境界の AA を省いて速度を優先
bdf render -pages=all -workers=4 -antialias=off out.bdf 'page-{page}.png'  # 独立ページを並列に描き、指定順に保存
bdf render -pages=all -antialias=off -mono=bilevel -scale 8.333333 out.bdf 'page-{page}.png'  # 600 dpi の 2 値（1 画素 1 bit）
bdf render -workers=1 -mono=bilevel -scale 8.333333 out.bdf print.tif  # 帯を 1 つずつ描く。メモリが最小
```

`render -antialias=default|on|off` で図形・文字・幾何クリップの境界のアンチエイリアスを選べます。`default` と `on` は倍率によらず従来の描画を維持し、`off` は境界の被覆率計算を省きます。dpi による自動切り替えはありません。半透明・ブレンド・画像の補間・ソフトマスク・ぼかしと、1 画素より細い線の薄い alpha は維持します。`thumbnail` と変換時のプレビューは従来のアンチエイリアスを使います。Go の指定と出力上の注意は[描画する](../rendering.ja.md#ラスタライズの品質と速度)を参照してください。`render -mono=gray|bilevel` はカラーの代わりにモノクロの画像を書きます。1 画素 8 bit の輝度か、黒と白の 2 値（PNG では 1 画素 1 bit。グレー値 128 未満が黒）で、1 ページでも `-pages` のバッチでも使えます（[モノクロの出力](../rendering.ja.md#モノクロの出力)）。PNG・TIFF のページは帯（`-band=N` 行、既定 128）に分けて描き、描けた帯から書きます。帯はコア数まで最大 8 本同時に描き、`-workers=N` でその数を変えられます（`-workers=1` ならメモリが最小で、A4 の 600 dpi で約 80 MiB）。PNG の圧縮も同じ数の goroutine で行い、既定は zlib レベル 1 です。保存用なら `-compression=normal`（6）か `best`（9。2 分の 1〜3 分の 1 の大きさで、1.5〜2 倍の時間）を指定します。

`.bdf` でない入力（PDF、`.docx` など）を渡すと、`thumbnail` はサムネイルに必要な 1 ページ目だけを変換します（`-view` を付けたときは全体）。500 ページの PDF でも数秒ではなく数ミリ秒で済みます。パスワード付きの入力には、暗号化した文書と同じく `$BDF_PASSWORD` と `-allow-plaintext` が要ります。

暗号化した文書には `thumbnail` と `text` に `-allow-plaintext` が必要です（`$BDF_PASSWORD` で先に復号）。どちらの出力も暗号化されないため、明示的に許可する仕組みです。それぞれが何を描く・抽出するかは[変換と出力 → サーバー側のサムネイルと検索用テキスト](conversion.ja.md#サーバー側のサムネイルと検索用テキスト)を参照してください。

## 文書の中身を見る

```sh
bdf ls out.bdf              # すべての Part: ハッシュ、種類、エンコーディング、圧縮前後のサイズ
bdf manifest out.bdf        # manifest を JSON で: View、ページ、メタデータ
bdf disasm out.bdf <hash>   # 1 つの Object Part の描画命令を逆アセンブル
bdf extract out.bdf <hash> out.bin  # Part の生バイト列（フォント、画像など）
```

## 2 つのコンテナ形式の変換

```sh
bdf split out.bdf out/    # 1 ファイル形式 → 分割形式
bdf join out/ out.bdf     # 分割形式 → 1 ファイル形式
```

どちらもパスワードは要りません。暗号化されていてもいなくても、コンテナの Part をそのままコピーします。

## encrypt, decrypt

```sh
BDF_PASSWORD=… bdf encrypt in.bdf out.bdf   # 既存の bdf をパスワードで封印
BDF_PASSWORD=… bdf decrypt in.bdf out.bdf   # 暗号化を解除（開くのにパスワードが必要）
```

`generate` は `-encrypt auto`（既定: 入力にパスワードが要ったときだけ）・`always`・`never` で、この 2 段階を一度にできます。

## sign, verify

```sh
bdf sign -key alice.key -cert alice-chain.pem -role author contract.bdf signed.bdf
bdf sign -key bob.key -cert bob-chain.pem -role counterparty -tsa https://tsa.example/ signed.bdf
bdf verify -roots ca.pem signed.bdf
```

`sign` は、文書がすでに持つ署名の後ろに署名を 1 つ足します（spec §3.7）。署名は署名した人の X.509 証明書を付けた CMS の署名で、manifest とすべての Part、それより前の署名の SHA-256 を覆います。鍵は PEM です（PKCS #8、EC、PKCS #1。PKCS #12 のファイルは `openssl pkcs12 -in key.p12 -nodes` で PEM にできます）。`-cert` には鍵の証明書と、それに続く鎖を渡します。`-role` と `-claims file.json` は文書と一緒に署名されます。`-tsa` はタイムスタンプ局（RFC 3161）に署名の時刻を印してもらいます。出力を省くと、ファイルをその場で署名します。分割形式の文書は、そのディレクトリの `signatures.json` に署名します。

`verify` は署名ごとに、署名が成り立つか（署名の後に Part・ページ・前の署名のどれも変わっていないか）と、署名した人が信頼できるか（`-roots`、なければシステムの根の証明書）を報告します。タイムスタンプがあれば、その時刻で証明書を確かめます。署名が成り立たないか信頼できないとき、または署名が 1 つもないときは終了コード 1 で終わります。`-json` は結果を JSON で書きます。

署名は変更を見つけるもので、変更を防ぐものではありません。`split` と `join` は署名を保ち、署名はどちらの形式でも成り立ちます。帳票の手書きのサインは絵で、`sign` の署名ではありません。

## demo

```sh
bdf demo out.bdf      # ブラウザの機能テストとデモビューアの既定が使うフィクスチャ文書
bdf demo out/         # その分割形式
```

## conformance

```sh
bdf conformance out/                 # suite.json と inputs/。testdata/ の文書を受理の事例として含む
bdf conformance -testdata "" out/    # 合成した事例だけ
```

他の言語で書かれた読み手（libbdf）のためのもので、入力と、この実装がそれをどう扱うかを `suite.json` に記録します（`conformance` パッケージ）。CI は成果物 `bdf-conformance` として、リリースのワークフローはタグのリリースに `bdf-conformance-<tag>.tar.gz` として添付します。

## 形式を横断するフォント埋め込みのフラグ

テキストをレイアウトして埋め込むすべての形式（PowerPoint、Excel、Word、CSV、Parquet、メタファイル、HTML、Markdown、EPUB、フォントファイル）に共通のフラグです。

| フラグ | 効果 |
|---|---|
| `-font-dir DIR` | システムのフォントより先にこのディレクトリを探す（繰り返し指定可） |
| `-fonts embed \| system` | レイアウトに使ったフォントを埋め込む（サブセット化）か、名前で参照するか（ビューア自身のフォントで描く。HTML・Markdown・EPUB の既定） |
| `-no-system-fonts` | `-font-dir` のフォントだけを使い、システムのフォントは使わない |
| `-no-woff2` | 埋め込みフォントを WOFF2 ではなく TrueType/OpenType のまま格納 |
| `-no-subset` | 使う字形だけでなくフォントファイル全体を埋め込む |
| `-ignore-fstype` | OS/2 の `fsType` が埋め込みやサブセット化を禁じるフォントも埋め込む（権利がある場合のみ） |
| `-compression normal \| best \| fast` | 部品の deflate の強さ: `normal`（レベル 6。既定）、`best`（レベル 9。数% 小さくなるが圧縮に 4 倍かかる）、`fast`（レベル 1） |

対応する Go の呼び出しは [API 一覧](../api.md)を、`bdf generate` と `bdf demo` で `testdata/` のフィクスチャを再生成する方法は[ビルドとテスト](development.ja.md)を参照してください。
