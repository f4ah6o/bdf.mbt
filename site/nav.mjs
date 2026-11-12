// このサイト（bdf.mbt）のページ構成。上流 BDF の docs/nav.mjs を日本語だけに絞り、
// bdf.mbt が持たないページ（帳票・プリントサーバー・npm パッケージ・設計メモ）を外したもの。

export const SITE = "https://f4ah6o.github.io/bdf.mbt/";
export const REPO = "https://github.com/f4ah6o/bdf.mbt";
export const UPSTREAM = "https://shibukawa.github.io/bdf/";

const page = (id, label) => ({ id, label });

export const SECTIONS = [
  {
    title: "はじめに",
    pages: [
      page("index", "ドキュメント"),
      page("why", "なぜ BDF か"),
      page("getting-started", "はじめかた"),
      page("integrating-to-frontend", "フロントエンドに組み込む"),
      page("integrate-to-server", "サーバーに組み込む"),
      page("rendering", "描画する"),
      page("build-wasm-runtime", "Wasm ランタイムをビルドする"),
    ],
  },
  {
    title: "対応形式",
    pages: [
      page("formats/index", "形式の一覧"),
      page("formats/pdf", "PDF・Illustrator"),
      page("formats/document", "Word・HTML・Markdown"),
      page("formats/presentation", "PowerPoint"),
      page("formats/layout", "InDesign"),
      page("formats/spreadsheet", "Excel・CSV・Parquet"),
      page("formats/diagram", "Visio・draw.io・Mermaid・Excalidraw"),
      page("formats/cad", "CAD の図面とプロット"),
      page("formats/xdw", "DocuWorks"),
      page("formats/audio", "音声ファイル"),
      page("formats/font", "フォントファイル"),
      page("formats/image", "画像・Photoshop"),
    ],
  },
  {
    title: "構成のサンプル",
    pages: [
      page("examples/index", "構成の選び方"),
      page("examples/light-server", "ブラウザで変換する"),
      page("examples/preview-server", "サーバーで変換する"),
      page("examples/search", "検索エンジンとつなぐ"),
      page("examples/secure-reader", "保護モードで読ませる"),
    ],
  },
  {
    title: "アーキテクチャ",
    pages: [
      page("architecture/index", "処理の流れ"),
      page("architecture/layout", "フォルダ構成"),
      page("architecture/cli", "コマンドとビルド"),
      page("architecture/browser", "ブラウザ側"),
      page("architecture/conversion", "変換と出力"),
      page("architecture/protection", "パスワードと保護モード"),
      page("architecture/development", "ビルドとテスト"),
    ],
  },
  {
    title: "リファレンス",
    pages: [
      page("licenses", "フォントとライセンス"),
      page("api", "bdf.mbt の API"),
    ],
  },
];

export const PAGES = SECTIONS.flatMap((section) => section.pages);
export const BY_ID = new Map(PAGES.map((p) => [p.id, p]));

/** ページの出力先（サイトのルートから）。 */
export function output(id) {
  return `docs/${id}.html`;
}

/** サイトのルートからの深さ（相対リンクの接頭辞に使う）。 */
export function depth(id) {
  return id.split("/").length;
}

export function relative(fromId) {
  return "../".repeat(depth(fromId));
}

/** 上流にあって、このサイトには無いページ。リンクは上流の日本語ページへ送る。 */
export const UPSTREAM_PAGES = {
  npm: "docs/npm.ja.html",
  forms: "docs/forms.ja.html",
  "print-server": "docs/print-server.ja.html",
  "examples/print-server": "docs/examples/print-server.ja.html",
  design: "docs/design.html",
  spec: "docs/spec.html",
  "process-memory-review": "docs/process-memory-review.ja.html",
  api: "docs/api.html",
};
