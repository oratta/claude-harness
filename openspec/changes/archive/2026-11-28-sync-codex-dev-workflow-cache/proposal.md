# Proposal

## Why

`scripts/sync.sh` は Claude の rules/output-styles だけを配線し、Codex の Git marketplace snapshot と導入済み dev-workflow を更新しない。そのため main を更新しても Codex が古い develop や移行済み command skill を読み続ける（#1865）。

## What Changes

- marketplace dir 側の sync から、同じ名前で登録済みの Codex Git marketplace を CLI で更新する。
- CLI に導入済みキャッシュと `.codex-plugin/migrated-command-skills` の再生成を任せ、更新失敗を終了コードへ反映する。
- 一時 HOME の bats で main と develop のバイト一致、旧移行スキルの除去、既存配線の維持を検証する。
- `plugins/dev-workflow/changes/1865.md` に変更とマージ後の実ホーム確認の扱いを記録する。

## Capabilities

### New Capabilities

- `codex-marketplace-sync`: sync.sh による登録済み Git marketplace と導入済みキャッシュの更新。

### Modified Capabilities

なし。既存の `harness-overlay-sync` の配線要件と `marketplace-plugin-sync` の manifest 整合要件は維持する。

## Impact

対象は `scripts/sync.sh`、`tests/codex-sync.bats`、既存 `tests/rules-sync.bats` の HOME 隔離、変更記録。Codex を使う場合は plugin marketplace list/upgrade の JSON 出力に対応する CLI と JSON 処理用 jq を使う。CLI 未導入時の既存配線は継続する。
手順書の版チェック、worktree 読込手順の文書化、`$develop` の開始実測、provider-compat-update.md は別の子 issue の範囲。plugin.json に version を足さず、この工程では実装も実ホーム更新もしない。
