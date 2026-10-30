# Design

## Context

背景は proposal.md の Why。リポジトリの他のスクリプト（`epic-dispatch.sh`、`owner-reply-check.sh`）は既に `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects` の形で会話記録を探していて、この 2 本が古い形のまま残っている。

## Goals / Non-Goals

**Goals:** 両スクリプトの既定の探索先が、Claude Code が会話記録を実際に書く場所と一致する。

**Non-Goals:**

- `subagent-context-audit.sh` と `epic-launch-tmux.sh` も同じ書き方で `CLAUDE_CONFIG_DIR` を見ないが、#1231 の受け入れ条件に無いので直さない。return で本体に伝え、扱いは本体が決める
- 設定フォルダをまたいだ合算はしない（Decisions 参照）

## Decisions

**探索先は 1 か所にする。** 候補は次の 2 つで、1 か所を選ぶ。

- 採用: `${CLAUDE_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}` の 1 か所。issue が定めた順で、`epic-dispatch.sh` の探索先と同じ形
- 不採用: `CLAUDE_CONFIG_DIR` の下と `~/.claude/projects` の両方を探す。別の設定の会話記録が候補に混ざり、`subagent-context.sh` が別セッションの同名の W を測りうる

**未設定と空文字を同じに扱う。** `:-` の展開をそのまま使う。空の `CLAUDE_CONFIG_DIR` で `/projects` を探しに行くことを防ぎ、既存の他のスクリプトとも揃う。

**スクリプトの中で共通の関数にしない。** 2 本とも 1 行の既定値の変更で足り、既に他のスクリプトが同じ 1 行を持っている。共通化は #1231 の範囲を超える。

## Risks / Trade-offs

- [1 つの記録先を別々の `CLAUDE_CONFIG_DIR` のセッションで進めると、`pr-token-budget.sh` は実行中のセッションの設定の分しか数えない] → 受け入れる。少なく数える向きで、修正前（0 と数える）より悪くならない
- [`CLAUDE_CONFIG_DIR` を使うセッションで上限超の exit 2 が初めて出る] → 意図した変化。exit 2 のあとの手順は既存の `skills/develop/SKILL.md` のまま

## Migration Plan

移行は要らない。保存する状態を変えていないので、差分を戻せば元に戻る。
