# ci: Pages デプロイの Action を Node 24 ランタイムへ更新する

Status: open
Model: unknown
Created: 2026-11-10
Updated: 2026-11-10
Branch: fix/20261110-pages-warnings

## 概要

Pages デプロイと検証ワークフローで使う `actions/checkout`、`actions/setup-node`、`actions/upload-pages-artifact`、`actions/deploy-pages` を Node 24 ランタイムのメジャーへ更新する。Pages の権限、トリガー、artifact 入力は変えない。

## 背景

Pages デプロイ run 42746639394 は成功したが、Node 20 Action の deprecation 警告が出た。2026-11-10 時点の公式 `action.yml` で確認した内容は次のとおり。

| Action | 更新前 | 更新後 | ランタイム |
| --- | --- | --- | --- |
| `actions/checkout` | `v4` | `v6` | `using: node24` |
| `actions/setup-node` | `v4` | `v6` | `using: 'node24'` |
| `actions/upload-pages-artifact` | `v3` | `v5` | composite。内部で `actions/upload-artifact@v7.0.0`（`node24`） |
| `actions/deploy-pages` | `v4` | `v5` | `using: 'node24'` |
| `hustcer/setup-moonbit` | `v1` | `v1` のまま | composite。内部で `hustcer/setup-nu@v3.27`（`node24`） |

参照した公式ファイル:

- https://raw.githubusercontent.com/actions/checkout/v6/action.yml
- https://raw.githubusercontent.com/actions/setup-node/v6/action.yml
- https://raw.githubusercontent.com/actions/upload-pages-artifact/v5/action.yml
- https://raw.githubusercontent.com/actions/deploy-pages/v5/action.yml
- https://raw.githubusercontent.com/hustcer/setup-moonbit/v1/action.yaml
- https://raw.githubusercontent.com/hustcer/setup-nu/v3.27/action.yaml

## 問題

- `pages-deploy.yml` の 4 Action が Node 20 ランタイムで、GitHub の deprecation 警告が出る。
- 将来 Node 24 が強制されると、警告ではなく失敗になる可能性がある。
- ローカルの actrun は `--skip-action` に Action の完全な `uses` 文字列を渡しているため、ワークフローだけ更新すると skip が効かなくなる。

## 目標

- GitHub で動く唯一のワークフロー `pages-deploy.yml` が Node 24 ランタイムの Action だけを使う。
- 検証ワークフローの `checkout` / `setup-node` も同じメジャーに揃える。
- ローカル actrun の skip 対象と自己テストを新しい文字列に追随させる。
- Pages の `workflow_dispatch` トリガー、`pages: write` / `id-token: write`、`path: _build/pages`、concurrency を変えない。

## 対象外

- ホスト型 Pages デプロイの実行・再実行。この worktree からは dispatch しない。
- `parity.yml` / `visual.yml` の `actions/upload-artifact@v4`。両ワークフローは GitHub では inert（`branches-ignore: ['**']`）で、Pages の警告には寄与しない。必要なら別途 `v6` へ上げる。
- ローカル検証のゲート構成や retained-scope の変更。

## 提案する方針

1. `.github/workflows/pages-deploy.yml` を `checkout@v6`、`setup-node@v6`、`upload-pages-artifact@v5`、`deploy-pages@v5` に更新する。
2. `.github/workflows/ci.yml`、`pages.yml`、`parity.yml`、`visual.yml` の `checkout` / `setup-node` を `v6` に更新する。
3. `.github/local/verify.mjs` の `skipActionsForGate` を新しい `uses` 文字列に更新する。
4. `.github/local/verify.test.mjs` の期待値を更新し、`docs/verification-scope.md` の手動デプロイ手順を更新する。
5. ローカルで self-test と `actrun lint` を実行する。ホスト型デプロイは未実行であることを明記する。

## 受け入れ条件

- [ ] `pages-deploy.yml` が `checkout@v6`、`setup-node@v6`、`upload-pages-artifact@v5`、`deploy-pages@v5` を使う。
- [ ] `pages-deploy.yml` のトリガー、権限、concurrency、artifact path が変わっていない。
- [ ] `node --test .github/local/verify.test.mjs` が 34/34 通る。
- [ ] `node .github/local/lint-workflows.mjs` が exit 0（4 ファイル、既存の parity 警告 1 件のみ）。
- [ ] ローカル actrun の skip 対象が新しい Action 文字列に追随している。
- [ ] ホスト型 Pages デプロイを再実行し、Node 20 警告が消えることを確認する（未実行）。

## テスト計画

- `node --test .github/local/verify.test.mjs` → 34 passed, 0 failed。
- `node .github/local/lint-workflows.mjs` → exit 0、`4 workflow file(s) linted`。
- `node .github/local/verify.mjs --only self-test` で self-test ゲートを確認する（任意）。
- ホスト型: 別途承認されたデプロイで run ログの Node 20 警告が消えることを確認する。この worktree では実行しない。

## リスク

- `upload-pages-artifact@v5` は内部で `actions/upload-artifact@v7` を使う。artifact 名と path は同じだが、ホスト型での挙動は未検証。
- `checkout@v6` / `setup-node@v6` の破壊的変更のうち、このリポジトリが使っていない入力（`package-manager-cache` など）は影響しない想定。`cache: npm` は明示済み。
- ホスト型デプロイを実行していないため、成功は未確認。ローカルの lint と自己テストだけでは hosted の挙動を保証しない。
- `parity.yml` / `visual.yml` の `upload-artifact@v4` は Node 20 のまま。inert なので実害はないが、将来有効化する場合は更新が必要。

## 変更履歴

`CHANGES.md` impact: no

## 注記

- 変更ファイル: `.github/workflows/{ci,pages,pages-deploy,parity,visual}.yml`、`.github/local/verify.mjs`、`.github/local/verify.test.mjs`、`docs/verification-scope.md`。
- 更新候補は別ブランチにあり、ホスト型デプロイでの確認は未実施。
