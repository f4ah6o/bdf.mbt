# compat: 下流の描画・形式フィードバックを 6f2918f で記録する

Status: open
Model: unknown
Created: 2026-11-10
Updated: 2026-11-10
Branch: research/20261110-consumer-feedback

## 概要

`bdf.mbt` `6f2918f` に対する匿名の下流観測を、再現できた項目とできない項目に分けて記録する。対象は 5 形式のピクセル差分、Office 拡張子 14 件と DOCM マクロ、PDF の `/Length 39`、拡張子一覧の差 48 件、未対応の MHTML と除外形式。入力サンプルと組織のデータは提供されていないため、数値から原因を推測しない。

## 背景

報告された数値（すべて報告値。この worktree では再現していない）:

| 対象 | ピクセル差分 |
| --- | ---: |
| PDF | 0.321% |
| Excel | 20.694% |
| Word | 10.262% |
| PowerPoint | 2.028% |
| JWW | 0% |
| BDF | 0% |
| 参照側の再描画（対照） | 0% |
| しきい値 | 0.05% |

環境は Chromium 1200x850、DPR 1、各 1 サンプル。同じ報告に、JWW のテキストレイヤー比較失敗（`20261110-jww-text-index-sample.md`）と Word のページ要素 4 対 3（`20261110-docx-page-count-sample.md`）が含まれる。

## 問題

- 5 形式のパーセントは、入力・ハーネス・フォント・スケールが不明で再現できない。
- 拡張子一覧の差 48 件は、比較対象の上流レジストリのダンプが無く、内訳を照合できない。
- 利用側は合成 DOCM の VBA 非実行・非埋め込みを確認済みと報告した。この worktree では同じケースを再実行していない。
- PDF の `/Length` 回復は 1〜8 バイトの重なりのみで、マーカー全体を含む長さは回復しない。この点は未評価のまま。

## 目標

- 再現できた項目を、コマンドと結果付きで固定する。
- 再現できない項目を、必要な入力とともに明示する。
- 除外形式を再導入しない。

## 対象外

- 利用者サンプル、組織データ、非公開文書の入手・再配布。
- 報告のパーセントから原因を推測すること。
- 基板（KiCad、Gerber/Excellon）、楽譜、EPUB の再導入。
- ピクセル比較のしきい値変更。
- 上流レジストリの再配布。

## 再現できた項目

### Office 拡張子 14 件

```sh
node compat/converter/office-extensions-test.mjs
# converter Worker advertises 24 formats; 14 Office extensions convert by
# content, by explicit format and by name.
```

`compat/converter/office-extensions-test.mjs:26` の一覧は xlsx 4 件（`.xlsx`、`.xlsm`、`.xltx`、`.xltm`）、docx 4 件（`.docx`、`.docm`、`.dotx`、`.dotm`）、pptx 6 件（`.pptx`、`.pptm`、`.ppsx`、`.ppsm`、`.potx`、`.potm`）で合計 14 件。内容・明示形式・名前の 3 経路で変換を確認している。

利用側は合成 DOCM で VBA の非実行・非埋め込みが成功したと報告した。今回の worktree はこの DOCM ケースを再実行していない。

### PDF の `/Length 39`

```sh
grep -c '^test ' convert/pdf/file_stream_wbtest.mbt   # 12
```

`convert/pdf/file_stream_wbtest.mbt:50` が報告と同じ形（38 バイトのストリームを 39 と宣言、キーワード前に改行なし）を再現している。`convert/pdf/file_stream.mbt:92` は宣言末尾から 1〜8 バイト戻った位置で `endstream` を探し、見つかった分だけ長さを縮める。

マーカー全体（9 バイト）を含む宣言は回復しない。`file_stream_wbtest.mbt:81` は「回復しない」ことだけを assert しており、その入力が実在するか、回復したほうがよいかは評価していない。これが報告の「full-marker-overlap remains unassessed」に対応する。

### 未対応の MHTML と除外形式

```sh
node compat/converter/office-extensions-test.mjs   # html は .html/.htm/.xhtml のみ
```

- `html` は `.mhtml` / `.mht` を通知しない（`office-extensions-test.mjs:193`）。MIME/MHTML リーダーが未移植のため。
- `convert/all/all.mbt:498` の `known_named` には `.mhtml` / `.mht` が残る。登録も変換もしないが、CSV や画像として誤検出させないための名前リスト。
- 除外形式は `office-extensions-test.mjs:33` の `DROPPED`（`epub`、`gerber`、`kicad`、`midi`、`mml`、`musicxml`）で、登録されていないことを assert している。

## 再現できない項目

| 項目 | 必要なもの | 現状 |
| --- | --- | --- |
| 5 形式のピクセル差分 | 再配布可能な合成入力、ハーネス設定、配布可能なテストフォント、Chromium のビルド | 未再現。`compat/parity/render-diff.mjs` は別のフィクスチャと 1280x1024 で動く |
| 拡張子一覧の差 48 件 | 比較に使った上流レジストリのダンプ | 未再現。このリポジトリ側の数は 24 形式、Office 14 拡張子、`known_named` 87 拡張子、除外 6 形式 |
| DOCM のマクロ非実行 | 利用側の合成 DOCM ケースに相当する再配布可能な入力 | 利用側は成功を報告。ここでは未再実行 |
| JWW のテキストレイヤー | JWW サンプル | `20261110-jww-text-index-sample.md` |
| Word のページ要素 4 対 3 | DOCX サンプル、数え方のセレクタ | `20261110-docx-page-count-sample.md` |

## 提案する方針

1. この issue を記録として維持し、再現できた項目だけをテストで固定する。
2. 5 形式のパーセントは、再配布可能な合成入力とテストフォントで条件を固定して切り分ける。ビューポートとスケールは報告に合わせ、しきい値は変えない。
3. 拡張子一覧の差は、上流レジストリのダンプが提供された時点で `office-extensions-test.mjs` の一覧と突き合わせる。推測で一覧を増やさない。
4. `/Length` のマーカー全体重なりは、実ファイルでの必要性が確認できるまで回復を広げない。広げる場合は、データ内の `endstream` を誤って切り落とさないことをテストで固定する。
5. MHTML は未対応のまま、除外形式は再導入しない。

## 受け入れ条件

- [ ] 再現できた項目（Office 14 拡張子、PDF 12 テスト、MHTML 非通知、除外 6 形式）がコマンド付きで記録されている。
- [ ] 再現できない項目に、必要な入力が書かれている。
- [ ] 除外形式を再導入していない。
- [ ] ピクセル比較のしきい値を変えていない。
- [ ] 報告の数値を、bdf.mbt の欠陥の証拠として扱っていない。

## テスト計画

- `node compat/converter/office-extensions-test.mjs`
- `MOON_HOME=$PWD/.moon-home moon test -p f4ah6o/bdf/convert/pdf`（`file_stream_wbtest.mbt` の 12 テストを含む）
- `node compat/parity/verify.mjs --format=pdf,docx,xlsx,pptx`
- `node compat/parity/render-diff.mjs --case=control/bdf-fixture`（対照が 0% であること）

## リスク

- 報告値を再現値として扱うと、存在しない回帰を追うことになる。
- 拡張子一覧を推測で増やすと、変換できない形式を通知してしまう。MHTML がまさにその例。
- `/Length` の回復範囲を広げると、データ内の `endstream` を誤って切り落とす可能性がある。
- 除外形式を「一覧の差」として戻すと、移植対象外のパッケージを再び抱えることになる。

## 変更履歴

`CHANGES.md` impact: no

## 注記

- 実測は `6f2918f` の worktree で行った。`MOON_HOME=$PWD/.moon-home moon build --target js` は exit 0。
- 報告の環境は Chromium 1200x850、DPR 1。この worktree の `render-diff.mjs` は 1280x1024、DPR 1、scale 1、repeat 2 で、フィクスチャも別。
- 5 形式のパーセントは 1 サンプルずつの値で、分散や再現性は報告に無い。
- `docs/compatibility-feedback.md` に、この記録の要約を追記する。
