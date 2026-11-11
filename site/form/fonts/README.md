# フォームの PDF に埋め込むフォント

どちらも M+ FONTS（SIL Open Font License 1.1、`OFL.txt`）です。

| ファイル | 使うところ | 出どころ |
| --- | --- | --- |
| `MPLUS1p-Regular.ttf` | Office・pdfme のテンプレート（字幅が自由な文） | 上流 BDF の `site/form/fonts/index.json` が指す `https://fonts.gstatic.com/s/mplus1p/v33/e3tjeuShHdiFyPFzBRro-A.ttf`（1,713,884 バイト、SHA-256 `e0a6455b…98a7c`） |
| `MPLUS1Code-Regular.ttf` | テキストのテンプレート（等幅の升目） | `https://fonts.gstatic.com/s/mplus1code/v18/ypvMbXOOx2xFpzmYJS3N2_J2hBN6RZ5oIp8m_7iN0HHp.ttf`（1,693,320 バイト） |

テキストのテンプレートは 1 文字が 1 升（全角は 2 升）の升目に置かれるので、
等幅の M PLUS 1 Code を使います。半角 0.5 em・全角 1 em なので、走りの幅を
升目に合わせて縮めると、どの文字も升目の中央に来ます。字幅が文字ごとに違う
フォントでも列がずれないよう、PDF は走り全体ではなく 1 文字ずつを自分の升目
の位置に置きます（同じ倍率の文字はまとめて 1 つの文字列にします）。

## 著作権

- `MPLUS1p-Regular.ttf`: Copyright 2016 The M+ Project Authors.
- `MPLUS1Code-Regular.ttf`: Copyright 2021 The M+ FONTS Project Authors
  (https://github.com/coz-m/MPLUS_FONTS).

`OFL.txt` は M+ 1p の 2016 年のものですが、どちらのファイルも同じ SIL Open
Font License 1.1 で配られます。

フォームのページは、記入済みの BDF を PDF にするときだけこのファイルを読み、
`bdf_wasm_export_pdf_font` に渡します。PDF には使った文字の字形だけを詰めた
サブセットを埋め込むので、1 ページの帳票は数十 KB になります。BDF そのものに
フォントは入りません（BDF を描くのはブラウザで、そちらは端末のフォントを
使います）。

上流は同じフォントを Google Fonts の CDN から取り、`BIZUDGothic-Regular.ttf`
も候補にしています。このページは CDN に頼らず、この 2 本を同梱します。
