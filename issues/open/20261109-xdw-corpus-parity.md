# xdw: 上流 43 文書のコーパスで変換結果を比較する

Status: open
Model: unknown
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-xdw-corpus-parity

## 概要

上流 `ezpzfile/ezpzfile-xdw` の `corpus/manifest.tsv` が挙げる 43 文書すべてについて、上流 CLI の `render`/`text` 出力と bdf.mbt の変換結果を比較するハーネスを作る。

## 背景

- 上流のコーパスは 43 ファイル。`corpus/manifest.tsv` に一覧がある。
- bdf.mbt の `convert/xdw/fixtures_wbtest.mbt` は 6 件(`test_xdw_ver8`、`test_xdw_ver9`、`test_xdw_ver10`、`okinawa-pref_61`、`test_xbd_ver8`、`koto-ku_r604kinyumihon`)を base64 で埋め込み、コンテナ・エントリ・LZH 展開後のプロパティ・ページモデルを上流 CLI の `pages` 出力と突き合わせている。
- 他の形式は `compat/<format>/verify.mjs` を持つが、`compat/xdw` は存在しない。
- `compat/parity`(PDF/DOCX/XLSX/PPTX/Markdown)の対象に xdw は入っていない。

## 問題

- 6 件でしか確認していない。残り 37 件の描画・テキストが未検証。
- 変換結果の差分が、どの文書のどのレコードに由来するか追えない。
- 回帰(例: パスレコード、回転、注釈ウィンドウ)を 6 件の外で検出できない。

## 目標

- 43 文書すべてで、上流 CLI と bdf.mbt の出力を比較できる。
- 差分を文書単位・レコード種別単位で一覧できる。
- CI で回せる時間に収まる(全件は重いので、既定はサブセット + 手動で全件)。

## 対象外

- 上流の `hidden.rs` 相当の文字除外(`20261109-xdw-hidden-text.md`)。
- 注釈の索引化(`20261109-xdw-annotation-index.md`)。
- XDW の書き戻し。
- 上流コーパスの再配布。ライセンスの確認が必要なため、fixture は取得手順だけを記録する。

## 提案する方針

1. `compat/xdw/` を作り、`verify.mjs` を置く。`compat/parity/verify.mjs` の構造(ローカル HTTP サーバ + Playwright + canonical 比較)を流用する。
2. 上流 CLI(`ezpzxdw`)の `pages`、`render`、`text` 出力を golden として保存する。`corpus/manifest.tsv` の 43 件を対象にする。
3. bdf.mbt 側は `native_converter_worker` で変換し、BDF を canonical 化して比較する。`compat/parity/canonical.mjs` を再利用する。
4. 差分は `_scratch/xdw/report.json` に書き、文書 ID と最初の差分パスを記録する。
5. 既定の実行は 6 件(現在の埋め込み fixture)にし、`--all` で 43 件にする。

## 受け入れ条件

- [ ] `node compat/xdw/verify.mjs` が 6 件で動き、レポートを書く。
- [ ] `node compat/xdw/verify.mjs --all` が 43 件で動く。
- [ ] レポートに文書ごとの pass/diff と最初の差分パスが入る。
- [ ] 現在の 6 件は pass する。
- [ ] CI に 6 件のジョブを足す(43 件は手動またはナイトリー)。

## テスト計画

- `moon build --target js`
- `node compat/xdw/verify.mjs`
- `node compat/xdw/verify.mjs --all`
- 既存の `moon test -p f4ah6o/bdf/convert/xdw` が通り続けること。

## リスク

- 上流コーパスのライセンスが再配布を許さない場合、fixture をリポジトリに置けない。取得スクリプトとハッシュだけを持つ形にする。
- 43 件の描画比較は重く、CI の時間制限に収まらない可能性がある。
- 上流 CLI の出力形式が変わると golden が壊れる。上流のコミットを固定する。

## 変更履歴

`CHANGES.md` impact: no

## 注記

PR #5 の「既知のギャップ」2 番がこれにあたる。`compat/parity` の canonical 比較を再利用できるため、新規に比較器を書く必要はない。
