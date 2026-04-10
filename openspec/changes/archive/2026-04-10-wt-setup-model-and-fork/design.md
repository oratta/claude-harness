## Context

wt-setup SKILL.mdから実装詳細を除去済み（hide-script-internals-from-skill）だが、LLMが依然としてスクリプト実行をスキップする問題が再発。Context7のClaude Code公式ドキュメントで、frontmatterの`model`と`context: fork`フィールドがスキル実行を制御できることを確認済み。

現状のfrontmatter:
```yaml
name: wt-setup
description: Git worktreeの開発環境セットアップ。worktree作成後に実行する。
version: 1.0.0
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
```

## Goals / Non-Goals

**Goals:**
- スキル実行時のモデル能力を保証する（`model: sonnet`）
- 会話コンテキストの汚染からスキルを隔離する（`context: fork`）
- コマンドファイルのdescriptionから実装詳細を除去する

**Non-Goals:**
- wt-setup.shスクリプトの変更
- SKILL.md本文の変更（前回changeで対応済み）
- 他スキルへの横展開（今回はwt-setupのみ）

## Decisions

### D1: model: sonnet

セッションモデルに依存せず、常にsonnetで実行する。

- **採用理由**: wt-setupは「スクリプト実行→出力読み取り→条件分岐」という定型タスク。sonnetの指示遵守能力で十分。opusは過剰（コスト面ではなく、タスク特性に対して）。
- **却下案**: `model: opus` — タスクの複雑度に対してオーバースペック。`model: haiku` — 指示遵守が不安定。

### D2: context: fork

スキルをフォークされたサブエージェントで実行する。

- **採用理由**: 失敗ログの分析で、LLMが会話コンテキスト（worktree作成の話題等）に影響されて「まず状態を調べよう」という汎用パターンに入ることが判明。fork環境ではSKILL.mdの指示のみがコンテキストとなり、脱線の余地がなくなる。
- **却下案**: `effort: high`のみ — 会話コンテキストの影響を排除できない。

### D3: コマンドファイルdescriptionの修正

`Worktreeのセットアップ（.claude/ symlink、.worktreeinclude生成、envコピー）` → 実装詳細を除去。

- **採用理由**: コマンドファイルはSKILL.md読み込み前にLLMが最初に読む。ここに「symlink」があるとフレーミングが汚染される。

## Risks / Trade-offs

- **[Risk] context: fork環境でAskUserQuestionが動作しない可能性** → 実装時に検証。動作しない場合、.worktreeinclude生成をfork外に分離するか、context: forkを断念してmodel + effortのみで対応する。
- **[Risk] forkによりスキル実行結果が親コンテキストに返らない可能性** → Claude Code公式ドキュメントではforkされたスキルは結果を返す仕様。ただし実動作の検証は必要。
- **[Trade-off] fork環境では$ARGUMENTSの受け渡しが変わる可能性** → 検証項目に含める。

## Open Questions

- `context: fork` 環境でのAskUserQuestionの動作（検証で解決）
- `effort` フィールドの併用が有効かどうか（検証で解決）
