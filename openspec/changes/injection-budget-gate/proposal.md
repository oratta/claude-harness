## Why

全セッション・全サブエージェントの起動直後に必ず載る「固定分」（`rules/*.md`・リポジトリ直下の `CLAUDE.md`・各プラグインの `SKILL.md` frontmatter の `description`）が、誰も見ていない間に増え続けている。2026-08-31 の約 42,000 トークンから 09-08 の約 58,000 へ 8 日で約 4 割増え、上限 150,000 のうち作業に使えるのは 9 万ほどしか残らない（エピック #257 の実測）。

増えたこと自体は悪ではなく、増やすかどうかを**編集する PR の場で決められない**のが問題。実行時に切り捨てる仕組みは作らない（どのルールが落ちたか誰も気づけない）。編集時に予算で止め、超えるなら「削るか、予算を上げるか」を diff として主の前に出す。

## What Changes

- 予算値を独立ファイル `tests/injection-budget.txt` に置く。値の変更が単独の diff 行として現れ、聖域扱いの対象をパスで指定できる形にする
- bats スイート `tests/injection-budget.bats` を 1 本足す。次の 3 種を測り、合計が予算を超えたら fail する:
  1. **rules**: `rules/*.md` のうち `scripts/sync.sh` が `~/.claude/rules/` へ symlink するもの（＝ `README.md` を除いた全件）
  2. **CLAUDE.md**: リポジトリ直下の `CLAUDE.md`（`AGENTS.md` は同期済みの複製なので二重計上しない）
  3. **SKILL.md description**: `plugins/*/skills/*/SKILL.md` の frontmatter `description` の合計
- fail メッセージに「超過量」「3 種の内訳」「削るか予算を上げるかの 2 択」を出す
- 予算の初期値は現状値に小さな余裕を足した値にする（導入直後に超過を出さない）
- 予算ファイルを上げるときは PR 本文に理由（何を削ろうとして、なぜ超えるままにするか）を書く旨を `CLAUDE.md` に 1 行足す（`AGENTS.md` も同期して更新する）
- `scripts/test.sh` は `git ls-files '*.bats'` で対象を動的に発見するので変更不要

## Capabilities

### New Capabilities
- `injection-budget-gate`: 常時注入される固定分の合計サイズに予算を置き、編集時（テスト）に超過を検出して「削るか予算を上げるか」の判断を PR の diff に出す仕組み。測定対象の定義・測定単位・予算ファイルの位置と変更手続きを含む

### Modified Capabilities
（なし。既存 capability の要件は変わらない）

## Impact

- 新規: `tests/injection-budget.bats`、`tests/injection-budget.txt`
- 変更: `CLAUDE.md` と `AGENTS.md`（予算ファイル変更時の規約 1 行。`tests/agents-md-sync.bats` が両者の同期を強制する）
- 変更なし: `scripts/test.sh`（動的発見）、`scripts/sync.sh`（測定は sync.sh の除外規則を参照するだけで sync.sh 自体は変えない）
- 下流: エピック #257 の #260（固定分の削減）が、このテストと同じ物差しで削減量を測る
- 対象外: `MEMORY.md`・接続コネクタ名・output style・Claude Code 本体の固定分（PR の diff に現れないので編集時ゲートでは扱えない）。実行時の監視は #259
