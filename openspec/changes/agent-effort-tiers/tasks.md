## 1. agent 定義

- [ ] 1.1 `worker.md` と `gate-runner.md` の frontmatter に `effort: medium` を 1 行足す。触る範囲: plugins/dev-workflow/agents/worker.md:1-6、plugins/dev-workflow/agents/gate-runner.md:1-6
- [ ] 1.2 `reviewer.md` と `decider.md` の frontmatter に `effort: high` を 1 行足す。触る範囲: plugins/dev-workflow/agents/reviewer.md:1-6、plugins/dev-workflow/agents/decider.md:1-6

## 2. model-tiers.md

- [ ] 2.1 「Agent / Task ツールで直接立てるサブエージェント」の前に節「役ごとの effort」を足す（4 役の表・frontmatter が既定で Agent の `effort` 引数が上書き・優先順位（環境変数 `CLAUDE_CODE_EFFORT_LEVEL` があればそれが frontmatter に勝つ例外、Agent の `effort` 引数との関係は「文書に記載なし」）・profile の effort は監査値のまま）。既存の model 表は変えない。触る範囲: plugins/dev-workflow/references/model-tiers.md:36-46（「残量モードによる降格」節の後、「Agent / Task ツールで直接立てるサブエージェント」節の前）

## 3. 記録とテスト

- [ ] 3.1 変更の記録 `plugins/dev-workflow/changes/711.md` を書く（直近の `662.md` の書式に倣う）。触る範囲: plugins/dev-workflow/changes/711.md（新規）
- [ ] 3.2 `plugins/dev-workflow/tests/agent-effort.bats`（新規）を足す。4 つの agent 定義の frontmatter 内の `effort:` が 1 行であることと役ごとの値（worker / gate-runner = medium、reviewer / decider = high）を検査する。frontmatter の取り出しは `decider-agent.bats` の `frontmatter` / `fm_value` に倣う。触る範囲: plugins/dev-workflow/tests/agent-effort.bats（新規）、plugins/dev-workflow/tests/decider-agent.bats:19-23（書き方の参照）
- [ ] 3.3 受け入れ条件を確かめる: `grep -c '^effort:' plugins/dev-workflow/agents/*.md` が 4 ファイルとも 1、`grep -n 'effort' plugins/dev-workflow/references/model-tiers.md` が 1 件以上、`scripts/test.sh` が exit 0。
- [ ] 3.4 変更前後で develop を 1 本ずつ回し、`/cost` の値を PR に貼る（合否には使わない）
