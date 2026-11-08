# フロントエンドに組み込む

画面に BDF を表示するには `@bdfkit/viewer` を使います。サーバーが変換済みの BDF を配るならビューアだけで足ります。ファイルをブラウザ内で変換する場合は、変換用の Wasm ランタイムを追加します。ビューアはページの配置、描画、スクロールを担当し、ファイル選択やツールバーなどの操作 UI はアプリが作ります。

以下の npm パッケージは現在このリポジトリの workspace にあり、`npm install` は公開後の利用例です。配布構成と計測サイズは [npm パッケージ](npm.ja.md)を参照してください。

## サーバーで変換した BDF を表示する

```sh
npm install @bdfkit/viewer
```

表示先の要素に幅と高さを与えます。

```html
<div id="preview" style="width:100%;height:70vh"></div>
```

```ts
import { Viewer } from "@bdfkit/viewer";

const host = document.querySelector<HTMLElement>("#preview")!;
const viewer = new Viewer(host, { mode: "embedded", layout: "single" });
await viewer.open({ kind: "single", url: "/documents/report.bdf" });
// 分割形式を配る場合: await viewer.open({ kind: "split", base: "/documents/report/" });

viewer.setLayout("spread");      // "single" / "spread" / "continuous"
viewer.setZoom(1.25);
viewer.scrollToPage(2);           // 0 始まり
// 画面を取り外す際に viewer.destroy()
```

単一ファイルの BDF は HTTP Range リクエストで必要な部分だけ取得できます。配信側の作り方は[サーバーに組み込む](integrate-to-server.ja.md)にあります。自分でページの配置まで作るなら、低レベルの `@bdfkit/render` と `@bdfkit/core` を直接使えます。

## ファイルをブラウザ内で変換する

`@bdfkit/viewer` と、入力形式に合う変換パッケージを 1 つ選びます。

| 入力形式 | パッケージ | 生成関数 |
|---|---|---|
| PDF、EPUB | `@bdfkit/convert-pdf-epub` | `createPdfEpubConverter()` |
| Word、Excel、PowerPoint、Visio、CSV/TSV、Parquet、PDF、EPUB | `@bdfkit/convert-office` | `createOfficeConverter()` |
| 全形式 | `@bdfkit/convert-all` | `createAllConverter()` |

```sh
npm install @bdfkit/viewer @bdfkit/convert-office
```

```ts
import { Viewer } from "@bdfkit/viewer";
import { createOfficeConverter } from "@bdfkit/convert-office";

const viewer = new Viewer(document.querySelector<HTMLElement>("#preview")!, {
  mode: "embedded", layout: "single",
});
const converter = createOfficeConverter();
await converter.ready; // 組み込まれた形式の一覧も返す

const input = document.querySelector<HTMLInputElement>("#file")!;
input.addEventListener("change", async () => {
  const file = input.files?.[0];
  if (!file) return;
  try {
    await viewer.openFile(converter, await file.arrayBuffer(), {
      name: file.name,
      fonts: "/fonts/", // 文字のレイアウトにフォントが必要な場合
    });
  } catch (error) {
    console.error(error); // アプリのエラー表示に置き換える
  }
});

// 画面を取り外す際に viewer.destroy() と converter.terminate() を呼ぶ
```

`fonts` を指定する場合、その URL にフォントファイルと `index.json` を配信します。ページ単位で変換できる形式では、`openFile` が先にページの輪郭を表示し、残りのページを順に追加します。進捗は `conversionprogress`、完了は `conversiondone`、非同期の失敗は `error` イベントで受け取れます。ファイルを開けない・変換できないときは `openFile` が reject します。その後の失敗（変換できなかった・描けなかったページ）は `error` イベントで届き、リスナーがイベントの `preventDefault()` を呼ばないかぎりコンソールにも出力します。

## 文書内を検索する

ビューアはページをビットマップで描くので、ブラウザ自身の検索ではページの文字が見つかりません。フォーカスがビューアの中にある間は、Cmd+F（macOS）や Ctrl+F でビューアの検索バーが開きます。検索バーは View 全体のテキストを探すので、まだ描いていないページも対象です。一致した箇所に印を付け、表示中の一致までスクロールします。Enter か Cmd/Ctrl+G で次の一致、Shift+Enter か Shift+Cmd/Ctrl+G で前の一致へ移り、Escape で閉じます。検索欄の中でもう一度ショートカットを押すと、ブラウザ自身の検索に渡ります。

```ts
new Viewer(host, { find: "page" }); // フォーカスの位置に関係なくビューアが受ける: ページ全体がビューアの画面向け
new Viewer(host, { find: false });  // 検索バーなし。ショートカットはブラウザのまま
```

既定は、埋め込みなら `"focus"`、ライトボックスなら表示中だけ `"page"` です。検索バーの文言（既定は英語）は `findLabels` で差し替えられます。アプリ側の UI から検索するには `viewer.find(query, step)` を呼びます。新しい検索語なら読んでいるページ以降の最初の一致を表示し、同じ検索語をもう一度渡すと次（`1`）か前（`-1`）の一致へ進みます。戻り値は `{ query, index, total, more }` で、`findchange` イベントでも同じものを受け取れます。`viewer.clearFind()` は検索を終え、`viewer.openFind()` は検索バーを開きます。

## 表示モードとアプリ側の操作

ライトボックスなら `new Viewer(host, { mode: "lightbox" })` とし、アプリのボタンから `viewer.show()` / `viewer.hide()` を呼びます。`setView(id)` で BDF 内の View、`setLayout(...)` で単ページ・見開き・連続表示を切り替えられます。View の一覧は `viewer.document?.views`、現在の View は `viewer.view` で取得できます。

音楽表示は通常のビューアーには含めません。必要な画面だけ `@bdfkit/viewer/music` を追加 import すると、ピアノロールと `MusicPlayer` を使えます。`music` を省いたビューアーは譜面のページ自体は表示できますが、`setMusicMode("piano-roll")` は受け付けません。

```ts
import { Viewer } from "@bdfkit/viewer";
import { pianoRoll, MusicPlayer } from "@bdfkit/viewer/music";

const viewer = new Viewer(host, { music: pianoRoll });
viewer.setMusicMode("piano-roll"); // "score" に戻すことも可能
// 再生 UI を作る場合は MusicPlayer を使用
```

音声ファイルのカードは、同じエントリが export する `AudioPlayer` で鳴らします。`<audio>` 要素を包むのでデコードはブラウザが行い、`MusicPlayer` のうち録音に意味のある操作を持ちます。

```ts
import { AudioPlayer } from "@bdfkit/viewer/music";

const view = viewer.view; // 音声ファイルのカード。view.play.audio がある
const data = await viewer.renderer.audio(view.id); // { blob, cues } または null
if (data) {
  const element = document.querySelector("audio")!; // ブラウザのコントロール付き
  const player = new AudioPlayer(data.blob, "", data.cues, { element });
  // cues: 歌っている歌詞の行（ページの単位）。なければ null
  element.ontimeupdate = () => highlight(player.cursorAt(player.position));
}
```

レンダラーが不要なアプリは `@bdfkit/viewer` を入れず、`@bdfkit/convert` と変換プリセットだけを使います。`converter.convert(...)` は BDF のバイト列を返すため、サーバーへのアップロードやダウンロードに使えます。[npm パッケージ](npm.ja.md#配信サイズ)にはレンダラーの有無によるサイズ差も載せています。

独自の形式の組み合わせは [Wasm ランタイムをビルドする](build-wasm-runtime.ja.md)の TinyGo 手順で作り、`@bdfkit/convert` の `createConverter(new URL("/my-converter.wasm", location.href))` を使います。その `converter` も上の `openFile` に渡せます。バンドラーがパッケージ内の Worker と Wasm を配信し、CSP が Worker と WebAssembly を許可するよう設定してください。
