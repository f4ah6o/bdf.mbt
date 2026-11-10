# native 対応: convert / export

Status: done
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-10
Branch: feat/20261109-native-convert-export

## 概要

`convert/*` と `export/*` を native で check/test/build できるようにする。

## 背景

前段の Issue で `crypto`、`core`、`encoding`、`font` が native 化済み。偵察で flip だけで通ることは確認済みなので、この Issue もコード変更を伴わない見込み。

## 問題

`convert/*` は 65 パッケージ（サブパッケージを含む）、`export/*` は 3 パッケージある。`convert/pdf/jpx/*` の 22 パッケージは `supported_targets` を宣言していないため `moon.mod` の cap を継承しており、`moon.mod` の flip で一斉に native 対象になる。

## 目標

全パッケージが native で green。

## 対象外

`print`、`form`、CI。

## 提案する方針

`convert/*` と `export/*` の `supported_targets` を flip する。`convert/pdf/jpx/*` は宣言が無いので `moon.mod` の flip で自動的に native になる。偵察で判明した失敗を修正する。

## 受け入れ条件

- [x] `moon check --target native` が convert と export で 0 errors
- [x] `moon test --target native` が全件 pass
- [x] `moon build --target native` が成功
- [x] `moon test --target js` と `moon test --target wasm-gc` が退行していない

## 結果

main `b05cd93` に統合済み。`convert/*` と `export/*` の `supported_targets` は native を宣言し、`convert/pdf/jpx/*` は `moon.mod` の宣言を継承している。#8 ブランチの最終測定は native 2733/2733、js 2749/2749、wasm-gc 2733/2733 で、これは historical な固定 head の測定であり、main `b05cd93` やその後の実行を主張するものではない。PR #8 は open のままの可能性があるが、実装は main にある。

## テスト計画

- `moon check --target js && moon test --target js && moon build --target js`
- `moon check --target wasm-gc && moon test --target wasm-gc && moon build --target wasm-gc`
- `moon check --target native && moon test --target native && moon build --target native`

## リスク

`convert/pdf/jpx` の 22 パッケージが最大の失敗源になり得る。整数演算とバイト操作が中心なので、native 固有の差は小さいと見込む。

## 変更履歴

`CHANGES.md` impact: no

## 注記

`convert/pdf/jpx` は `moon.pkg` に `supported_targets` が無い唯一の領域。
