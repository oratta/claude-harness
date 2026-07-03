# Decisions: repo-cleanup-final (change-7)

builder 実装時に確定した意思決定の記録。design.md の Decisions を実測で裏付け・確定したもの。

## D7-1: OpenSpec 4 系統の生成元調査（tasks 1.1 / 1.2, S1）

### 実機調査結果（file 単位の根拠）

| 系統 | ファイル数 | 生成元マーカー（実測） | 判定 |
|---|---|---|---|
| `.claude/skills/openspec-*` | 10 | frontmatter に `metadata.author: openspec` / `generatedBy: "1.2.0"` / `compatibility: Requires openspec CLI` | CLI 生成物 |
| `.claude/commands/opsx/*.md` | 10 | `name: "OPSX: Apply"` / `description: ...(Experimental)` / `tags: [workflow, artifacts, experimental]`、`/opsx:apply` 形式 | CLI 生成物（slash command 出力） |
| `.agents/skills/openspec-*` | 10 | `.claude/skills/openspec-*` と **byte 単位で完全一致**（`diff -rq` = IDENTICAL）、同じ `generatedBy: "1.2.0"` | CLI の agent 非依存ミラー出力 |
| `.agents/skills/source-command-opsx-*` | 10 | 本文に「Use this skill when the user asks to run the migrated source command」表記（10/10 ファイル） | CLI の migrated-source wrapper 生成物 |

補強証拠:
- `which openspec` = `/Users/oratta/.volta/bin/openspec`、`openspec --version` = **1.2.0** → 生成物の `generatedBy: "1.2.0"` と一致。
- 全 20 の openspec-* SKILL.md（`.claude` 10 + `.agents` 10）が `generatedBy: "1.2.0"` を保持（10/10 + 10/10）。
- グローバル設定 `~/.config/openspec/config.json`: `"profile": "custom"`, `"delivery": "both"`, `workflows` に explore/new/continue/apply/ff/sync/archive/bulk-archive/verify/onboard の 10 個 → `.claude`/`.agents` 双方への delivery を生む設定。
- プロジェクトローカルの `openspec/config.yaml`（tool 選択を保持するファイル）は **`.gitignore` で除外され、ローカルにも存在しない**（`.gitignore:27` = `openspec/config.yaml`）。

### 再生成有無の判定（tasks 1.2）

- 4 系統はすべて `openspec init --tools ...`（+ `openspec update`）の生成物。`openspec update --help` は tool 選択の制御オプションを露出せず（`--force` / `--help` のみ）、どの tool へ出力するかは **プロジェクトローカルの `openspec/config.yaml`** に依存する。
- その config.yaml は gitignore + 不在のため、**「削除しても次回 `openspec update` で `.agents/` 系統が再生成されるか」を git-tracked な範囲で確定・制御できない**。config.yaml を復元して tool を絞る操作は「個人環境のローカル設定変更」であり、リポジトリ（git-tracked）側の変更としてコミットできない。
- したがって「削除しても再生成されうる」条件に該当。

## D7-2: 採用分岐 = **分岐 C（現状維持縮退）**（tasks 1.3 / 2.1, S2/S5）

### (a) 調査結論

**CLI 管理**（openspec CLI 1.2.0 の生成物）。手動管理ではない。ただし tool 選択を保持する `openspec/config.yaml` が gitignore + 不在のため、削除後の再生成挙動を git-tracked な範囲で制御できない = 実質「判断不能（CLI 管理の疑いが残る）」。

### (b) 採用分岐と理由

**分岐 C（現状維持 + 文書化）を採用**。4 系統（40 ファイル）は削除しない。

理由:
1. plan.md 意思決定ガイドライン「OpenSpec 重複整理（change-7）だけは調査結果次第で『現状維持 + 文書化』への縮退を許容する」に合致。
2. config.yaml rule「CLI 管理の疑いが残る場合は削除せず調査結果と抑制手順を decisions.md に記録して次善（現状維持+文書化）に倒す」に合致。
3. 分岐 B（`.agents/` 側 20 ファイルを `git rm`）を採ると、tool 選択が残ったまま次回 `openspec update` で再生成され、削除が無効化される恐れがある（再生成の有無を git-tracked に固定できない）。
4. 分岐 A（CLI 設定で 1 系統に抑制）は、`openspec/config.yaml`（gitignore・個人ローカル）または `~/.config/openspec/config.json`（全プロジェクト共有のグローバル設定）を編集する必要があり、いずれも **本リポジトリの git-tracked 変更として表現できない**。リポジトリ change の責務範囲を超える。
5. 優先順位「安全性（消しすぎない・壊さない） > シンプルさ > 網羅性」に照らし、可逆で副作用のない現状維持が最善。

### 将来 CLI 設定で抑制する手順（分岐 A を将来採る場合の再現手順）

スキル一覧の二重掲載（`openspec-apply-change` と `opsx:apply`、`.claude` と `.agents` の重複）を将来解消したい場合は、リポジトリ削除ではなく **openspec CLI の tool 選択を絞る**:

1. `openspec init --tools claude`（`.claude/` 系統のみに絞って再初期化。`--force` で legacy を自動整理）を実行し、`.agents/` tool の選択を外す。これで `openspec/config.yaml` の tool 集合から `.agents` 系統が消える。
2. tool 集合更新後に `.agents/skills/openspec-*` と `.agents/skills/source-command-opsx-*` を `git rm`。以降 `openspec update` で再生成されないことを 1 サイクル観察して確定する。
3. あるいはグローバル `~/.config/openspec/config.json` の `"delivery": "both"` を単一 delivery に変更する（ただし全プロジェクトへ波及するため影響確認が必要）。
4. `.agents/` を git 追跡から外すだけでよいなら `.gitignore` に `/.agents/` を追加して `git rm -r --cached .agents/` する選択肢もある（ローカルには残るがコミットには含めない）。ただし本 run では skill 一覧掲載自体は disk 上のファイル存在に依存するため、この手段は掲載重複を解消しない点に留意。

いずれも「個人環境 or グローバル設定の変更を伴う」ため、リポジトリ内で完結する change としては実施せず、運用判断として別途行う。

## D7-3: 削除は git tracked で可逆（S6）

本 change で実施した削除は全て `git rm`（tracked ファイル）で行い、commit 履歴から復元可能:
- `templates/rules/` 配下 4 ファイル（`git rm`）→ ディレクトリごと不存在化。
- `docs/cooking-mvp-mode-plan.md`（`git rm`）。
- OpenSpec 4 系統は分岐 C により削除せず（S6 は「削除する分岐を採る場合」の条件のため、削除ゼロで自明に成立）。
- untracked ファイルの物理削除はしていない。

## D7-4: cross-change テスト調整（change-6 S14）

change-6 の `plugin-retirement-cleanup.bats` S14 は `grep -rln ... plugins/ README.md docs/` で `docs/` を走査していたが、本 change が `docs/` を丸ごと削除したため `docs/` が実在しなくなった。テストの意図（scoped surface に廃止プラグイン名の生存参照ゼロ）を保ったまま、実在するパスのみを走査するよう更新した（`[ -d docs ] && targets+=(docs/)`）。テスト削除ではなく新しいリポジトリ構造への追随。

## D7-5: 統合検証結果（受け入れ条件 5-16, S19/S20/S21）

マージ前 worktree 上で実行し全て期待値を確認（条件 4 のマージ後 main 再実行に備えた記録）:

| 条件 | 検証コマンド（要約） | 結果 |
|---|---|---|
| 3 (JSON) | `git ls-files '*.json'` を全 `jq empty` | 全 PASS |
| 3 (mjs) | 全 `*.mjs` を `node --check` | 全 PASS |
| 5 | infra templates の `secrets.*`（GITHUB_TOKEN 除く）⊆ Phase 4 投入 | PASS |
| 6 | phase-5-finalize に「コメントアウト」旧方式なし | PASS |
| 7 | build-verify workflow の render + `node --check`（workflow-template.bats / minimal-fixture.bats） | PASS |
| 8 | `plugins/longrun/references/workflow-tool-reference.md` 実在、`grep _longruns/2026-06-12 plugins/` = 0 | PASS |
| 9 | `longrun-orchestrator`=0、`update-checkpoint.sh` 不在、`mode=mvp`（longrun/lr）=0 | PASS |
| 10 | wt-clean.md(30 行)/wt-setup.md(31 行) が SKILL.md ラッパー | PASS |
| 11 | weekly-report SKILL.md に `{source_path}/LLM/` markdown 読み込みなし | PASS |
| 12 | obsidian/skill-aware dir 不在・marketplace index=null・参照 0 | PASS |
| 13 | LLM 退避（衝突ゼロ、post-merge-steps.md に記録） | PASS（change-6 済） |
| 14 | `templates/rules/` 不在・`docs/cooking-mvp-mode-plan.md` 不在 | PASS |
| 15 | 8 プラグインで plugin.json version == marketplace.json version | PASS |
| 16 | daily/weekly SKILL.md に非対話（/schedule・cron）節あり | PASS |

bats: plugins 配下 438 件 + run-dir 39 件（うち change-7 新規 15 件） = 全 PASS。
