# ビルドとテスト

Go 1.27 以上、そして TypeScript のパッケージとデモサイトのために Node.js が要ります。

テストは現在の動作を対象にし、正常入力、不正入力、境界条件、資源制限、描画結果を確かめます。旧実装をテスト内にコピーして比較するより、期待値を直接検証します。古いファイル形式の fixture も、現在対応している形式なら残します。一度きりの調査、手動確認用の出力、過去のテスト実行結果はテストスイートに含めません。

## Go

```sh
go test ./...                          # すべてのパッケージ
go run ./cmd/bdf demo out.bdf          # フィクスチャ文書を書き出す
go build -tags bdf_noconv ./...        # 画像・WOFF2 のコーデックを含めないビルド（ブラウザ向けの構成）
GOEXPERIMENT=simd go build ./...       # Go 1.27、amd64/arm64: SIMD 版コーデック（amd64 は AVX2 必須）
```

`bdf_noconv` はブラウザに要らないコーデックを除きます（[design.md §2](../design.md#2-go-と-wasm-について)を参照）。CI はこの構成も別にビルド・テストしています。コーデックを含めた状態でしか動かない変更は、手元でもこの構成を確かめないと、CI まで気づきません。

## TypeScript

```sh
npm ci
npm run build           # tsc -b packages/core packages/render
npm test                # packages/*/test/*.test.mjs を node --test で（先にビルドする）
npm run test:browser    # ブラウザで描画・選択・検索・アクセシビリティを検証
```

ブラウザの機能テストには Chromium が要ります。`npx playwright-core install chromium` で入れるか、インストール済みの実行ファイルを `CHROMIUM_PATH` で指定してください。現在の動作を検証し、保存済みスクリーンショットとの比較は行いません。

## フィクスチャの再生成

`npm run testdata` は各 `converter/*/testdata/` のソースファイルから `testdata/` 以下をすべて作り直します（Go が必要）。CI はその結果をコミット済みのものとバイト単位で照合します。各形式のサンプル*入力*（`.pptx`・`.dxf`・`.epub` などのファイル自体）は形式ごとのスクリプトが生成し、多くは Python が要ります。

```sh
npm run test:pptx:gen      # python-pptx, msoffcrypto-tool
npm run test:xlsx:gen      # openpyxl
npm run test:dxf:gen       # ezdxf
npm run test:kicad:gen
npm run test:musicxml:gen  # (converter/musicxml/testdata から実行)
npm run test:audio:gen     # ffmpeg、mutagen
# … 形式ごとに 1 つ。全一覧は package.json の scripts を参照
```

## 手元でビューアを動かす

```sh
npm run demo         # http://127.0.0.1:8765/examples/viewer/.out/ — ビューア単体。?src= でリポジトリ内の任意の .bdf を開く
npm run site         # site/dist をビルド: フルのサイト（トップページ、ビューア、サムネイル・検索テキストのページ、ドキュメント）。Go が必要
npm run site:serve   # npm run site の後、配信もする
node examples/viewer/serve.mjs   # npm run demo と同じ
```

`?src=` はスタンドアロンのビューアにリポジトリ内の `.bdf` のパスを渡します。例: `http://127.0.0.1:8765/examples/viewer/.out/?src=/testdata/drawio/multipage.bdf`。`&layout=spread` で本のように開きます。`BDF_SITE_FONTS=dir1:dir2 npm run site` は既定のテスト用フォントの代わりにそれらのフォントをサイトと一緒に公開します。

## 任意の `.bdf` を描画・確認する

```sh
node test/render.mjs out.bdf pngdir/     # すべてのページを headless Chromium で PNG に
go run ./cmd/bdf ls out.bdf              # Part の一覧
go run ./cmd/bdf render -page 2 out.bdf page2.png  # 1 ページを純 Go で描画（ブラウザ不要）
```

## プリンタなしで印刷する

印刷のテストのプリンタ役は `print/fakeprinter` が務める。テストは `fakeprinter.Start(t, p)`（IPP）、`StartSocket`、`StartLPD`、`StartSerial`、`StartCUPS` で起こし、`p.Inject(fakeprinter.Fault{…})` で壊す。`bdf print` や `bdf printd` を手で試すには `test/print/farm.yaml` の農場（IPP Everywhere、AirPrint、PWG Raster、PostScript、PCLm、IPP/1.1 だけの古いプリンタ、紙切れになるプリンタ、クラスのある CUPS のサーバー、9100、LPD、ZPL、SBPL、TPCL、ESC/POS、シリアルの ESC/P）を起こし、刷られたものを見る:

```sh
go run ./tools/fakeprinter -config test/print/farm.yaml   # プリンタの URL を出す
open http://127.0.0.1:8650/                               # ジョブを絵に戻して見る。故障を注入する
go run ./cmd/bdf print -printer ipp://127.0.0.1:18631/ipp/print testdata/form/rows.bdf
go run ./tools/fakeprinter -presets                        # プリンタの種類
```

`go test ./print/fakeprinter/` は、CUPS の `ipptool` と `ippeveprinter` がある所（macOS には両方、Ubuntu は `cups-ipp-utils` と Avahi）で偽物そのものを確かめる。

## CI の出力とバイト単位で一致させる

CI の「testdata is up to date」ステップは、`ubuntu-latest`（amd64）上の `bdf generate` の出力をコミット済みのものとバイト単位で比較します。ただ、Go の浮動小数点の融合積和はアーキテクチャによって異なるため、Apple Silicon では同じコマンドでも Object の境界ボックスなどの下位ビットが数箇所変わることがあります。`GOARCH=amd64 go build` でクロスビルドし、その（Rosetta 上の）バイナリを使えば、手元でも CI と同じバイト列を再現でき、差分が本当の回帰かどうかを先に確かめられます。

各パッケージ・コマンドが公開するものは [API 一覧](../api.md)を、`bdf` のサブコマンドは [BDF コマンド](cli.ja.md)を参照してください。
