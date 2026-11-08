# ドキュメント

BDF はブラウザでのプレビューのために作られた文書フォーマットです。実際に動くところを見るなら[デモサイト](https://shibukawa.github.io/bdf/)が一番早く、なぜそれがあるのか、各部がどうつながっているのかは、この下のページで説明します。

## 次に読むもの

- **[なぜ BDF か](why.ja.md)** — どんな問題を解決するか、対応形式の一覧、ページめくり・検索・読み上げ
- **[はじめかた](getting-started.ja.md)** — ファイルを変換して開くまで、5 分で
- **[フロントエンドに組み込む](integrating-to-frontend.ja.md)** — サーバー変換済み BDF の表示とブラウザ内変換
- **[サーバーに組み込む](integrate-to-server.ja.md)** — 必要な形式だけを登録する Go の変換サーバー
- **[帳票を作る](forms.ja.md)** — Excel・Word・PowerPoint のテンプレート、入力欄のある PDF、pdfme のテンプレートとデータから、請求書や伝票を BDF として作り、PDF（タグ付き、PDF/A も）に書き出す
- **[プリントサーバー](print-server.ja.md)** — `bdf printd`: IPP プリンタとラベル・レシート・連帳のプリンタ（ZPL、SBPL、TPCL、ESC/POS、ESC/P）のキュー、再起動をまたいでも残り二重に刷らないスプール、HTTP の API、常駐のさせ方
- **[描画する](rendering.ja.md)** — 文書と数式を Go の `image.Image`、Ebitengine、ブラウザの Canvas に描く
- **[Wasm ランタイムをビルドする](build-wasm-runtime.ja.md)** — 形式を選んで TinyGo または Go でビルド
- **[対応形式](formats/index.ja.md)** — すべての入力形式と、それぞれのレイアウト
- **[構成のサンプル](examples/index.ja.md)** — BDF をシステムに組み込む 3 つの方法。それぞれ実際に動く小さなサーバーです
- **[アーキテクチャ](architecture/index.ja.md)** — 変換と描画の仕組み、数式やサムネイル、パスワードと保護モード、フォルダ構成、BDF コマンド、ビルドとテスト

## リファレンス（日本語）

詳しいリファレンスは今のところ日本語のみです。

- **[フォーマット仕様 v1.0](spec.md)** — 安定版のコンテナ、manifest、命令セットと互換性方針
- **[API 一覧](api.md)** — パッケージとコマンドの一覧
- **[設計メモ](design.md)** — 各変換器がその作りになっている理由

- **[フォントとライセンス](licenses.ja.md)** — BDF が含むフォントとデモサイトが配るフォント、それぞれの出元

## ソース

ドキュメントは [`docs/`](https://github.com/shibukawa/bdf/tree/main/docs) に Markdown として置かれ、説明する対象のコードのそばにあります。このサイトはそれを描画したものです。訂正や質問は [issue や pull request](https://github.com/shibukawa/bdf) で歓迎します。
