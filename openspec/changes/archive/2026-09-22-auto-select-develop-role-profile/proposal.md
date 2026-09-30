## Why

develop の role profile は明示指定しない限り Claude の既定構成に固定され、Claude と Codex のどちらに週次枠の余裕があるかを工程開始時に活用できない。既存の usage snapshot と role resolver を結び、書く役と検査する役を異なる provider に置く構成も含めて、残量に応じた投げ先を自動選択する。

## What Changes

- 書く役と補助役を Claude、レビュー役と decider を Codex に置く組み込み profile `claude-write-codex-review` を追加する。
- 明示 profile が無い各 develop 工程の開始時に、Claude 起動 account と登録された Codex accounts の週次余裕から `claude-write-codex-review`、`codex-standard`、または Claude 既定構成を選ぶ。
- 登録された複数 CODEX_HOME の quota snapshot を account ごとに取得し、fresh な account のうち週次余裕が最大の account を Codex 側の代表として profile に束縛する。
- 欠測・不正・取得から 300 秒を超えた snapshot は「余っている」と扱わず、選択した構成、両 provider の余裕、取得時刻、Codex account を記録する。
- 明示 `--profile NAME` は自動選択より優先し、usage snapshot を読まない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `codex-role-profiles`: 逆向き hybrid profile、残量に基づく自動選択、複数 Codex account の観測・束縛、選択理由の記録を追加する。

## Impact

- `plugins/dev-workflow/references/codex-role-profiles.json`
- `plugins/dev-workflow/scripts/codex-develop.py` とその Python/bats テスト
- `plugins/dev-workflow/scripts/codex-develop.py` の account 別 Codex quota 取得・cache とテスト
- develop の SKILL/reference/docs、共有枠の余裕定義を持つ decision criteria
- `openspec/specs/codex-role-profiles/spec.md`
- dev-workflow plugin version、CHANGELOG、全体回帰
