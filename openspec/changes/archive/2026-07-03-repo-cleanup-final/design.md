# Design: repo-cleanup-final

## Context

本 change は plugin-review-fixes run の最終 change（change-7）であり、依存関係は change-1 / change-3 / change-4 / change-6 の完了後に直列実行される（marketplace.json 同期は全プラグイン編集完了後でないと競合するため）。付録 G の 6 items + 統合検証を担う。

意思決定ガイドラインにより、OpenSpec 重複整理だけは調査結果次第で「現状維持 + 文書化」への縮退を許容する。他の掃除（templates/rules・cooking 残骸・skill-pack 注記・e2s 修正・marketplace 同期）は縮退なしで完遂する。

## Decisions

### D1: OpenSpec 4 系統の生成元調査手順

spec 作成時点での予備調査で以下を確認済み（builder は実装時に再確認し `decisions.md` に転記する）:

- `.claude/skills/openspec-*/SKILL.md` の frontmatter に `author: openspec` / `generatedBy: "1.2.0"` / `compatibility: Requires openspec CLI` が存在 → CLI 生成物の強いシグナル
- `.claude/commands/opsx/*.md` は `OPSX: Apply` 等のタイトルと `/opsx:apply` 形式 → openspec CLI のスラッシュコマンド生成物
- `.agents/skills/openspec-*/SKILL.md` は `.claude/skills/openspec-*` とバイト単位でほぼ同一（同じ `generatedBy` マーカー）→ CLI の agent 非依存ミラー出力
- `.agents/skills/source-command-opsx-*/SKILL.md` は「Use this skill when the user asks to run the migrated source command」表記 → CLI の migrated wrapper 生成物
- `openspec` CLI は volta グローバルに 1.2.0 が存在（`which openspec` / `openspec --version` = 1.2.0）で、生成物の `generatedBy: "1.2.0"` と一致

**調査の一次判定基準**: 上記マーカーが揃うため 4 系統は `openspec init --tools claude`（+ `openspec update`）の生成物と判定するのが自然。ただし「削除しても次回 `openspec update` で再生成されるか」は CLI 挙動に依存するため、builder は次のいずれかで再生成有無を確定する:

1. openspec CLI のヘルプ / ドキュメントで `--tools` の対象（claude / agents 両出力の制御可否）を確認
2. `.agents/skills/` を退避した状態で（またはドライに）`openspec update` 相当を実行し再生成されるか観察（実機検証は破壊的操作を伴うため decisions.md に手順を記録した上で慎重に）

### D2: OpenSpec 重複の解決分岐と縮退条件

| 調査結論 | 採る分岐 | 具体アクション |
|---|---|---|
| CLI 管理 + 設定で系統抑制可能 | A | CLI 設定変更で 1 系統に抑制。手順を decisions.md に記録 |
| 手動管理（再生成されない）と確認 | B | `.claude/` 側 2 系統を残し `.agents/skills/openspec-*` と `.agents/skills/source-command-opsx-*` を `git rm` |
| CLI 管理の疑いが残る / 判断不能 | C（縮退） | 削除せず現状維持。調査結果 + 将来の抑制手順を decisions.md に記録 |

**縮退条件の明示**: 「削除しても `openspec update` で再生成されうる」「CLI 設定で系統を制御する正規手段が確認できない」のいずれかに該当したら分岐 C に倒す。予備調査のマーカーからは分岐 C（現状維持 + 文書化）が最も確度が高い着地と見込まれるが、builder が分岐 A/B を実機で確証できればそちらを優先してよい。いずれの分岐でも `decisions.md` の生成は必須。

### D3: marketplace.json 同期の対象プラグイン一覧

本 change が version・description を plugin.json と一致させる対象（8 プラグイン）:

| プラグイン | 現 plugin.json version（spec 時点） | 備考 |
|---|---|---|
| infra | 0.2.0 | change-1 で編集、bump 済み想定 |
| longrun | 6.2.0 | change-2/3 で編集、bump 済み想定 |
| lr | 6.1.0 | change-3 で編集、bump 済み想定 |
| worktree | 2.1.1 | change-4 で編集、bump 済み想定 |
| daily-report | 0.3.0 | change-5 で編集、bump 済み想定 |
| weekly-report | 1.0.2 | change-5 で編集、bump 済み想定 |
| skill-pack | 0.1.0 | 本 change で編集 → 本 change で bump |
| experience-to-skill | 0.2.0 | 本 change で編集 → 本 change で bump |

各 change が自分の担当プラグインを bump 済みである前提だが、本 change は最後に横断確認し、未 bump のものがあれば補完する。marketplace.json 側 version は各 plugin.json と 1 文字も違わず一致させる。

**責務分離**: obsidian-llm-session-rules / skill-aware-workflow のエントリ**除去**は change-6 の責務。本 change はそれらに触れず、残る 8 プラグインの version/description 同期のみを行う（付録 F-6 の reviewer NOTE）。

### D4: 依存順（実装順序）

1. 調査（OpenSpec 生成元、templates/rules 参照ゼロ再確認）
2. 削除（OpenSpec 分岐 B/C の確定後の削除、templates/rules、docs/cooking-mvp-mode-plan.md）
3. 小修正（.gitignore コメント、skill-pack 注記 + cooking 掃除、e2s の `$0` 修正）
4. version bump（skill-pack / experience-to-skill）
5. 最終同期（marketplace.json ↔ 全 plugin.json）
6. 統合検証（受け入れ条件 5-16）

marketplace.json 同期を最後に置くのは、他 change と同一ファイルを触る競合を避けるため。

### D5: 触らない範囲

- `openspec/changes/archive/` と `_longruns/_archive/`（履歴）
- change-6 が扱う廃止 2 プラグインのエントリ
- 削除は全て git tracked の状態で行い、untracked ファイルの物理削除はしない（履歴復元可能性の担保）
