# 楽譜

MML・MIDI・MusicXML は、いずれも共通の組版エンジン（`converter/internal/music`）が SMuFL のフォント Bravura で A4 のページに五線譜として組む。各 View はその音楽を Standard MIDI File として持つので、デモビューアで演奏できる。演奏の仕組みは[変換と出力 → 楽譜と演奏](../architecture/conversion.ja.md#楽譜と演奏)を参照してほしい。共通なのはそこまでで、MML と MIDI は演奏データから記譜そのものを組み立て直す必要があるのに対し、MusicXML はすでに書かれた記譜をそのまま読む。

## ギターTABの運指候補

ビューアの **Display** から **Score（五線譜）**・**Piano roll（ピアノロール）**・**Guitar TAB（ギターTAB）** を直接切り替えられる。Guitar TAB ではパートと運指方針を選ぶ。方針は**低いポジション優先**（Low positions）、**ポジション移動を減らす**（Less shifting）、**開放弦を積極的に使う**（Open strings）、**初心者向け**（Beginner friendly）の4種類。どれも「実際にその運指で演奏した」という記録ではなく、標準チューニング E A D G B E を前提にした推定候補である。TAB でも五線譜と同じ音楽を、速度調整とメトロノームを使って再生できる。

各音高の弦・フレット候補を列挙し、フレーズ全体の手の移動量も考慮して選ぶ。同時または重なって鳴る音を同じ弦に置かず、和音の押弦は4〜5フレットの範囲に収める。MusicXML の `<notations><technical>` にある `<string>`・`<fret>` は優先し、和音内で衝突するときだけ別の候補を検討する。ギターの音域外の音、演奏不可能な和音、5番目以降の有音高パート、2万音を超えるパートはTABから省き、変換時に警告する。TABが不要なら `-param tab=false` を指定できる。

## 試す

[ビューア](https://shibukawa.github.io/bdf/viewer/)にファイルをドロップするか、サンプルを試せる。[MML のチップチューン](https://shibukawa.github.io/bdf/viewer/?file=samples/frere.mml)、[歌詞付きの MIDI カラオケ](https://shibukawa.github.io/bdf/viewer/?file=samples/twinkle.kar)、[MusicXML のピアノ譜](https://shibukawa.github.io/bdf/viewer/?file=samples/minuet.musicxml)。**Display** から表示を選び、再生速度を%で調整できる（曲中のテンポ比は維持され、冒頭の換算 BPM を表示）。再生中にはメトロノームも有効にできる。

## MML（converter/mml）

MML と MIDI はどちらも演奏されたとおりのデータ（記譜済みではなく、時刻と長さのある音の並び）なので、組む前に共通の記譜の工程（`Notate`）を通す。音を音価に量子化し（拍や小節線をまたぐタイ、付点、3 連符）、小節と 1 段あたり最大 2 声部に分け、調（ファイルのもの、なければ音から推定したもの）で綴り、音域から音部記号を選ぶ（鍵盤楽器は大譜表になる）。

`converter/mml` は中身から 3 つの方言を判別する。汎用（FlMML と BASIC の `PLAY` 文）、マビノギの `MML@…;`、ファミコンの MCK・PPMCK のトラック行形式である。署名のない `.mml` ファイルで、MML と判別できる行が 2 行に満たないものは、中身に判別の手がかりが無いため拡張子だけで MML と判定される。

| オプション | 値 | 既定 |
|---|---|---|
| `dialect` | `auto`、`generic`（FlMML、MSX BASIC）、`mabinogi`（`MML@…;`）、`ppmck`（ファミコンの MCK・PPMCK） | `auto` |
| `octave` | `auto`、`normal`（`>` でオクターブが上がる）、`reverse`（`<` で上がる） | `auto` — 方言ごとの既定 |
| `time` | 拍子記号。例: `3/4`、`6/8` | `4/4` |
| `key` | 調号。例: `G`、`Bb`、`F#m`、`Em` | 音から推定 |
| `program` | 音色の指定が無いトラックの General MIDI プログラム番号（`0`〜`127`） | 方言ごとの既定 |
| `tab` | `true` または `false` | `true` |

## MIDI（converter/midi）

`converter/midi` は Standard MIDI File のフォーマット 0・1・2 と RIFF の `RMID` を読む。トラック（またはトラックとチャンネルの組）ごとにパートになり、名前はトラック名、無ければ General MIDI のプログラム名を使う。カラオケの歌詞（`.kar` の文字、またはメタイベント 05）は、最も合うトラックの音符に付く。MML と同じく、MIDI の音符も演奏されたとおりのデータなので、上と同じ `Notate` の工程を経て記譜される。

| オプション | 値 | 既定 |
|---|---|---|
| `time` | 拍子記号（`3/4`、`6/8`、`C` は 4/4、`cut`） | ファイルのもの |
| `key` | 調号（`G`、`Bb`、`F#m`、または 2 つのフラットを表す `-2`） | ファイルのもの、無ければ音から推定 |
| `tab` | `true` または `false` | `true` |

## MusicXML（converter/musicxml）

MusicXML は MML や MIDI と違い、演奏データから記譜し直すのではなく書かれたとおりに読む。複数の段のパート、声部、和音、連桁、連符、装飾音、臨時記号、タイとスラー、アーティキュレーションと装飾記号、強弱記号とヘアピン、節ごとの歌詞、音部記号・調号・拍子の変更、繰り返しと括弧、速度記号とリハーサルマーク、段の区切りは、すべてファイル自身の記述からそのまま読む。partwise・timewise のどちらの文書形式も、圧縮した `.mxl` も読む。演奏は繰り返しと、D.C.・D.S.・Fine・To Coda のような跳躍を展開して行う。

MusicXML では `-param tab=false` で推定TABの View を省ける。五線譜は引き続き元データの記譜どおりに変換される。

共通の組版エンジン（小節の間隔、符幹と連桁、タイとスラー、歌詞の折り返しなど）の内部は [design.md §3.27](../design.md#327-楽譜と演奏convertermmlconvertermidiconvertermusicxmlconverterinternalmusic) を参照。
