## ADDED Requirements

### Requirement: Skill 命名規則の統一

longrun プラグインは Skill と Agent の役割を命名で識別可能にしなければならない。Skill は動詞または名詞単独の名前（例: `longrun-plan`, `longrun-orchestrator`）を持ち、Agent は役割を示す `-er` または `-or` で終わる名前（例: `longrun-builder`, `longrun-reviewer`, `longrun-verifier`）を持つこと。これに違反する命名は Skill/Agent 種別の誤認を招く。

#### Scenario: plan Skill の命名

- **WHEN** plan.md を生成する Skill を配置する
- **THEN** Skill ディレクトリは `plugins/longrun/skills/longrun-plan/` であり、SKILL.md の `name:` フィールドは `longrun-plan` でなければならない

#### Scenario: 旧名称の不在

- **WHEN** plugin.json の skills 配列を読む
- **THEN** `./skills/longrun-planner` のパスは存在せず、`./skills/longrun-plan` のみが存在しなければならない

### Requirement: コマンドからの起動プロトコル

`/longrun:plan` および `/lr:p` コマンドは、Claude が `longrun-plan` Skill を Agent として誤起動しないよう、Skill tool 経由での委譲を明示的に指示しなければならない。Agent tool での起動を禁止する文言を含むこと。

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

`longrun-orchestrator` Skill は、`longrun-reviewer` Agent からのレビュー結果を受領するフェーズにおいて、self-preference bias とフィードバック過剰受容バイアスへの対処を明示的に指示しなければならない。具体的には、reviewer の指摘を仮説として扱い、(a) spec 違反 / 契約違反 / 事実誤認のいずれかの根拠がある指摘のみ採用する、(b) 嗜好や読みやすさレベルの指摘は plan 意図を優先して反論する、という判定ルールを skill 内に固定文として含むこと。

#### Scenario: orchestrator の reviewer 受領セクション

- **WHEN** `plugins/longrun/skills/longrun-orchestrator/SKILL.md` を読む
- **THEN** reviewer のレビュー結果を扱うセクションに「指摘は仮説として扱う」「明確な根拠（spec違反/契約違反/事実誤認）の有無で採否を判定する」「嗜好レベルの指摘は反論する」という趣旨の文言が含まれていなければならない

#### Scenario: バイアス緩和文の長さ制約

- **WHEN** バイアス緩和プロンプトを SKILL.md に直接埋め込む
- **THEN** 該当ブロックは 50 行以内に収まること。それを超える場合は `references/` 配下の別ファイルに切り出して読み込み参照にしなければならない

### Requirement: プラグインキャッシュ無効化のためのバージョンバンプ

skill ディレクトリ名・SKILL.md の `name:` フィールド・skills 配列のいずれかを変更する場合、`plugins/longrun/.claude-plugin/plugin.json` の `version` を必ず引き上げなければならない。バージョンを引き上げないと他プロジェクトのプラグインキャッシュが古いままとなり変更が反映されない。

#### Scenario: スキル名変更時のバージョンバンプ

- **WHEN** longrun プラグインで skill 名・skill ディレクトリ・skills 配列が変更される
- **THEN** `plugin.json` の `version` フィールドが旧バージョンより大きい値（最低でも minor bump）に更新されていなければならない

#### Scenario: 本変更でのバージョン

- **WHEN** 本 change の実装後に plugin.json を読む
- **THEN** `version` は `5.1.0` 以上でなければならない（変更前は `5.0.0`）
