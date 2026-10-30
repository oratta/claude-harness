## 1. スクリプト

- [x] 1.1 `plugins/dev-workflow/scripts/synced-skills-name-only.sh` を書く（`--dry-run`、列挙、jq での統合、バックアップ、一時ファイル経由の置き換え、壊れた入力の拒否）。ひな型は `plugins/statusline/scripts/install.sh` の dry-run と書き込みの分け方、jq 無しの失敗。symlink と権限は design の「symlink と権限」どおり  触る範囲: plugins/dev-workflow/scripts/synced-skills-name-only.sh（新規）、plugins/statusline/scripts/install.sh（参照のみ）

## 2. コマンド

- [x] 2.1 `plugins/dev-workflow/commands/synced-skills-slim.md` を書く。`allowed-tools` に AskUserQuestion を入れる。探索ループは `memory-refresh.md` の `plugin_root="${CLAUDE_PLUGIN_ROOT}"` の形にする（プラグインルートの特定 → `--dry-run` → 確認 → 適用 → 結果報告、戻し方、`name-only` の注意、実測した版）。`description` は短くする  触る範囲: plugins/dev-workflow/commands/synced-skills-slim.md（新規）、plugins/dev-workflow/commands/memory-refresh.md（探索ループの手本）、plugins/statusline/commands/setup.md:1-60（進め方の手本）
- [x] 2.2 `plugins/dev-workflow/.claude-plugin/plugin.json` の `commands` に `./commands/synced-skills-slim.md` を足す  触る範囲: plugins/dev-workflow/.claude-plugin/plugin.json:31-36
- [x] 2.3 `tests/command-plugin-root.bats` の LOOPS（33 行目付近）と `plugins/dev-workflow/tests/command-search-zsh.bats` の DOCS（9 行目）・EXPECT_N に新しいコマンド文書を足す  触る範囲: tests/command-plugin-root.bats:33、plugins/dev-workflow/tests/command-search-zsh.bats:9

## 3. テスト

- [x] 3.1 `plugins/dev-workflow/tests/synced-skills-name-only.bats` を書く。HOME と `CLAUDE_CONFIG_DIR` を一時ディレクトリにして、spec の全シナリオ（列挙と除外、既存値の保持、他キーの保持、同期スキル無し、同期スキル無しなら壊れた設定でも exit 0、冪等、増えた分だけ、dry-run、壊れた JSON、最上位が非オブジェクト、`skillOverrides` が非オブジェクト、未知の引数、jq 無し、設定が無いときの作成とバックアップ無し、symlink と権限の維持、`plugin.json` への登録、コマンド文書の検査（`allowed-tools` に AskUserQuestion・`--dry-run` → 確認 → 適用の順・断ったら `--dry-run` なしで呼ばない）、戻し方、hook から呼ばれないこと）を確かめる。実物の `~/.claude/settings.json` には触れない  触る範囲: plugins/dev-workflow/tests/synced-skills-name-only.bats（新規）、plugins/statusline/tests/setup-command-zsh.bats（形の参照）

## 4. 予算と記録

- [x] 4.1 `tests/injection-budget.bats` の実測と予算の差を測る。超えるなら W は予算ファイルを動かさず本体に知らせる  触る範囲: tests/injection-budget.txt:1
- [ ] 4.2 PR 本文に、同期スキルの名前の取り方の根拠（design の 2 つ）と実測した Claude Code の版（2.1.314）を書く（PR を作る段で行う）
- [x] 4.3 変更の記録 `plugins/dev-workflow/changes/1470.md` を書く  触る範囲: plugins/dev-workflow/changes/1470.md（新規）
