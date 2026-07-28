# dev-workflow-issue-entry Specification (Delta)

## MODIFIED Requirements

### Requirement: issueify フォールバックは loops-issueify を path-discovery で解決する
issueify フォールバックは、`loops-issueify/SKILL.md` を github-issue と同一の path-discovery パターン（CLAUDE_PLUGIN_ROOT 起点 → marketplaces → installed の順）で探して Read し、その手順（原子化 → 測定可能な受け入れ条件 → 承認 → 起票）をインライン実行しなければならない（MUST）。Skill tool は使用してはならない（MUST NOT）。

#### Scenario: loops プラグイン導入済み環境での起票
- **WHEN** path-discovery で `loops-issueify/SKILL.md` が見つかる
- **THEN** その SKILL.md の手順に従って issue を起票し、起票された番号を github-issue パイプラインに渡す

#### Scenario: loops プラグイン未導入時は fail-soft で縮退する
- **WHEN** path-discovery で `loops-issueify/SKILL.md` が見つからない
- **THEN** コマンド定義に明記された最小手順（「これで何が変わるか」「やらないとどうなるか / 今のコスト」・概要・触るファイル・測定可能な受け入れ条件を含むドラフトを提示し、承認後 `gh issue create` で起票）にフォールバックし、エラーで停止しない
