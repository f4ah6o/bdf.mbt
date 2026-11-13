# MEGASOFT DXF サンプルの upstream 表示差と日本語文字化けを調査する

Status: open
Model: unknown
Created: 2026-11-13
Updated: 2026-11-13
Branch: research/20261113-dxf-megasoft-parity

## 概要

MEGASOFT の 2D / 3D DXF サンプルについて、固定した shibukawa/bdf と bdf.mbt の表示差を比較し、修正可能な単位に分解する。2DDXF_Sample.dxf の日本語文字化けを優先して切り分ける。

## 背景

出典: https://www.megasoft.co.jp/3darchi_pro/data.php

同ページは 2DDXF_Sample.zip と AutoCAD.zip を CAD サンプルとして配布している。3D ファイルには敷地・建物・小物を含み読み込みに時間がかかる旨の注意がある。

確認対象は利用者提供の次のファイル。原本の公開リポジトリへの追加は行わない。

| ファイル | bytes | SHA256 |
|---|---:|---|
| 2DDXF_Sample.dxf | 241601 | 0fa79313956d72ca84128a8f299407395f9e0f501e46bbb20d4d6edc8f501c0e |
| AutoCAD.DXF | 7511158 | 2f7661780f99e22ad36a4a1af9412c0ab2a6972dc33beb31ca92eb321cccbb19 |

## 問題

利用者報告: upstream と表示内容が異なり、2DDXF_Sample.dxf では文字化けも発生する。表示差のエンティティ別内訳と画面再現は未検証。

ローカルで確認した事実（bdf.mbt main ea2d633a7c465fd60ee9244878357f80ece3f3ab）:

- 両添付には `$ACADVER` と `$DWGCODEPAGE` が存在しない。
- 2D 添付は UTF-8 strict decode が byte 4791 で失敗し、CP932 strict decode は成功する。UTF-8 replacement decode では 10527 個の U+FFFD が生じる。
- `convert/dxf/dxf_read.mbt` の `read_tags` は先頭 8192 bytes に `ansi_932` / `shift_jis` がある場合のみ Shift-JIS を選び、それ以外は UTF-8 lossy decode を行う。2D 添付にはこのマーカーがないため、現行分岐で情報を失うことが静的に確認できる。
- AutoCAD.DXF は UTF-8 / CP932 の両 strict decode に成功する。2D と同一原因であるとは判断しない。
- upstream の実変換・画面比較はまだ実施していない。上記は文字デコード経路の証拠であり、全表示差の根因確定ではない。

## 目標

同一入力・表示条件による差分証拠を揃え、文字デコード、フォント、図形・座標等を分離して最小の修正 issue を起こせる状態にする。

## 対象外

無根拠なエンコーディング固定、全 DXF 機能の一括実装、他 CAD 形式、原本サンプルの再配布。

## 提案する方針

1. upstream のバージョンまたは commit と bdf.mbt commit を記録し、固定した upstream binary から同じ入力の比較基準を実行時生成する。
2. viewport・倍率・背景・フォント条件を揃えて両サンプルを変換し、描画と抽出文字を比較する。
3. `convert/dxf/dxf_read.mbt` / `dxf_draw.mbt` と upstream の対応実装を比較する。コードページなし、UTF-8、CP932、Unicode escape の入力を区別する。
4. 差をエンティティ、文字列、位置、欠落、色・線種等に分類し、原因ごとの修正 issue に分割する。文字化けについては原本を含まない自作最小 DXF を作る。
5. 出典ページ上のダウンロード案内だけでは再配布許諾を確認できない。原本を公開 fixture にせず、ローカル検証用の取得手順とハッシュを記録する。追加許諾が確認できた場合のみ別途判断する。

## 受け入れ条件

- [ ] 両サンプルの固定 upstream / bdf.mbt 比較結果を、使用 commit と表示条件付きで記録する。
- [ ] 2D のデコード後文字列と描画グリフを分離し、文字化け原因と最小再現ケースを確定する。
- [ ] AutoCAD.DXF の差を独立に分類し、2D の原因を推測で流用しない。
- [ ] 未再現・対象外・差なしの項目も記録し、根拠に基づく修正 issue を作成する。
- [ ] 原本や許諾不明の派生画像を公開リポジトリに含めない。

## テスト計画

- SHA256 とファイルサイズを照合する。
- 固定 upstream binary と bdf.mbt converter に同じ入力を渡して、テキスト・描画命令・画像を比較する。
- CP932 / UTF-8 / コードページ欠落 / Unicode escape の自作 fixture で decode 結果を検証する。
- 修正時には `moon test convert/dxf --target js` および対応する既存 DXF 回帰テストを実行する。

## リスク

コードページなし入力の推定は曖昧であり、UTF-8 を破壊しない判定と明示設定の必要性を検討する。3D サンプルは投影・エンティティ対応差と性能差もあり得る。upstream も完全な正解ではなく、差分を仕様確認せず追従しない。

## 変更履歴

`CHANGES.md` impact: no

## 注記

本 issue は調査登録であり、表示改善完了を意味しない。実装 issue 作成時に利用者向け変更履歴を改めて判断する。

## 実装進捗（2026-11-13）

ASCII DXF の文字デコードに、固定 upstream `a5e4d7a` の保守的な
Shift-JIS 推定条件を接続。コードページ欠落／既定 ANSI_1252 に限り、
UTF-8 でなく、Shift-JIS 解読が成功し、かな／第一水準漢字の先行バイトを
2組以上含む場合に推定する。UTF-8 と AC1021 以降の優先は維持する。
明示コードページは header tag から取得し、8192 bytes 上限と本文内文字列の
誤検出を除去した。合成 fixture でコードページ欠落、既定、明示、UTF-8、
近代版、曖昧な半角／西欧文字、不正byte、長いheaderを分離して検証する。

これは文字デコードの限定修正であり、原本の描画差・3D差・全codepage対応や
binary DXF の decode 対応を完了したものではない。本Issueはopenを維持する。

Validation: DXF JS tests pass (9/9), including existing binary-DXF regression. Independent review found no blocking regression. Native/wasm-gc tests could not start because the local Moon core bundle lacks bigint.mi; not a test failure. Inference currently inspects the complete ASCII file rather than individual string tags, so malformed trailing bytes can differ from upstream. Full drawing parity is still open.
