## Why

常時注入の固定分（`rules/` / `CLAUDE.md` / `output-styles/` / 各種 `description`）は `tests/injection-budget.bats` が合計バイト数で見張っているが、「何を削れるか」を見つける手段は人の目だけだった。Claude Code 2.1.261 以降に入った公式の診断コマンド 3 つ（`/doctor prompt-audit`・`/skill-doctor`・`claude plugin details <name>`）は、旧モデル向けの言い回し・使われていないスキル・プラグインごとの固定分を機械的に挙げてくれる。予算値を見直すたびにこれを使えるよう、手順を残す（issue #712、エピック #717 の子）。

## What Changes

- 診断 3 コマンドを 1 回ずつ実行した結果は issue #712 に記録済み（2026-10-08、https://github.com/oratta/claude-harness/issues/712#issuecomment-6055775344 ）。この change はその結果を受けた変更を扱う
- 予算値を見直すときの手順（3 コマンドの実行方法、出力の読み方、結果の記録先）を `docs/injection-budget-review.md` に新しく書く
- `tests/injection-budget.bats` の失敗時の出力（超過側・下振れ側の両方）に、その手順のパスを 1 行足す。`CLAUDE.md` は書き換えない
- 診断が挙げた旧モデル向けの言い回しのうち、思考の深さを文で指示している「Think deeply.」を `.claude/commands/opsx/explore.md` と `.claude/skills/openspec-explore/SKILL.md` から削る。`rules/` と `plugins/*/skills/*/SKILL.md` には該当が無かったので、そこは削るものが無い
- 旧モデル向けの言い回しが `rules/`・`CLAUDE.md`・`output-styles/`・`.claude/` に戻ってきたら落ちるテストを足す
- `tests/injection-budget.txt` の値は動かさない（測定対象のバイト数がこの change で変わらないため）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `injection-budget-gate`: 予算値を見直すときの診断手順を docs に置き、テストの失敗時の出力から辿れるようにする要件と、思考の深さを文で指示する言い回しを常時注入の文書とリポジトリ内のスキル・コマンドに置かない要件を足す

## Impact

- 新規: `docs/injection-budget-review.md`
- 変更: `tests/injection-budget.bats`（失敗時の出力とテストの追加）、`.claude/commands/opsx/explore.md`、`.claude/skills/openspec-explore/SKILL.md`
- 変更なし: `CLAUDE.md`、`AGENTS.md`、`rules/*.md`、`plugins/**`、`tests/injection-budget.txt`
- プラグイン配下を変えないので `plugins/<name>/changes/712.md` は作らない
- 診断コマンドは Claude Code の版に依存する（`/doctor prompt-audit` は 2.1.283 以降、`/skill-doctor` は 2.1.261 以降）。手順には確かめた版を書く
