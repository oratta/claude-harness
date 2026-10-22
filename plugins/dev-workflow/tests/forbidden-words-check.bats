#!/usr/bin/env bats
#
# 共有の禁止語検査スクリプト scripts/forbidden-words-check.sh のテスト（issue #1207）。
# spec: dev-workflow-forbidden-words-check
#
# fixture の語はテスト内で作る架空の語（zorbix / quuxly）で、実在の固有名は書かない。
# gh は PATH 先頭のスタブで差し替える（OPEN / CLOSED / 失敗）。
# テスト名は ASCII のみ。否定検査と単独の [[ ]] は書かず、has / lacks の関数で検査する
# （openspec/specs/bats-assertion-guard/spec.md）。

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/forbidden-words-check.sh"
  D="${BATS_TEST_TMPDIR}/fx"
  mkdir -p "$D" "${BATS_TEST_TMPDIR}/stub-open" "${BATS_TEST_TMPDIR}/stub-closed" "${BATS_TEST_TMPDIR}/stub-fail"
  GHLOG="${BATS_TEST_TMPDIR}/gh-calls.log"
  : > "$GHLOG"
  mkstub open 'echo OPEN'
  mkstub closed 'echo CLOSED'
  mkstub fail 'echo "gh: not authenticated" >&2; exit 1'
  STUB="${BATS_TEST_TMPDIR}/stub-open"
  COUNT="${BATS_TEST_TMPDIR}/count"
  printf 'zorbix\nquuxly\n' > "$D/dict.txt"
  : > "$D/allow.txt"
  unset FORBIDDEN_WORDS_NO_GH CLAUDE_PLUGIN_ROOT
}

mkstub() {
  cat > "${BATS_TEST_TMPDIR}/stub-$1/gh" <<EOF
#!/bin/sh
echo "\$*" >> "$GHLOG"
$2
EOF
  chmod +x "${BATS_TEST_TMPDIR}/stub-$1/gh"
}

# put <相対パス> <中身>
put() { mkdir -p "$D/$(dirname "$1")"; printf '%s\n' "$2" > "$D/$1"; }
allow() { printf '%s\n' "$@" > "$D/allow.txt"; }

# check <ファイル一覧(改行区切り)> [追加の引数...] — 標準入力に一覧を渡す
check() {
  local list="$1"; shift
  run --separate-stderr env PATH="$STUB:$PATH" bash -c \
    'printf "%s\n" "$1" | bash "$2" --root "$3" --dict dict.txt --allow allow.txt --count-file "$4" "${@:5}"' \
    _ "$list" "$SCRIPT" "$D" "$COUNT" "$@"
}

has() {
  case "$1" in *"$2"*) return 0 ;; esac
  echo "missing: $2 in: $1" >&2
  return 1
}

lacks() {
  case "$1" in *"$2"*) echo "unexpected: $2 in: $1" >&2; return 1 ;; esac
  return 0
}

# line_no <文字列> <部分文字列> — 文字列の中で部分文字列を含む最初の行の番号（無ければ 0）
line_no() {
  local n=0 l
  while IFS= read -r l; do
    n=$((n+1))
    case "$l" in *"$2"*) echo "$n"; return 0 ;; esac
  done <<EOF
$1
EOF
  echo 0
}

@test "script is executable with bash shebang" {
  [ -x "$SCRIPT" ] || return 1
  [ "$(head -n 1 "$SCRIPT")" = "#!/bin/bash" ] || return 1
}

@test "works from a copy outside the plugin without CLAUDE_PLUGIN_ROOT" {
  cp "$SCRIPT" "${BATS_TEST_TMPDIR}/copy.sh"
  put a.txt 'plain'
  run --separate-stderr env -u CLAUDE_PLUGIN_ROOT bash -c \
    'printf "a.txt\n" | bash "$1" --root "$2" --dict dict.txt' _ "${BATS_TEST_TMPDIR}/copy.sh" "$D"
  [ "$status" -eq 0 ] || return 1
}

@test "clean input exits 0 with empty output and count 0" {
  put a.txt 'nothing here'
  check "a.txt"
  [ "$status" -eq 0 ] || return 1
  [ -z "$output" ] || return 1
  [ -z "$stderr" ] || return 1
  [ "$(cat "$COUNT")" = "0" ] || return 1
}

@test "violation exits 1 with line on stderr and count" {
  put a.txt "$(printf 'l1\nl2\nuse zorbix here')"
  check "a.txt"
  [ "$status" -eq 1 ] || return 1
  [ -z "$output" ] || return 1
  [ "$stderr" = "a.txt:3:zorbix" ] || { echo "stderr=$stderr" >&2; return 1; }
  [ "$(cat "$COUNT")" = "1" ] || return 1
}

@test "missing --root exits 2 with usage" {
  run --separate-stderr bash -c 'printf "a\n" | bash "$1" --dict x' _ "$SCRIPT"
  [ "$status" -eq 2 ] || return 1
  has "$stderr" "usage" || return 1
}

@test "unknown argument exits 2" {
  run --separate-stderr bash -c 'printf "a\n" | bash "$1" --root /tmp --dict x --bogus' _ "$SCRIPT"
  [ "$status" -eq 2 ] || return 1
}

@test "missing --dict exits 2" {
  run --separate-stderr bash -c 'printf "a\n" | bash "$1" --root /tmp' _ "$SCRIPT"
  [ "$status" -eq 2 ] || return 1
}

@test "unreachable --root exits 2" {
  run --separate-stderr bash -c 'printf "a\n" | bash "$1" --root /nonexistent-dir-xyz --dict x' _ "$SCRIPT"
  [ "$status" -eq 2 ] || return 1
}

@test "case is ignored and display uses dictionary spelling" {
  printf 'Quuxly\n' > "$D/dict.txt"
  put a.txt "$(printf '1\nQUUXLY and quuxly')"
  check "a.txt"
  [ "$status" -eq 1 ] || return 1
  [ "$stderr" = "a.txt:2:Quuxly" ] || { echo "stderr=$stderr" >&2; return 1; }
}

@test "path name hit is reported as path" {
  put sub/zorbix-notes.md 'clean'
  check "sub/zorbix-notes.md"
  [ "$status" -eq 1 ] || return 1
  [ "$stderr" = "sub/zorbix-notes.md:path:zorbix" ] || { echo "stderr=$stderr" >&2; return 1; }
}

@test "comments and blank lines in dictionary are not words" {
  printf '# zorbix\n\n# only comment\n' > "$D/dict.txt"
  put a.txt 'zorbix'
  check "a.txt"
  [ "$status" -eq 0 ] || return 1
  [ "$(cat "$COUNT")" = "0" ] || return 1
}

@test "binary content is not scanned" {
  printf 'zorbix\000\001\002bin\n' > "$D/bin.dat"
  check "bin.dat"
  [ "$status" -eq 0 ] || return 1
}

@test "missing dictionary is a violation" {
  put a.txt 'x'
  run --separate-stderr env PATH="$STUB:$PATH" bash -c \
    'printf "a.txt\n" | bash "$1" --root "$2" --dict nodict.txt --count-file "$3"' _ "$SCRIPT" "$D" "$COUNT"
  [ "$status" -eq 1 ] || return 1
  [ "$stderr" = "nodict.txt: 無い" ] || { echo "stderr=$stderr" >&2; return 1; }
  [ "$(cat "$COUNT")" = "1" ] || return 1
}

@test "unreadable dictionary is a violation" {
  put a.txt 'x'
  printf 'zorbix\n' > "$D/nr.txt"
  chmod 000 "$D/nr.txt"
  run --separate-stderr bash -c \
    'printf "a.txt\n" | bash "$1" --root "$2" --dict nr.txt' _ "$SCRIPT" "$D"
  chmod 644 "$D/nr.txt"
  if [ "$(id -u)" = "0" ]; then skip "root can read anything"; fi
  [ "$status" -eq 1 ] || return 1
  [ "$stderr" = "nr.txt: 読めない" ] || { echo "stderr=$stderr" >&2; return 1; }
}

@test "multiple dicts are combined" {
  printf 'onlysecond\n' > "$D/dict2.txt"
  put a.txt 'has onlysecond'
  check "a.txt" --dict dict2.txt
  [ "$status" -eq 1 ] || return 1
  [ "$stderr" = "a.txt:1:onlysecond" ] || { echo "stderr=$stderr" >&2; return 1; }
}

@test "same word in several dicts is counted once per occurrence in dict order" {
  printf 'foo\n' > "$D/dict.txt"
  printf 'Foo\n' > "$D/dict2.txt"
  put a.txt 'a foo here'
  check "a.txt" --dict dict2.txt
  [ "$status" -eq 1 ] || return 1
  [ "$stderr" = "$(printf 'a.txt:1:foo\na.txt:1:Foo')" ] || { echo "stderr=$stderr" >&2; return 1; }
  [ "$(cat "$COUNT")" = "2" ] || return 1
}

@test "two words on one line give two violations and one word on two lines gives two" {
  put a.txt "$(printf 'zorbix quuxly\nzorbix')"
  check "a.txt"
  [ "$stderr" = "$(printf 'a.txt:1:zorbix\na.txt:2:zorbix\na.txt:1:quuxly')" ] || { echo "stderr=$stderr" >&2; return 1; }
}

@test "unreadable file is a violation" {
  put a.txt 'zorbix'
  chmod 000 "$D/a.txt"
  check "a.txt"
  chmod 644 "$D/a.txt"
  if [ "$(id -u)" = "0" ]; then skip "root can read anything"; fi
  [ "$status" -eq 1 ] || return 1
  [ "$stderr" = "a.txt: 読めない" ] || { echo "stderr=$stderr" >&2; return 1; }
}

@test "timed allow permits every hit in the file including path" {
  put zorbix.txt "$(printf 'x\nzorbix\ny\nzorbix')"
  allow 'zorbix.txt:Zorbix:#10'
  check "zorbix.txt"
  [ "$status" -eq 0 ] || { echo "stderr=$stderr" >&2; return 1; }
  has "$(cat "$GHLOG")" "issue view 10" || return 1
}

@test "permanent allow permits only lines containing the fixed string" {
  put a.txt "$(printf 'x\nref (zorbix#599) ok\ny\ny\ny\ny\nzorbix use')"
  allow '# 出典: テスト' 'a.txt:zorbix:=(zorbix#599)'
  check "a.txt"
  [ "$status" -eq 1 ] || return 1
  [ "$stderr" = "a.txt:7:zorbix" ] || { echo "stderr=$stderr" >&2; return 1; }
}

@test "permanent allow does not permit path hits" {
  put zorbix-notes.md 'clean'
  allow 'zorbix-notes.md:zorbix:=x'
  check "zorbix-notes.md"
  [ "$status" -eq 1 ] || return 1
  has "$stderr" "zorbix-notes.md:path:zorbix" || return 1
}

@test "permanent allow is never looked up on gh" {
  put a.txt 'see zorbix:x'
  allow 'a.txt:zorbix:=zorbix:x'
  run --separate-stderr env PATH="${BATS_TEST_TMPDIR}/stub-closed:$PATH" bash -c \
    'printf "a.txt\n" | bash "$1" --root "$2" --dict dict.txt --allow allow.txt' _ "$SCRIPT" "$D"
  [ "$status" -eq 0 ] || { echo "stderr=$stderr" >&2; return 1; }
  [ ! -s "$GHLOG" ] || return 1
}

@test "unused permanent allow is a violation" {
  put a.txt 'zorbix'
  allow 'a.txt:zorbix:=nomatch'
  check "a.txt"
  [ "$status" -eq 1 ] || return 1
  has "$stderr" "allow.txt:1: 何も打ち消していない（出荷集合に無い・語がもう無い）: a.txt:zorbix:=nomatch" || return 1
}

@test "unused timed allow is a violation" {
  put a.txt 'clean'
  allow 'a.txt:zorbix:#10'
  check "a.txt"
  [ "$status" -eq 1 ] || return 1
  has "$stderr" "allow.txt:1: 何も打ち消していない（出荷集合に無い・語がもう無い）: a.txt:zorbix:#10" || return 1
}

@test "allow format violations keep the original wording" {
  put a.txt 'clean'
  allow 'a:b:c' 'a:b' 'x:y:=' '# comment' ''
  check "a.txt"
  [ "$status" -eq 1 ] || return 1
  has "$stderr" "allow.txt:1: 書式が <path>:<語>:#<issue番号> でない: a:b:c" || return 1
  has "$stderr" "allow.txt:2: 書式が <path>:<語>:#<issue番号> でない: a:b" || return 1
  has "$stderr" "allow.txt:3: 書式が <path>:<語>:#<issue番号> でない: x:y:=" || return 1
  [ "$(cat "$COUNT")" = "3" ] || return 1
}

@test "missing allow file is fine" {
  put a.txt 'clean'
  run --separate-stderr bash -c \
    'printf "a.txt\n" | bash "$1" --root "$2" --dict dict.txt --allow nothere.txt' _ "$SCRIPT" "$D"
  [ "$status" -eq 0 ] || return 1
}

@test "allow word is case-insensitive and path must match exactly" {
  put a.txt 'ZORBIX'
  put b/a.txt 'ZORBIX'
  allow 'a.txt:zorbix:#10'
  check "$(printf 'a.txt\nb/a.txt')"
  [ "$stderr" = "b/a.txt:1:zorbix" ] || { echo "stderr=$stderr" >&2; return 1; }
}

@test "closed issue is a violation for each line citing it and looked up once" {
  put a.txt 'zorbix quuxly'
  allow 'a.txt:zorbix:#10' 'a.txt:quuxly:#10'
  run --separate-stderr env PATH="${BATS_TEST_TMPDIR}/stub-closed:$PATH" bash -c \
    'printf "a.txt\n" | bash "$1" --root "$2" --dict dict.txt --allow allow.txt --count-file "$3"' _ "$SCRIPT" "$D" "$COUNT"
  [ "$status" -eq 1 ] || return 1
  has "$stderr" "allow.txt:1: issue #10 が OPEN でない（CLOSED）: a.txt:zorbix:#10" || return 1
  has "$stderr" "allow.txt:2: issue #10 が OPEN でない（CLOSED）: a.txt:quuxly:#10" || return 1
  [ "$(grep -c . "$GHLOG")" = "1" ] || return 1
  [ "$(cat "$COUNT")" = "2" ] || return 1
}

@test "gh failure prints notice with --name and is not a violation" {
  put a.txt 'zorbix'
  allow 'a.txt:zorbix:#10'
  run --separate-stderr env PATH="${BATS_TEST_TMPDIR}/stub-fail:$PATH" bash -c \
    'printf "a.txt\n" | bash "$1" --root "$2" --dict dict.txt --allow allow.txt --name ship-check --count-file "$3"' _ "$SCRIPT" "$D" "$COUNT"
  [ "$status" -eq 0 ] || { echo "stderr=$stderr" >&2; return 1; }
  [ "$stderr" = "ship-check: gh で issue #10 の状態を引けないため、allow は書式だけ検査する" ] || { echo "stderr=$stderr" >&2; return 1; }
  [ "$(cat "$COUNT")" = "0" ] || return 1
}

@test "default name is forbidden-words-check" {
  put a.txt 'zorbix'
  allow 'a.txt:zorbix:#10'
  run --separate-stderr env PATH="${BATS_TEST_TMPDIR}/stub-fail:$PATH" bash -c \
    'printf "a.txt\n" | bash "$1" --root "$2" --dict dict.txt --allow allow.txt' _ "$SCRIPT" "$D"
  has "$stderr" "forbidden-words-check: gh で issue #10" || return 1
}

@test "FORBIDDEN_WORDS_NO_GH skips gh" {
  put a.txt 'zorbix'
  allow 'a.txt:zorbix:#10'
  run --separate-stderr env FORBIDDEN_WORDS_NO_GH=1 PATH="${BATS_TEST_TMPDIR}/stub-closed:$PATH" bash -c \
    'printf "a.txt\n" | bash "$1" --root "$2" --dict dict.txt --allow allow.txt' _ "$SCRIPT" "$D"
  [ "$status" -eq 0 ] || return 1
  [ ! -s "$GHLOG" ] || return 1
}

@test "gh is run with the root as cwd" {
  put a.txt 'zorbix'
  allow 'a.txt:zorbix:#10'
  cat > "${BATS_TEST_TMPDIR}/stub-open/gh" <<EOF
#!/bin/sh
pwd -P >> "$GHLOG"
echo OPEN
EOF
  run --separate-stderr env PATH="$STUB:$PATH" bash -c \
    'cd / && printf "a.txt\n" | bash "$1" --root "$2" --dict dict.txt --allow allow.txt' _ "$SCRIPT" "$D"
  [ "$status" -eq 0 ] || return 1
  [ "$(cat "$GHLOG")" = "$(cd "$D" && pwd -P)" ] || return 1
}

@test "violations come in the fixed order" {
  put a.txt 'zorbix'
  allow 'bad-line' 'gone.txt:zorbix:#10'
  run --separate-stderr env PATH="${BATS_TEST_TMPDIR}/stub-closed:$PATH" bash -c \
    'printf "a.txt\n" | bash "$1" --root "$2" --dict nodict.txt --dict dict.txt --allow allow.txt' _ "$SCRIPT" "$D"
  [ "$stderr" = "$(printf 'nodict.txt: 無い\nallow.txt:1: 書式が <path>:<語>:#<issue番号> でない: bad-line\na.txt:1:zorbix\nallow.txt:2: 何も打ち消していない（出荷集合に無い・語がもう無い）: gone.txt:zorbix:#10\nallow.txt:2: issue #10 が OPEN でない（CLOSED）: gone.txt:zorbix:#10')" ] || { echo "stderr=$stderr" >&2; return 1; }
}

@test "within a file path hit then content hits per word in dictionary order" {
  put zorbix.txt "$(printf 'quuxly\nzorbix')"
  check "zorbix.txt"
  [ "$stderr" = "$(printf 'zorbix.txt:path:zorbix\nzorbix.txt:2:zorbix\nzorbix.txt:1:quuxly')" ] || { echo "stderr=$stderr" >&2; return 1; }
}

@test "files follow list order and blank lines in list are ignored" {
  put b.txt 'zorbix'
  put a.txt 'zorbix'
  check "$(printf 'b.txt\n\na.txt')"
  [ "$stderr" = "$(printf 'b.txt:1:zorbix\na.txt:1:zorbix')" ] || { echo "stderr=$stderr" >&2; return 1; }
}

@test "files not in the list are not checked" {
  put a.txt 'zorbix'
  put b.txt 'clean'
  check "b.txt"
  [ "$status" -eq 0 ] || return 1
}

@test "unlisted words pass" {
  put a.txt 'someothername'
  check "a.txt"
  [ "$status" -eq 0 ] || return 1
}

@test "count equals number of stderr lines" {
  put a.txt "$(printf 'zorbix\nquuxly\nzorbix')"
  allow 'a.txt:other:#3'
  check "a.txt"
  n="$(printf '%s\n' "$stderr" | grep -c .)"
  [ "$(cat "$COUNT")" = "$n" ] || { echo "count=$(cat "$COUNT") lines=$n" >&2; return 1; }
}
