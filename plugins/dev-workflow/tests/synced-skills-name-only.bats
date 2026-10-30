#!/usr/bin/env bats
# synced-skills-name-only.sh と /dev-workflow:synced-skills-slim の検査（issue #1470）。
# 設定ディレクトリは一時ディレクトリ（CLAUDE_CONFIG_DIR）で、実物の ~/.claude/settings.json には触れない。
# テスト名は ASCII のみ（bats の制約）。

setup() {
  PLUGIN_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$PLUGIN_DIR/scripts/synced-skills-name-only.sh"
  CMD="$PLUGIN_DIR/commands/synced-skills-slim.md"
  export CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/cfg"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$CLAUDE_CONFIG_DIR" "$HOME"
  S="$CLAUDE_CONFIG_DIR/settings.json"
}

mk_skill() { # <バケット> <名>
  mkdir -p "$CLAUDE_CONFIG_DIR/skills/synced/$1/$2"
  : > "$CLAUDE_CONFIG_DIR/skills/synced/$1/$2/SKILL.md"
}
baks() { ls "$CLAUDE_CONFIG_DIR"/settings.json.bak-* 2>/dev/null | wc -l | tr -d ' '; }
tmps() { ls -A "$CLAUDE_CONFIG_DIR" | grep -c '^\.settings\.json\.'; }

# 書き換えの jq（フィルタに '.skillOverrides = ' を含む呼び出し）だけを失敗させる偽物を置く。
# $1 は失敗する前に実行する文。
fake_jq() {
  local real
  real="$(command -v jq)"
  mkdir -p "$BATS_TEST_TMPDIR/fakebin"
  cat > "$BATS_TEST_TMPDIR/fakebin/jq" <<EOF
#!/bin/bash
case "\$*" in
  *'.skillOverrides = '*) $1; exit 1 ;;
esac
exec "$real" "\$@"
EOF
  chmod +x "$BATS_TEST_TMPDIR/fakebin/jq"
}

@test "script and command files exist" {
  [ -f "$SCRIPT" ]
  [ -f "$CMD" ]
}

@test "dry-run lists only real skill dirs of non-dot buckets" {
  mk_skill org_acct pdf; mk_skill org_acct docs
  mk_skill .bucket-x pdf2; mk_skill org_acct .hidden
  : > "$CLAUDE_CONFIG_DIR/skills/synced/org_acct/.last-complete-round"
  echo '{"model":"opus"}' > "$S"
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"anthropic-skills:pdf"* ]] || return 1
  [[ "$output" == *"anthropic-skills:docs"* ]] || return 1
  [[ "$output" != *pdf2* ]] || return 1
  [[ "$output" != *hidden* ]] || return 1
  [ "$(jq -c . "$S")" = '{"model":"opus"}' ]
  [ "$(baks)" = 0 ]
}

@test "existing values and other keys are kept" {
  mk_skill o pdf; mk_skill o docs
  echo '{"model":"opus","skillOverrides":{"anthropic-skills:pdf":"off","mine":"on"}}' > "$S"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(jq -S -c . "$S")" = '{"model":"opus","skillOverrides":{"anthropic-skills:docs":"name-only","anthropic-skills:pdf":"off","mine":"on"}}' ]
  [[ "$output" == *"anthropic-skills:docs"* ]] || return 1
  [ "$(baks)" = 1 ]
}

@test "skillOverrides is created when absent" {
  mk_skill o pdf
  echo '{"model":"opus"}' > "$S"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(jq -S -c . "$S")" = '{"model":"opus","skillOverrides":{"anthropic-skills:pdf":"name-only"}}' ]
}

@test "no synced skills writes nothing and says so" {
  echo '{"model":"opus"}' > "$S"
  cp "$S" "$BATS_TEST_TMPDIR/before"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"同期スキルが無い"* ]] || return 1
  cmp "$S" "$BATS_TEST_TMPDIR/before"
  [ "$(baks)" = 0 ]
}

@test "no synced skills exits 0 even when settings.json is broken" {
  echo 'not json' > "$S"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(cat "$S")" = 'not json' ]
}

@test "missing settings.json is created without a backup" {
  mk_skill o pdf
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(jq -c . "$S")" = '{"skillOverrides":{"anthropic-skills:pdf":"name-only"}}' ]
  [ "$(baks)" = 0 ]
}

@test "symlinked settings.json stays a symlink and keeps permissions" {
  mk_skill o pdf
  mkdir -p "$BATS_TEST_TMPDIR/real"
  echo '{"model":"opus"}' > "$BATS_TEST_TMPDIR/real/s.json"
  chmod 644 "$BATS_TEST_TMPDIR/real/s.json"
  cp "$BATS_TEST_TMPDIR/real/s.json" "$BATS_TEST_TMPDIR/before"
  ln -s "$BATS_TEST_TMPDIR/real/s.json" "$S"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -L "$S" ]
  [ "$(jq -r '.skillOverrides["anthropic-skills:pdf"]' "$BATS_TEST_TMPDIR/real/s.json")" = name-only ]
  [ "$(stat -c %a "$BATS_TEST_TMPDIR/real/s.json" 2>/dev/null || stat -f %Lp "$BATS_TEST_TMPDIR/real/s.json")" = 644 ]
  [ "$(baks)" = 1 ]
  cmp "$(echo "$CLAUDE_CONFIG_DIR"/settings.json.bak-*)" "$BATS_TEST_TMPDIR/before"
  [ "$(ls "$BATS_TEST_TMPDIR/real" | wc -l | tr -d ' ')" = 1 ]
}

@test "second run changes nothing" {
  mk_skill o pdf
  echo '{}' > "$S"
  bash "$SCRIPT"
  cp "$S" "$BATS_TEST_TMPDIR/after1"
  touch -t 202001010000 "$S"
  m1="$(stat -c %Y "$S" 2>/dev/null || stat -f %m "$S")"
  n1="$(baks)"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  cmp "$S" "$BATS_TEST_TMPDIR/after1"
  [ "$(stat -c %Y "$S" 2>/dev/null || stat -f %m "$S")" = "$m1" ]
  [ "$(baks)" = "$n1" ]
}

@test "only newly added skills are added on a later run" {
  mk_skill o pdf
  echo '{}' > "$S"
  bash "$SCRIPT"
  jq '.skillOverrides["anthropic-skills:pdf"]="on"' "$S" > "$S.t" && mv "$S.t" "$S"
  rm -f "$CLAUDE_CONFIG_DIR"/settings.json.bak-* # 同じ秒のバックアップは拒否されるので、2 回目の適用の前に消す
  mk_skill o docs
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(jq -S -c .skillOverrides "$S")" = '{"anthropic-skills:docs":"name-only","anthropic-skills:pdf":"on"}' ]
}

@test "broken settings.json fails without writing when skills exist" {
  mk_skill o pdf
  echo 'not json' > "$S"
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [ "$(cat "$S")" = 'not json' ]
  [ "$(baks)" = 0 ]
}

@test "non-object top level fails without writing" {
  mk_skill o pdf
  for v in '[]' 'null'; do
    echo "$v" > "$S"
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [ "$(cat "$S")" = "$v" ]
  done
  [ "$(baks)" = 0 ]
}

@test "non-object skillOverrides fails without writing" {
  mk_skill o pdf
  echo '{"skillOverrides":["x"]}' > "$S"
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [ "$(cat "$S")" = '{"skillOverrides":["x"]}' ]
  [ "$(baks)" = 0 ]
}

@test "unknown argument fails without writing, with or without skills" {
  mk_skill o pdf
  echo '{}' > "$S"
  run bash "$SCRIPT" --dry-rnu
  [ "$status" -ne 0 ]
  [ "$(cat "$S")" = '{}' ]
  [ "$(baks)" = 0 ]
  rm -rf "$CLAUDE_CONFIG_DIR/skills"
  run bash "$SCRIPT" --dry-rnu
  [ "$status" -ne 0 ]
}

@test "missing jq fails, with or without skills" {
  mkdir -p "$BATS_TEST_TMPDIR/emptybin"
  echo '{}' > "$S"
  run env PATH="$BATS_TEST_TMPDIR/emptybin" /bin/bash "$SCRIPT"
  [ "$status" -ne 0 ]
  mk_skill o pdf
  run env PATH="$BATS_TEST_TMPDIR/emptybin" /bin/bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [ "$(cat "$S")" = '{}' ]
}

@test "a key whose value is null is kept as it is" {
  mk_skill o pdf; mk_skill o docs
  echo '{"skillOverrides":{"anthropic-skills:pdf":null}}' > "$S"
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c 'anthropic-skills:docs')" = 1 ]
  [[ "$output" == *"変えない:"*"anthropic-skills:pdf"*"足す予定"* ]] || return 1
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(jq -S -c .skillOverrides "$S")" = '{"anthropic-skills:docs":"name-only","anthropic-skills:pdf":null}' ]
}

@test "only a null-valued key means nothing to add" {
  mk_skill o pdf
  echo '{"skillOverrides":{"anthropic-skills:pdf":null}}' > "$S"
  cp "$S" "$BATS_TEST_TMPDIR/before"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  cmp "$S" "$BATS_TEST_TMPDIR/before"
  [ "$(baks)" = 0 ]
}

@test "null or false skillOverrides fails without writing" {
  mk_skill o pdf
  for v in null false; do
    echo "{\"skillOverrides\":$v}" > "$S"
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [ "$(cat "$S")" = "{\"skillOverrides\":$v}" ]
  done
  [ "$(baks)" = 0 ]
}

@test "several JSON values in settings.json fail without writing" {
  mk_skill o pdf
  for v in '[]' '{"a":1}'; do
    printf '%s\n{"b":2}\n' "$v" > "$S"
    cp "$S" "$BATS_TEST_TMPDIR/before"
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    cmp "$S" "$BATS_TEST_TMPDIR/before"
  done
  [ "$(baks)" = 0 ]
}

@test "an empty-string argument fails without writing" {
  mk_skill o pdf
  echo '{}' > "$S"
  run bash "$SCRIPT" ""
  [ "$status" -ne 0 ]
  [ "$(cat "$S")" = '{}' ]
  [ "$(baks)" = 0 ]
}

@test "a circular symlink fails instead of looping" {
  mk_skill o pdf
  ln -s "$S" "$S"
  run bash "$SCRIPT" --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"循環"* ]] || return 1
  rm -f "$S"
  ln -s "$S.2" "$S"
  ln -s "$S" "$S.2"
  run bash "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"循環"* ]] || return 1
}

@test "the backup holds the content from before the write" {
  mk_skill o pdf
  echo '{"model":"opus"}' > "$S"
  cp "$S" "$BATS_TEST_TMPDIR/before"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(baks)" = 1 ]
  cmp "$(echo "$CLAUDE_CONFIG_DIR"/settings.json.bak-*)" "$BATS_TEST_TMPDIR/before"
  [[ "$output" == *"バックアップ: $CLAUDE_CONFIG_DIR/settings.json.bak-"* ]] || return 1
}

@test "a failed rewrite leaves settings.json and no temp file" {
  mk_skill o pdf
  echo '{"model":"opus"}' > "$S"
  cp "$S" "$BATS_TEST_TMPDIR/before"
  fake_jq ':'
  run env PATH="$BATS_TEST_TMPDIR/fakebin:$PATH" bash "$SCRIPT"
  [ "$status" -ne 0 ]
  cmp "$S" "$BATS_TEST_TMPDIR/before"
  [ "$(tmps)" = 0 ]
}

@test "a signal during the rewrite leaves settings.json and no temp file" {
  mk_skill o pdf
  echo '{"model":"opus"}' > "$S"
  cp "$S" "$BATS_TEST_TMPDIR/before"
  fake_jq 'kill -TERM $PPID'
  run env PATH="$BATS_TEST_TMPDIR/fakebin:$PATH" bash "$SCRIPT"
  [ "$status" -eq 143 ]
  cmp "$S" "$BATS_TEST_TMPDIR/before"
  [ "$(tmps)" = 0 ]
}

@test "a backup from the same second is not overwritten" {
  mk_skill o pdf
  echo '{}' > "$S"
  mkdir -p "$BATS_TEST_TMPDIR/fakebin"
  printf '#!/bin/bash\necho 20200101000000\n' > "$BATS_TEST_TMPDIR/fakebin/date"
  chmod +x "$BATS_TEST_TMPDIR/fakebin/date"
  run env PATH="$BATS_TEST_TMPDIR/fakebin:$PATH" bash "$SCRIPT"
  [ "$status" -eq 0 ]
  mk_skill o docs
  cp "$S" "$BATS_TEST_TMPDIR/after1"
  run env PATH="$BATS_TEST_TMPDIR/fakebin:$PATH" bash "$SCRIPT"
  [ "$status" -ne 0 ]
  cmp "$S" "$BATS_TEST_TMPDIR/after1"
  [ "$(cat "$S.bak-20200101000000")" = '{}' ]
}

@test "keys with spaces or glob characters are printed one per line as they are" {
  mk_skill o 'my skill'; mk_skill o 'a*'
  : > "$BATS_TEST_TMPDIR/a-file"
  echo '{}' > "$S"
  cd "$BATS_TEST_TMPDIR"
  run bash "$SCRIPT" --dry-run
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c -F -x '  anthropic-skills:my skill')" = 1 ]
  [ "$(printf '%s\n' "$output" | grep -c -F -x '  anthropic-skills:a*')" = 1 ]
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c -F -x '  anthropic-skills:my skill')" = 1 ]
  run bash "$SCRIPT"
  [ "$(printf '%s\n' "$output" | grep -c -F -x '  anthropic-skills:a*')" = 1 ]
}

@test "command is registered in plugin.json and the file exists" {
  jq -e '.commands | index("./commands/synced-skills-slim.md")' "$PLUGIN_DIR/.claude-plugin/plugin.json" >/dev/null
  [ -f "$CMD" ]
}

@test "command asks for confirmation between dry-run and apply, and declining writes nothing" {
  head -8 "$CMD" | grep -q '^allowed-tools:.*AskUserQuestion'
  d=$(grep -n 'name-only.sh" --dry-run$' "$CMD" | head -1 | cut -d: -f1)
  q=$(grep -n '^### 3\..*AskUserQuestion' "$CMD" | head -1 | cut -d: -f1)
  a=$(grep -n 'name-only.sh"$' "$CMD" | head -1 | cut -d: -f1)
  [ -n "$d" ] && [ -n "$q" ] && [ -n "$a" ]
  [ "$d" -lt "$q" ] && [ "$q" -lt "$a" ]
  grep -q '断られたらスクリプトを `--dry-run` なしで呼ばずに終了' "$CMD"
}

@test "command documents undo, name-only caveat and the measured version" {
  grep -q 'settings.json.bak-' "$CMD"
  grep -q 'del(.skillOverrides' "$CMD"
  grep -q '自動' "$CMD"
  grep -q '2.1.314' "$CMD"
}

@test "command undo follows CLAUDE_CONFIG_DIR, the printed backup path and symlinks" {
  sed -n '/^## 元に戻す/,/^## 注意/p' "$CMD" > "$BATS_TEST_TMPDIR/undo"
  grep -q 'CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"' "$BATS_TEST_TMPDIR/undo"
  grep -q '`バックアップ:`' "$BATS_TEST_TMPDIR/undo"
  grep -q 'symlink なら' "$BATS_TEST_TMPDIR/undo"
  ! grep -q '~/.claude/settings.json' "$BATS_TEST_TMPDIR/undo" || return 1
}

@test "command stops after step 2 when --dry-run is given" {
  sed -n '/^### 2\./,/^### 3\./p' "$CMD" | grep -q '引数に `--dry-run` があれば.*終了する'
}

@test "no hook calls the script" {
  ! grep -rq 'synced-skills-name-only' "$PLUGIN_DIR/hooks" || return 1
}
