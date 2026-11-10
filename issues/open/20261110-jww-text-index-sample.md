# jww: 下流のテキストレイヤー比較失敗を再現できるサンプルを特定する

Status: open
Model: unknown
Created: 2026-11-10
Updated: 2026-11-10
Branch: research/20261110-consumer-feedback

## 概要

下流の利用者から「JWW はピクセル差分 0% なのにテキストレイヤー比較で失敗した」と報告された。この worktree の JWW フィクスチャ 2 件では、上流と bdf.mbt のテキスト索引が完全に一致し、再現しない。索引に入る文字列の条件（非表示レイヤー、空白のみ、`^@`、高さ 0）を切り分ける合成フィクスチャを作り、どれが差分になるか決める。

## 背景

報告は `bdf.mbt` `6f2918f` に対する匿名の下流観測で、入力サンプルと実行環境は提供されていない。数値から原因を推測しない。

この worktree で実行した結果:

```sh
MOON_HOME=$PWD/.moon-home moon build --target js        # exit 0
node compat/converter/phase5-test.mjs                   # exit 0
# Phase 5-8 CAD, draw.io and PDF Type1: 15 fixtures convert with the expected
# layers and coverage; ...
```

`compat/converter/phase5-test.mjs:151` は JWW を含む非 DXF/SXF/CGM/draw.io の形式で
`assert.equal(entry.moon.text, entry.upstream.text)` を課す。この assert は通っている。

索引の中身も直接比較した（`_scratch/jww-text-index.mjs`、上流 `@bdfkit/convert-all` 0.2.1 と
`_build/js/debug/build/native_converter_worker/native_converter_worker.js`）:

| フィクスチャ | 上流 run 数 | bdf.mbt run 数 | 文字列 | `a`/`b` が非 0 の run |
| --- | ---: | ---: | --- | ---: |
| `compat/jww/fixtures/shapes.jww` | 13 | 13 | 一致 | 0 / 0 |
| `compat/jww/fixtures/old.jww` | 1 | 1 | 一致 | 0 / 0 |

`shapes.jww` の文字列は `文字のサイズ 5mm`、`Jw_cad 2026 ハンカク`、`字間 あり`、
`ヨコナガ`、`イタリック`、`ボールド`、`カイテン 30°`、`タテガキ`、`4000`、`A`×4。
`old.jww` は `キュウ バージョン`。両者とも `a`/`b` は 0 で、上流も同じなので
索引の矩形欠落は差分の原因ではない。

## 問題

- 報告された失敗を、リポジトリ内のフィクスチャで再現できない。
- 索引に入る文字列の条件が上流と一致しているか、フィクスチャが網羅していない。
- ピクセル差分 0% のまま索引だけ変わりうる経路が、コード上に 4 つある。

`convert/jww/jww.mbt` の該当箇所:

- `jww.mbt:279` `if !self.visible(value.base) { return }` — 非表示レイヤーの文字は描画も索引もしない。上流が索引だけに残すなら、ピクセル 0% で索引だけ差分になる。
- `jww.mbt:623` `if jww_blank(text) { continue }` — 空白のみの文字を索引から落とす。描画は元々何も出ないため、ピクセル差分は 0 のまま。
- `jww.mbt:277` `^@` で始まる特殊文字を警告付きで描画も索引もしない。
- `jww.mbt:280` `value.h <= 0.0` の文字を描画も索引もしない。

いずれも「描画しない」と「索引に入れない」を同じ条件で行っている。上流が両者を別条件に
している場合、今回の報告と同じ形（ピクセル一致・索引不一致）になる。

## 目標

- 非表示レイヤー、空白のみ、`^@`、高さ 0 の文字について、上流と bdf.mbt の索引を実測で比べる。
- 差分がある条件を特定し、上流と同じ索引にする（または上流も同じなら対象外と記録する）。
- 再現する合成フィクスチャを `compat/jww/fixtures/` に置き、`phase5-test.mjs` の比較対象に加える。

## 対象外

- 利用者サンプルの入手・再配布。提供されていないため、合成または再配布可能なフィクスチャだけを使う。
- 報告のパーセントから原因を推測すること。
- 基板、楽譜、EPUB の再導入。
- JWW の書き戻し。
- ピクセル比較のしきい値変更。

## 提案する方針

1. JWW のコンテナを合成する生成スクリプトを `_scratch/` で作り、非表示レイヤーの文字と空白のみの文字を持つ 1 ページ文書を作る。形式は `convert/jww/jww_read.mbt` の読み取り経路に合わせる。
2. 上流 `@bdfkit/convert-all` 0.2.1 と bdf.mbt で変換し、`decodeTextIndex` の run 列を比較する。比較は文字列・順序・`a`/`b` の 3 点。
3. 差分が出た条件について、上流の挙動（索引に残す／残さない）を確定し、bdf.mbt を合わせる。合わせられない場合は警告と docs に記録する。
4. 生成したフィクスチャを `compat/jww/fixtures/` に置き、出所とライセンスを `compat/jww/README.md` に書く。`phase5-test.mjs` のケース一覧に追加する。
5. 索引の `a`/`b` が 0 のままなのは上流と同じなので、変更しない。

## 受け入れ条件

- [ ] 非表示レイヤー・空白のみ・`^@`・高さ 0 のそれぞれで、上流と bdf.mbt の索引を実測した結果が記録されている。
- [ ] 差分がある条件を修正した、または上流も同じで対象外と記録した。
- [ ] 再現フィクスチャが `compat/jww/fixtures/` にあり、出所とライセンスが README にある。
- [ ] `node compat/converter/phase5-test.mjs` が通る。
- [ ] ピクセル比較のしきい値を変えていない。

## テスト計画

- `MOON_HOME=$PWD/.moon-home moon build --target js`
- `node compat/converter/phase5-test.mjs`
- `node compat/parity/render-diff.mjs --case=jww/shapes --case=jww/old` で描画差分が 0% のままであることを確認する。
- 追加フィクスチャで `decodeTextIndex` の run 列を上流と比較する。

## リスク

- 非表示レイヤーの文字を索引に入れると、検索結果に画面に出ない文字が現れる。上流がそうしている場合でも、利用者には見え方の変化として映る。
- 空白のみの文字を索引に入れると、検索のヒット数が増える。
- 合成 JWW の生成が形式の細部（LZH 圧縮、ヘッダ）で上流の読み取りと一致しない可能性がある。一致しない場合は生成をやめ、再配布可能な実ファイルを探す。
- `phase5-test.mjs` の比較対象を増やすと、既存の 15 フィクスチャの実行時間が伸びる。

## 変更履歴

`CHANGES.md` impact: yes（索引の文字列集合が変わる場合）

項目案：

- jww: 非表示レイヤーと空白のみの文字を、上流と同じ条件でテキスト索引に入れる。

## 注記

- 実測コマンド: `MOON_HOME=$PWD/.moon-home moon build --target js`、`node compat/converter/phase5-test.mjs`、`node _scratch/jww-text-index.mjs`。
- `_scratch/jww-text-index.mjs` は作業用で、リポジトリには含めない。
- 報告の「0% ピクセル差分」は再現していない。この worktree では JWW の描画比較を実行していない。
- 索引の `a`/`b` が両者 0 であることは実測済み。テキストレイヤーの矩形が無いこと自体は上流と同じで、差分の説明にならない。
