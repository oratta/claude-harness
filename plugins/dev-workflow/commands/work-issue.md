---
name: work-issue
description: GitHub issue に取り組む標準開発ワークフローを起動する（issue が無ければ issueify で起票してから接続する）
argument-hint: "[issue番号|issueURL|自然文の依頼]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

`github-issue` スキルの薄いラッパー。手順の正（Step A〜D の本体）は **`skills/github-issue/SKILL.md` の 1 箇所にのみ存在する**。このコマンドはそれを Read tool で読み込み、その指示に従ってメインセッションで interactive モードのままインライン実行する。

**Skill tool は使わないこと。** この command は既に「ユーザーが起動した slash command」であり、Read tool で SKILL.md 本文（および必要なら `references/decision-criteria.md`）を読み込み、この command の frontmatter（`allowed-tools`）配下でそのままインライン実行する。

## ファイル特定

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/skills/github-issue}" \
  ~/.claude/plugins/marketplaces/*/plugins/dev-workflow/skills/github-issue \
  ~/.claude/plugins/installed/*/dev-workflow/skills/github-issue; do
  [ -n "$dir" ] && [ -f "$dir/SKILL.md" ] && echo "$dir/SKILL.md" && break
done
```

特定した絶対パス（`skills/github-issue/SKILL.md`）を Read tool で読み込み、Step A〜D に従って実行する。**interactive モード**（デフォルト）で実行する。`--unmanned` は loop-dev-agent の憲法ファイル（`docs/agent-loop.md`）からサブエージェント経由で呼ばれる時専用であり、このコマンドから human が起動した場合には使わない。

## 引数の解釈（5分岐）

`$ARGUMENTS` から対象 issue を特定する:

- **① 数字のみ（例: `42`）で issue が存在する** → カレントリポジトリの issue #42（従来どおり）
- **② 数字のみだが issue が存在しない** → 新規作成に直行せず **typo 確認を先に行う**（番号を打った人の意図は高確率で既存 issue 参照）。`gh issue list` で近い番号・タイトルの候補を提示して意図を確認し、ユーザーが「新規に issue 化したい」と明示した場合のみ後述の issueify フォールバックへ
- **③ GitHub issue URL、または自然文（例: `issue#12 のログイン不具合を直して`）で既存 issue が特定できる** → URL から owner/repo/番号を抽出、自然文なら番号を推測し `gh issue view <番号>` で存在確認（従来どおり）
- **④ 自然文がどの既存 issue にもマッチしない** → 「該当する issue が見つかりません。この依頼を新規 issue 化して進めますか？」と確認し、承諾されたら issueify フォールバックへ
- **⑤ 引数なし** → `gh issue list --state open` で開いている issue を一覧し、選択肢に「**新しいタスクを説明して issue 化する**」を加えて提示する。新規が選ばれたらタスクの説明を聞いて issueify フォールバックへ

特定（または起票）した issue 番号を SKILL.md の実行にそのまま渡す。①③の既存分岐の挙動はこの拡張で変更されていない。

## issueify フォールバック（issue が特定できない場合）

対象 issue が存在しない場合に、**起票してから標準パイプラインに乗せる**ための手順。ユーザーが `/work-issue` を明示的に起動していることが入口ゲートであり、これは自動の入口分類（issue #26 で却下済み）には該当しない。

1. **loops-issueify を path-discovery で解決する**（github-issue と同じパターン）:

   ```bash
   for dir in \
     "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT%/*}/loops/skills/loops-issueify}" \
     ~/.claude/plugins/marketplaces/*/plugins/loops/skills/loops-issueify \
     ~/.claude/plugins/installed/*/loops/skills/loops-issueify; do
     [ -n "$dir" ] && [ -f "$dir/SKILL.md" ] && echo "$dir/SKILL.md" && break
   done
   ```

2. **見つかった場合**: その SKILL.md を Read tool で読み込み、手順（原子化 → 測定可能な受け入れ条件のドラフト → 不足だけヒアリング → 承認 → 起票）をインライン実行する。Skill tool は使わない（この command の方針と同じ）。
3. **見つからない場合（fail-soft）**: エラーで停止せず、最小手順に縮退する — 依頼内容から「これで何が変わるか（最大 3 行・技術用語禁止）/ やらないとどうなるか・今のコスト（最大 3 行）/ 概要 / 触るファイル（Grep で実在確認）/ 測定可能な受け入れ条件（実行コマンド + 期待値）」のドラフトを作って提示し、承認後に `gh issue create` で起票する。
4. **承認ゲート（両経路共通）**: ドラフトを提示してユーザーの**承認を得てから**起票する。承認なしに `gh issue create` を実行しない。
5. **複数 issue に割れた場合**: 原子化の結果が複数 issue になったら全件を起票した上で、**着手する1件**をユーザーに選択させ、その1件だけを SKILL.md の実行に渡す。残りは起票のみ（次回の `/work-issue` や loop-dev-agent が拾う）。
6. 起票された issue 番号で通常フロー（`skills/github-issue/SKILL.md` の Step A〜D）に接続する。これにより issue 未起票の依頼も、実行戦略の4象限判定（Step B/C）を必ず通過する。

引数 (`$ARGUMENTS`) の内容: $ARGUMENTS
