## Why

全セッション・全サブエージェントの起動直後に必ず載る「固定分」（`rules/*.md`・`output-styles/*.md`・リポジトリ直下の `CLAUDE.md`・各プラグインと `.claude/` 配下の `SKILL.md` / `agents` / `commands` の `description`）が、誰も見ていない間に増え続けている。2026-08-31 の約 42,000 トークンから 09-08 の約 58,000 へ 8 日で約 4 割増え、上限 150,000 のうち作業に使えるのは 9 万ほどしか残らない（エピック #257 の実測）。

増えたこと自体は悪ではなく、増やすかどうかを**編集する PR の場で決められない**のが問題。実行時に切り捨てる仕組みは作らない（どのルールが落ちたか誰も気づけない）。編集時に予算で止め、動かすなら「削るか、予算を動かすか」を diff として主の前に出す。

## What Changes

- 予算値を独立ファイル `tests/injection-budget.txt` に置く。値の変更が単独の diff 行として現れ、聖域判定の対象をパスで指定できる形にする
- bats スイート `tests/injection-budget.bats` を 1 本足す。次の 8 種を測り、合計が予算から外れたら fail する:
  1. **rules**: `rules/*.md` のうち `scripts/sync.sh` が `~/.claude/rules/` へ symlink するもの（basename が `README.md` のものを除く全件）
  2. **CLAUDE.md**: リポジトリ直下の `CLAUDE.md`（`AGENTS.md` は同期済みの複製なので二重計上しない）
  3. **output-styles**: `output-styles/*.md` のうち `scripts/sync.sh` が `~/.claude/output-styles/` へ symlink するもの
  4. **SKILL.md description**: `plugins/*/skills/*/SKILL.md` の frontmatter `description` の合計
  5. **agent description**: `plugins/*/agents/*.md` の frontmatter `description` の合計
  6. **command description**: `plugins/*/commands/*.md` の frontmatter `description` の合計
  7. **local SKILL description**: `.claude/skills/` 配下の `SKILL.md` の frontmatter `description` の合計
  8. **local command description**: `.claude/commands/` 配下の `*.md` の frontmatter `description` の合計
- 判定は上下両方向。合計が予算を超えたら fail し、合計が予算を大きく（10% 超）下回っても fail する。削減 PR に予算の引き下げを強制し、削った分が次の増加の余地として残らないようにする
- fail メッセージに「予算・実測・差分量」「8 種の内訳」「取るべき行動（削る／予算ファイルを動かして PR 本文に理由を書く）」を出す
- `description` の折りたたみ記法（`description: >`）で 2 行目以降を集計から逃がす抜け道を塞ぐガードを 1 本足す
- 予算ファイルを `.github/workflows/auto-merge.yml` の聖域（`SACRED`）に足し、`scripts/test-auto-merge-workflow.sh` の必須一致リストにも同じパスを足す。予算を動かす PR が機械マージされないようにする
- 予算ファイルを動かすときは PR 本文に理由を書く旨を `CLAUDE.md` に 1〜2 文足す（`AGENTS.md` も同期して更新する）
- `scripts/test.sh` は `git ls-files '*.bats'` で対象を動的に発見するので変更不要

## Capabilities

### New Capabilities
- `injection-budget-gate`: 常時注入される固定分の合計サイズに予算を置き、編集時（テスト）に予算からの逸脱を上下両方向で検出して「削るか予算を動かすか」の判断を PR の diff に出す仕組み。測定対象の定義・測定単位・予算ファイルの位置と聖域扱い・変更手続きを含む

### Modified Capabilities
（なし。既存 capability の要件は変わらない）

## Impact

- 新規: `tests/injection-budget.bats`、`tests/injection-budget.txt`
- 変更: `CLAUDE.md` と `AGENTS.md`（予算ファイル変更時の規約。`tests/agents-md-sync.bats` が両者の同期を強制する）
- 変更: `.github/workflows/auto-merge.yml`（`SACRED` に 1 パス追加）と `scripts/test-auto-merge-workflow.sh`（必須一致リストに 1 行追加）。workflow のコメントがこの二重化を要求している
- 変更なし: `scripts/test.sh`（動的発見）、`scripts/sync.sh`（測定は sync.sh の除外規則を参照するだけで sync.sh 自体は変えない）
- 下流: エピック #257 の #260（固定分の削減）が、このテストと同じ物差しで削減量を測る。測定対象に `output-styles`、agent / command の description、`.claude/` 配下の skill / command の description を含めたのは、rules → `output-styles/readable.md` や SKILL description → command description の移動で、実注入量を減らさずに測定合計だけ減らせる経路を塞ぐため
- 対象外: `MEMORY.md`・接続コネクタ名・Claude Code 組み込みのスキル / ツール定義（tracked ファイルではなく PR の diff に現れないので編集時ゲートでは原理的に測れない）と、`plugins/*/hooks/` が毎ターン出力するテキスト（tracked だが出力が条件分岐するので静的には測れない）。実行時の監視は #259
