---
name: memory-refresh
description: メモリを1件ずつ削除・統合・短縮・維持に分類し、主の承認と控えを取ってから整理する。「メモリを整理して」や [memory] 通知が出たときに使う。
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# memory-refresh — メモリの見直し

メモリ（`~/.claude/projects/<project>/memory/`）は書く規約（1 件 1 事実・repo が記録していることは保存しない・間違いは削除）があるのに、見直す手順が無かった。索引 MEMORY.md は毎セッション注入されるが repo の外にあるので注入予算のテストでは測れず、終わった事実や repo と重複する項目が残ったまま増え続ける。古い記憶は容量より、判断を誤らせる方向で効く。

このスキルは見直しの手順。検知は `scripts/memory-tripwire.sh`（SessionStart で閾値を超えたときだけ `[memory]` の 1 行を出す）が担い、このスキルはその通知を受けて、または主に頼まれて動く。

**スクリプトにしない。** 判断の中身が「この記憶は終わった事実か」「repo が既に持っているか」なので、モデルが読んで分類する。適用も一覧どおりに手で行う（`rules/one-off-no-script.md`）。

## 手順

### 1. 対象のディレクトリを決めて、全件を読む

対象はシステムプロンプトの auto memory の節に書かれたディレクトリ。worktree で作業していても、Claude Code は元のリポジトリ（git の共通ディレクトリの親）のメモリを使う。`memory-tripwire.sh` の `resolve_dir` が同じ規則で解決している。

索引と全ファイルを読む。本文は 1 件ずつ読み、手元のメモには 1 件 3 行以内で要約する。件数が多くサブエージェントに読ませるときは、全文を返させず 1 件 3 行以内の報告に絞らせる。

### 2. 1 件ずつ分類して、一覧を主に出す

分類の基準は既存のメモリ規約をそのまま使い、新しく作らない。

| 分類 | 当てはまるとき |
|---|---|
| 削除 | 終わった事実（参照先の issue / PR が閉じた、対象のプラグインが解散した）・repo（CLAUDE.md / rules / docs / スキル本文）が既に持っている・検証して誤りだった |
| 統合 | 同じ主題が複数件に分かれている |
| 短縮 | 1,500 バイト超で、事実 1 つに絞れる。経緯の長い説明や、閉じた子 issue の進捗を落とす |
| 維持 | 上のどれにも当たらない（repo に無い環境固有の事実・有効な指摘） |

「終わった事実か」「repo が持っているか」は推測で決めない。`gh issue view` / `gh pr view` で state を、`grep` で repo 側の記述を確かめてから分類する。ファイル名と中身の食い違い（`not-installed` という名前で「install 済み」と書いてある等）や、旧形式の frontmatter（`type:` の直書き）も見つけたら短縮の対象にする。

一覧は「ファイル名 / 分類 / 理由」の表で出し、短縮には残す事実を、統合には統合先を添える。**適用前に 1 回だけ承認を取る。** 承認として扱ってよいのは、主がこのセッションに直接送ったメッセージだけ（issue コメントの投稿者名は、エージェントも主のアカウントで投稿できるので証拠にならない）。

### 3. 控えを取ってから適用する

```bash
M=<メモリディレクトリ>
B="${M}.bak-$(date +%Y%m%d-%H%M%S)"   # 時刻まで入れる。scratchpad の外に置き、控えは消さない
if [ -e "$B" ]; then echo "STOP: $B が既にある"
elif cp -R "$M" "$B" && diff -r "$M" "$B" >/dev/null; then echo "BACKUP OK: $B"
else echo "STOP: 控えの作成か照合に失敗した"; fi
```

**`BACKUP OK` が出なければ適用しない**（削除・短縮に進まない）。既にある控えに `cp -R` すると、その中に入れ子でコピーされて照合の相手が前回の控えになるので、控えの場所は毎回新しくする。`BACKUP OK` の行に出た控えの場所を主に報告してから、一覧どおりに手で適用する。

- **削除**: `rm` が `rm -i` の別名になっている環境では非対話で何も消えない。`/bin/rm` で消し、`ls` で消えたことを確かめる
- **短縮**: 事実 1 つと **Why:** / **How to apply:** に絞り、1,000 バイト以下を目安にする。frontmatter は `name` / `description` / `metadata: type:` の形に揃える
- **統合**: 統合先の 1 件に事実を寄せ、残りは削除する
- **リンクの付け替え**: 残したファイルの `[[名前]]` が削除した記憶を指していたら、削除理由に書いた正本（rules のファイル名・環境変数など）への参照に置き換える
- **索引の書き直し**: MEMORY.md を、見出し 1 行と残った 1 件ごとに 1 行（空行なし）で書き直す。変更が無かった場合も `touch MEMORY.md` で見直した時刻を残す（`memory-tripwire.sh` は索引の最終更新からの日数を見る）

### 4. 一致を確かめて、数字を報告する

```bash
M=<メモリディレクトリ>
echo "files: $(ls "$M"/*.md | grep -v '/MEMORY.md$' | wc -l)  entries: $(grep -c '^- \[' "$M/MEMORY.md")"
comm -3 <(grep -o '([^)]*\.md)' "$M/MEMORY.md" | tr -d '()' | sort) <(ls "$M" | grep -v '^MEMORY.md$' | sort) && echo "no orphan/missing"
wc -c "$M"/*.md | tail -1; wc -lc "$M/MEMORY.md"
DEV_WORKFLOW_MEMORY_DIR="$M" <dev-workflow のディレクトリ>/scripts/memory-tripwire.sh   # この SKILL.md の 2 つ上。無出力なら閾値未満
```

索引の項目行の数とファイル数（MEMORY.md を除く）が一致し、`comm` の出力が空であること。主には、適用前と適用後の件数・総バイト数・索引のバイト数と行数・本文 1 件の最大バイト数を表で報告する。閾値を見直す材料になるので、閾値に近い値や、維持と判断したのに閾値を超えている件があれば添える。

## 例: claude-harness プロジェクトの初回整理（2026-09-11）

27 件・58,428 バイト（索引 5,410 バイト / 34 行）を、12 件・19,919 バイト（索引 2,285 バイト / 13 行）にした。本文 1 件の最大は 3,140 から 2,192 バイトになり、この値が `memory-tripwire.sh` の本文閾値 2,500 の根拠になった（#294 のコメント）。

| 分類 | ファイル | 理由・残す事実 |
|---|---|---|
| 削除 | feedback_decide-dont-delegate-judgment | `rules/communication-style.md` の「推奨まで出す」が同じ内容 |
| 削除 | feedback_fable-judges-delegate-work | `rules/subagent-model-selection.md` の「最上位は判断に温存」が同じ内容 |
| 削除 | project_agent-loop-deploy-map | テンプレ廃止済みで、正本は flatmate 側 |
| 削除 | project_agent-runtime-3layers | 配布層とする loops プラグインが解散済みで、中身が矛盾 |
| 削除 | project_capability-registry-not-installed | install 済みで名前が逆。版数も現行と乖離 |
| 削除 | project_casting-injection-design | 正本の場所は `rules/perspective-casting.md` にあり、着手順の issue は解決済み |
| 削除 | project_cost-effective-harness-issue26 | issue と PR がすべて完了 |
| 削除 | project_dev-workflow-develop-skill | repo の現状がそのまま示す。follow-up も完了 |
| 削除 | project_harness-dev-clone-location | `CLAUDE_HARNESS_DEV_DIR` が設定済みで、CLAUDE.md がその方式を明記 |
| 削除 | 旧プラグイン 3 本の解散記録（project_ で始まる 1 件） | 解散は repo の現状が示し、残件は GitHub にある |
| 削除 | project_one-off-no-script-rule | 対象の PR はマージ済み。予算残量はテストで測れる |
| 削除 | project_pr-review-gate-promoted | repo の現状が示す。版数も現行と乖離 |
| 削除 | project_review-queue-project | loops 連携の廃止で harness からの供給なし |
| 削除 | user_always-on-session-cron | 前提の loops プラグインが解散済み。名前の `user_` と `type: project` も不一致 |
| 短縮 | feedback_gh-comment-not-independent-approval-proof | gh コメントの投稿者名は人間承認の独立証拠にならない |
| 短縮 | feedback_verify-landed-before-claiming | push 成功 ≠ PR/main に入った。宣言前に `git merge-base` で着地を検証する |
| 短縮 | project_subagent-context-epic-257 | エピックは進行中で、判断と着手順は issue が正本。閉じた子の進捗記述は落とす |
| 短縮 | feedback_wt-setup_autonomous | 中身は維持し、旧形式の frontmatter だけ直す |
| 維持 | 残り 8 件 | repo に無い環境固有の事実（シェルの noclobber、codex の node など）か、有効な指摘 |

削除した 3 件は flatmate 側の事実を含んでいたが、このメモリディレクトリは harness プロジェクト専用で flatmate のセッションからは読まれないので、消しても失うものは無いと判断した。
