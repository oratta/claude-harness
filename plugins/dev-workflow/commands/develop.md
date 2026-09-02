---
name: develop
description: 標準開発ワークフロー（develop スキル）を起動する。issue があればそれを記録先に、無ければ Draft PR を記録先にして進める（issue を切るのは追跡・キュー・議論が要るときだけ）
argument-hint: "[issue番号|issueURL|自然文の依頼]"
allowed-tools: Read, Glob, Grep, Bash, Agent, SendMessage, AskUserQuestion
---

`develop` スキルの薄いラッパー。手順の正（本体＝オーケストレータの 1 ループ・入口 0・エピックの扱い）は **`skills/develop/SKILL.md` の 1 箇所にのみ存在する**。このコマンドはそれを Read tool で読み込み、その指示に従ってメインセッションで interactive モードのままインライン実行する。本体はコードを書かない（`allowed-tools` に Edit / Write が無いのはそのため。編集は W が行う）。

**Skill tool は使わないこと。** この command は既に「ユーザーが起動した slash command」であり、Read tool で SKILL.md 本文（および必要なら `references/decision-criteria.md`）を読み込み、この command の frontmatter（`allowed-tools`）配下でそのままインライン実行する。

## ファイル特定

```bash
for dir in \
  "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/skills/develop}" \
  ~/.claude/plugins/marketplaces/*/plugins/dev-workflow/skills/develop \
  ~/.claude/plugins/installed/*/dev-workflow/skills/develop; do
  [ -n "$dir" ] && [ -f "$dir/SKILL.md" ] && echo "$dir/SKILL.md" && break
done
```

特定した絶対パス（`skills/develop/SKILL.md`）を Read tool で読み込み、本体として 1 ループを回す。**interactive モード**（デフォルト）で実行する。`--unmanned` は loop-dev-agent の憲法ファイル（`docs/agent-loop.md`）の Step 3 でメインが develop の本体を務めるとき専用であり、このコマンドから human が起動した場合には使わない。

## 引数の解釈（5分岐）

`$ARGUMENTS` から記録先を確定する。既存 issue が特定できる分岐（①③）は従来どおり。issue を特定できない分岐（②④⑤）の既定は **develop の入口 0（issue を切らず Draft PR を記録先にする）** で、issueify フォールバックは「追跡・キュー・議論が要る」とユーザーが選んだときだけ:

- **① 数字のみ（例: `42`）で issue が存在する** → カレントリポジトリの issue #42 を記録先にして develop パイプラインへ（従来どおり）
- **② 数字のみだが issue が存在しない** → 新規作成に直行せず **typo 確認を先に行う**（番号を打った人の意図は高確率で既存 issue 参照）。`gh issue list` で近い番号・タイトルの候補を提示して意図を確認し、ユーザーが「新規に issue 化したい」と明示した場合のみ後述の issueify フォールバックへ。希望しなければ入口 0（Draft PR を記録先）へ
- **③ GitHub issue URL、または自然文（例: `issue#12 のログイン不具合を直して`）で既存 issue が特定できる** → URL から owner/repo/番号を抽出、自然文なら番号を推測し `gh issue view <番号>` で存在確認し、その issue を記録先にして develop パイプラインへ（従来どおり）
- **④ 自然文がどの既存 issue にもマッチしない** → 既定は入口 0（issue を切らず Draft PR を記録先）へ。追跡・キュー・議論が要る（エピック／無人キューに載せたい／判断の経緯を issue に残したい）場合のみ、確認のうえ issueify フォールバックへ
- **⑤ 引数なし** → `gh issue list --state open` で開いている issue を一覧し、選択肢に「**新しいタスクを説明して着手する（issue は切らない）**」と「**新しいタスクを説明して issue 化する**」を加えて提示する。前者はタスクの説明を聞いて入口 0 へ、後者は issueify フォールバックへ

特定（または起票）した issue 番号、または「Draft PR を記録先にする」の指示を SKILL.md の入口 0 にそのまま渡す。①③の既存分岐の挙動はこの変更で変わっていない。

## issueify フォールバック（issue を切ると決めた場合）

追跡・キュー・議論が要るときに、**起票してから標準パイプラインに乗せる**ための手順。ユーザーが `/develop` を明示的に起動していることが入口ゲートであり、これは自動の入口分類（issue #26 で却下済み）には該当しない。

1. **同じプラグイン内の issueify スキルを解決する**（develop 本体の特定と同じパターン。他プラグインへは探索しない）:

   ```bash
   for dir in \
     "${CLAUDE_PLUGIN_ROOT:+${CLAUDE_PLUGIN_ROOT}/skills/issueify}" \
     ~/.claude/plugins/marketplaces/*/plugins/dev-workflow/skills/issueify \
     ~/.claude/plugins/installed/*/dev-workflow/skills/issueify; do
     [ -n "$dir" ] && [ -f "$dir/SKILL.md" ] && echo "$dir/SKILL.md" && break
   done
   ```

2. **見つかった場合**: その `skills/issueify/SKILL.md` を Read tool で読み込み、手順（原子化 → 測定可能な受け入れ条件のドラフト → 不足だけヒアリング → 承認 → 起票）をインライン実行する。Skill tool は使わない（この command の方針と同じ）。
3. **見つからない場合（fail-soft）**: エラーで停止せず、最小手順に縮退する — 依頼内容から「これで何が変わるか（最大 3 行・技術用語禁止）/ やらないとどうなるか・今のコスト（最大 3 行）/ 概要 / 触るファイル（Grep で実在確認）/ 測定可能な受け入れ条件（実行コマンド + 期待値）」のドラフトを作って提示し、承認後に `gh issue create` で起票する。
4. **承認ゲート（両経路共通）**: ドラフトを提示してユーザーの**承認を得てから**起票する。承認なしに `gh issue create` を実行しない。
5. **複数 issue に割れた場合**: 原子化の結果が複数 issue になったら全件を起票した上で、**着手する1件**をユーザーに選択させ、その1件だけを SKILL.md の実行に渡す。残りは起票のみ（次回の `/develop` や loop-dev-agent が拾う）。複数 PR にまたがるなら SKILL.md「エピックの扱い」に従いエピックとして作る。
6. 起票された issue 番号で通常フロー（`skills/develop/SKILL.md` の入口 0 → 1 ループ）に接続する。

引数 (`$ARGUMENTS`) の内容: $ARGUMENTS
