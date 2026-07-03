# Design: plugin-retirement

## Context

`plugins/obsidian-llm-session-rules/`（10ファイル）と `plugins/skill-aware-workflow/`（21ファイル、うち plugin.json 未登録の孤児 `skills/n8n-workflow-git/` を含む）は、2026-07-03 全面レビューで公式機能との重複・壊れた tool ID・規約違反のハードコードパスを理由に完全削除が確定した（plan.md 付録 F）。

両プラグインの Skill 9個（`session-logger` / `context-reader` / `research-workflow` / `pre-task-orchestrator` / `task-analyzer` / `skill-inventory` / `skill-finder` / `execution-tracker` / `skill-proposer`）は `openspec/backlog.md` の「Skill 命名規則リファクタリング」節（33-79行目）が `-er`/`-or` 終わり違反として管理していた対象であり、リポジトリ内の全 SKILL.md `name:` frontmatter を確認した結果、この7個（`skill-inventory` は `-er`/`-or` 終わりではないため命名規則リファクタリング対象外）が違反の全量であることを確認済み（`grep -rn "^name:" plugins/*/skills/*/SKILL.md` で命名規則違反は他に存在しない）。

`obsidian-llm-session-rules` の `hooks/hooks.json` Stop hook（`auto-save.py`）は稼働実績としてリポジトリ直下 `LLM/` に untracked ファイルを蓄積し続けており（本 change 着手時点で54ファイル）、削除に先立って `$LLM_LOG_DIR`（設定済み: Obsidian Vault の `90 - LLM`、絶対パス `/Users/oratta/Dropbox/Application/Obsidian/oratta2025/90 - LLM`）への退避が必要。untracked ファイルは git 履歴で復元できないため、削除ではなく mv による退避とし、件数照合を必須とする。

本 change は change-5（weekly-report の `{source_path}/LLM/*.md` 依存切断）のマージ後に着手する。weekly-report が obsidian-llm-session-rules の成果物を読む設計のままだと、本 change の削除で weekly-report が壊れるため。

## Goals / Non-Goals

**Goals:**

- `LLM/` 全ファイルを untracked のまま失わずに `$LLM_LOG_DIR` へ退避する（snapshot 基準の件数照合、同名衝突はスキップしてリスト報告）
- 両プラグインディレクトリを git tracked の状態で削除する（履歴から復元可能）
- `marketplace.json` の `plugins[]` と `bundles[].all.plugins[]` から両エントリを除去する
- 両プラグイン名・旧 Skill 名9個への参照を `openspec/changes/archive/` と `_longruns/` を除く全ファイルから掃除する
- `openspec/backlog.md` の該当項目を消込む
- ユーザー向け後始末手順と退避結果を `post-merge-steps.md` に書き出す

**Non-Goals:**

- `marketplace.json` の `version` / 他プラグインの `description` の最終同期（change-7 の責務。本 change はエントリ除去のみ行い、それ以外のフィールドは触らない）
- `plugins/skill-pack/skills/skill-pack/SKILL.md` 内の `cooking@1h-cooking` 言及の掃除（change-7 の責務）
- README.md 内の longrun セクション等、他の非対象箇所の陳腐化した記述の修正（本 change のスコープは退役2プラグインへの言及除去のみ）
- OpenSpec 重複整理・`templates/rules/*.md` 削除等のリポジトリルート掃除（change-7 の責務）

## Decisions

### D1: 退避先は `$LLM_LOG_DIR` 環境変数を参照し、ハードコードしない

- 採用: 実行時に `$LLM_LOG_DIR` を参照する（設定済み値: Obsidian Vault の `90 - LLM`）。CLAUDE.md の規約（LLM_LOG_DIR 未設定時はユーザーに確認、デフォルトパスを勝手に決めない）を踏襲し、spec/tasks 内には絶対パスを書かない
- 理由: 個人のディレクトリ構成を git 管理下のプラグインリポジトリに残さないため（CLAUDE.md 既存規約）

### D2: 退避の件数照合は「退避直前スナップショット」基準で行う

- 採用: mv 開始前に `LLM/` のファイル数・ファイル名一覧をスナップショットとして記録する。mv 完了後の照合は「スナップショット件数 = 移動成功件数 + 衝突スキップ件数」で行い、mv 完了後に `LLM/` へ新規発生したファイル（`auto-save.py` hook が退避作業中の会話ターンでも稼働し続けるため起こりうる）はスナップショット外として扱い、エラーではなく hook 起因の新規発生分として `post-merge-steps.md` に別記する
- 代替案: mv 完了後の `LLM/` 実件数で照合 — 却下。退避セッション中も hook が新規ファイルを生成しうるため、事後の実件数はスナップショットと一致しない可能性があり、誤って「ファイル消失」と誤検知するリスクがある
- 理由: config.yaml rules「退避は単一セッション内で完結させる。mv完了後に差分が出た場合は auto-save.py hook 起因として記録し、照合は snapshot 基準で行う」を直接反映

### D3: 同名衝突は上書きせずスキップし、リスト報告する

- 採用: `$LLM_LOG_DIR` 側に同名ファイルが既に存在する場合、その1ファイルの mv をスキップし、リポジトリ直下 `LLM/` に残置する。衝突ファイル名は `post-merge-steps.md` に列挙する
- 理由: 上書きは既存の Vault 側ファイルを破壊しうる不可逆操作であり、安全性最優先（plan.md 意思決定ガイドライン「安全性 > シンプルさ > 網羅性」）の原則に反する。スキップ + リスト化なら人間が個別に判断して手動マージできる

### D4: 参照掃除の対象範囲とファイルごとの処理方針

`grep -rln "obsidian-llm-session-rules\|skill-aware-workflow"` と9個の旧 Skill 名の grep を `openspec/changes/archive/` と `_longruns/` を除く全リポジトリに対して実行し、ヒットした各ファイルを以下の方針で処理する:

| ファイル | 処理方針 |
|---|---|
| `README.md` | クイックスタート（12/14行目相当の install コマンド）、`### skill-aware-workflow` セクション（19-64行目相当、末尾 `---` 込み）、`### obsidian-llm-session-rules` セクション（101-128行目相当、末尾 `---` 込み）、ローカル開発の `/plugin add ./plugins/skill-aware-workflow` `/plugin add ./plugins/obsidian-llm-session-rules`（149/151行目相当）を削除する。他セクション（longrun 等の陳腐化）は本 change のスコープ外につき触らない |
| `AGENTS.md` / `CLAUDE.md` | 「LLM ログ保存先」節の `` `session-logger` / `daily-report` / `weekly-report` など `` から `` `session-logger` / `` の部分のみ除去し `` `daily-report` / `weekly-report` など `` に短縮する（文意は保持） |
| `CONTRIBUTING.md` | NGパターンの「悪い」例示（`longrun-orchestrator`, `session-logger`, `skill-finder`）を、実在した/する Skill 名に依存しない汎用架空名（例: `data-fetcher`, `image-processor`）に入れ替える。「既存の不整合」節（`pre-task-orchestrator` 等3例を挙げる段落）は、本 change の削除で命名規則違反が全量解消されるため段落ごと削除する |
| `plugins/skill-pack/skills/skill-pack/SKILL.md` | サンプル JSON 内の `"obsidian-llm-session-rules@oratta-claude-harness": false` を、削除されず現存する他プラグインの disable 例（例: `"worktree@oratta-claude-harness": false`）に入れ替える。同一サンプル内の `"cooking@1h-cooking": false` 行は変更しない（change-7 の担当範囲であり、同一ファイルへの重複編集を避けるため本 change はこの行に触れない） |
| `openspec/backlog.md` | retirement-handoff-docs capability が担当（D6 参照） |

### D5: `marketplace.json` は entry 除去のみ。version/description 同期は change-7 に委譲

- 採用: `plugins[]` から両エントリを削除し、`bundles[].all.plugins[]` からも両プラグイン名を削除する。それ以外のフィールド（top-level `version`、残存プラグインの `version`/`description`）は一切変更しない
- 理由: plan.md 付録F item 6「reviewer NOTE 反映」で明記された責務分担（エントリ除去=change-6、version/description同期=change-7）を厳守する。同一ファイルを change-6/change-7 の双方が編集する以上、変更範囲を狭く保つことで worktree 内の直列実行時のコンフリクトを避ける

### D6: `openspec/backlog.md` の該当項目消込み方式は実装時判断を許容する

- 採用: 「Skill 命名規則リファクタリング」節（33-79行目相当、前後の `---` セパレータは残す）を全削除する、または対象7スキル部分のみ「本 change で消滅済み」の1行注記に置き換える、のいずれかを builder が選択してよい（plan.md 付録F item 4「消化の経緯を1行残すかbacklogから完全除去かはbuilder判断」を反映）
- 制約: どちらを選んでも、削除後の `openspec/backlog.md` に9個の旧 Skill 名の生文字列が残らないこと（1行注記に残す場合は「Skill 名」ではなく「対象7スキル」等の総称で言及する）

## Risks / Trade-offs

- [LLM/ データロス] mv 中断や誤ったスクリプトで untracked ファイルが失われる → Mitigation: snapshot 基準の件数照合を必須のゲートとし、照合が一致するまで `plugins/` 削除ステップに進まない（依存順: 退避 → 削除）
- [hook レースコンディション] 退避作業中の会話ターンで `auto-save.py` hook が新規ファイルを `LLM/` に書き込み、素朴な事後カウントでは「ファイル数が合わない」と誤検知する → Mitigation: D2 のスナップショット基準照合
- [Vault 側の既存ファイル破壊] 同名ファイルを無条件上書きすると Vault 側の既存記録を失う → Mitigation: D3 のスキップ + リスト報告
- [change-7 とのファイル競合] `marketplace.json` と `plugins/skill-pack/skills/skill-pack/SKILL.md` は change-7 も編集する → Mitigation: D5/D4 で変更範囲を明示的に限定し、直列実行（本 change 完了後に change-7 着手）を前提とする
- [参照掃除の見落とし] grep パターンに含まれない表記ゆれ（部分一致・別名）が残る → Mitigation: 受け入れ条件のグレップ検証をプラグイン名・Skill名9個の両方に対して個別に実行する

## Migration Plan

1. change-5 マージ後、worktree 内で着手
2. `LLM/` スナップショット取得 → mv 実行 → 件数照合（D2/D3）
3. 両プラグインディレクトリの git 削除
4. `marketplace.json` エントリ除去（D5）
5. 参照掃除（D4 の表に従う）
6. `openspec/backlog.md` 消込み（D6）
7. `post-merge-steps.md` 書き出し（退避結果 + ユーザー向け後始末手順）
8. ロールバック: 単一 PR のため PR クローズ（または revert）で復元可能。ただし `LLM/` の mv は untracked ファイル操作のため git revert の対象外 — ロールバックする場合は `$LLM_LOG_DIR` から手動で戻す必要がある（この非対称性を post-merge-steps.md に注記する）

## Open Questions

- なし（plan.md 付録F の記載が十分に具体的で、実装時判断が必要な箇所は D6 の1点のみ）
