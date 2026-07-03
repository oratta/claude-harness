---
name: e2s-distill
description: cwd のセッション jsonl から自然言語の依頼でスキルを蒸留し SKILL.md を生成する（対話完結 1 コマンド）。
allowed-tools: Read, Write, Bash, Glob, Grep
---

# /e2s:distill — 対話完結のスキル蒸留

`~/.claude/projects/<encoded-cwd>/*.jsonl` から、ユーザーが自然言語で示した過去作業を見つけ出し、その成功手順を SKILL.md として蒸留する。**1 コマンドで完結する**（旧 `/e2s:reflect` → `/e2s:distill` の 2 段階分離は廃止）。

## $ARGUMENTS

- 引数なし: cwd の jsonl 一覧（日付・サイズ）を表示して、ユーザーに「どんな作業をスキル化したいか」自然言語で示してもらう
- 引数 `<自然言語指示>`: 例「先週どこかで動画の生成を行ったと思う。最終的に成功したプロセスをスキルにしてほしい」

## 実行手順

### Step 1: jsonl ディレクトリの解決

```bash
# plugin ルートは Claude Code が注入する ${CLAUDE_PLUGIN_ROOT} を基点に解決する。
# （slash command 実行時のシェル位置パラメータは command ファイルを指さないため、
#  位置パラメータからの逆算による plugin ルート導出は使えない）
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"
# shellcheck source=/dev/null
source "$PLUGIN_ROOT/scripts/jsonl-finder.sh"

cwd="$(pwd)"
jsonl_dir="$(e2s_resolve_jsonl_dir "$cwd")" || {
  echo "❌ cwd '$cwd' に対応する jsonl ディレクトリが ~/.claude/projects/ 配下に見つかりません。"
  echo "   このディレクトリで Claude Code が起動した実績がない可能性があります。"
  exit 1
}
echo "📂 jsonl ディレクトリ: $jsonl_dir"
```

逆引きフォールバックは `e2s_resolve_jsonl_dir` 内で自動適用される。

### Step 2: 初期候補リストの提示

```bash
# デフォルトは「過去 30 日 / 50MB 以下」
E2S_JSONL_SINCE_DAYS=30 e2s_list_jsonl "$cwd" | head -20
```

各 jsonl について以下を整形して表示する（LLM が `jq` / `python3` で parse）：

- 日付（mtime）
- ファイルサイズ
- 先頭 user メッセージ抜粋（30 字程度、必ず Layer 1 `e2s_sanitize` を通す）
- ターン数（行数 / 2 で概算）

### Step 3: ユーザー指示の解釈

引数として渡された自然言語指示から以下のヒントを抽出する：

- **期間**: 「先週」「3日前」「昨日」等を ISO 日付範囲に変換
- **トピックキーワード**: 「動画」「ffmpeg」「デプロイ」等
- **成否ヒント**: 「成功したプロセス」「うまくいった方」等

抽出した日付範囲は `E2S_JSONL_SINCE_DAYS`（または独自 since 計算）、キーワードは `E2S_JSONL_KEYWORDS` 環境変数で `e2s_list_jsonl` に渡す。

### Step 4: 候補絞り込みとユーザー確認

絞り込み後の jsonl が 1 件: そのまま Step 5 へ。
2 件以上: ユーザーに番号付きリストで提示し、選択してもらう。各候補について以下も提示：

- そのファイル内でキーワード（複数あれば全部）が最初に出現するターン
- そのファイル内で最後に「成功」「ok」「done」相当の語が出現するターン

### Step 5: 該当ターンの読み込み

選ばれた jsonl について、キーワード初出ターン〜成功ターンを `+5` ターンずつ含めて読み込む。Bash で `jq -c '.[]'` または `python3 -c "import json; ..."` を活用。

### Step 6: Layer 1 サニタイズ

抽出テキストを `e2s_sanitize` に通す：

```bash
sanitized="$(printf '%s' "$extracted_text" | bash "$PLUGIN_ROOT/scripts/sanitize.sh")"
```

API key / PEM / メール等の正規表現マッチが `[REDACTED:<kind>]` に置換される。

### Step 7: Layer 2 セマンティックレビュー（LLM 判断）

サニタイズ後テキストを LLM 自身が再レビューし、以下を確認・処理：

- **独自形式トークン**: 社内 API token、カスタム認証 string、personal access token 相当
- **PII**: 個人名 + 識別子の組合せ、住所、電話
- **URL embedded credentials**: `https://user:password@...`
- **TODO/FIXME 仮 credentials**: 「後で直す」系の placeholder

疑わしい箇所は抽象化・削除。判断が分かれる場合は必ずユーザーに確認する。

### Step 8: SKILL.md 草案生成

以下のテンプレートに沿って構築する。**frontmatter の `name:` は `e2s-` または `distilled-` prefix 必須**：

```markdown
---
name: e2s-<kebab-case>
description: <一行説明、原文転記禁止>
---

# <Human-readable title>

## このスキルを起動する条件

<どんなときに役立つかを自然言語で>

## 手順

1. <step>
2. <step>
...

## 注意事項

<試行錯誤の中で発見した「やってはいけないこと」、落とし穴>

## Source

蒸留元 jsonl: <relative-path-to-jsonl> (turns N-M)
蒸留日時: <ISO timestamp>
蒸留コマンド: /e2s:distill <自然言語指示>
```

### Step 9: 配置先選択

LLM がユーザーに以下を尋ねる（AskUserQuestion は使わず通常の対話で）：

```
SKILL.md を生成します:
  - skill 名: e2s-<name>
  - 配置先候補:
    1) プロジェクトローカル: <repo>/.claude/skills/distilled/<name>/SKILL.md
    2) ユーザーグローバル: ~/.claude/skills/distilled/<name>/SKILL.md

どちらに配置しますか？（1 / 2）
```

`<repo>` は `git rev-parse --show-toplevel` で取得。git 管理外なら 2 のみ提示。

### Step 10: 書き出し

```bash
mkdir -p "$skill_dir"
# Write tool で SKILL.md を作成
```

衝突時は AskUserQuestion ではなく通常の対話で次を尋ねる：

```
既に <target_file> が存在します:
  1) 上書きする
  2) -v2 等の suffix を付けて別ファイルにする
  3) キャンセル
```

### Step 11: 結果報告

```
✅ SKILL.md を生成しました

場所: <target_file>
frontmatter name: e2s-<name>
蒸留元: <jsonl-path> (turns N-M)

次のアクション:
  - 内容をレビューして手直し
  - Claude Code で `/reload-plugins` または新セッションで認識
  - 別の作業も蒸留: /e2s:distill <次の自然言語指示>
```

## Guardrails

- frontmatter `name:` に `e2s-` または `distilled-` prefix を必ず付ける（本家 skill-creator との衝突回避）
- `~/.claude/skills/` 直下（`distilled/` サブディレクトリ外）には書き込まない
- 既存ファイルを黙って上書きしない（必ず確認）
- jsonl 原文を SKILL.md にそのまま転記しない
- 旧 e2s が依存していた一時候補ファイル（旧 reflect 系コマンドの中間生成物）には **依存しない**。このコマンドだけで自己完結する
- git 操作（add / commit / tag）は一切行わない

## 関連参照

- スキル本体: `plugins/experience-to-skill/skills/experience-to-skill/SKILL.md`
- jsonl 探索: `plugins/experience-to-skill/scripts/jsonl-finder.sh`
- サニタイズ: `plugins/experience-to-skill/scripts/sanitize.sh`
