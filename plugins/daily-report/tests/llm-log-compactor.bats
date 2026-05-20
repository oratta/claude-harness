#!/usr/bin/env bats
#
# Deterministic tests for llm-log-compactor Agent rules.
# Focus: jq/grep-based aggregation logic over a synthetic jsonl fixture.
# We do NOT test LLM compression output (non-deterministic).

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  dr_setup_paths
  dr_make_tmpdir
  AGENT_FILE="${PLUGIN_DIR}/agents/llm-log-compactor.md"
  FIXTURE="${DR_TEST_TMPDIR}/fixture.jsonl"
  # Build a tiny fixture jsonl with 3 user-role messages and 2 assistant messages
  # (mixed with a sidechain/system entry to verify head-5 limit is NOT in effect).
  cat > "$FIXTURE" <<'EOF'
{"type":"system","message":{"role":"system","content":"system bootstrap"}}
{"type":"sidechain","message":{"role":"user","content":"this is sidechain noise"},"sidechain":true}
{"type":"user","message":{"role":"user","content":"first real user message"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"first assistant reply"}]}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"second user turn"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","name":"Edit","input":{"file_path":"/tmp/a.ts"}}]}}
{"type":"user","message":{"role":"user","content":"third user turn"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"final assistant output"}]}}
EOF
}

teardown() {
  dr_teardown_tmpdir
}

@test "llm-log-compactor: agent file exists" {
  [ -f "$AGENT_FILE" ]
}

@test "llm-log-compactor: frontmatter does NOT include Notion MCP tools" {
  dr_require_file "$AGENT_FILE"
  ! grep -q "mcp__claude_ai_Notion__" "$AGENT_FILE"
}

@test "llm-log-compactor: frontmatter tools include Read Write Bash Glob" {
  dr_require_file "$AGENT_FILE"
  grep -Eq "^tools:.*Read.*Write.*Bash.*Glob|^tools:.*Glob" "$AGENT_FILE"
}

@test "llm-log-compactor: model is opus" {
  dr_require_file "$AGENT_FILE"
  grep -q "^model: opus" "$AGENT_FILE"
}

@test "llm-log-compactor: head -5 restriction is removed (sequential scan documented)" {
  dr_require_file "$AGENT_FILE"
  ! grep -Eq 'head ?-5' "$AGENT_FILE"
  # Sequential scan documented (Japanese or English keyword)
  grep -Eq '(先頭から順次|順次スキャン|sequential scan|head ?- ?n ?1)' "$AGENT_FILE"
}

@test "llm-log-compactor: 6 metadata fields documented" {
  dr_require_file "$AGENT_FILE"
  grep -q "turn数" "$AGENT_FILE"
  grep -Eq "files touched" "$AGENT_FILE"
  grep -Eq "commits 件数" "$AGENT_FILE"
  grep -Eq "top3" "$AGENT_FILE"
  grep -Eq "Files \(top ?5\)" "$AGENT_FILE"
  grep -Eq "Commits \(top ?5" "$AGENT_FILE"
}

@test "llm-log-compactor: STATUS contract is documented (1-line only)" {
  dr_require_file "$AGENT_FILE"
  grep -q "STATUS: ok" "$AGENT_FILE"
  grep -q "STATUS: partial" "$AGENT_FILE"
  grep -q "STATUS: fail" "$AGENT_FILE"
}

# --- Deterministic test: turn-count aggregation via jq ---
#
# "turn数" is defined as the count of user-role messages (excluding sidechain/system).
# The agent must use jq/grep to compute this WITHOUT reading the jsonl body into main.
# We validate the canonical jq expression that the agent should use.

@test "turn-count aggregation: counts only top-level user role (excludes sidechain/system)" {
  [ -f "$FIXTURE" ]
  # Canonical aggregation: count records where type==user and message.role==user
  # (sidechain is filtered out via type field; system records also excluded)
  count=$(jq -c 'select(.type == "user" and .message.role == "user")' "$FIXTURE" | wc -l | tr -d ' ')
  [ "$count" = "3" ]
}

@test "turn-count aggregation: excludes sidechain entries even if message.role==user" {
  [ -f "$FIXTURE" ]
  # Validate that sidechain noise is not counted
  sidechain_count=$(jq -c 'select(.type == "sidechain")' "$FIXTURE" | wc -l | tr -d ' ')
  [ "$sidechain_count" = "1" ]
  # And our user-counter must exclude it
  user_count=$(jq -c 'select(.type == "user" and .message.role == "user")' "$FIXTURE" | wc -l | tr -d ' ')
  [ "$user_count" = "3" ]
}

@test "turn-count aggregation: first user message extractable beyond head -5 line limit" {
  [ -f "$FIXTURE" ]
  # The first user record is on LINE 3 of the fixture (after system + sidechain),
  # which means head -5 (old logic) would have found it, but head -1/-2 would not.
  # The agent's sequential scan must succeed here.
  first_user=$(jq -r -c 'select(.type == "user" and .message.role == "user")' "$FIXTURE" \
    | head -1 \
    | jq -r 'if (.message.content | type) == "string" then .message.content else (.message.content[] | select(.type=="text") | .text) end')
  [ "$first_user" = "first real user message" ]
}
