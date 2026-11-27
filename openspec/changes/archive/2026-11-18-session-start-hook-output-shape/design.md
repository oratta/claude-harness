# Design

## Context

出力の形の問題と原因は proposal.md の Why。同じプラグインの `scripts/develop-compact-reread.sh`・`scripts/team-mode-warning.sh`、worktree プラグインの `scripts/wt-setup-guard.sh` は、SessionStart で既に `hookSpecificOutput` の形を出している。プラグイン内で JSON を出す hook を grep した結果、トップレベルの `additionalContext` を出しているのは `session-tripwires.sh` の 1 か所だけだった（SubagentStart の `subagent-start-context.sh`、UserPromptSubmit の `prompt-tripwires-refresh.sh`・`unclear-reply-rephrase.sh`、PreToolUse/PostToolUse の `browser-guard.sh`・`context-tripwire.sh` はどれも `hookSpecificOutput` 入り）。

`session-tripwires.sh` の出力は hook として Claude Code が読むほかに、`prompt-tripwires-refresh.sh` が呼び出して JSON から本文を取り出し、`hookEventName: "UserPromptSubmit"` で包み直して再注入している。

## Goals / Non-Goals

**Goals:**
- SessionStart の本文が Claude Code の文脈に入る形で出る
- プラグイン更新時の再注入（UserPromptSubmit）が今までどおり動く

**Non-Goals:**
- 本文の中身・順序・fail-soft の条件を変えること
- `TRIPWIRES_SCOPE=subagent-budget` の本文テキスト出力を変えること
- hook の出力を `tests/injection-budget.bats` の測定対象に入れること（別の判断。必要なら別の issue）

## Decisions

### `hookEventName` は常に `"SessionStart"` を出す

`session-tripwires.sh` は hooks.json で SessionStart にだけ登録されている。stdin の `hook_event_name` を読んで切り替える案もあるが、今の登録先は 1 つで、読む処理を足すと fail-soft の経路が増えるだけなので固定値にする。`prompt-tripwires-refresh.sh` から呼ばれたときも `"SessionStart"` のまま出し、包み直す側が `"UserPromptSubmit"` を付ける（今の作りのまま）。

### `prompt-tripwires-refresh.sh` は新しい形だけを読む

トップレベルと `hookSpecificOutput` の両方を読む案もある。`prompt-tripwires-refresh.sh` は自分と同じ `CLAUDE_PLUGIN_ROOT` の `session-tripwires.sh` を呼ぶので、2 つの版が食い違う組み合わせは起きない。両方を読むと、古い形に戻る退行をテストが見逃すので、新しい形だけを読む。

### テストは出力の形を 1 か所で検査し、本文の取り出しは新しい形から行う

各テストのヘルパ（`json.loads(...)['additionalContext']`）を `['hookSpecificOutput']['additionalContext']` に置き換える。トップレベルの読み方を残すと `KeyError` で落ちるので、置き換え漏れはテストの失敗として見える。加えて `tripwire-hook.bats` の「注入 JSON が節を含む」テストで `hookEventName == "SessionStart"` とトップレベルに `additionalContext` が無いことを確かめる（受け入れ条件の `jq -e` と同じ判定）。

## Risks / Trade-offs

- [これまで届いていなかった本文が全セッションの開始時に載るので、開始時の文脈が増える] → 文面は最初から載る前提で書かれ、予算の議論もそれを前提にしていた。量は変えない。増え方が問題になれば本文の側で削る
- [Claude Code の版によって受け取る形が違う可能性] → 公式の形（`hookSpecificOutput`）は他の hook で実際に届いている。受け入れ条件の実機確認（新しいセッションの会話ログに文脈に入った印が残る）で確かめる

## Migration Plan

プラグインの更新だけで切り替わる。旧版のセッションが途中で新版に更新されたときは、`prompt-tripwires-refresh.sh`（新版）が `session-tripwires.sh`（新版）を呼ぶので食い違わない。戻すときは commit を revert する。
