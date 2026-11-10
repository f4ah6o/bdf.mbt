# deps: @mizchi/vlmkit 経由の @hono/node-server 勧告を追跡する

Status: open
Model: unknown
Created: 2026-11-10
Updated: 2026-11-10
Branch: fix/20261110-pages-warnings

## 概要

開発依存の `@mizchi/vlmkit@0.23.2` が `@hono/node-server@1.19.17` を解決し、GHSA-rmxm-3fg6-px4f の影響範囲に入る。実際に使われているコードパスを確認し、更新またはリスク受容の根拠を決める。

## 背景

[GitHub Advisory GHSA-rmxm-3fg6-px4f](https://github.com/advisories/GHSA-rmxm-3fg6-px4f) の公開情報:

- 影響範囲: `>=1.19.10 <2.1.3`
- 修正版: `2.1.3`
- 内容: `serveStatic` が保護されたパスを二重デコードする問題。

このリポジトリの実測:

- `package.json` の `devDependencies` に `@mizchi/vlmkit: 0.23.2`。
- `node_modules/@mizchi/vlmkit/package.json` は `@hono/node-server: ^1.19.12` を要求。
- `package-lock.json` は `node_modules/@hono/node-server` を `1.19.17` に固定。
- `node_modules/@mizchi/vlmkit/dist/api-server-IaDaeuyF.mjs:8` は `import { serve } from "@hono/node-server";` のみ。
- vlmkit の `dist/*.mjs` に `serveStatic` は存在しない。
- `api-server` は `dist/cli-Bx6DgUWZ.mjs:133` で遅延 import され、CLI の `api-server` コマンドを実行したときだけ読み込まれる。
- このリポジトリの検証は `vlmkit diff` / `check` / `scan` を使い、`api-server` は使っていない。
- リポジトリのソースに `@hono/node-server` の直接 import はない（`package-lock.json` のみ）。

## 問題

- `npm audit` が `@hono/node-server` の勧告を報告する。
- vlmkit は `^1.19.12` を要求しており、修正版 `2.1.3` はメジャーが異なる。
- ただし、このリポジトリが読み込む経路に `serveStatic` はなく、`api-server` も実行していない。

## 目標

- `npm audit` の該当行を解消する、またはリスク受容の根拠を docs に残す。
- vlmkit の CLI（`check` / `scan`）が引き続き動くことを確認する。
- 公開 Pages が脆弱であるかのような断定をしない。

## 対象外

- 公開サイトの脆弱性断定。`serveStatic` を使っていないため、公開 Pages の脆弱性は確認されていない。
- vlmkit の fork やパッチ。
- 本番デプロイ。
- 他の依存の更新。

## 提案する方針

1. 2026-11-10 に npm の latest として確認した vlmkit 0.24.0 も `^1.19.12` を要求する。以後のリリースで修正済みの 2.1.3 以上を採用したか確認する。
2. ならない場合、`package.json` の `overrides` で `@hono/node-server` を `2.1.3` に固定し、`vlmkit check` / `vlmkit scan` と `api-server` の起動を検証する。`serve` の API 互換性は未確認なので、実際に動かすまで採用しない。
3. どちらも取れない場合、`npm audit` の該当行をリスク受容として docs に記録する。根拠は「devDependency」「`serveStatic` 未使用」「`api-server` 未実行」。

## 受け入れ条件

- [ ] `npm audit` の `@hono/node-server` 行が消える、またはリスク受容の根拠が docs にある。
- [ ] `vlmkit check` / `vlmkit scan` が動く。
- [ ] `overrides` を採用する場合、`api-server` の `serve` が 2.x で動くことを確認する。
- [ ] 公開 Pages の脆弱性を断定しない表現になっている。

## テスト計画

- `npm audit` で該当行を確認する（ネットワークが必要）。
- `node_modules/.bin/vlmkit --help` で CLI が起動することを確認する。
- 変更後に `node .github/local/verify.test.mjs` と、対象を絞った `vlmkit check` / `vlmkit scan` を実行する。
- `overrides` を採用する場合は `node -e "import('@hono/node-server').then(m => console.log(typeof m.serve))"` で `serve` の存在を確認する。

## リスク

- メジャー跨ぎの `overrides` は vlmkit の想定外で、`serve` の API 変更により CLI が壊れる可能性がある。
- `package-lock.json` の変更は他の依存解決に影響する可能性がある。
- Advisory の影響範囲は公開情報を確認済み。将来の vlmkit 更新で利用経路が変わる場合は再確認する。
- `api-server` を使っていないという根拠は静的検索に基づく。動的な読み込み経路が別にあれば再確認が必要。

## 変更履歴

`CHANGES.md` impact: no

## 注記

- 実測コマンド: `node -e` で `package-lock.json` と `node_modules/@mizchi/vlmkit/package.json` を読み、`grep -rn "serveStatic" node_modules/@mizchi/vlmkit/dist` で 0 件を確認した。
- 依存の更新は行っていない。
