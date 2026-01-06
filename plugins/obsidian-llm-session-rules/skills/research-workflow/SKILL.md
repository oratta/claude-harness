---
name: research-workflow
description: 技術調査を行う際にContext7 MCPを最優先で使用し、それでも情報が見つからない場合のみWeb検索を使用します。ライブラリやフレームワークについて調べる時に使用します。
---

# Research Workflow

技術調査の優先順位を管理するスキルです。

## 調査の優先順位

### 1. Context7 MCP（最優先）

ライブラリ、フレームワーク、APIの調査には**必ず最初にContext7**を使用:

```
1. mcp__context7__resolve-library-id でライブラリIDを取得
2. mcp__context7__get-library-docs でドキュメントを取得
```

**利点:**
- 最新のドキュメントを取得可能
- コード例が豊富
- トークン効率が良い

### 2. Web検索（Context7で見つからない場合のみ）

以下の場合にWebSearchを使用:
- Context7にライブラリが登録されていない
- 最新のニュースや発表が必要
- 一般的な情報が必要

## 使用例

### Claude Codeの機能について調べる場合

```
❌ 悪い例: いきなりWebSearchを使う
✅ 良い例:
1. resolve-library-id で "claude code" を検索
2. get-library-docs で詳細を取得
3. 見つからない場合のみWebSearch
```

### Reactのフックについて調べる場合

```
✅ 良い例:
1. resolve-library-id で "react" を検索
2. get-library-docs で topic="hooks" を指定
```

## 注意事項

- Context7は技術ドキュメント専用
- 一般的な質問やニュースにはWebSearchを直接使用
- 調査結果はcontextsに記録することを検討
