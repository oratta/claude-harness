---
name: develop
description: 標準開発ワークフロー（develop スキル）を起動する。issue があればそれを記録先に、無ければ Draft PR を記録先にして進める（issue を切るのは追跡・キュー・議論が要るときだけ）
argument-hint: "[(--profile NAME [--profile-file PATH] | --account NAME --model MODEL) (--account-home NAME=PATH… | --account-home-file PATH) [--executor codex] [--worker-state DIR] [--run-dir DIR]] [issue URL | request]"
allowed-tools: Read, Glob, Grep, Bash, Agent, SendMessage, AskUserQuestion
---

## 実行先オプション

`$ARGUMENTS` に `--profile <名前> [--profile-file <JSON>]` または旧形式の `--account <登録名> --model <CodexモデルID>` があればprovider adapterを適用する。`--executor codex` も後方互換の別名として受理するが、その場合もprofile形式か旧形式のどちらか一方を必須とする。両形式の併用、`--profile-file` 単独、旧形式の片方欠落は開始前に拒否する。これらを依頼本文から分離し、まず下記のSKILLパス探索でpluginルートを特定し、`${CLAUDE_PLUGIN_ROOT}/references/codex-develop.md`（環境変数がなければ発見した `skills/develop/SKILL.md` の3階層上のpluginルート＋`references/codex-develop.md`）を絶対パスでReadしてprovider adapterを適用する。いずれの実行先オプションも無い場合は従来のClaude経路とし、未知のexecutorは拒否する。profile が決めた投げ先を別 provider で代行しない。実行先オプションは委譲transportだけを変え、仕様要否・レビュー・チェック・順序は既存develop正本を使う。adapter の適用を理由に仕様を必須にしない。

引数なしの追加依頼では初回の Codex 設定を再推測しない。前景実行は台帳もrunも持たず継続記録を残さないので、追加依頼では実行先オプション（`--profile` または `--account`＋`--model`、および account名からCODEX_HOMEへの対応）を明示し直す。継続記録から再開できるのは `--run-dir` を使う台帳経路だけで、その場合は既存 develop が選んだ記録先（issue、issue が無い場合は Draft PR）のコメントを本体が取得し、旧runの `v1` またはprofile runの `v2` の最新候補を版混在のまま選んで検証する。不正・未知版の最新候補から古いv1へ戻らない。profile/config版/config hashはrun内snapshotだけと照合し、外部profile-fileを再読込しない。不在・不一致なら Claude や別 run/account へ fallbackせず停止する。形式の生成・解析とrun検証は `scripts/codex-develop.py` の継続記録ヘルパーを使う。

前景実行のCodexオプションは、account名からCODEX_HOMEへの対応表である。`--account-home NAME=PATH`（繰り返し可）か、account名をキー・CODEX_HOMEの絶対パスを値とする平らなJSON 1つを指す `--account-home-file PATH` のどちらか一方を渡し、併用は拒否する。本体はこれを依頼本文から分離し、`codex-develop.py request` へそのまま渡す。前景実行は台帳を読まないので、対応に無いaccount名は依頼ファイルを作らずに拒否する。

台帳経路のCodexオプション `--worker-state DIR` は登録済みworker台帳を指定する。省略時は `$HOME/.local/state/claude-harness-codex/jobs`。`--run-dir DIR` は継続するrunを明示するときに指定する。新規で省略するとinitが `$HOME/.local/state/claude-harness-codex/runs/<UUID>` を作り返す。本体は返された絶対pathを記録先と会話に記録し、以後の全操作で同じpathを使う。これらも依頼本文から除外する。前景実行ではどちらも使わない（`request` はrun-dirもworker-stateも取らない）。

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
