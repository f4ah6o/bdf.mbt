# P0 v1.1: 変換入口の契約差による情報欠落を互換維持で修正する

Status: open
Model: unknown
Created: 2026-11-13
Updated: 2026-11-13
Branch: fix/20261113-p0-conversion-contract

## 概要

`convert/all`、形式別 direct API、Worker、Wasm bridge の契約差による情報欠落を、合意済み P0 実装契約 v1.1 に従って最小修正する。
本 issue の登録は仕様の記録であり、実装開始やマージの承認を意味しない。

## 背景

client/server は変換 Core の責務分類ではなく、ホスト・transport・配布の違いとして扱う。
既存の Worker 非依存 bytes API を基礎とし、コンバーターを `core` に移す再編は行わない。
設計レビューの参照基点は main `3c78c4b9db5c60314e2b6730a89d795e8e26c701`。
対象は `convert/all`、`convert/pdf`、`convert/docx`、`convert/pptx`、`browser/native_converter_worker.mbt`、`bridge/wasm/bridge.mbt` の入口契約である。

## 問題

入口ごとの options の位置・解釈、結果のフィールド、失敗応答が異なるため、同義の呼び出しで情報が落ちる可能性がある。
一律な引数転送や入力厳格化は既存 consumer を壊し、生の例外の公開は入力や秘密値の漏洩につながる。

## 目標

BDF v1 wire format、既存呼び出し、入口ごとの既存挙動を維持し、実証した契約差だけを修正する。
結果は「対応」「未サポート」「未検証」を区別し、未検証の target/runtime を対応済みと扱わない。

## 対象外

- 大規模 Core 再編、万能 Host Adapter、native 対応、CLI 追加、真の streaming・逐次変換。
- P1 の runtime 間結果比較、P2 の配信サイズ実測。
- 厳格モード、非推奨化、構造化エラーコード、新引数が必要な別版 API。
- 根拠のない protected 等の結果フィールド追加。
- KiCad・基板・楽譜・EPUB の移植。

## 提案する方針

### P0-1: Options 契約

1. 入力口ごとに形式、キー名、位置（options 直下・params 等）、型、既定値、値解釈、未知キー・不正値時の挙動を表にする。
   Worker の password/pages（options 直下）と DOCX views/title（params 内）を同一階層と仮定しない。
2. 既知かつ現行 direct API が対応する項目だけを `convert/all` から同じ意味で伝達する。
   PDF password/box/title 等の実装可能性を先に確認する。
3. 未知キーは P0 では従来どおり無視し、下層に転送しない。
   未知形式・既知オプションの不正値は、入口ごとに記録した既存エラー挙動を維持する。
   全入口の挙動が既に同一とは仮定しない。
   Worker boolean の文字列 `"true"` 以外を false と解釈する等の互換動作を一律に厳格化しない。

### P0-2: PDF bridge 成功応答

1. 既存 export 名・引数数（ABI）を変えず、JSON `ok` / `pages` / `bdf` の名前・型・意味を維持する。
2. 元の PDF 結果に存在し、汎用 bridge でも提供される `summary` / `warnings` を追加フィールドとして提供する。
   旧 consumer と新 consumer の両方で検証する。
3. 新しい引数が必要なら、既存 export の変更ではなく別版として別途検討する。

### P0-3: PDF bridge 失敗応答と情報漏洩防止

1. 失敗時の既存 `error` 文字列型と成功判定の意味を維持する。
2. 既知の失敗分類には安全な診断文言を割り当てる。
   生の例外メッセージは返さず、未知例外は従来の定型文を維持する。
   入力 bytes・ファイル名・URL・password・本文等を診断に露出しない。
3. 構造化エラーコードは本変更に含めない。

## 受け入れ条件

- [ ] direct / Worker / bridge の差分表があり、形式・キー位置・型・既定値・値解釈・未知キー・不正値の現状と変更点を入口ごとに記録している。
- [ ] 既知かつ対応済み options だけが意味を保って伝達され、未知キーの無視と各入口の既存不正値処理を維持している。
- [ ] PDF bridge の既存 export ABI と `ok/pages/bdf` を維持し、根拠のある `summary/warnings` のみを追加している。
- [ ] `error` の文字列型と成功判定を維持し、既知失敗は安全な診断、未知例外は従来の定型文を返している。
- [ ] 変更前後の JSON ABI 比較、旧・新 consumer の回帰確認、秘密値を含む失敗の負例がある。
- [ ] 対応・未サポート・未検証を区別し、各検証結果を PASS / FAIL / 未実行で報告している。

## テスト計画

- 合成入力で有効・無効 password、box/pages/views、未知キー、既知の不正値を入口ごとに確認する。
- malformed PDF、warning 発生、秘密値を含む失敗を用意し、応答に入力由来の秘密情報が含まれないことを確認する。
- 既存 JSON consumer による回帰と、追加フィールドを読む新 consumer を確認する。
- `moon check --target js`
- `moon test --target js`
- `moon check --target wasm-gc`
- `moon test --target wasm-gc`
- 実施可能な Browser E2E を行い、各コマンドと E2E の PASS / FAIL / 未実行を厳密に記録する。

## リスク

入口ごとの既存挙動を統一済みと誤認すると互換性を失う。
summary/warnings の追加でも厳密な consumer に影響し得るため、旧 consumer 検証を省略しない。
診断改善で生の例外文字列を返さない。
Worker の隔離・強制終了・既存 open/page 呼び出しを壊さず、同期処理の Promise 化を cancel/progress/streaming 対応と見なさない。

## 変更履歴

`CHANGES.md` impact: yes

項目案：

- 既存の変換入口と PDF bridge の互換性を維持しつつ、対応済み options と summary/warnings の情報欠落を修正し、安全な失敗診断を提供する。

## 注記

本 issue は P0 v1.1 の凍結済み契約を記録する。
issue 作成時点で実装変更・動作テスト・マージは行わない。
