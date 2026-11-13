# Linux・macOS・Windows でシステムフォントを選びやすくする

Status: open
Model: unknown
Created: 2026-11-13
Updated: 2026-11-13
Branch: feat/20261113-system-font-picker

## 概要

共通 Web UI にフォント検索と明確な許可・非対応時の導線を用意する。

## 背景

共通 UI は `site/assets/local-fonts.js`、契約は `docs/local-fonts-ui.md`。責務は bdf.mbt の Web UI とブラウザーアダプターで、下流プラグインは共通機能を利用する。
参考: https://developer.chrome.com/docs/capabilities/web-apis/local-fonts 、https://wicg.github.io/local-font-access/

## 問題

Local Font Access の利用可否は OS 名だけでは判定できず、ブラウザー・secure context・権限に依存する。既存のファイル選択 fallback を維持しながら、多数の書体からの選択を改善する。

## 目標

共通 Web UI にフォント検索と明確な許可・非対応時の導線を用意する。

## 対象外

ブラウザー制限の回避、自動権限要求、OS のフォントディレクトリ直接読取、ネイティブ CLI アダプター、フォント配布・ライセンス判断。

## 提案する方針

feature detection を使い、利用可能・許可拒否・非対応を区別して説明する。fullName/family/style を検索できる UI と選択数・解除導線を設ける。検索しても既選択状態を失わない。非対応または拒否時は手動ファイル選択へ誘導し、OS ごとの利用手順をドキュメント化する。

## 受け入れ条件

- [ ] OS 名だけで対応を断定せず、queryLocalFonts と secure context を検出する。
- [ ] API 呼び出しは利用者操作時だけ行い、拒否・非対応・空一覧からファイル選択へ進める。
- [ ] 表示名・family・style を検索でき、検索解除後も選択状態とキーボード操作が維持される。
- [ ] Linux/macOS/Windows の確認手順とブラウザー制約を文書化し、未実機検証は未検証と明記する。
- [ ] 選択したフォント以外の bytes を読まず、一覧や bytes を保存・送信・ログ出力しない。

## テスト計画

`node site/local-fonts-test.mjs` と `node site/test.mjs` を実行する。API success/denial/unsupported/insecure/empty を mock で検証する。検索・空結果・選択保持・キーボードを検証し、利用可能な OS/ブラウザーだけ実機結果を記録する。

## リスク

表示名は一意識別子ではない。既存のサイズ上限、TTC セレクター、ユーザー操作時のみの許可要求、メモリのみでの保持を維持する。OS フォントをテスト用 fixture としてコミットしない。

## 変更履歴

`CHANGES.md` への影響: yes

項目案：
- 共通 Web UI にフォント検索と明確な許可・非対応時の導線を用意する。

## 注記

確認基点: main 相当の `ea2d633a`。同基点の issues に本件の重複なし。GitHub の最新 PR 状態は着手時に再確認する。二件は独立レビュー可能だが共通 UI を触るため、表示名分離を先に実装し、その後に検索・導線改善を行う。
