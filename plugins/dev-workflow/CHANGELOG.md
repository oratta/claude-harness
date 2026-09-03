# Changelog — dev-workflow

## 2.2.0 — 2026-09-03: pr-review-gate 手順 1 の受け入れ条件取得を空本文で fail-closed にする（#220）

手順 1-3 のコマンド例が、記録先（issue → 無ければ PR 自身）の本文を `--jq '.body // ""'` で取り、空・`null`・空白のみなら stderr に `agent-review:failed` を含む失敗メッセージを出して非 0 で終了する（oratta/claude-harness#220、#219 の Codex レビュー指摘の follow-up）。issue 本文経路・PR 本文経路の両方に同じ検査が掛かる。`pr-review-gate-spec-declaration.bats` の偽 gh が `MOCK_ISSUE_BODY` で issue 本文を差し替えられるようになり、jq の `// ""` の挙動（null → 空）を模す。スキル `pr-review-gate` 1.7.0。

## 2.1.0 — 2026-08-31: loops / longrun / lr の解散と契約の移設（#205）

`loops`・`longrun`・`lr` の 3 プラグインを解散し、中に埋まっていた契約だけを dev-workflow に移した（oratta/claude-harness#205、epic #208）。手順書としての層はモデルが自力でできるようになったので持たない。契約は他プラグインからも参照されるため、スキル配下ではなくプラグイン直下の `references/` に置く。

### install 済み環境でやること

marketplace から 3 エントリが消えるため、install 済みの環境ではキャッシュに残った旧プラグインを外す:

```
/plugin uninstall loops@oratta-claude-harness
/plugin uninstall longrun@oratta-claude-harness
/plugin uninstall lr@oratta-claude-harness
/reload-plugins
```

各プロジェクトの `.claude/settings.local.json` の `enabledPlugins` に `loops@oratta-claude-harness` / `longrun@oratta-claude-harness` / `lr@oratta-claude-harness` のキーが残っていれば外す（skill-pack の `enabledPlugins` 編集の規約に従う）。

### 契約の新旧パス

| 旧（loops / longrun / lr） | 新（dev-workflow 2.1.0） | 備考 |
|---|---|---|
| `plugins/loops/references/self-verification.md` | `plugins/dev-workflow/references/self-verification.md` | 自己検証の共通原則。6 スキルの `## 自己検証` 節が参照（旧 `longrun-plan` は対象から外れた） |
| `plugins/loops/references/pr-body-format.md` | `plugins/dev-workflow/references/pr-body-format.md` | PR / issue 本文の型。内容は同じ。`.github/PULL_REQUEST_TEMPLATE.md` と `roles/worker.md` の参照先も差し替え |
| `plugins/longrun/references/model-tiers.md` | `plugins/dev-workflow/references/model-tiers.md` | Workflow 実行のロール別ティア → `opts.model` エイリアス。longrun 固有の resolver・plan.md の割り当て節・`LONGRUN_AUTOMATED` は廃止。`rules/subagent-model-selection.md` の参照先も差し替え |
| `/loops:issueify`（`plugins/loops/skills/loops-issueify/SKILL.md`） | `plugins/dev-workflow/skills/issueify/SKILL.md`（スキル名 `issueify`） | `/develop` の issueify フォールバックは同プラグイン内を Read する。goalify・レシピへの参照は本文に取り込んで解消 |
| `/lr:e` / `/longrun:exec`（plan.md → Workflow スクリプト生成） | ネイティブ Workflow ツール。型は `plugins/dev-workflow/references/workflow-execution.md`、書き方は `workflow-authoring` スキル | 昇格トリップワイヤー 1 と develop SKILL.md の乗り換え先を差し替え。Build Contract レビュー・verifier のしきい値（品質 100% / 完成度 80%）・schema 付きレポートの知見はこの 1 ファイルに集約 |
| `/lr:p` / `/longrun:plan`（brain dump → plan.md） | `/opsx:explore`（openspec ネイティブ） | develop は上流の壁打ちを呼ばない方針のまま。トリップワイヤー 3 の構造的決定の逃がし先も `/opsx:explore` |
| `/loops:review-queue` | **廃止** | このリポに呼び出し元が無く、読み取り専用ビューのデータ源（GitHub Project「Review Queue」）は直接使える。人が捌く PR は `gh pr list --label human-merge --state open` |
| `plugins/loops/references/feature-list-format.md` | **廃止** | 唯一の利用者 `recipes/routine-long-build.md` が同時に消えた。外部状態は Workflow の `args` / return 値と `resumeFromRunId` で持つ |
| `plugins/loops/templates/agent-loop-template.md`（憲法テンプレ） | **廃止**。各リポの `docs/agent-loop.md`（flatmate が保守）が正本 | harness からの再生成・逆同期はしない |
| `plugins/loops/tests/integration.bats` の S130 / S130b / S131 / S132 / S133 / S139 | `tests/marketplace-sync.bats`（リポ直下） | marketplace と `plugins/` の整合ガード。特定プラグインに属さないので loops と一緒に消さない |
| レシピ 10 本・`loops-design`・`goalify`・`dev-agent-start`・longrun の agents / schemas / scripts | **廃止**（git 履歴のみ） | 参照ゼロ。必要なら `git log --diff-filter=D -- plugins/loops plugins/longrun plugins/lr` から復元できる |

`openspec/specs/` の `loops-*`・`longrun-*`・`workflow-exec`・`workflow-tool-reference`・`workflow-run-control`・`legacy-command-removal`・`loop-dev-agent-tripwires`（38 件）も削除した。生き残る契約の要件は `dev-workflow-shared-references`・`dev-workflow-issueify`・`marketplace-plugin-sync`・`loops-longrun-retirement` に引き継いだ。

### flatmate 側で追従が必要なもの

genetta-inc/flatmate#458 で追従する（https://github.com/genetta-inc/flatmate/issues/458）:

- `docs/agent-loop.md`（loop-dev-agent 憲法）: 正本宣言後は flatmate 側で自立。本文の `/loops:issueify`・`plugins/loops/references/pr-body-format.md`・`loops-dev-agent-install` の参照を新パスに
- `docs/burn-mode.md`: 「残り PR を人が捌く経路」の `/loops:review-queue` を `gh pr list --label human-merge` / Project 直接参照に
- issue テンプレート（`agent-task.md` 等）の書式の正本パスを `plugins/dev-workflow/references/pr-body-format.md` に
- リポジトリローカル pre-push フック（main 拒否込み）の雛形と挙動テスト（旧 `pre-push-merged-pr-guard.bats`）が harness から消えた。以後の正本は `new-resident` 側

### その他の変更

- `templates/escalation-tripwires.md`: unmanned の組み込み先を憲法（flatmate 保守）に、乗り換え先を `references/workflow-execution.md` と `/opsx:explore` に
- `skills/develop/SKILL.md`: 「longrun:plan を呼ばない理由」→「上流の壁打ち（`/opsx:explore`）を呼ばない理由」、参照節に憲法の正本宣言と Workflow 実行の型
- `skills/push-guard-setup/SKILL.md`: ローカル層の設置者を「loop-dev-agent 導入済み repo（flatmate の `new-resident` が設置）」に
- 参照を直した他プラグインの patch bump: casting 0.4.1・experience-to-skill 0.3.2・skill-pack 0.2.1・infra 0.5.7・weekly-report 1.1.3・daily-report 0.3.5・worktree 2.12.3
