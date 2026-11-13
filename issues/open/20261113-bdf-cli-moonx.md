# BDF CLI の追加に向けて moonx 実行契約と最小スコープを確定する

Status: open
Model: unknown
Created: 2026-11-13
Updated: 2026-11-13
Branch: research/20261113-bdf-cli-moonx

## 概要

ブラウザーを使わず bdf.mbt をコマンドラインから利用できるようにするため、上流 `bdf` CLI の最小移植範囲と `moonx` による実行・配布契約を実証する。
調査結果から実装可能な CLI 追加 issue を作成する。

## 背景

- 利用者の要望は「CLI を追加し、moox で実行できるようにする」。公式ツールとローカル環境で確認できた名称は `moonx` であり、本 issue はこれを対象とする。別ツールを指す場合は実装前に区別する。
- 上流 [cmd/bdf/main.go](https://github.com/shibukawa/bdf/blob/a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22/cmd/bdf/main.go) は generate、fill、text、render、pdf、manifest、split/join、印刷など多数のコマンドを提供する。
- [公式 moonx 文書](https://docs.moonbitlang.com/en/latest/toolchain/moon/moonx.html) は Mooncakes の公開パッケージをインストールせず実行する入口を説明する。
- 確認基点は bdf.mbt `3c78c4b9`。`moon.mod` の対応 target は js、wasm-gc、native。`native_converter_worker/moon.pkg` は名称に反して js executable であり、一般利用者向けファイル CLI ではない。
- 2026-11-13 のローカル `moonx --help` は target を linear-memory `wasm` のみに限定している。`wasm-gc` とは異なるため、そのままのパッケージ公開で実行できるとは判断できない。

## 問題

上流 Go CLI と同じ入口がなく、ライブラリー利用者がホスト入出力を実装する必要がある。
また CLI の追加と moonx 対応は同義ではなく、target、ファイル入出力、依存パッケージ、配布単位の実証が不足している。

## 目標

最小 CLI を実装できる具体的なコマンド契約、必要 target、公開パッケージ座標、検証方法を確定する。
可能なら `manifest`/`ls` のような読取専用操作と、既存変換器を利用する `generate` の最小実証を行う。

## 対象外

- 本調査だけで上流 CLI の全機能互換を約束すること。
- KiCad・基板・楽譜・EPUB の移植。
- 印刷サーバー、実プリンター操作、署名鍵管理、ネットワーク公開。
- npm/ブラウザー API の破壊的変更、調査中のパッケージ公開。

## 提案する方針

1. 上流コマンドと現行の変換・読み取り・出力 API を対応表にし、最初の独立した実装単位を選ぶ。
2. 使用する moon/moonx と依存版を固定し、wasm でコンパイル可能な最小依存グラフを確認する。native CLI の代替を評価する場合も moonx から実行できるとは記載しない。
3. 引数、help、バージョン表示、stdout/stderr、終了コード、ファイル読み書き、既存出力ファイルの扱いを定義する。ホスト処理と変換ライブラリーを分離する。
4. Mooncakes のバージョン付きパッケージ座標と実行構文を実証し、必要な公開工程を実装 issue に落とす。`f4ah6o/bdf` のモジュール版と npm の `bdf.mbt` CalVer を混同しない。
5. 既存 `site/docs-src/architecture/cli.md` が説明する上流コマンドと、新 CLI の対応範囲を明確に分ける。

## 受け入れ条件

- [ ] 上流コマンドに対する対応可能・不足・対象外の表があり、最小実装範囲が決まっている。
- [ ] 固定した toolchain で moonx の target 制約と依存・ファイル入出力を実証し、成功または具体的な阻害を記録している。
- [ ] help、終了コード、出力保護と package/version 指定の契約がある。
- [ ] 合成入力で既存 API と出力を比較し、未対応入力・読取失敗・書込失敗の挙動を確認している。
- [ ] 結果を基に、推測を含まない CLI 実装 issue を作成している。

## テスト計画

- `moonx --help` / `moonx --version` と `moon version` を記録する。
- 最小 executable の wasm build と、その成果物に対する対応ランタイムでの実行を検証する。
- 合成 BDF/CSV、空入力、不正形式、空白・非ASCIIを含むパス、既存出力に対する挙動を確認する。
- 上流を固定して意味上の出力を比較する。圧縮バイトの完全一致は必要条件にしない。
- 調査で既存コードを変更する場合は js/wasm-gc/native の既存回帰を保つ。

## リスク

wasm 非対応の依存やホスト API が CLI 全体の移植範囲を広げる可能性がある。
上流と同名のコマンドでも未対応機能を明示し、成功したように振る舞わせない。
調査成果は実装・公開の完了と区別する。

## 変更履歴

`CHANGES.md` impact: no

## 注記

本 issue は調査。利用者向け CLI の実装時は `CHANGES.md` impact を yes とする実装 issue に引き継ぐ。
