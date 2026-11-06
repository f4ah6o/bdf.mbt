---
title: Markdown のテスト文書
author: テスト太郎
date: 2026-09-26
lang: ja
tags: [bdf, markdown]
---

# Markdown のテスト文書

段落の本文です。**太字**、*斜体*、~~取り消し線~~、`インラインのコード`、[リンク](https://example.com/)
を含みます。ソースの改行は
和文の間では空白になりません。English text wraps at spaces, and a long line of text goes on to show how the lines of a paragraph break.

## リスト

- 項目 1
- 項目 2
  - 入れ子の項目 A
  - 入れ子の項目 B
    1. 番号付き
    2. 番号付き
- 項目 3

1. 手順 1
2. 手順 2

   続きの段落。

- [x] 完了したタスク
- [ ] 未完了のタスク

## 引用とコード

> 引用の段落です。
>
> > 入れ子の引用。

```go
func main() {
	fmt.Println("こんにちは、世界") // タブで字下げ
	if aVeryLongCondition && anotherVeryLongConditionThatMakesTheLineWrapInTheBox {
		return
	}
}
```

## 表

| 左寄せ | 中央 | 右寄せ |
|:-------|:----:|------:|
| りんご | 赤 | 120 |
| バナナ | 黄 | 98 |
| Long cell text that wraps in its column | 緑 | 1,000 |

## 画像

![グラデーションの画像](images/photo.png)

<p align="center"><img src="images/icon.png" alt="アイコン" width="48"><br>中央寄せの HTML</p>

---

見出しへのリンク: [リスト](#リスト)、脚注[^1]。

用語
: 定義リストの説明。

<details>
<summary>詳細</summary>

折りたたまれた内容も表示します。

</details>

[^1]: 脚注の本文です。
