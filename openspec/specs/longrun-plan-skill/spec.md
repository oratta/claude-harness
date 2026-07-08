# longrun-plan-skill Specification

## Purpose

longrun プラグインの plan.md 作成 Skill と関連コマンドの命名規則・起動プロトコル・orchestrator のバイアス緩和ガード・プラグインキャッシュ無効化ルールを定義する。
## Requirements
### Requirement: Skill 命名規則の統一

longrun プラグインは Skill と Agent の役割を命名で識別可能にしなければならない (MUST)。Skill は動詞または名詞単独の名前（例: `longrun-plan`, `longrun-orchestrator`）を持ち、Agent は役割を示す `-er` または `-or` で終わる名前（例: `longrun-builder`, `longrun-reviewer`, `longrun-verifier`）を持つこと。これに違反する命名は Skill/Agent 種別の誤認を招く。

#### Scenario: plan Skill の命名

- **WHEN** plan.md を生成する Skill を配置する
- **THEN** Skill ディレクトリは `plugins/longrun/skills/longrun-plan/` であり、SKILL.md の `name:` フィールドは `longrun-plan` でなければならない

#### Scenario: 旧名称の不在

- **WHEN** plugin.json の skills 配列を読む
- **THEN** `./skills/longrun-planner` のパスは存在せず、`./skills/longrun-plan` のみが存在しなければならない

### Requirement: コマンドからの起動プロトコル

`/longrun:plan` および `/lr:p` コマンドは、Claude が `longrun-plan` Skill を Agent として誤起動しないよう、Skill tool 経由での委譲を明示的に指示しなければならない (MUST)。Agent tool での起動を禁止する文言を含むこと。

#### Scenario: longrun:plan コマンドの記述

- **WHEN** `plugins/longrun/commands/plan.md` の本文を読む
- **THEN** 「Skill tool を使って `longrun:longrun-plan` を呼び出す」旨と「Agent tool は使わない」旨が明示的に記載されていなければならない

#### Scenario: lr:p コマンドの記述

- **WHEN** `plugins/lr/commands/p.md` の本文を読む
- **THEN** Skill 名 `longrun:longrun-plan`（旧 `longrun:longrun-planner` ではなく）を参照していなければならない

#### Scenario: 起動時の Agent 誤起動が発生しない

- **WHEN** ユーザーが `/longrun:plan <任意の引数>` を実行する
- **THEN** Claude は Skill tool で `longrun-plan` を起動し、`Agent type 'longrun:longrun-planner' not found` エラーは発生してはならない

### Requirement: orchestrator のバイアス緩和ガード

`longrun-orchestrator` Skill は、`longrun-reviewer` Agent からのレビュー結果を受領するフェーズにおいて、self-preference bias とフィードバック過剰受容バイアスへの対処を明示的に指示しなければならない (MUST)。具体的には、reviewer の指摘を仮説として扱い、(a) spec 違反 / 契約違反 / 事実誤認のいずれかの根拠がある指摘のみ採用する、(b) 嗜好や読みやすさレベルの指摘は plan 意図を優先して反論する、という判定ルールを skill 内に固定文として含むこと。

#### Scenario: orchestrator の reviewer 受領セクション

- **WHEN** `plugins/longrun/skills/longrun-orchestrator/SKILL.md` を読む
- **THEN** reviewer のレビュー結果を扱うセクションに「指摘は仮説として扱う」「明確な根拠（spec違反/契約違反/事実誤認）の有無で採否を判定する」「嗜好レベルの指摘は反論する」という趣旨の文言が含まれていなければならない

#### Scenario: バイアス緩和文の長さ制約

- **WHEN** バイアス緩和プロンプトを SKILL.md に直接埋め込む
- **THEN** 該当ブロックは 50 行以内に収まること。それを超える場合は `references/` 配下の別ファイルに切り出して読み込み参照にしなければならない

### Requirement: プラグインキャッシュ無効化のためのバージョンバンプ

skill ディレクトリ名・SKILL.md の `name:` フィールド・skills 配列のいずれかを変更する場合、`plugins/longrun/.claude-plugin/plugin.json` の `version` を必ず引き上げなければならない (MUST)。バージョンを引き上げないと他プロジェクトのプラグインキャッシュが古いままとなり変更が反映されない。

#### Scenario: スキル名変更時のバージョンバンプ

- **WHEN** longrun プラグインで skill 名・skill ディレクトリ・skills 配列が変更される
- **THEN** `plugin.json` の `version` フィールドが旧バージョンより大きい値（最低でも minor bump）に更新されていなければならない

### Requirement: Archive command MUST branch on the mvp-mode marker

`plugins/longrun/commands/archive.md` SHALL define a discriminator step that inspects the target longrun directory's `plan.md` for the literal HTML comment `<!-- mvp-mode -->`. When the marker is present, the command MUST skip the OpenSpec-change archival step (the existing step that copies delta specs and moves `openspec/changes/<name>` to `openspec/changes/archive/...`) and proceed directly to archive only the longrun directory under `_longruns/_archive/`, then perform the standard worktree cleanup, commit, and completion report. When the marker is absent, the command MUST execute the existing full-mode flow without modification, including OpenSpec-change archival.

#### Scenario: MVP-mode archival skips OpenSpec change moves

- **WHEN** `/longrun:archive` is invoked against a directory whose `plan.md` begins with `<!-- mvp-mode -->`
- **THEN** the command MUST NOT move any directory under `openspec/changes/` to `openspec/changes/archive/`, MUST NOT copy delta specs into `openspec/specs/`, and MUST move only the longrun directory itself into `_longruns/_archive/`

#### Scenario: Full-mode archival is unchanged

- **WHEN** `/longrun:archive` is invoked against a directory whose `plan.md` does not contain the `<!-- mvp-mode -->` marker
- **THEN** the command MUST execute the existing flow: parse Changes 分解 from `plan.md`, archive each OpenSpec change under `openspec/changes/archive/`, copy delta specs into `openspec/specs/` when present, move the longrun directory under `_longruns/_archive/`, clean up worktrees, and create the archive commit

#### Scenario: Marker detection examines the file head

- **WHEN** `/longrun:archive` reads the target `plan.md` for marker detection
- **THEN** the detection MUST be based on the literal substring `<!-- mvp-mode -->` appearing at or near the start of the file (within the first content line) so that ordinary comments later in the document do not falsely trigger the MVP branch

### Requirement: plugin.json and longrun-plan SKILL.md MUST share the same version after MVP-mode delivery

When the MVP-mode feature set (template + archive branch + README update) is added to the longrun plugin, the `version` field in `plugins/longrun/.claude-plugin/plugin.json` and the `version` field in the YAML frontmatter of `plugins/longrun/skills/longrun-plan/SKILL.md` MUST both be updated and MUST hold the same value after the change. This synchronized bump is required so that plugin caches (keyed on plugin.json version) and skill caches (keyed independently) both invalidate together. The new value MUST be a strict increase over the previous `plugin.json` version (no downgrades), and MUST be at least a minor bump.

#### Scenario: Both versions match

- **WHEN** a reader reads `plugins/longrun/.claude-plugin/plugin.json` and `plugins/longrun/skills/longrun-plan/SKILL.md`
- **THEN** the `version` value in plugin.json MUST equal the `version` value in the SKILL.md frontmatter

#### Scenario: plugin.json version is not downgraded

- **WHEN** the version is bumped as part of this change
- **THEN** the new `plugin.json` version MUST be strictly greater than the immediately preceding `plugin.json` version, with at least the minor segment incremented

### Requirement: README MUST document MVP mode usage

`plugins/longrun/README.md` SHALL contain a section that documents the standalone MVP plan entry point, its differences from full mode, and the situations in which it is appropriate to use. The section MUST include the literal command form `/longrun:mvp` (and MAY include the alias `/lr:m` if the alias plugin is available). The section MUST state that `--mode=mvp` is deprecated and that invoking `/longrun:plan --mode=mvp` produces a migration notice instead of running the MVP flow. The section MUST state that the MVP plan skill is a generic capability not tied to any specific project and is intended for short-time human-implemented MVP scenarios.

#### Scenario: MVP section is present

- **WHEN** a reader scans `plugins/longrun/README.md`
- **THEN** a section MUST exist that names the MVP plan skill and includes the literal text `/longrun:mvp`

#### Scenario: Differences from full mode are described

- **WHEN** a reader reads the MVP section in the README
- **THEN** the section MUST describe at least these differences: Build Contract review is skipped, TDD enforcement is skipped, Verifier auto-invocation is skipped, OpenSpec change archival is skipped on `/longrun:archive`

#### Scenario: Deprecation of the old flag is documented

- **WHEN** a reader reads the MVP section in the README
- **THEN** the section MUST state that `--mode=mvp` is deprecated and that `/longrun:plan --mode=mvp` now emits a migration notice pointing to `/longrun:mvp`

#### Scenario: Use-case guidance is generic

- **WHEN** a reader reads the MVP section in the README
- **THEN** the section MUST state that the MVP plan skill is suitable for short-time human-implemented MVP scenarios and is not specific to any particular project

### Requirement: Deprecated `--mode=mvp` flag MUST surface a migration notice and terminate

The `longrun-plan` Skill (`plugins/longrun/skills/longrun-plan/SKILL.md`) SHALL inspect its invocation arguments before executing Step 1. When `--mode=mvp` is present, the Skill MUST output a migration notice stating that MVP plan creation has moved to `/longrun:mvp` (with the `/lr:m` shortcut), and MUST terminate without executing any of Step 1〜Step 8 and without generating a plan.md. The flag MUST NOT be silently ignored and MUST NOT fall through to full mode. When the flag is absent, or when `--mode=full` is provided, the Skill SHALL execute the existing full-mode flow (Step 1〜Step 8) without any behavioral change. The SKILL.md MUST no longer contain the MVP-mode section body (moved to the `longrun-mvp-plan` skill).

#### Scenario: Old flag shows migration notice

- **WHEN** a user runs `/longrun:plan --mode=mvp <args>`
- **THEN** the Skill MUST output a notice naming `/longrun:mvp` (and `/lr:m`) as the new entry point, MUST NOT execute Step 1〜Step 8, and MUST NOT generate any plan.md

#### Scenario: Old flag via shortcut shows the same notice

- **WHEN** a user runs `/lr:p --mode=mvp <args>` (arguments forwarded transparently to the skill)
- **THEN** the same migration notice MUST be shown and the flow MUST terminate without producing a plan.md

#### Scenario: Full mode is unaffected

- **WHEN** a user runs `/longrun:plan` with no `--mode` flag, or with `--mode=full`
- **THEN** the Skill MUST execute the existing full-mode Step 1〜Step 8 exactly as before, including reading `templates/plan-template.md` and invoking the `longrun-reviewer` Agent at Step 7

#### Scenario: MVP-mode section is removed from the skill body

- **WHEN** a reader greps `plugins/longrun/skills/longrun-plan/SKILL.md` for the MVP-mode step definitions (e.g., `MVP Step 4.5`, `longrun-mvp-plan-reviewer`)
- **THEN** zero matches MUST be found; only the migration-notice handling MAY reference MVP

### Requirement: longrun-plan は Synthesis でモデル割り当て推奨を生成する

`longrun-plan` スキル（`plugins/longrun/skills/longrun-plan/SKILL.md`、change-3 分離後のフルモード plan スキル）は、Step 5（Synthesis）で plan.md を生成する際に「モデル割り当て」セクションを必ず含めなければならない (MUST)。表には Changes分解 の各 change × 自律実行で起動される agent ロール（reviewer / builder / verifier / browser-verifier 等）ごとに 1 行を生成し、ティア（haiku / sonnet / inherit）の推奨と推奨理由を記入すること。推奨は以下のヒューリスティクスに従う:

- アーキテクチャレビュー・複雑な TDD 実装 → `inherit`（指定なし）
- 定型的検証・要約 → `haiku`
- リサーチ・ブラウザ操作・中規模実装 → `sonnet`
- 確信度が低い・分類に迷うタスク → `inherit`（保守的デフォルト。「迷ったら inherit」）

SKILL.md にはこのヒューリスティクスと保守的デフォルトの方針を明記し、ティアからモデル ID への解決は `plugins/longrun/references/model-tiers.md` を参照する旨を記載すること。SKILL.md 本文にモデル ID をハードコードしてはならない (MUST NOT)。

#### Scenario: 生成された plan.md にモデル割り当て表が含まれる

- **WHEN** ユーザーが `/longrun:plan` で plan.md を作成し Step 5（Synthesis）が完了する
- **THEN** 生成された plan.md に「モデル割り当て」セクションが存在し、Changes分解 の各 change × agent ロールごとの行にティア（haiku / sonnet / inherit のいずれか）と理由が記入されている

#### Scenario: SKILL.md にヒューリスティクスが明記されている

- **WHEN** ユーザーが `plugins/longrun/skills/longrun-plan/SKILL.md` の推奨生成ステップを読む
- **THEN** 「アーキテクチャレビュー・複雑な TDD 実装 → inherit」「定型的検証・要約 → haiku」「リサーチ・ブラウザ操作・中規模実装 → sonnet」の 3 ルールと「迷ったら inherit に倒す」保守的デフォルトが記載されている

#### Scenario: 確信度の低いタスクは inherit に倒される

- **WHEN** Synthesis 中にあるタスクがどのヒューリスティクス分類にも明確に該当しない
- **THEN** スキルは該当行のティアに `inherit` を記入し、理由欄に確信度が低いため保守的デフォルトを適用した旨を記載する

#### Scenario: ユーザーが plan 確認時に表を上書きできる

- **WHEN** ユーザーが Step 8（ユーザー確認）で plan.md のモデル割り当て表の `上書き` 欄またはティア欄を直接編集する
- **THEN** スキルは編集後の値をそのまま確定し、推奨値への巻き戻しや再生成を行わない

### Requirement: longrun-plan の Validation はモデル割り当てセクションの存在を検査する

`longrun-plan` スキルの Step 6（Validation）のセクション存在チェックリストは、「モデル割り当て」セクションの存在確認項目を含まなければならない (MUST)。セクションが欠落している場合は、フルモード Step 6 の既存 GATE セマンティクスに従い、plan.md を修正してから保存すること（欠落したままの保存は禁止）。

#### Scenario: Validation チェックリストにモデル割り当てが含まれる

- **WHEN** ユーザーが SKILL.md の Step 6（Validation）のセクション存在チェックリストを読む
- **THEN** 「モデル割り当て」セクションの存在確認項目がチェックリストに含まれている

#### Scenario: セクション欠落時は保存前に修復される

- **WHEN** Step 6 の Validation で生成済み plan.md に「モデル割り当て」セクションが無いことが検出される
- **THEN** スキルは plan.md を修正してセクションを追加してから保存し、欠落したままファイルを保存しない

