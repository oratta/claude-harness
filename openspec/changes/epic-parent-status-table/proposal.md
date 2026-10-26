# Proposal

## Why

エピックの親が主に出す報告は、知らせが来た子の件だけを書きがちで、前に聞いた件が流れて主が見失う。また、主が子のタブで直接答えても子は issue の停止の記録を書き直さないため、親は古い記録だけを見て、子の実際の状態とずれた報告を出す（oratta/mac-mini-migration のエピック #33、2026-10-26）。Refs oratta/claude-harness#1377。

## What Changes

- 親が主に出す報告すべての最後に、まだ閉じていない全部の子と親自身の状態表（列は「issue 番号・内容・ステータス・確認内容・推奨・答え方」、上に確かめた時刻 JST）を付け、表の下に答えが要る子の URL を 1 行 1 本で置き、「前回の報告から片付いたもの」を書く、と `references/epic.md` に規定する（別セッション方式とサブエージェント方式の両方）
- 表を書く前に、親が各子の会話ログの末尾を読んで子のタブで進んだ分を反映する、と規定する。読めない子のステータスは「確かめられなかった」と書く
- `scripts/epic-dispatch.sh` に読み取り専用の `child-log` サブコマンドを足す（LLM を使わず、子ごとの最後の主の発言と最後の子の発言の時刻と冒頭を出す）

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 親の報告の状態表と、子の会話ログ末尾を読む `child-log` の要件を足す（既存の要件の文は変えない）

## Impact

- `plugins/dev-workflow/skills/develop/references/epic.md`
- `plugins/dev-workflow/scripts/epic-dispatch.sh`、`plugins/dev-workflow/tests/epic-dispatch.bats`
- `plugins/dev-workflow/changes/1377.md`
