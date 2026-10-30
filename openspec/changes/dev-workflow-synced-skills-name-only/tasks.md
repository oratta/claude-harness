## 1. スクリプト

- [ ] 1.1 `plugins/dev-workflow/scripts/synced-skills-name-only.sh` を書く（`--dry-run`、列挙、jq での統合、バックアップ、一時ファイル経由の置き換え、壊れた入力の拒否）。ひな型は `plugins/statusline/scripts/install.sh` の dry-run と書き込みの分け方  触る範囲: plugins/dev-workflow/scripts/synced-skills-name-only.sh（新規）、plugins/statusline/scripts/install.sh（参照のみ）

## 2. コマンド

- [ ] 2.1 `plugins/dev-workflow/commands/synced-skills-slim.md` を書く（プラグインルートの特定 → `--dry-run` → 確認 → 適用 → 結果報告、戻し方、`name-only` の注意、実測した版）。`description` は短くする  触る範囲: plugins/dev-workflow/commands/synced-skills-slim.md（新規）、plugins/statusline/commands/setup.md:1-60（ひな型）

## 3. テスト

- [ ] 3.1 `plugins/dev-workflow/tests/synced-skills-name-only.bats` を書く。HOME と `CLAUDE_CONFIG_DIR` を一時ディレクトリにして、spec の全シナリオ（列挙、既存値の保持、他キーの保持、同期スキル無し、冪等、増えた分だけ、dry-run、壊れた JSON、コマンドの戻し方と hook から呼ばれないこと）を確かめる。実物の `~/.claude/settings.json` には触れない  触る範囲: plugins/dev-workflow/tests/synced-skills-name-only.bats（新規）、plugins/statusline/tests/setup-command-zsh.bats（形の参照）

## 4. 予算と記録

- [ ] 4.1 `tests/injection-budget.bats` の実測と予算の差を測る。超えるなら W は予算ファイルを動かさず本体に知らせる  触る範囲: tests/injection-budget.txt:1
- [ ] 4.2 変更の記録 `plugins/dev-workflow/changes/1470.md` を書く  触る範囲: plugins/dev-workflow/changes/1470.md（新規）
