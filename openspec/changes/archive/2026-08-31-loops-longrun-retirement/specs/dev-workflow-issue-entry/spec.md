## RENAMED Requirements

- FROM: `### Requirement: issueify フォールバックは loops-issueify を path-discovery で解決する`
- TO: `### Requirement: issueify フォールバックは同プラグイン内の issueify スキルを Read で解決する`

## MODIFIED Requirements

### Requirement: issueify フォールバックは同プラグイン内の issueify スキルを Read で解決する
issueify フォールバックは、同じ dev-workflow プラグイン内の `skills/issueify/SKILL.md`（`${CLAUDE_PLUGIN_ROOT}/skills/issueify/SKILL.md`。`CLAUDE_PLUGIN_ROOT` が無い環境では `~/.claude/plugins/marketplaces/*/plugins/dev-workflow/skills/issueify` → `~/.claude/plugins/installed/*/dev-workflow/skills/issueify` の順で探す）を Read し、その手順（原子化 → 測定可能な受け入れ条件 → 不足だけヒアリング → 承認 → 起票）をインライン実行しなければならない（MUST）。Skill tool は使用してはならない（MUST NOT）。他プラグイン（旧 loops）への path-discovery を行ってはならない（MUST NOT）。

#### Scenario: 同プラグイン内の issueify で起票する
- **WHEN** `${CLAUDE_PLUGIN_ROOT}/skills/issueify/SKILL.md` が読める
- **THEN** その SKILL.md の手順に従って issue を起票し、起票された番号を develop パイプラインに渡す

#### Scenario: SKILL.md が読めないときは fail-soft で縮退する
- **WHEN** 上の探索で `skills/issueify/SKILL.md` が見つからない
- **THEN** コマンド定義に明記された最小手順（「これで何が変わるか」「やらないとどうなるか / 今のコスト」・概要・触るファイル・測定可能な受け入れ条件を含むドラフトを提示し、承認後 `gh issue create` で起票）にフォールバックし、エラーで停止しない

### Requirement: 起票前のユーザー承認ゲートを維持する
issueify フォールバック経由の起票は、`skills/issueify/SKILL.md` の承認ゲート（ドラフト提示 → ユーザー承認 → `gh issue create`）を維持しなければならない（MUST）。fail-soft の縮退手順でも承認なしに起票してはならない（MUST NOT）。

#### Scenario: 承認前に起票されない
- **WHEN** issueify フォールバックが issue ドラフトを生成した
- **THEN** ドラフトの提示とユーザーの承認を経てから `gh issue create` が実行される
