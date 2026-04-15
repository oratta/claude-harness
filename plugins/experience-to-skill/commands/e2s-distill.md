---
name: e2s-distill
description: /e2s:reflect で提示された skill 候補を SKILL.md ファイルとして生成する。
allowed-tools: Read, Write, Bash, Glob, AskUserQuestion
---

# /e2s:distill — skill 候補の SKILL.md 実体化

`/e2s:reflect` で生成された候補リスト（`/tmp/e2s/reflect-candidates.json`）から指定 ID を選び、`SKILL.md` ファイルとして書き出す。

## $ARGUMENTS

- 引数 `<candidate-id>`: 必須。整数（例: `1`, `2`）
- 引数なし / 不正な ID: エラー終了

## 実行手順

### Step 1: 候補リストの読み込み

```bash
if [ ! -f /tmp/e2s/reflect-candidates.json ]; then
  echo "❌ 候補リストがありません。先に /e2s:reflect を実行してください。"
  exit 1
fi
```

JSON を parse し、`$ARGUMENTS` の ID に該当する候補を取り出す。該当なしなら：

```
❌ 候補 ID <id> は存在しません。
利用可能な ID: 1, 2, 3

候補リストを再生成するには /e2s:reflect を実行してください。
```

### Step 2: 配置先の決定

AskUserQuestion で以下を問う：

```
候補 <id>「<name>」を SKILL.md として書き出します。
配置先を選んでください：

1. プロジェクトローカル: <repo-root>/.claude/skills/distilled/<name>/SKILL.md
   → このプロジェクトでのみ有効。リポジトリ内なので git 管理可能。

2. ユーザーグローバル: ~/.claude/skills/distilled/<name>/SKILL.md
   → 全プロジェクトで有効。個人資産として蓄積。

3. キャンセル
```

repo-root は `git rev-parse --show-toplevel` で取得。

### Step 3: ディレクトリと名前の確認

skill 名は `e2s-` または `distilled-` prefix を必須とする：

```bash
# candidate.name が "verify-infra-setup" なら
# prefixed_name = "e2s-verify-infra-setup" (デフォルト)
prefixed_name="e2s-${candidate_name}"

# frontmatter の name field に prefixed_name を使う
# ディレクトリ名は distilled/<candidate_name>/ でも distilled/<prefixed_name>/ でもOK
# デフォルトは distilled/<candidate_name>/ で短くする
skill_dir="${base_path}/.claude/skills/distilled/${candidate_name}"
```

### Step 4: 既存チェックと衝突時の対応

```bash
target_file="${skill_dir}/SKILL.md"

if [ -f "$target_file" ]; then
  # 衝突
fi
```

衝突時は AskUserQuestion で：

```
既に <target_file> が存在します。どうしますか？

1. 上書きする (既存を失う)
2. バージョン suffix を付ける (<name>-v2/)
3. キャンセル
```

バージョン suffix 選択時:
- `<name>-v2` → 存在すれば `<name>-v3` ... と最初の空き番号を使う
- frontmatter の name も `<prefixed_name>-v2` 等に合わせる

### Step 5: SKILL.md の生成

以下のテンプレートに沿って生成：

```markdown
---
name: <prefixed_name>
description: <candidate.description の一行。絶対に session 原文を含めない>
---

# <Human-readable title>

## このスキルの起動タイミング

<candidate.triggers から導出した条件文>

## 手順

<candidate.steps を番号付きリストで>

## 根拠

<candidate.rationale を抽象化して転記>

## 参照すべきファイル・概念

<candidate が検出されたコミットで頻繁に変更されたファイル・概念を列挙>

## 注意事項

<LLM が抽出した「やってはいけないこと」「落とし穴」があれば記載>

## Source

このスキルは以下の作業履歴から蒸留されました：

- commit <sha1> — <subject>
  session: <session-id>#turn-<N> (or `session-unavailable`)
- commit <sha2> — <subject>
  session: ...
- ...

蒸留日時: <ISO timestamp>
蒸留元範囲: <range>
蒸留元コマンド: /e2s:reflect <args> → /e2s:distill <id>
```

**sanitize 絶対ルール**（再掲）:

- session jsonl の原文を転記しない
- API key / PII を含む可能性がある文字列は除外
- 固有の個人名・会社名・URL が含まれる場合は抽象化するか削除
- frontmatter description は session 原文ではなく**パターンの抽象表現**

### Step 6: ファイル書き出し

```bash
mkdir -p "$skill_dir"
cat > "$target_file" <<'EOF'
<...上記テンプレート展開結果...>
EOF
```

### Step 7: 結果報告

```
✅ SKILL.md を生成しました

場所: <target_file>
frontmatter name: <prefixed_name>

次のアクション:
- 内容をレビュー: <target_file> を開いて確認
- 有効化: Claude Code の skills は配置すれば自動検出されます
  (プロジェクトローカルなら /reload-plugins、グローバルなら新セッションで認識)
- 別の候補も蒸留: /e2s:distill <other-id>
- 改善したい: 生成された SKILL.md を手で編集してください
```

## Guardrails

- frontmatter の `name:` に必ず `e2s-` または `distilled-` prefix を付ける（本家 skill-creator との衝突回避）
- 既存ファイルを黙って上書きしない（必ず確認）
- session jsonl 原文の転記を絶対にしない
- `~/.claude/skills/` 直下（`distilled/` サブディレクトリ外）には書き込まない
- git 操作は一切行わない（書き込まれる SKILL.md をユーザー自身でコミットするかは任意）

## 使い分けのガイド（プロジェクトローカル vs グローバル）

- **プロジェクトローカル (`<repo>/.claude/skills/distilled/`)**:
  - このコードベース固有のパターン（該当のアーキテクチャでのみ意味がある）
  - チーム共有したい（git に含めてレビュー可能）
  - ユーザーへの提案: 「このプロジェクト固有？」→ Yes ならプロジェクトローカル

- **ユーザーグローバル (`~/.claude/skills/distilled/`)**:
  - 複数プロジェクトで使い回せる汎用パターン
  - 個人の作業スタイル（コミットルール、レビュー手順など）
  - ユーザーへの提案: 「汎用性ある？」→ Yes ならグローバル
