# フォントとライセンス

bdf.mbt は MIT ライセンスで配っています。上流 BDF のコードと文書を取り込んでいるので、その著作権表示とライセンスもここにまとめています。

## bdf.mbt 自身

- コード: [MIT](https://github.com/f4ah6o/bdf.mbt/blob/main/LICENSE)（\`licenses/PROJECT-MIT.txt\`）
- 文書とサイトの文章: 同じ MIT

## 上流 BDF

bdf.mbt は [shibukawa/bdf](https://github.com/shibukawa/bdf)（BDF）の MoonBit 移植です。このサイトの文章の多くは上流の日本語文書（\`docs/*.ja.md\`）から取り、上流の \`site.css\` も使っています。どちらも MIT ライセンスで、著作権は上流の作者にあります。

- 著作権表示: \`licenses/Shibukawa-bdf.txt\`
- 移植の対象: BDF のファイル形式、レンダラの振る舞い、変換器の対応形式

上流のサイトが配っているフォント一式（Liberation、Carlito、Caladea、M PLUS 1p、IPAex、DejaVu、STIX Two Math）は、**このサイトには含めていません**。bdf.mbt のブラウザ側にはフォントのディレクトリが無く、Office 文書の文字幅は推定値で組むためです。上流のフォントを使いたい場合は、上流の配布物から取ってきてください。

## サンプルに埋め込まれているフォント

このサイトのサンプル文書には、次のフォントが埋め込まれています。フォント自体を配っているのではなく、文書の一部として含まれているものです。

- Liberation Serif・Liberation Sans（SIL Open Font License 1.1）: \`samples/demo.pdf\`、\`samples/upstream-report.pdf\` など
- IPAex ゴシック・IPAex 明朝（IPA フォントライセンス v1.0）: \`samples/cjk-cmaps.pdf\`
- WenQuanYi（GPL v2 + フォント埋め込み例外）: \`samples/cjk-cmaps.pdf\`
- STIX Two Math（SIL Open Font License 1.1）: \`samples/stix.ttf\`
- Bravura（SIL Open Font License 1.1）: 楽譜の描画に使う記号

ライセンスの全文は \`licenses/\` に置いています: \`Liberation.txt\`、\`IPA.txt\`、\`WenQuanYi.txt\`、\`WenQuanYi-README.txt\`、\`STIX-OFL.txt\`、\`Bravura-OFL.txt\`。

## ライブラリ

- [MiniSearch](https://github.com/lucaong/minisearch) — MIT。トップページとビューアの「MiniSearch で検索」で使います。
- [marked](https://github.com/markedjs/marked) — MIT。このサイトのビルド時にだけ使い、配布物には含めません。
- [Playwright](https://playwright.dev/) — Apache-2.0。テストと計測にだけ使います。

## 上流のサイトから取ったもの

- \`site.css\`（このサイトの \`site.css\`）: 上流 \`site/site.css\`、MIT。
- 文書の文章: 上流 \`docs/*.ja.md\`、MIT。各ページの末尾に出典を書いています。

上流のサイトが配っている \`lib/bdf-*.wasm\`（Go のビルド）は含めていません。このサイトの変換と描画は、すべて bdf.mbt の JS と wasm-gc のビルドです。

## サンプル文書

\`samples/\` の文書は上流 BDF のテスト用サンプル（MIT）と、公開されているテスト用 PDF（Chrome・ReportLab・WeasyPrint・cairo が作ったもの）です。SHA-256 を \`verify-samples.mjs\` に記録し、ビルドのたびに照合しています。
