## Why

claude.ai から同期されたスキル（`~/.claude/skills/synced/` に置かれるもの）の名前と説明は、使わないセッションでも毎回の最初のリクエストに載る。実測（Claude Code 2.1.314、同期スキル 13 本）では、13 本を `skillOverrides` で `name-only` にすると最初のリクエストが 9,282 バイト、`claude -p` の開始時のトークン数が 3,029 減った。`skillOverrides` はプラグインの設定では配れず、利用者の `settings.json` に書くしかない。手で 13 本のキーを調べて書くのは続かないので、確認つきで書き込む設定コマンドを足す。

## What Changes

- `dev-workflow` に設定コマンド `/dev-workflow:synced-skills-slim` と、書き込みを担う `scripts/synced-skills-name-only.sh` を足す
- その環境に同期されているスキルを列挙し、`settings.json` の `skillOverrides` に `anthropic-skills:<スキルのディレクトリ名>` を `name-only` として足す。既存のキーと値、他の設定は変えない
- 同期スキルが無ければ何も書かない。もう一度実行したときは、まだ入っていないキーだけを足し、足すものが無ければ書き換えない
- コマンドは書き込む内容を見せて利用者の確認を取ってから書く。元に戻す手順をコマンドの案内に書く

やらないこと（issue の「やらないこと」どおり）: `SessionStart` などの hook で確認なしに書き換えること／claude.ai の接続を外す設定／artifact の無効化。取り消し用のオプション（`--uninstall`）は足さない（戻し方は案内の jq 1 行とバックアップで足りる）。

## Capabilities

### New Capabilities
- `dev-workflow-synced-skills-name-only`: 同期スキルを `skillOverrides` で `name-only` にする設定コマンドとスクリプトの振る舞い

### Modified Capabilities
なし

## Impact

- 新規: `plugins/dev-workflow/commands/synced-skills-slim.md`（`plugins/dev-workflow/.claude-plugin/plugin.json` の `commands` にも登録する。登録が無いと読み込まれない）、`plugins/dev-workflow/scripts/synced-skills-name-only.sh`、`plugins/dev-workflow/tests/synced-skills-name-only.bats`、`plugins/dev-workflow/changes/1470.md`
- 既存の検査への追加: `tests/command-plugin-root.bats` の LOOPS、`plugins/dev-workflow/tests/command-search-zsh.bats` の DOCS と EXPECT_N に新しいコマンド文書を加える（コマンドの探索ループを検査対象にするため）
- 常時注入の予算: 新しいコマンドの `description`（frontmatter）が `tests/injection-budget.bats` の「plugins command description」に加わる。現状の実測は予算 40905 バイトとほぼ同じで余裕が約 1 バイトしかないため、`tests/injection-budget.txt`（聖域）を動かす必要が出る見込み。値を動かす前に本体に知らせ、PR 本文に理由を書く。実際は `plugins/dev-workflow/commands/work-issue.md` の `description` を縮めて相殺し、予算は動かさなかった
- `~/.claude/settings.json` は、利用者がコマンドを実行して確認したときにだけ書き換わる
