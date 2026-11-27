## Why

develop が使った Claude と Codex の消費を、工程・試行・アカウントごとに分けて数えるための印が、記録に残っていない。flatmate の `scripts/burn_consumption.py`（genetta-inc/flatmate#709）は工程・試行・アカウントを記録の印からだけ読み、印が無ければ「欠測」と出す。このままだと実データで常に欠測になる（oratta/claude-harness#1158）。

## What Changes

- develop の本体が、消費の記録に機械で読める 1 行の印 `[消費記録 工程=<工程> 試行=<n> アカウント=<provider>:<登録名> 引継ぎ=<k>]` を書く
- 置き場は 3 か所: `Codex 消費:` コメントの 2 行目以降／サブエージェントの `description`（`#N` と同じ文字列の中）／`develop 開始` コメント
- `plugins/dev-workflow/skills/develop/SKILL.md` の「PR トークン上限」節（紐付けの規約・Codex の消費の記録）と「Role profile の選択」節の develop 開始コメントの記述に、印の形・置き場・工程名の語彙・試行と引継ぎの数え方を書く
- 印を検査する bats を足す
- 同じ W を SendMessage で再開する既存の 1 ループと整合させるため、再開される W の description には工程・試行を書かない（design の決定 4）
- 範囲外: 印への時刻（`開始=` `終了=`）の追加。理由と扱いは design の決定 3

## Capabilities

### New Capabilities
なし

### Modified Capabilities
- `dev-workflow-pr-token-budget`: 消費の記録に工程・試行・アカウントの印を書く要件を足す

## Impact

- `plugins/dev-workflow/skills/develop/SKILL.md`、`plugins/dev-workflow/tests/develop-skill.bats`（印の検査）、`plugins/dev-workflow/changes/1158.md`
- `scripts/codex-records.sh` と `scripts/pr-token-budget.sh` は変えない（`Codex 消費:` の 1 行目の形は不変。印は 2 行目以降）
