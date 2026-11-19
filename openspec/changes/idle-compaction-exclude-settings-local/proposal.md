## Why

develop は開始時に `develop-idle-compaction.py --apply` で worktree の `.claude/settings.local.json` を書く。このファイルは git の無視対象に入っておらず、`git status --porcelain` に `??` で出る。`epic-dispatch.sh reap` は porcelain が空でなければ `kept <N> dirty` を返すので、マージ済みで完了の印も付いた子の worktree が片付かない（エピック #1237 の子 #1235・#1236 で確認）。

## What Changes

- `develop-idle-compaction.py --apply` が設定ファイルを書くとき、そのリポジトリの `$(git rev-parse --git-common-dir)/info/exclude` に `.claude/settings.local.json` の 1 行を足す。既に同じ行があれば足さない
- `.gitignore` には足さない（develop はどのリポジトリでも動き、作業リポジトリの追跡ファイルを書き換えないため）。`reap` 側の例外判定も作らない（dirty の判定を緩めると、本物の未コミット変更を見逃すため）
- 既に追跡されているファイルの追跡は変えない（exclude は追跡済みファイルに効かない）。`--check` は何も書かない

## Capabilities

### Modified Capabilities
- `dev-workflow-develop`: 要件「idle compaction の設定操作は既存設定と承認規則を保つ」に、`--apply` が共有の除外設定へ 1 行足す規則を加える

## Impact

- `plugins/dev-workflow/scripts/develop-idle-compaction.py`
- `plugins/dev-workflow/tests/develop-idle-compaction.bats`
