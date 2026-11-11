# site/

このサイト（[https://f4ah6o.github.io/bdf.mbt/](https://f4ah6o.github.io/bdf.mbt/)）の元になるファイル。
上流 BDF のサイト（[shibukawa.github.io/bdf](https://shibukawa.github.io/bdf/)）を、
日本語だけにして、bdf.mbt（MoonBit の JS と wasm-gc）で動くように作り直したもの。

## ビルド

\`\`\`sh
npm run build:site      # moon build（js・wasm-gc）と node site/build.mjs
\`\`\`

\`moon build\` でできる束（\`browser.js\`、\`render_worker.js\`、\`native_converter_worker.js\`、
\`export.js\`、\`wasm-gc.wasm\`）と、ここのファイルを \`_build/pages\` にまとめる。
配るのは \`_build/pages\` だけで、GitHub Pages のサブパス \`/bdf.mbt/\` に置く。

## ファイル

| パス | 役割 |
| --- | --- |
| \`build.mjs\` | ビルドの入口。ページ・ドキュメント・サンプル・束を \`_build/pages\` に集める |
| \`home.mjs\` | トップページ。上流 \`site/home.mjs\` の構成を日本語だけで書き直したもの |
| \`nav.mjs\` | ページの一覧（サイドバーの順）とサイトの定数 |
| \`docs.mjs\` | Markdown → HTML（見出しの id、目次、サイドバー、リンクの書き換え） |
| \`pages/\` | ビューア・フォーム・サムネイル・検索テキスト・wasm-gc のページ（そのまま写す） |
| \`assets/\` | \`site.css\`（上流の \`site/site.css\`、MIT）と、ページのスクリプト |
| \`docs-src/\` | 日本語のドキュメント。上流の \`docs/*.ja.md\` と、bdf.mbt のために書いた 2 ページ |
| \`samples/\` | サンプル文書（上流 BDF のテスト用サンプルなど） |
| \`previews/\` | ギャラリーのカードの画像。\`npm run previews:site\` がビルドしたサイト自身から作る |
| \`licenses/\` | フォントとライブラリのライセンス |
| \`benchmarks/\` | 上流の計測（\`upstream.json\`）と bdf.mbt の計測（\`bdfmbt.json\`） |
| \`form/\` | フォームのページのサンプル（\`index.json\` と \`samples/\`）。ビルドで \`forms/\` に写す |
| \`test.mjs\` | Playwright のテスト（トップ・ビューア・フォーム・サムネイル・テキスト・wasm-gc・ドキュメント・スマホ幅）。\`BDF_ONLY=form\` でフォームの段だけ動かす |
| \`check-links.mjs\` | \`_build/pages\` の中のリンクと画像が実在するか |
| \`make-previews.mjs\` | ギャラリーの画像を作り直す（\`--check\` はずれていないかだけ見る） |
| \`benchmark.mjs\` | bdf.mbt の計測（\`--check\` は前回から 3 倍以上遅くなっていないかだけ見る） |
| \`benchmark-upstream.mjs\` | 上流の \`docs/benchmarks/latest.json\` を取り直す |
| \`verify-samples.mjs\` | サンプルの SHA-256 を確かめる |
| \`copy.txt\` | トップページに必ず出る日本語（vlmkit の copy チェックに渡す） |

## 上流から取ったもの

- \`docs-src/*.md\`: 上流 \`docs/*.ja.md\`（MIT）。取り込んだコミットは \`docs-src/UPSTREAM-COMMIT\`。
- \`docs-src/images/\`: 上流 \`docs/images/\` のうち、文章が参照している 2 枚（MIT）。
- \`assets/site.css\`: 上流 \`site/site.css\`（MIT）。bdf.mbt 用の追記は末尾。

上流のサイトが配っているフォント一式と、Go でビルドした \`lib/bdf-*.wasm\` は含めていない。

## フォームのページ

\`pages/form/\` と \`assets/form.js\` は、上流 \`site/form/\`（\`index.html\` と \`main.ts\`、MIT）の
移植。上流は Go にコンパイルした BDF のランタイムを読むが、このページは
\`form_page/\`（MoonBit の \`form\` パッケージを JS にしたもの、\`form_api.js\`）を読む。
テンプレートを読み、タグからデータの JSON Schema を作り、そのスキーマからフォームを作り、
記入済みの BDF をビューア（\`browser.js\` と \`render_worker.js\`）で描き、PDF は wasm-gc の
\`bdf_wasm_export_pdf\` で書き出す。テンプレートもデータもブラウザの外へ出ない。

\`form_page/form_page.mbt\` の 3 つの関数が、ページと \`form\` パッケージの間の橋:

| 関数 | すること |
| --- | --- |
| \`bdf_form_describe(template, sample)\` | 形式・サンプル・JSON Schema・記入途中の名前と値の数 |
| \`bdf_form_fill(template, data, open, strict)\` | 記入済みの BDF（\`open\` があれば記入途中の .bdff）と注意 |
| \`bdf_form_compile(template, name, data)\` | コンパイルした .bdft |

\`Result.bdf\` は描ける BDF そのもの（\`form.fill\` が中で変換する）なので、プレビューは
そのままビューアに渡せる。

### 上流と違うところ

- **Office のテンプレートの画像は入らない。** 写真・QR コード・バーコード・署名・印影の
  タグは空のまま残り、記入のたびに注意に出る（\`form/ooxml\` は画像を埋め込まない）。
  pdfme のテンプレートでは PNG・JPEG・SVG が入る。
- **手書きの署名パッドと、印影の白抜きは無い。** 署名と印影の欄は、画像を選ぶか
  データ URL を入れる欄にした。
- **PDF/A もタグ付き PDF も書き出せない。** 書き出せるのは PDF だけ（上流は PDF/A-2b・2u・2a とタグ付き PDF も書ける）。
- **Excel のシート表示の帳票は PDF に書き出せない。** プレビューと BDF・.bdft の保存はできるが、PDF にできるのはページを持つ帳票（Word・PowerPoint・PDF フォーム・テキスト・pdfme）だけ。シートをページに組む印刷はまだ移植していない。
- **プレビューはブラウザのフォント、PDF は同梱のフォント。** 上流は M PLUS 1p を CDN から
  取ってくるが、このページは \`site/form/fonts/\` の 2 本（M PLUS 1p と M PLUS 1 Code、
  どちらも SIL OFL 1.1）を同梱する。記入済みの BDF を PDF にするときだけ読み、
  \`bdf_wasm_export_pdf_font\` が使った文字のサブセットを埋め込む。**BDF そのものには
  フォントは入らない**（BDF を描くのはブラウザで、そちらは端末のフォントを使う）。
  同梱のフォントに字形の無い文字は、別の字に置き換えずに省き、「注意」に残す。
- **\`_blank_first\` は Office のテンプレートでは効かない**（テキストのテンプレートでは効く）。
- **上流のサンプルの一部はまだ読めない。** 結合したセルをまたぐ繰り返しの行
  （\`form-rows.xlsx\`・\`form-pages.xlsx\`）、\`{{#tags}}\` の外の \`{{#_last}}\`
  （\`form-fixed.pptx\`）、\`{{#rows}}\` の外の \`{{#_blank_first}}\`（\`form-pages.pptx\`）、
  相互参照のない PDF（\`application.pdf\`）。\`site/form/index.json\` には読めるものだけを並べている。

これらはページの「このページでできないこと」にも出している。

## 書くときの決まり

- 日本語だけ。英語のページも言語の切り替えも作らない。
- ページの中のリンクは、サイトのルートからの相対パス（\`docs.mjs\` がページの深さに合わせて直す）。
- 上流にあってこのサイトに無いページ（帳票・プリントサーバー・npm パッケージ・設計メモ）への
  リンクは、上流の日本語ページを指す。
- 数値は必ず計測した日と環境を添えて出す（\`benchmarks/*.json\` の \`measuredAt\` と \`environment\`）。
