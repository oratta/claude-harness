## 1. subagent-context-audit.sh

- [ ] 1.1 `projects` の既定を `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}` にし、`cache` の既定を `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.subagent-context-audit` にする。触る範囲: plugins/dev-workflow/scripts/subagent-context-audit.sh:62-63
- [ ] 1.2 `CLAUDE_CONFIG_DIR` を一時ディレクトリにしたテストを足す（会話記録を読むこと、cache がその下に作られること）。触る範囲: tests/（subagent-context-audit のテストの置き場を探す。無ければ新規 tests/subagent-context-audit.bats）

## 2. epic-launch-tmux.sh

- [ ] 2.1 `log_has_prompt` の `root` とコメントを同じ順にする。触る範囲: plugins/dev-workflow/scripts/epic-launch-tmux.sh:99-103
- [ ] 2.2 `CLAUDE_CONFIG_DIR` を一時ディレクトリにしたテストを足す。触る範囲: tests/epic-launch-tmux.bats（log_has_prompt を使う既存のテストの近く）
