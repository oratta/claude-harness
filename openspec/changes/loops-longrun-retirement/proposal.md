## Why

`loops` と `longrun`（および短縮コマンド集 `lr`）は、モデルが自力でできるようになった「手順書」を層として抱えたまま残っている（2026-08-28〜29 主整理、oratta/claude-harness#205・epic #208）。手順書としての価値は落ちた一方で、中に埋まっている**契約**——PR 本文の型・自己検証の共通原則・issue 化の手順（issueify）・ロール別モデルティア——は現役で、dev-workflow・worktree・infra・daily/weekly-report・experience-to-skill など他プラグインが参照している。プラグインとしては解散し、契約だけを生き残る場所（dev-workflow）に移す。PR #204（dev-workflow 2.0.0、github-issue → develop）がマージされ、移設先の書き換えが終わったので今やる。

## What Changes

- **BREAKING** `plugins/loops/`・`plugins/longrun/`・`plugins/lr/` を git 追跡の削除として取り除き、`.claude-plugin/marketplace.json` の `plugins[]` エントリと `bundles[].all.plugins[]` から 3 名を外す。`/plugin uninstall` の手順は新設する `plugins/dev-workflow/CHANGELOG.md` に書く
- **契約を dev-workflow のプラグイン直下 `references/` に移す**（他プラグインからも参照される契約はスキル配下ではなくプラグイン直下に置く）:
  - `self-verification.md`（自己検証の共通原則。7 スキルの `## 自己検証` 節が参照）— 対象スキル一覧から解散プラグインの行を除いて移す
  - `pr-body-format.md`（PR / issue 本文の型）— 内容は維持し、末尾の生成ロジックの参照先を issueify の新パスに差し替える
  - `model-tiers.md`（Workflow スクリプトのロール別ティア → `opts.model` エイリアス対応表）— longrun 固有の resolver・`inherit` の実装詳細・`LONGRUN_AUTOMATED` を落とし、ティア表・エイリアス規則・残量モードによる降格（正本は `decision-criteria.md`）だけを残す
  - `workflow-execution.md`（新規 1 ファイル）— develop の 1 ループに収まらない規模を**ネイティブ Workflow ツール**（`workflow-authoring` スキル）で回すときの型。longrun から残す価値があるもの＝Review → Build → Verify の 3 フェーズ、Build Contract レビュー（develop では R1 が担う）、verifier の姿勢（懐疑・品質 100% / 完成度 80% のハードしきい値・FAIL 側に倒す・schema 付きレポート）をここに集約する
- **issueify を dev-workflow のスキルに移す**: `plugins/dev-workflow/skills/issueify/SKILL.md`（名前 `issueify`）。`commands/develop.md` の issueify フォールバックは loops への path-discovery をやめ、同プラグイン内の `${CLAUDE_PLUGIN_ROOT}/skills/issueify/SKILL.md` を Read する。goalify・loop-dev-agent レシピへの参照は、受け入れ条件の作り方をスキル本文に取り込んで解消する
- **`/lr:e`（Workflow 実行）への委譲を解消**: `templates/escalation-tripwires.md` と develop SKILL.md の昇格先を「ネイティブ Workflow ツール（`workflow-authoring` スキルを読み込んで書く。型は `references/workflow-execution.md`）」に書き換える
- **`/lr:p`（brain dump → plan.md）は廃止**: 「形になっていない要望を対話でほぐす」役割は openspec ネイティブの `/opsx:explore` が担う。develop SKILL.md の「longrun:plan を呼ばない理由」節は「上流の壁打ちを呼ばない理由」に改め、トリップワイヤー 3（仕様の発明検知）の構造的な決定の逃がし先も `/opsx:explore` にする
- **`review-queue` は廃止**（dev-workflow へは移さない）: 読み取り専用のビューであり、データ源の GitHub Project「Review Queue」はそのまま使える。auto-merge の全面展開と `human-merge` ラベルで「人が捌く PR」は `gh pr list --label human-merge` で足りる。このリポ内に呼び出し元は無い。flatmate `docs/burn-mode.md` の「人が捌く経路」の書き換えは flatmate 側 issue で行う
- **`feature-list-format.md` は廃止**（dev-workflow へは移さない）: 唯一の利用者 `recipes/routine-long-build.md` が本 change で消え、`{longrun-dir}` の配置規約も消える。外部状態が要る長期ビルドは Workflow の `args` / return 値と `resumeFromRunId` で持つ
- **憲法テンプレートは廃止**: flatmate の `docs/agent-loop.md` を正本と明記し、harness 側からの再生成・逆同期はしない
- **参照の掃除**: `rules/subagent-model-selection.md`（model-tiers の参照先）、`rules/git-commit-policy.md`（`/lr:a`）、`plugins/experience-to-skill`（完了通知の語から `longrun:archive` を外す）、`plugins/casting/catalog/injection.md`（設計時の配線先を longrun plan から `/opsx:explore`・proposal に）、`plugins/skill-pack`（例示の `longrun@…`）、`plugins/dev-workflow/skills/push-guard-setup`（`loops-dev-agent-install` → loop-dev-agent 導入済み repo）、7 スキルの `## 自己検証` 節の参照パス、`README.md`、`scripts/test-auto-merge-workflow.sh` の fixture パス、`openspec/backlog.md` の loops/longrun 項目
- **解散した capability の spec を削除**: `openspec/specs/loops-*`・`longrun-*`・`workflow-exec`・`workflow-tool-reference`・`workflow-run-control`・`legacy-command-removal`・`loop-dev-agent-tripwires`（すべて解散プラグインの振る舞いだけを規定していた）。過去の一回性作業を記録した spec（`marketplace-final-sync`・`retirement-handoff-docs`・`llm-log-relocation` 等）は歴史記述なので触らない
- バージョン: dev-workflow 2.0.0 → 2.1.0、参照を直したプラグイン（casting・experience-to-skill・skill-pack・infra・weekly-report・daily-report・worktree）は patch bump。marketplace.json の各エントリを同期する

## Capabilities

### New Capabilities
- `loops-longrun-retirement`: 3 プラグインの git 追跡削除・marketplace エントリと bundle からの除去・参照ゼロの掃除条件・解散 capability の spec 削除・アンインストール手順の CHANGELOG 記載・憲法の正本宣言
- `dev-workflow-shared-references`: dev-workflow プラグイン直下 `references/` に置く他プラグイン共有の契約 4 本（self-verification / pr-body-format / model-tiers / workflow-execution）の内容と、各契約が守るべき要件（旧 `loops-pr-body-format` の reference 要件と旧 `longrun-model-allocation` のティア表要件を引き継ぐ）
- `dev-workflow-issueify`: タスクメモ・バックログ・受け入れ条件の無い issue を測定可能な受け入れ条件付き issue に変換する `issueify` スキル（4 入力モード・原子化・不足だけヒアリング・承認ゲート・依存関係の張り方）

### Modified Capabilities
- `dev-workflow-issue-entry`: issueify フォールバックの解決先を loops への path-discovery から同プラグイン内の `skills/issueify/SKILL.md` に変える（fail-soft の縮退手順は維持）
- `dev-workflow-escalation-tripwires`: トリップワイヤー 1 の乗り換え先を `/lr:e 系のスキル` からネイティブ Workflow 実行（`references/workflow-execution.md`）に、トリップワイヤー 3 の構造的決定の逃がし先を `/lr:p` から `/opsx:explore` に変える
- `skill-verification-sections`: 共通原則リファレンスのパスを `plugins/dev-workflow/references/self-verification.md` に変え、対象スキル一覧から `longrun-plan` を外す（対象 6 スキル）
- `experience-to-skill-jsonl-distillation`: 起動しないケースの列挙から `longrun:archive` を外し `openspec:archive`（`/opsx:archive`）だけにする
- `global-push-guard`: リポジトリローカル層の設置者の記述を `loops-dev-agent-install` から「loop-dev-agent 導入済み repo（flatmate の `new-resident` が設置）」に変える

## Impact

- 削除: `plugins/loops/`（49 ファイル）、`plugins/longrun/`（約 75 ファイル）、`plugins/lr/`（6 ファイル）、`openspec/specs/{loops-*,longrun-*,workflow-exec,workflow-tool-reference,workflow-run-control,legacy-command-removal,loop-dev-agent-tripwires}/`（38 ディレクトリ）
- 追加: `plugins/dev-workflow/references/{self-verification,pr-body-format,model-tiers,workflow-execution}.md`、`plugins/dev-workflow/skills/issueify/SKILL.md`、`plugins/dev-workflow/CHANGELOG.md`、`plugins/dev-workflow/tests/{pr-body-format,shared-references,issueify-skill,retirement}.bats`
- 変更: `.claude-plugin/marketplace.json`、`README.md`、`rules/subagent-model-selection.md`、`rules/git-commit-policy.md`、`plugins/dev-workflow/{.claude-plugin/plugin.json,README.md,commands/develop.md,skills/develop/SKILL.md,skills/push-guard-setup/SKILL.md,templates/escalation-tripwires.md,tests/*.bats}`、`plugins/{infra,weekly-report,daily-report,experience-to-skill}/skills/*/SKILL.md` と `plugins/worktree/{skills/wt-setup,skills/wt-clean}/SKILL.md`・`plugins/worktree/references/wt-clean-verification.md`（自己検証の参照パス）、`plugins/casting/catalog/injection.md`、`plugins/skill-pack/skills/skill-pack/SKILL.md`、`plugins/experience-to-skill/{README.md,skills/experience-to-skill/SKILL.md}`、`scripts/test-auto-merge-workflow.sh`、`openspec/backlog.md`、各 plugin.json の version
- 外部への影響: 既に install 済みの環境では `/plugin uninstall loops|longrun|lr@oratta-claude-harness` が必要（CHANGELOG に記載）。flatmate の `docs/agent-loop.md`（憲法。正本宣言後は自立）・`docs/burn-mode.md`（review-queue の参照）・issue テンプレートは flatmate 側の issue で更新する。`rules/` に触れるため PR は human-merge
- 触らないもの: ルート `_longruns/`（過去の自律実行のアーカイブ。`scripts/test.sh`・`lint.sh` の除外指定も残す）、`openspec/changes/archive/`、`plugins/product-handover/CHANGELOG.md` の「loops の解散は #205」という説明文
