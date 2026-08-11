#!/usr/bin/env bats
#
# loops-dev-agent-respond-mode: 応答モード（人間の行頭メンションを最優先で拾う）の配布テンプレート
#
# 検証対象:
#   - templates/agent-loop-inbox.sh  … 検出（決定論・fail-open・投稿者を見ない・状態ファイル無し）
#   - templates/agent-loop-reply.sh  … 返信投稿 + rocket 付与 + 自己発火ガード
#   - templates/select-target.sh     … respond 分岐が他モードより前にあり即 emit する
#   - templates/agent-loop-template.md … Step 0.9 の mode 表と応答モードの手順
#   - skills/loops-dev-agent-install/SKILL.md … 3 本とも設置する手順
#
# ここで守りたいのは「flatmate にだけ実装されて配布テンプレに来ていない」状態の再発防止。
# 配布側が欠けると、導入先のリポジトリでは人間が issue に何を書いてもループに届かない。
#
# spec: loops-respond-mode

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  loops_setup_paths
  TEMPLATES="${PLUGIN_DIR}/templates"
  INBOX="${TEMPLATES}/agent-loop-inbox.sh"
  REPLY="${TEMPLATES}/agent-loop-reply.sh"
  SELECT="${TEMPLATES}/select-target.sh"
  CONSTITUTION="${TEMPLATES}/agent-loop-template.md"
  INSTALL_SKILL="${PLUGIN_DIR}/skills/loops-dev-agent-install/SKILL.md"
}

# --- テンプレートの存在と構文 ---

@test "inbox/reply templates exist" {
  [ -f "$INBOX" ]
  [ -f "$REPLY" ]
}

@test "all three loop scripts parse as bash (raw template)" {
  bash -n "$INBOX"
  bash -n "$REPLY"
  bash -n "$SELECT"
}

@test "all three loop scripts parse after placeholder substitution" {
  for f in "$INBOX" "$REPLY" "$SELECT"; do
    sed -e 's|{{AGENT_MENTION}}|@example-agent|g' -e 's|{{PROPOSAL_CAP}}|3|g' \
      "$f" > "${BATS_TEST_TMPDIR}/$(basename "$f")"
    bash -n "${BATS_TEST_TMPDIR}/$(basename "$f")"
  done
}

@test "templates carry no project-specific repo or account hardcoding" {
  # 移植元（flatmate）固有の repo 名・アカウント名を持ち込まない。
  # マーカーは {{AGENT_MENTION}} プレースホルダ + AGENT_INBOX_MARKER で解決する。
  ! grep -q 'genetta' "$INBOX"
  ! grep -q 'genetta' "$REPLY"
  ! grep -q 'genetta' "$SELECT"
}

# --- 検出スクリプト: 設計意図のコメントが失われていないこと ---
#
# 実装だけを移植して設計意図のコメントを落とすと、次に触る人が
# 「行頭限定」「投稿者を見ない」「状態ファイルを持たない」を緩めて自己発火を再発させる。

@test "inbox documents why matching is anchored to line start" {
  grep -q '行頭' "$INBOX"
  grep -Eq '緩めて|緩めては' "$INBOX"
  grep -q '無限ループ' "$INBOX"
  grep -q '2026-08-06' "$INBOX"   # 実測の日付（設計判断の根拠）
}

@test "inbox documents that the author account is never used for judgement" {
  grep -q '投稿者アカウントで人間かどうかを判定しない' "$INBOX"
}

@test "inbox documents that no local state file is kept" {
  grep -q 'ローカル状態ファイルを持たない' "$INBOX"
}

@test "inbox is fail-open and emits an empty pending set on every failure" {
  grep -q 'fail-open' "$INBOX"
  grep -q '{"pending":\[\]}' "$INBOX"
  # 失敗時の共通出口 bail は必ず exit 0（ループを止めない）
  grep -Eq 'bail\(\).*exit 0' "$INBOX"
}

@test "inbox uses the documented env vars with rocket as the done reaction" {
  grep -q 'AGENT_INBOX_MARKER' "$INBOX"
  grep -q 'AGENT_INBOX_DONE_REACTION:-rocket' "$INBOX"
}

@test "inbox excludes human-only and agent-wip but not agent-blocked" {
  grep -q 'index("human-only")' "$INBOX"
  grep -q 'index("agent-wip")' "$INBOX"
  ! grep -q 'index("agent-blocked")' "$INBOX"
  grep -q 'agent-blocked は意図的に除外しない' "$INBOX"
}

@test "inbox reports fetch failures on stderr instead of swallowing them" {
  grep -q '取得失敗=' "$INBOX"
}

# --- 返信スクリプト: 自己発火ガードと rocket 付与の束ね ---

@test "reply guards against a line-start marker before posting" {
  grep -q 'index(line, m) == 1' "$REPLY"
  grep -q '自己発火' "$REPLY"
}

@test "reply posts and reacts in one command and fails loudly" {
  grep -q 'issues/\$N/comments' "$REPLY"
  grep -q "content=\"\$DONE_REACTION\"" "$REPLY"
  grep -q 'set -euo pipefail' "$REPLY"
}

@test "reply reads the body with -F (not -f) so file contents are sent" {
  grep -q -- '-F "body=@\$BODYFILE"' "$REPLY"
}

# --- 選定スクリプト: respond が最優先で、副作用より前にある ---

@test "select-target has a respond branch" {
  grep -q 'mode: "respond"' "$SELECT"
  grep -q 'comment_id' "$SELECT"
}

@test "select-target calls the inbox script from its own directory" {
  grep -q 'dirname "\$0")/agent-loop-inbox.sh' "$SELECT"
}

@test "select-target evaluates respond before any other mode" {
  respond_line="$(grep -n 'mode: "respond"' "$SELECT" | head -1 | cut -d: -f1)"
  review_line="$(grep -n 'mode:"review"' "$SELECT" | head -1 | cut -d: -f1)"
  [ -n "$respond_line" ]
  [ -n "$review_line" ]
  [ "$respond_line" -lt "$review_line" ]
}

@test "select-target does not run label writes before the respond decision" {
  # respond の判定より前に POST（ラベル付与など副作用）を置かない
  respond_line="$(grep -n 'mode: "respond"' "$SELECT" | head -1 | cut -d: -f1)"
  post_line="$(grep -n 'gh api -X POST' "$SELECT" | head -1 | cut -d: -f1)"
  if [ -n "$post_line" ]; then
    [ "$respond_line" -lt "$post_line" ]
  fi
}

@test "select-target keeps the other modes intact" {
  grep -q 'mode:"review"' "$SELECT"
  grep -q 'mode:"fix"' "$SELECT"
  grep -q 'mode:"implement"' "$SELECT"
  grep -q 'mode:"propose"' "$SELECT"
  grep -q 'mode:"skip"' "$SELECT"
}

# --- 憲法テンプレート ---

@test "constitution lists respond in the mode table with comment_id" {
  grep -q '`respond`' "$CONSTITUTION"
  grep -q '| `comment_id` |' "$CONSTITUTION"
}

@test "constitution states the respond-first priority order" {
  grep -Eq '`respond` > `review`' "$CONSTITUTION"
}

@test "constitution has the respond mode procedure" {
  grep -q '応答モード' "$CONSTITUTION"
  grep -q 'scripts/agent-loop-reply.sh' "$CONSTITUTION"
  grep -q 'scripts/agent-loop-inbox.sh' "$CONSTITUTION"
  grep -q 'rocket' "$CONSTITUTION"
}

@test "constitution forbids the agent from writing the marker at line start" {
  grep -q '行頭' "$CONSTITUTION"
  grep -Eq '書いてはならない|禁止' "$CONSTITUTION"
}

# --- 導入スキル ---

@test "install skill deploys all three scripts" {
  grep -q 'templates/agent-loop-inbox.sh' "$INSTALL_SKILL"
  grep -q 'templates/agent-loop-reply.sh' "$INSTALL_SKILL"
  grep -q 'scripts/agent-loop-inbox.sh' "$INSTALL_SKILL"
  grep -q 'scripts/agent-loop-reply.sh' "$INSTALL_SKILL"
}

@test "install skill substitutes the mention placeholder" {
  grep -q '{{AGENT_MENTION}}' "$INSTALL_SKILL"
}

@test "install skill documents re-wiring for already-installed repos" {
  grep -q '導入済みリポジトリへの応答モードの追加配線' "$INSTALL_SKILL"
}

@test "install skill verifies placeholder substitution and syntax" {
  grep -q 'bash -n' "$INSTALL_SKILL"
}
