# convert/xdw の残りのギャップ: 詳細 Issue へのポインタ

Status: superseded
Model: deepseek-v4-1-flash-1017
Created: 2026-11-09
Updated: 2026-11-10
Branch: feat/20261109-xdw-remaining-gaps

## 概要

この Issue は `convert/xdw` の残りを 1 つにまとめていたが、内容が既存の詳細 Issue と重複するため superseded にする。実装済みの項目は詳細 Issue 側に記録し、残るコーパス検証だけを `20261109-xdw-corpus-parity` で追跡する。

## 背景

`convert/xdw` は上流 `shibukawa/bdf` の converter ではなく、`ezpzfile/ezpzfile-xdw` v0.3（MIT）の移植。PR #5 で main に入り、PR #6 の精度改善は main `b05cd93` に統合済み。

## 現状

- 覆われた文字の除去と `include_hidden` は main `b05cd93` に統合済み（`8e968da`、`959c032`、`9f224fc`）。詳細は `20261109-xdw-hidden-text`。
- 注釈テキストの索引化と注釈レイヤー分離は main `b05cd93` に統合済み（`8e968da`、`959c032`、`bb16d5b`）。詳細は `20261109-xdw-annotation-index`。
- wasm-gc と native の宣言は #8 で main `b05cd93` に入った。`convert/xdw/moon.pkg` は `+js+wasm-gc+native` を宣言している。
- 43 ファイルのコーパス比較は未実施。詳細は `20261109-xdw-corpus-parity`。

## 対象外

XDW の書き戻し（上流も対象外）。上流 `shibukawa/bdf` の移植範囲。

## 受け入れ条件

- [x] 覆われた文字と注釈テキストの扱いを詳細 Issue に委譲した
- [x] コーパス検証の残りを `20261109-xdw-corpus-parity` に委譲した
- [ ] 43 ファイルのコーパスで `render` と `text` が上流 CLI と一致する（`20261109-xdw-corpus-parity` で追跡）

## テスト計画

- `20261109-xdw-hidden-text`、`20261109-xdw-annotation-index`、`20261109-xdw-corpus-parity` のテスト計画に従う。

## リスク

コーパスのライセンスと入手性は `20261109-xdw-corpus-parity` に記載済み。

## 変更履歴

`CHANGES.md` impact: no

## 注記

上流の移植範囲外なので、ロードマップの完了条件には含めない。
