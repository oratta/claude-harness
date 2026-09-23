#!/usr/bin/env bats
#
# plugins/*/tests/test_*.py の Python テストを全件走らせるスイート（issue #344）。
#
# scripts/test.sh は git 追跡下の *.bats しか発見しないので、Python のテストはこのスイートが
# 引き受ける。以前はプラグインごとの bats ラッパーが `-p 'test_codex_*.py'` のように
# ファイル名を絞って走らせており、新しく足したファイルや絞り込みから外れたファイルが
# 黙って検証から漏れた（#334 / PR #343）。ここではファイル名を絞らず、git 追跡下の
# test_*.py の置き場所ごとに unittest discover を回す。
#
#   scripts/test.sh python-suites          Python のテストだけを走らせる
#   PYTHON_SUITES_PYTHON=<cmd>              呼ぶ Python のコマンド名（既定 python3）

# <root> の git 追跡下の plugins/*/tests/test_*.py を、置き場所のディレクトリごとに
# unittest discover で走らせる。ディレクトリごとに「<dir>: Ran N tests (exit M)」を出し、
# 失敗したディレクトリは unittest の出力全体を出す。1 つでも失敗すれば非 0 を返す。
# Python が無い・対象が無い・0 件で終わったディレクトリも失敗にする（走ったつもりで何も走っていない状態を通さない）。
run_python_suites() { # <root>
  local root=$1 py=${PYTHON_SUITES_PYTHON:-python3} files dirs d out st ran rc=0
  if ! command -v "$py" >/dev/null 2>&1; then
    echo "Python のコマンド '$py' が見つかりません（PYTHON_SUITES_PYTHON で変更可）。次のコマンドで導入してください:"
    echo "  macOS:  brew install python"
    echo "  Ubuntu: sudo apt-get install -y python3"
    return 1
  fi
  files=$(git -C "$root" ls-files -- 'plugins/*/tests/test_*.py')
  if [ -z "$files" ]; then
    echo "git 追跡下に plugins/*/tests/test_*.py が 1 件もありません（パスが変わっていないか確認してください）"
    return 1
  fi
  dirs=$(printf '%s\n' "$files" | sed 's|/[^/]*$||' | sort -u)
  for d in $dirs; do
    out=$(cd "$root" && PYTHONDONTWRITEBYTECODE=1 "$py" -m unittest discover -s "$d" -p 'test_*.py' 2>&1)
    st=$?
    ran=$(printf '%s\n' "$out" | grep -E '^Ran [0-9]+ tests?' | tail -1)
    case "$ran" in
      ""|"Ran 0 "*)
        echo "$d: 0 件（テストが 1 件も走っていない。exit $st）"
        printf '%s\n' "$out"
        rc=1
        continue ;;
    esac
    echo "$d: $ran (exit $st)"
    if [ "$st" -ne 0 ]; then
      printf '%s\n' "$out"
      rc=1
    fi
  done
  return "$rc"
}

setup() {
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}

@test "python-suites: runs every git-tracked plugins/*/tests/test_*.py without a file-name filter" {
  run run_python_suites "$ROOT"
  # 成否に関係なく、ディレクトリごとの件数を TAP のコメントに出す（bats の件数には 1 件としか出ないため）
  printf '%s\n' "$output" | grep -E '^[^ ]+: (Ran |0 件)' | sed 's/^/# /' >&3
  if [ "$status" -ne 0 ]; then
    printf '%s\n' "$output"
    return 1
  fi
}

# ── 判定そのものの検査（使い捨ての git リポで run_python_suites を回す） ──

# 使い捨てリポに Python のテストファイルを置いて git add する。 <相対パス> <中身>
put_py() {
  mkdir -p "$FIX/$(dirname "$1")"
  printf '%s\n' "$2" >"$FIX/$1"
  git -C "$FIX" add "$1"
}

new_fixture() {
  FIX="${BATS_TEST_TMPDIR}/repo"
  mkdir -p "$FIX"
  git -C "$FIX" init -q
}

PASSING='import unittest
class T(unittest.TestCase):
    def test_ok(self):
        self.assertTrue(True)'

@test "python-suites: a new file not named test_codex_* is picked up without a wrapper" {
  new_fixture
  put_py plugins/alpha/tests/test_codex_one.py "$PASSING"
  put_py plugins/newplug/tests/test_widget.py "$PASSING"
  run run_python_suites "$FIX"
  [ "$status" -eq 0 ]
  [[ "$output" == *"plugins/alpha/tests: Ran 1 test"* ]]
  [[ "$output" == *"plugins/newplug/tests: Ran 1 test"* ]]
}

@test "python-suites: untracked files are not picked up" {
  new_fixture
  put_py plugins/alpha/tests/test_a.py "$PASSING"
  printf '%s\n' "$PASSING" >"$FIX/plugins/alpha/tests/test_b.py"
  mkdir -p "$FIX/plugins/untracked/tests"
  printf '%s\n' "$PASSING" >"$FIX/plugins/untracked/tests/test_c.py"
  run run_python_suites "$FIX"
  [ "$status" -eq 0 ]
  [[ "$output" != *"plugins/untracked/tests"* ]]
}

@test "python-suites: one failing test fails the suite and shows the unittest FAIL line" {
  new_fixture
  put_py plugins/alpha/tests/test_a.py "$PASSING"
  put_py plugins/beta/tests/test_b.py 'import unittest
class T(unittest.TestCase):
    def test_broken(self):
        self.assertEqual(1, 2)'
  run run_python_suites "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL: test_broken"* ]]
  [[ "$output" == *"AssertionError: 1 != 2"* ]]
}

@test "python-suites: a directory that runs 0 tests fails" {
  new_fixture
  put_py plugins/alpha/tests/test_a.py "$PASSING"
  put_py plugins/empty/tests/test_nothing.py 'X = 1'
  run run_python_suites "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"plugins/empty/tests: 0 件"* ]]
}

@test "python-suites: no target files at all fails" {
  new_fixture
  run run_python_suites "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"plugins/*/tests/test_*.py"* ]]
}

@test "python-suites: a missing Python command fails with the looked-up name and an install hint" {
  new_fixture
  put_py plugins/alpha/tests/test_a.py "$PASSING"
  PYTHON_SUITES_PYTHON=python3-not-installed run run_python_suites "$FIX"
  [ "$status" -ne 0 ]
  [[ "$output" == *"python3-not-installed"* ]]
  [[ "$output" == *"brew install python"* ]]
}

# ── ファイル名を絞った実行方法を残さない ──

@test "python-suites: no other .bats calls unittest discover (no double runs, no filtered wrappers)" {
  # xargs は grep を複数回に分けて呼ぶことがあり、ヒットの無い回があると非 0 を返すので、一覧だけを見る
  run sh -c "cd '$ROOT' && git ls-files '*.bats' | xargs grep -ln 'unittest discover'"
  [ "$output" = "tests/python-suites.bats" ]
}

@test "python-suites: docs and test docstrings carry no file-name-filtered command" {
  cd "$ROOT"
  run grep -rn 'test_codex_worker.py\|test_codex_\*.py\|-p test_codex.py' --include='*.md' plugins scripts docs README.md
  [ "$status" -eq 1 ]
  run sh -c 'grep -n -- "-p test_codex" plugins/*/tests/test_*.py'
  [ "$status" -eq 1 ]
}
