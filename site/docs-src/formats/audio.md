# 音声ファイル

音声ファイルにページはありませんが、絵と文字はあります。プレイヤーが見せるカバーアートとタグです。`converter/audio` は MP3、AAC（M4A、または生の ADTS）、FLAC、Ogg Vorbis・Opus、WAV、AIFF のファイルを 1 ページの文書、つまりカードにします。上端いっぱいにカバーを置き、その下に題名・アーティスト・アルバム、ほかの項目の表、歌詞、章を並べます。タグは文書の Dublin Core になるので、ファイル一覧は文書と同じように音声を検索し並べ替えられ、文書のサムネイルはカバーになります。カードは再生できます。文書は音声ファイルをそのまま持ち、ビューアはそれをブラウザ自身のプレイヤーに渡します。歌詞が各行の歌われる時刻を持っていれば、ビューアは曲に合わせてカードの上の行を示します。

## 試してみる

ファイルを[ビューア](https://shibukawa.github.io/bdf/viewer/)にドロップするか、[カバーアートと時刻つきの歌詞を持つ曲](https://shibukawa.github.io/bdf/viewer/?file=samples/synced.mp3)と、[タグ・歌詞・章がもっと多い MP3](https://shibukawa.github.io/bdf/viewer/?file=samples/tagged.mp3) を試してください。▶ かスペースキーで鳴ります。

## 再生

音声は丸ごと、何も変えずに格納します。`audio` の Part になり、View の `play` がメディアタイプと一緒に指します（[spec §4.4](../spec.md#44-演奏play)）。途中でデコードも再エンコードもしないので、変換器はコーデックを持たず、音はファイルそのままです。デコードするのはブラウザで、何が鳴るかもブラウザで決まります。MP3、AAC、FLAC、Ogg Vorbis・Opus、WAV はいまのブラウザで鳴ります。AIFF と Apple Lossless は Safari だけです。ブラウザが鳴らせないファイルもカードは表示され、ビューアは鳴らせないことを伝えます。

デモビューアは楽譜と同じ操作で鳴らします。▶ と ■、スペースキー、パーセントの速度（音程は変わりません）、それに位置のスライダーです。サンプルサーバーのミニビューアは、カードの下にブラウザ自身のコントロールを出します。

音声を持つぶん、文書はファイルと同じ大きさになり、変換器はそれをメモリに持ちます。抑える手段は 3 つあります。

| | コマンドライン | Go |
|---|---|---|
| 音声を格納しない | `-param play=false` | `audio.Options.NoPlay` |
| 音声を格納するファイルの大きさの上限（既定 256 MiB） | `-param maxaudio=64`（MiB） | `audio.Options.MaxAudio`（バイト） |
| サムネイルのための変換 | `-pages 1` | `converter.Options{Pages: converter.PageList(1)}` |

上限を超えるファイルも変換します。音声のないカードになり、警告が出ます。ブラウザでの既定の上限は 64 MiB です。変換モジュールが変換のあいだファイルを何重にもメモリに持つためです。変換器の `convert`・`open` の `params` オプションに同じ名前で渡せます（`{ maxaudio: "128" }`、`{ play: "false" }`）。ページを選んだ変換が音声を格納しないのは、サムネイルやファイル一覧には要らないからです。`-param play=true` を付ければ格納します。DRM で保護された音声は格納しません。

## 曲を追う歌詞

歌詞はどちらの場合もカードに載ります。各行の時刻を持っていれば、View は cue も持ちます（[spec §4.4](../spec.md#44-演奏play)）。カードの上の各行の矩形と、その行が始まるミリ秒です。ビューアは歌っている行を示し、その行が見えるようにスクロールし、行をクリックするとそこから鳴らします。

時刻つきの歌詞は次のものから読みます。

- **ID3 の `SYLT`** フレーム。内容種別が歌詞で、タイムスタンプがミリ秒のもの。項目は行ごとでも、行の間に改行を挟んだ語・音節ごとでも読みます。
- **歌詞のフィールドに入った LRC のテキスト**。`USLT`、`©lyr`、Vorbis コメントの `LYRICS`・`UNSYNCEDLYRICS`・`SYNCEDLYRICS` です。タグ付けソフトの多くはこの形で書きます。

```
[ti:晴れた野原]
[offset:+250]
[00:01.50]野原の上に太陽
[00:04.50]雲ひとつない夏の空
[00:07.25]
[00:08.00][00:20.00]小道を歩いて帰る
```

LRC のテキストのうち、タイムスタンプと、ファイルを説明するタグ（`[ti:…]`、`[ar:…]`、`[offset:…]` など）は表示しません。`offset` は時刻をずらします。タイムスタンプが複数ある行は、歌われる順にその数だけ表示します。タイムスタンプだけの行は歌の切れ目で、次の行から連を改めます。拡張形式の語ごとのタイムスタンプ（`<00:08.40>`）は落とします。追うのは行で、語ではありません。タイムスタンプのある行がほかの行より少ないテキストは LRC とみなさないので、`[Chorus: All]` のような見出しを持つふつうの歌詞はそのまま表示されます。

両方を持つファイルでは `SYLT` を使います。時刻つきの歌詞がなく章があるファイル（オーディオブック、ポッドキャスト）では、章が cue になります。ビューアは再生中の章を示し、章をクリックするとそこから鳴らします。

まだ読まないもの: 音声ファイルの隣の `.lrc` ファイルと、MPEG フレーム単位の `SYLT` のタイムスタンプ（その歌詞は時刻なしで表示します）。

## 読むもの

| 形式 | 拡張子 | タグ | カバーアート | 長さと符号化 |
|---|---|---|---|---|
| MP3（MPEG レイヤー I・II も） | .mp3 | ID3v2（2.2・2.3・2.4）、ID3v1 | ID3v2 の `APIC` | フレーム。Xing/Info/VBRI ヘッダー、なければ全フレーム |
| MP4 の AAC | .m4a、.m4b、.m4p | iTunes 形式の `ilst`（自由形式の `----` フィールド、QuickTime の `keys` を含む）、Nero の章（`chpl`）、`uuid` ボックスの XMP | `covr` | `mvhd`、サンプル記述（`esds`: AAC・HE-AAC・MP3。`alac`、`fLaC`、`Opus`、PCM …） |
| 生の AAC | .aac | 先頭の ID3v2 タグ（あれば） | | ADTS のフレーム |
| FLAC | .flac | Vorbis コメント（先頭の ID3v2 タグは足りない項目を補う） | `PICTURE` ブロック | `STREAMINFO` |
| Ogg | .ogg、.oga、.opus、.spx | Vorbis・Opus・FLAC・Speex ストリームの Vorbis コメント | `METADATA_BLOCK_PICTURE`（古い `COVERART` も） | 識別ヘッダーと最後のページ |
| WAV | .wav | RIFF の `INFO` リスト、Broadcast Wave 拡張（`bext`）、`id3 ` チャンク | ID3 チャンク | `fmt ` と `data` の大きさ（RF64 も） |
| AIFF、AIFF-C | .aif、.aiff、.aifc | `NAME`、`AUTH`、`(c) `、`ANNO`、`ID3 ` チャンク | ID3 チャンク | `COMM` |

ページの幅はカバーの幅です（小さいカバーは 360 pt まで拡大し、大きいカバーは 720 pt まで縮小します）。カバーは `converter/image` が画像を格納するのと同じく、ファイルが持つ形式（たいてい JPEG か PNG）のまま格納します。`-images convert` はほかの文書の画像と同じく再エンコードします。カバーのないファイルには音符を描いたプレースホルダーの正方形を置きます。文字は HTML・Markdown の文書と同じくビューアのサンセリフのフォントで組み、推定した幅で折り返します。カードは検索と読み上げのための構造を持ちます。題名は見出し、項目は表、歌詞は段落と行、章はリストです。

ID3 の「ISO-8859-1」のフレーム、ID3v1、RIFF の `INFO`、AIFF のテキストチャンクの文字列は、MIDI の変換器と同じ読み方で、すべてが正しい UTF-8 なら UTF-8、すべてが Shift_JIS なら Shift_JIS、そうでなければ Windows-1252 として読みます。1 つのフレームに入った複数のアーティスト（ID3v2.4 は NUL 区切り、ほかはセミコロン区切り）は複数の値に、ID3v1 の番号のジャンル（`(17)`、`17`）は名前に、年・日月・時刻のフレームに分かれた日付（ID3v2.3）は 1 つの日付にします。

## メタデータ

タグは次のように Dublin Core の要素に写します（MP4 ファイルが XMP を持てば、画像と同じくそれが先）。`type` は常に `Sound`、`format` はファイルのメディアタイプです。

| 要素 | ID3v2 | MP4 | Vorbis コメント | RIFF INFO、AIFF |
|---|---|---|---|---|
| `title` | `TIT2` | `©nam` | `TITLE` | `INAM`。`NAME` |
| `creator` | `TPE1` | `©ART` | `ARTIST` | `IART`。`AUTH` |
| `contributor` | `TPE2`（アルバムアーティスト）、`TCOM`、`TEXT`、`TPE3`、`TPE4` | `aART`、`©wrt` | `ALBUMARTIST`、`COMPOSER`、`LYRICIST`、`CONDUCTOR`、`ARRANGER`、`REMIXER` | `IMUS`、`IWRI` |
| `subject` | `TCON` | `©gen`、`gnre` | `GENRE` | `IGNR` |
| `description` | `COMM`（iTunes などプログラム自身のものは除く） | `©cmt`、`desc` | `COMMENT`、`DESCRIPTION` | `ICMT`、`bext` の説明。`ANNO` |
| `publisher` | `TPUB` | `----:…:LABEL` | `PUBLISHER`、`LABEL`、`ORGANIZATION` | – |
| `date` | `TDRC`、または `TYER` + `TDAT` + `TIME`、または `TDRL` | `©day` | `DATE` | `ICRD`、`bext` の作成日 |
| `identifier` | `TSRC` | `----:…:ISRC` | `ISRC` | – |
| `relation` | `TALB`（アルバム） | `©alb` | `ALBUM` | `IPRD` |
| `language` | `TLAN`（ISO 639-2 を BCP 47 で書く） | トラックの `mdhd` | `LANGUAGE` | `ILNG` |
| `rights` | `TCOP` | `cprt` | `COPYRIGHT`、`LICENSE` | `ICOP`。`(c) ` |

カードにはほかに副題、グループ、トラックとディスクの番号、原盤の日付、BPM、長さ、符号化（コーデック、PCM とロスレスのビット深度、ビットレート、サンプリング周波数、チャンネル）、歌詞（`SYLT`、`USLT`。`©lyr`。`LYRICS`、`UNSYNCEDLYRICS`、`SYNCEDLYRICS`）、章（ID3 の `CHAP`、`chpl`、Vorbis コメントの `CHAPTER001` …）を載せます。上の項目と同じ名前のユーザー定義フィールド（`TXXX`、`----`）は、ファイルがほかで設定していない項目を補います。

`-param` は `play` と `maxaudio` で、[再生](#再生)で説明しています。内部は [design.md §3.31](../design.md#331-音声ファイル--bdf-変換器converteraudio) を参照してください。
