#!/usr/bin/env bats
#
# statusline-copy-update:
#   ステータスラインのコピーを、手を入れていなければ SessionStart フックで本体に揃え、
#   手を入れていれば上書きせず「更新あり」を出す仕組み（issue #1113）。
#   仕様: openspec/specs/statusline-copy-update/spec.md
#
# 隔離: CLAUDE_CONFIG_DIR と HOME を一時ディレクトリに向ける。プラグインの本体は
# <config>/plugins/cache/x/statusline/1/ に複製し、「本体を別の内容にする」ときはこの複製を
# 書き換える（リポジトリのファイルは触らない）。

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  INSTALL="${PLUGIN_DIR}/scripts/install.sh"
  HOOK="${PLUGIN_DIR}/scripts/statusline-update-hook.sh"
  WORK="$(mktemp -d)"
  export HOME="$WORK/home" FLATMATE_RATE_SHARE_CONF="$WORK/no-share-conf"
  unset FLATMATE_RATE_SHARE_DIR CLAUDE_ACCOUNTS_FILE CLAUDE_SECURESTORAGE_CONFIG_DIR
  mkdir -p "$HOME"
  export CLAUDE_CONFIG_DIR="$WORK"
  export STATUSLINE_API_PACE=0 STATUSLINE_CODEX=0
  # インストール済みのプラグインの代わり（<config>/plugins/ の下）
  ROOT="$WORK/plugins/cache/x/statusline/1"
  mkdir -p "$ROOT"
  cp -R "$PLUGIN_DIR/scripts" "$ROOT/scripts"
  export CLAUDE_PLUGIN_ROOT="$ROOT"
  RECORD="$WORK/.statusline-installed"
  MARK="$WORK/.statusline-update-available"
}

teardown() {
  rm -rf "$WORK"
}

sha() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

# 記録のうち、ファイル名 $1 の行のハッシュ
recorded() {
  awk -v f="$1" '$2 == f {print $1}' "$RECORD"
}

# プラグインの本体（複製）を新しい版にする
bump_plugin() {
  printf '# new version\n' >> "$ROOT/scripts/statusline.sh"
  printf '# new version\n' >> "$ROOT/scripts/statusline-codex.py"
}

render() {
  printf '{"session_id":"copy-update-test","workspace":{"current_dir":"%s"},"model":{"display_name":"Opus 5"},"context_window":{"remaining_percentage":91}}' "$WORK" \
    | bash "$WORK/statusline.sh"
}

strip_ansi() {
  sed $'s/\033\\[[0-9;]*m//g'
}

# 本体の複製から導入する（記録はその内容になる）
install_from_root() {
  bash "$ROOT/scripts/install.sh" >/dev/null
}

# ---- install.sh の記録 ----

@test "install: writes the record with the hashes of both copies" {  # 導入すると記録ができる
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -f "$RECORD" ]
  [ "$(wc -l < "$RECORD" | tr -d ' ')" -eq 2 ]
  [ "$(recorded statusline.sh)" = "$(sha "$WORK/statusline.sh")" ]
  [ "$(recorded statusline-codex.py)" = "$(sha "$WORK/statusline-codex.py")" ]
  grep -Eq '^[0-9a-f]{64}  statusline\.sh$' "$RECORD"
  grep -Eq '^[0-9a-f]{64}  statusline-codex\.py$' "$RECORD"
}

@test "install: writes the record even when the copies are already up to date" {  # 内容が既に同じでも記録を書く
  cp "$PLUGIN_DIR/scripts/statusline.sh" "$WORK/statusline.sh"
  cp "$PLUGIN_DIR/scripts/statusline-codex.py" "$WORK/statusline-codex.py"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ -f "$RECORD" ]
  [ "$(recorded statusline.sh)" = "$(sha "$PLUGIN_DIR/scripts/statusline.sh")" ]
}

@test "install: --dry-run neither writes the record nor removes the mark" {  # dry-run は記録を書かず印も残す
  printf 'statusline.sh\n' > "$MARK"
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
  [ ! -e "$RECORD" ]
  [ -f "$MARK" ]
}

@test "install: --dry-run leaves an existing record unchanged" {  # dry-run は既存の記録を変えない
  printf 'deadbeef  statusline.sh\n' > "$RECORD"
  run bash "$INSTALL" --dry-run
  [ "$status" -eq 0 ]
  [ "$(cat "$RECORD")" = "deadbeef  statusline.sh" ]
}

@test "install: removes the update mark right after installing" {  # 打ち直した直後に印が消える
  printf 'statusline.sh\n' > "$MARK"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ ! -e "$MARK" ]
}

# ---- フック: 手を入れていないコピーを揃える ----

@test "hook: an untouched old copy becomes identical to the plugin" {  # 記録どおりの古いコピーは本体と同じになる
  install_from_root
  bump_plugin
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  cmp "$WORK/statusline.sh" "$ROOT/scripts/statusline.sh"
  [ "$(recorded statusline.sh)" = "$(sha "$ROOT/scripts/statusline.sh")" ]
  [ -x "$WORK/statusline.sh" ]
  [ ! -e "$MARK" ]
  [ -z "$output" ]
}

@test "hook: an untouched old Codex helper becomes identical to the plugin" {  # Codex helper も同じ扱いになる
  install_from_root
  bump_plugin
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  cmp "$WORK/statusline-codex.py" "$ROOT/scripts/statusline-codex.py"
  [ "$(recorded statusline-codex.py)" = "$(sha "$ROOT/scripts/statusline-codex.py")" ]
}

@test "hook: does nothing when nothing is installed" {  # 導入していなければ何も作らない
  before="$(ls -A "$WORK" | sort)"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ "$(ls -A "$WORK" | sort)" = "$before" ]
  [ -z "$output" ]
}

# ---- フック: 手を入れたコピーは上書きしない ----

@test "hook: a copy with an added line is kept and line 1 shows the update mark" {  # 1 行書き足したコピーは変わらず、1 行目に更新ありが出る
  install_from_root
  printf '# my tweak\n' >> "$WORK/statusline.sh"
  cp "$WORK/statusline.sh" "$WORK/expected.sh"
  bump_plugin
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  cmp "$WORK/statusline.sh" "$WORK/expected.sh"
  grep -qx 'statusline.sh' "$MARK"
  [ -z "$output" ]  # 印を読めるコピーなので案内は重ねない
  line1="$(render | head -1 | strip_ansi)"
  [[ "$line1" == *"更新あり /statusline:setup" ]] || return 1
}

@test "hook: a copy without the record file is not overwritten" {  # 記録ファイルが無いコピーは上書きしない
  install_from_root
  rm -f "$RECORD"
  bump_plugin
  cp "$WORK/statusline.sh" "$WORK/expected.sh"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  cmp "$WORK/statusline.sh" "$WORK/expected.sh"
  [ -f "$MARK" ]
}

@test "hook: a copy whose line is missing from the record is not overwritten" {  # 記録にそのファイルの行が無いコピーは上書きしない
  install_from_root
  grep -v ' statusline-codex.py$' "$RECORD" > "$RECORD.tmp" && mv "$RECORD.tmp" "$RECORD"
  bump_plugin
  cp "$WORK/statusline-codex.py" "$WORK/expected.py"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  cmp "$WORK/statusline-codex.py" "$WORK/expected.py"
  grep -qx 'statusline-codex.py' "$MARK"
  # statusline.sh は記録どおりなので揃う
  cmp "$WORK/statusline.sh" "$ROOT/scripts/statusline.sh"
}

@test "hook: removes the mark and fixes the record once the copy matches the plugin" {  # 本体と同じになったらフックが印を消す
  install_from_root
  printf '# my tweak\n' >> "$WORK/statusline.sh"
  bump_plugin
  bash "$HOOK" >/dev/null
  [ -f "$MARK" ]
  cp "$ROOT/scripts/statusline.sh" "$WORK/statusline.sh"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ ! -e "$MARK" ]
  [ "$(recorded statusline.sh)" = "$(sha "$ROOT/scripts/statusline.sh")" ]
}

# ---- 表示 ----

@test "render: without the mark the output has no update notice" {  # 印が無ければ出力は変わらない
  install_from_root
  run render
  [ "$status" -eq 0 ]
  [[ "$output" != *"更新あり"* ]] || return 1
}

@test "render: the mark only appends to line 1 and keeps the other lines" {  # 印は 1 行目の末尾に足すだけ
  install_from_root
  without="$(render | strip_ansi)"
  printf 'statusline.sh\n' > "$MARK"
  with="$(render | strip_ansi)"
  [ "$(printf '%s\n' "$with" | head -1)" = "$(printf '%s\n' "$without" | head -1)  更新あり /statusline:setup" ]
  [ "$(printf '%s\n' "$with" | tail -n +2)" = "$(printf '%s\n' "$without" | tail -n +2)" ]
}

# ---- フック: 古いコピーへの案内 ----

@test "hook: an old copy that cannot draw the mark gets a systemMessage" {  # 古いコピーには案内が出る
  printf '#!/usr/bin/env bash\necho old\n' > "$WORK/statusline.sh"
  run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 1 ]
  printf '%s' "$output" | jq -e '(keys == ["systemMessage"]) and (.systemMessage | contains("/statusline:setup"))' >/dev/null
  [ "$(cat "$WORK/statusline.sh")" = "$(printf '#!/usr/bin/env bash\necho old')" ]
}

# ---- フック: 動く場所と失敗 ----

@test "hook: does nothing when CLAUDE_PLUGIN_ROOT is outside <config>/plugins/" {  # plugin-dir で読み込んだ版では何もしない
  install_from_root
  bump_plugin
  mkdir -p "$WORK/dev"
  cp -R "$ROOT/scripts" "$WORK/dev/scripts"
  cp "$WORK/statusline.sh" "$WORK/expected.sh"
  cp "$RECORD" "$WORK/expected.record"
  CLAUDE_PLUGIN_ROOT="$WORK/dev" run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  cmp "$WORK/statusline.sh" "$WORK/expected.sh"
  cmp "$RECORD" "$WORK/expected.record"
  [ ! -e "$MARK" ]
}

@test "hook: a symlink into <config>/plugins/ from outside is resolved, not trusted by its name" {  # 実体のパスで判定する
  install_from_root
  bump_plugin
  mkdir -p "$WORK/dev"
  cp -R "$ROOT/scripts" "$WORK/dev/scripts"
  ln -s "$WORK/dev" "$WORK/plugins/devlink"
  cp "$WORK/statusline.sh" "$WORK/expected.sh"
  CLAUDE_PLUGIN_ROOT="$WORK/plugins/devlink" run bash "$HOOK"
  [ "$status" -eq 0 ]
  cmp "$WORK/statusline.sh" "$WORK/expected.sh"
}

@test "hook: empty CLAUDE_PLUGIN_ROOT exits 0 and changes nothing" {  # CLAUDE_PLUGIN_ROOT が空でも止まらない
  install_from_root
  bump_plugin
  cp "$WORK/statusline.sh" "$WORK/expected.sh"
  CLAUDE_PLUGIN_ROOT="" run bash "$HOOK"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  cmp "$WORK/statusline.sh" "$WORK/expected.sh"
  [ ! -e "$MARK" ]
}

@test "hook: an unwritable config dir still exits 0 with no stderr" {  # 失敗しても exit 0 で標準エラーを出さない
  [ "$(id -u)" -ne 0 ] || skip "root ignores permissions"
  install_from_root
  bump_plugin
  chmod 555 "$WORK"
  run --separate-stderr bash "$HOOK"
  chmod 755 "$WORK"
  [ "$status" -eq 0 ]
  [ -z "$stderr" ]
}

@test "hooks.json registers the SessionStart hook" {  # SessionStart に登録されている
  hj="$PLUGIN_DIR/hooks/hooks.json"
  [ -f "$hj" ]
  jq -e '.hooks.SessionStart[] | select(.matcher == "startup|resume|clear") | .hooks[] | select(.command == "\"${CLAUDE_PLUGIN_ROOT}/scripts/statusline-update-hook.sh\"")' "$hj" >/dev/null
}
