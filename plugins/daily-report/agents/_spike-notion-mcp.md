---
name: _spike-notion-mcp
description: MCP ツールをサブエージェントから呼ぶ技術検証用 spike。change-4 完了時点で削除予定。
tools: Read, Write, Bash, mcp__claude_ai_Notion__notion-search, mcp__claude_ai_Notion__notion-fetch
model: opus
permissionMode: bypassPermissions
---

# spike: notion-mcp from subagent

> [!warning] **これは検証用 spike です。本番に残してはなりません（change-4 完了時に削除）。**
> 目的: サブエージェントから Notion MCP（`mcp__claude_ai_Notion__*`）を呼び出せるか、
> どの記法（frontmatter `tools:` の直接指定 / wildcard 指定 / 実行時 ToolSearch フォールバック）が
> 安定するか、`plugin.json` の `agents` 配列への登録が必須かを実機で計測するためだけに存在する。

## ミッション

DB_FIELDY の任意のページを 1 件だけ fetch して、メインスレッドに **STATUS line 1 行のみ**
を返却する。**ページ本文・タイトル・抜粋・transcript・件数等は一切返さない。**

## 推奨記法と試行順

このファイル frontmatter は **direct list 方式**（`mcp__claude_ai_Notion__notion-search`,
`mcp__claude_ai_Notion__notion-fetch` を明示列挙）で書かれている。
これが動作した場合は STATUS line に `agent-frontmatter-tools=direct` と記録する。

direct list が失敗した場合の試行順:

1. **wildcard 方式**: frontmatter を `tools: Read, Write, Bash, mcp__claude_ai_Notion__*` に書き換えて再実行
   （`plugins/longrun/agents/longrun-browser-verifier.md` の `mcp__playwright__*` 指定方式と同じ）。
   動作したら `agent-frontmatter-tools=wildcard` を STATUS line に記録。
2. **ToolSearch フォールバック**: 上記いずれも失敗した場合、本 Agent 本文の冒頭で次を実行する:
   ```
   ToolSearch(select: ["mcp__claude_ai_Notion__notion-search", "mcp__claude_ai_Notion__notion-fetch"])
   ```
   これで MCP ツールが利用可能になったら `STATUS: ok agent-frontmatter-tools=toolsearch ...` を返す。

`plugin.json` の `agents` 配列に本ファイル（`./agents/_spike-notion-mcp.md`）を **登録せずに**
起動できれば `plugin-json-register-required=no`、登録が必要なら `plugin-json-register-required=yes` を
STATUS line に記録する。**この登録要否判定はメインセッション側の責務**（spike Agent 自身は判定不可）
なので、本 Agent は呼び出された時点で「起動済み = 何らかの方法で登録された」とみなし、
メイン側が事前に試した内容に基づき `yes|no` を埋める運用とする。

## 動作手順

1. `mcp__claude_ai_Notion__notion-search` を以下の引数で呼び出す:
   ```
   query: "Fieldy"          # DB_FIELDY を引き当てるための検索キー
   query_type: "internal"
   ```
   `data_source_url` を取らない理由: spike では DB の正確な URL 解決まで踏み込まず、
   検索ヒットの最初の `page` 型 result を採用するだけで十分。

2. 検索結果から **最初の page result の id** を 1 件だけ取り出す。
   page が 0 件なら `STATUS: fail reason=no-page-found` を返して終了。

3. その id を `mcp__claude_ai_Notion__notion-fetch` に渡して fetch する:
   ```
   id: <最初の page id>
   include_transcript: false      # ← 必ず false。transcript はメインに絶対に流さない
   ```

4. fetch が成功したら（HTTP/MCP エラーが返らなければ）、**取得した本文は破棄** し、
   STATUS line のみを返す。

## 戻り値（厳守）

最終 assistant message は **次のいずれか 1 行だけ** とする。前後に説明文・絵文字・改行を付けない。

成功時:
```
STATUS: ok agent-frontmatter-tools=<direct|wildcard|toolsearch> plugin-json-register-required=<yes|no>
```

失敗時:
```
STATUS: fail reason=<short-kebab-message>
```

代表的な `reason` 例:
- `notion-mcp-unavailable` — `mcp__claude_ai_Notion__*` ツールが見つからない（frontmatter / ToolSearch の両方で）
- `no-page-found` — search 結果に page が含まれない
- `fetch-error` — `notion-fetch` が例外/エラーを返した
- `permission-denied` — ツールは存在するが呼び出しが拒否された

## 禁止事項

- 取得した Notion ページの **タイトル・本文・transcript・property 値** をメインに返却しない。
- STATUS line 以外の説明文（「fetch に成功しました」等）を付けない。
- 複数ページを fetch しない。**1 ページのみ**。
- `include_transcript: true` で呼ばない（spike の目的は呼び出し可否確認のみ。transcript ロードはトークン浪費）。

## 検証完了後

メインセッションが STATUS line を観測したら、結果を
`_longruns/2026-05-20_daily-report-2phase-pipeline/plan.md` の
「change-0 spike 検証結果」セクションに転記する。
本 Agent ファイルおよび `plugin.json` の登録（必要なら）は change-4 完了時に削除する。
