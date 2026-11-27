#!/usr/bin/env bash
# SessionStart hook: チーム機能（CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS）が有効なら警告する（#591）。
# 有効だと名前付き spawn が teammate になり、subagent_type の道具制限・本文が無視される（#330）。
# 無効とみなす値: 未設定・空・0・false（大文字小文字を区別しない）。それ以外は有効として警告する。
# 常に exit 0（セッション開始を止めない）。
set -uo pipefail

VALUE="${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}"
LOWER="$(printf '%s' "$VALUE" | tr '[:upper:]' '[:lower:]')"
case "$LOWER" in
  "" | 0 | false) exit 0 ;;
esac

# JSON は固定文なので、python3 に頼らず cat の heredoc でそのまま出す（実行環境に依存せず警告が消えないように）。
cat <<'JSON'
{"systemMessage": "警告: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS が有効です。チーム機能が有効だと、名前付きで起こした担当が teammate として起動し、subagent_type の定義（道具の制限・本文）が無視されます。develop は W / G を名前付きで起こすため、読み取り専用の種別も Bash・Edit を持ちます。CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS を未設定か 0 にしてから develop を回してください。", "hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "警告: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS が有効です。チーム機能が有効だと、名前付きで起こした担当が teammate として起動し、subagent_type の定義（道具の制限・本文）が無視されます。develop は W / G を名前付きで起こすため、読み取り専用の種別も Bash・Edit を持ちます。CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS を未設定か 0 にしてから develop を回してください。"}}
JSON
exit 0
