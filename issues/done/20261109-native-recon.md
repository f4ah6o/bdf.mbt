# native ターゲットの偵察: 全パッケージを flip して失敗を列挙する

Status: done
Model: unknown
Created: 2026-11-09
Updated: 2026-11-13
Branch: chore/20261109-native-recon

## 概要

`moon.mod` と全パッケージの `supported_targets` を `+js+wasm-gc+native` に変えた使い捨てブランチで `moon check` と `moon test` を native で回し、失敗するパッケージと原因を一覧化する。

## 背景

`moon.mod` の `supported_targets = "+js+wasm-gc"` がモジュール全体を cap している。2026-11-09 の実測では `moon.mod`、`crypto`、`core` の 3 つを flip すると `moon test --target native core` が 81/81 pass した。残りの依存グラフは未検証。

## 問題

現状の `moon check --target native` は native 非対応パッケージをスキップするため exit 0 になり、実際の失敗を隠す。`moon test --target native` は `Total tests: 0` を報告する。この偽の green が native 対応のコスト見積もりを誤らせる。

## 目標

native で失敗するパッケージ、失敗種別（コンパイル / テスト / リンク）、原因の分類（JS extern、`moonbitlang/async`、`@ffi`、その他）を一覧化する。

## 対象外

修正そのもの。CI への native 追加。

## 提案する方針

`moon.mod` と全 `moon.pkg` の `supported_targets` を一括で `+js+wasm-gc+native` に置換する。`moon check --target native` と `moon test --target native` を実行し、失敗を `_scratch/native-recon.md` に記録する。ブランチはマージしない。

## 受け入れ条件

- [x] `moon.mod` と全パッケージを flip したブランチで `moon check --target native` を実行し、失敗パッケージを列挙した
- [x] `moon test --target native` を実行し、失敗テストを列挙した
- [x] 各失敗を「JS extern」「async」「FFI」「その他」に分類した
- [x] 結果を `_scratch/native-recon.md` に記録した
- [x] ブランチをマージしていない

## 結果

2026-11-09 の偵察で `moon.mod` と 73 個の `moon.pkg` を `+js+wasm-gc+native` に flip し、ソースは変更しなかった。`moon check --target native`、`moon test --target native`、`moon build --target native` はすべて通り、native のテストは 2730/2730 だった。これは偵察時点の固定 head での測定であり、main `b05cd93` やその後の実行を主張するものではない。

失敗パッケージは無く、分類する項目も無かった。偵察ブランチはマージしていない。結果は `docs/roadmap.md` の M1 に記録し、後続の 3 つの native Issue はこの結果を入力にした。実装は #8 のパッチとして main `b05cd93` に統合済み。

## テスト計画

- `moon check --target native`
- `moon test --target native`
- `_scratch/native-recon.md` の目視レビュー

## リスク

一括 flip はビルド計画の再計算を伴い時間がかかる。`_build` のキャッシュが古い結果を返す場合は `moon clean` を使う。

## 変更履歴

`CHANGES.md` impact: no

## 注記

この Issue の成果物は一覧であり、コード変更ではない。後続の 3 つの native Issue はこの一覧を入力にする。

## 2026-11-13 トリアージ結果

- 照合対象: main `d13b9578c86982cb6ea0d955f678c16e2edc84e9`。
- 判断: この Issue の限定された実装・受入範囲は統合済み。状態と格納先を done に整合。
- 根拠: Issue完了記録、docs/roadmap.md M1、moon.mod/native宣言とCI matrix。
- 範囲と留保: 既存の本文doneに格納先を整合した。historical testは新規実行とは区別。
- 検証記録は上記コミット・PR時点のもの。今回の整理で製品テスト全体を新規実行したとは主張しない。本文の過去の問題記述は履歴として保持し、受入チェック欄を照合結果に整合した。
