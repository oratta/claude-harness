#!/usr/bin/env bats
#
# Deterministic tests for voice-compactor Agent rules.
# Tests the regex-level invariants documented in the agent spec
# (noise-tag stripping, car-nav phrase matching, fixed 8-category set).
#
# These tests are intentionally narrow: they cover regex/string-matching
# rules that the agent's instructions reference. They do NOT attempt to
# test LLM compression output (non-deterministic).

load "$(dirname "$BATS_TEST_FILENAME")/helper.bash"

setup() {
  dr_setup_paths
  AGENT_FILE="${PLUGIN_DIR}/agents/voice-compactor.md"
}

@test "voice-compactor: agent file exists" {
  [ -f "$AGENT_FILE" ]
}

@test "voice-compactor: frontmatter contains direct-list Notion MCP tools" {
  dr_require_file "$AGENT_FILE"
  grep -q "mcp__claude_ai_Notion__notion-search" "$AGENT_FILE"
  grep -q "mcp__claude_ai_Notion__notion-fetch" "$AGENT_FILE"
}

@test "voice-compactor: frontmatter declares model: opus and permissionMode: bypassPermissions" {
  dr_require_file "$AGENT_FILE"
  grep -q "^model: opus" "$AGENT_FILE"
  grep -q "^permissionMode: bypassPermissions" "$AGENT_FILE"
}

@test "voice-compactor: all 8 fixed categories are documented in agent body" {
  dr_require_file "$AGENT_FILE"
  for tag in '\[user\]' '\[user-思考\]' '\[family-talk\]' '\[family-meal\]' '\[driving\]' '\[media-listen\]' '\[device-cmd\]' '\[pet\]' '\[unknown\]'; do
    grep -q "$tag" "$AGENT_FILE" || {
      echo "missing category tag: $tag"
      return 1
    }
  done
}

@test "voice-compactor: STATUS line contract is documented (1-line only)" {
  dr_require_file "$AGENT_FILE"
  grep -q "STATUS: ok" "$AGENT_FILE"
  grep -q "STATUS: partial" "$AGENT_FILE"
  grep -q "STATUS: fail" "$AGENT_FILE"
  grep -q "notion-mcp-unavailable" "$AGENT_FILE"
}

@test "voice-compactor: notion-fetch parallelism cap is 5" {
  dr_require_file "$AGENT_FILE"
  grep -Eq "(最大 ?5 ?並列|5 ?並列|max ?5 ?parallel|parallel.*5|並列.*5)" "$AGENT_FILE"
}

# --- Rule (a): noise-tag stripping regex ---
#
# voice-compactor must strip Fieldy noise markers like:
#   "**[Speaker Unknown] **"        — raw transcript speaker tag (drop)
#   "[音楽]" / "[BGM]" / "[拍手]"     — bracketed sfx markers (drop)
# but preserve compressed category tags like "[user]" / "[driving]".
#
# We test the regex that an implementation should use.

@test "noise-tag stripping: removes [Speaker Unknown] marker" {
  input='**[Speaker Unknown] **こんにちは、これはテスト発話です。'
  # Strip the speaker marker via sed (POSIX BRE)
  result=$(echo "$input" | sed -E 's/\*\*\[Speaker [A-Za-z]+\] \*\*//g')
  [ "$result" = "こんにちは、これはテスト発話です。" ]
}

@test "noise-tag stripping: removes bracketed SFX markers" {
  input='[音楽] テスト発話 [BGM] 続き [拍手] 終わり'
  # Strip well-known SFX brackets but keep meaningful text
  result=$(echo "$input" | sed -E 's/\[(音楽|BGM|拍手|笑|笑い|無音)\] ?//g')
  [ "$result" = "テスト発話 続き 終わり" ]
}

@test "noise-tag stripping: preserves compressed category tags" {
  input='[user] 思考メモ [driving] 移動中の話'
  # The same stripper from the SFX rule must NOT touch category tags.
  result=$(echo "$input" | sed -E 's/\[(音楽|BGM|拍手|笑|笑い|無音)\] ?//g')
  [ "$result" = "$input" ]
}

# --- Rule (b): car-nav phrase regex matching ---
#
# Car navigation device prompts are noise. They follow stereotyped patterns:
#   "300メートル先、右方向です"
#   "まもなく目的地です"
#   "ルートを再検索しています"
#   "次の信号を左折です"
# Compressor should match these and fold them into [driving].

@test "car-nav phrase: matches distance+direction prompt" {
  input='300メートル先、右方向です'
  # 全角数字は範囲 [０-９] ではなく列挙で書く。GNU grep は C ロケールだと多バイトの
  # 範囲指定を "Invalid collation character" で拒否し、終了コード 2 で落ちる（macOS の
  # BSD grep では通るため、ロケール依存の差異になる）。
  echo "$input" | grep -Eq '([0-9]|[０１２３４５６７８９])+(メートル|m|キロ|km)先、(右|左|斜め右|斜め左)?方向'
}

@test "car-nav phrase: matches destination-approach prompt" {
  input='まもなく目的地です'
  echo "$input" | grep -Eq '(まもなく|間もなく).*目的地'
}

@test "car-nav phrase: matches reroute prompt" {
  input='ルートを再検索しています'
  echo "$input" | grep -Eq 'ルート.*(再検索|検索|更新)'
}

@test "car-nav phrase: matches turn-at-signal prompt" {
  input='次の信号を左折です'
  echo "$input" | grep -Eq '(次の|この先の)?信号を(右折|左折|直進)'
}

@test "car-nav phrase: does NOT match generic driving thought" {
  # A regular driver thought should NOT match the car-nav regex.
  input='今日は道が空いてるな'
  # 上と同じ理由で列挙にする。範囲のままだと grep が終了コード 2（エラー）で落ち、
  # 否定の ! が真になって「マッチしなかった」と区別できず、偶然 pass していた。
  ! echo "$input" | grep -Eq '([0-9]|[０１２３４５６７８９])+(メートル|m|キロ|km)先、(右|左)?方向'
  ! echo "$input" | grep -Eq '(まもなく|間もなく).*目的地'
  ! echo "$input" | grep -Eq 'ルート.*(再検索|検索|更新)'
  ! echo "$input" | grep -Eq '(次の|この先の)?信号を(右折|左折|直進)'
}
