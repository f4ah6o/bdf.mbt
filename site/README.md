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
| \`pages/\` | ビューア・サムネイル・検索テキスト・wasm-gc のページ（そのまま写す） |
| \`assets/\` | \`site.css\`（上流の \`site/site.css\`、MIT）と、ページのスクリプト |
| \`docs-src/\` | 日本語のドキュメント。上流の \`docs/*.ja.md\` と、bdf.mbt のために書いた 2 ページ |
| \`samples/\` | サンプル文書（上流 BDF のテスト用サンプルなど） |
| \`previews/\` | ギャラリーのカードの画像。\`npm run previews:site\` がビルドしたサイト自身から作る |
| \`licenses/\` | フォントとライブラリのライセンス |
| \`benchmarks/\` | 上流の計測（\`upstream.json\`）と bdf.mbt の計測（\`bdfmbt.json\`） |
| \`test.mjs\` | Playwright のテスト（トップ・ビューア・サムネイル・テキスト・wasm-gc・ドキュメント・スマホ幅） |
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

## 書くときの決まり

- 日本語だけ。英語のページも言語の切り替えも作らない。
- ページの中のリンクは、サイトのルートからの相対パス（\`docs.mjs\` がページの深さに合わせて直す）。
- 上流にあってこのサイトに無いページ（帳票・プリントサーバー・npm パッケージ・設計メモ）への
  リンクは、上流の日本語ページを指す。
- 数値は必ず計測した日と環境を添えて出す（\`benchmarks/*.json\` の \`measuredAt\` と \`environment\`）。
