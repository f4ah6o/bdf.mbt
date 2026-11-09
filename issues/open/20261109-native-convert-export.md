# native 対応: convert / export

Status: open
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-09
Branch: feat/20261109-native-convert-export

## 概要

`convert/*` と `export/*` を native で check/test/build できるようにする。

## 背景

前段の Issue で `crypto`、`core`、`encoding`、`font` が native 化済み。偵察で flip だけで通ることは確認済みなので、この Issue もコード変更を伴わない見込み。

## 問題

`convert/*` は 40 パッケージ、`export/*` は 3 パッケージある。`convert/pdf/jpx/*` の 20 パッケージは `supported_targets` を宣言していないため `moon.mod` の cap を継承しており、`moon.mod` の flip で一斉に native 対象になる。

## 目標

全パッケージが native で green。

## 対象外

`print`、`form`、CI。

## 提案する方針

`convert/*` と `export/*` の `supported_targets` を flip する。`convert/pdf/jpx/*` は宣言が無いので `moon.mod` の flip で自動的に native になる。偵察で判明した失敗を修正する。

## 受け入れ条件

- [ ] `moon check --target native` が convert と export で 0 errors
- [ ] `moon test --target native` が全件 pass
- [ ] `moon build --target native` が成功
- [ ] `moon test --target js` と `moon test --target wasm-gc` が退行していない

## テスト計画

- `moon check --target js && moon test --target js && moon build --target js`
- `moon check --target wasm-gc && moon test --target wasm-gc && moon build --target wasm-gc`
- `moon check --target native && moon test --target native && moon build --target native`

## リスク

`convert/pdf/jpx` の 20 パッケージが最大の失敗源になり得る。整数演算とバイト操作が中心なので、native 固有の差は小さいと見込む。

## 変更履歴

`CHANGES.md` impact: no

## 注記

`convert/pdf/jpx` は `moon.pkg` に `supported_targets` が無い唯一の領域。
