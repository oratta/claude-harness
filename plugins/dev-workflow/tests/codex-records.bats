#!/usr/bin/env bats
#
# codex-records.sh: 記録先の `Codex 消費:` コメントを集めて pr-token-budget.sh の
# --codex-records に渡すファイルを作る。全番号の取得と抽出に成功したときだけファイルを作り、
# 1 つでも失敗したら exit 1 でファイルを残さない（取得失敗を空記録の成功に化けさせない）。
#
# spec: openspec/changes/codex-records-fetch-failure（dev-workflow-pr-token-budget）

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/codex-records.sh"
  BUDGET="${PLUGIN_DIR}/scripts/pr-token-budget.sh"
  WORK="$(cd "$(mktemp -d)" && pwd -P)"
  STUB="${WORK}/stub"
  OUT="${WORK}/codex-records.txt"
  mkdir -p "${WORK}/bin" "$STUB"
  # gh のスタブ: issues/<番号>/comments の <番号> ごとに $STUB/<番号>.json を出す。
  # $STUB/<番号>.fail があれば（$STUB/<番号>.partial があればそれを出してから）exit 1
  cat > "${WORK}/bin/gh" <<'SH'
#!/usr/bin/env bash
n=""
for a in "$@"; do
  case "$a" in */issues/*/comments) n="${a%/comments}"; n="${n##*/}" ;; esac
done
echo "$*" >> "${GH_STUB_DIR}/calls"
if [ -e "${GH_STUB_DIR}/${n}.fail" ]; then
  [ -e "${GH_STUB_DIR}/${n}.partial" ] && cat "${GH_STUB_DIR}/${n}.partial"
  echo "gh: HTTP 401: Bad credentials" >&2
  exit 1
fi
cat "${GH_STUB_DIR}/${n}.json"
SH
  chmod +x "${WORK}/bin/gh"
  export GH_STUB_DIR="$STUB"
  export PATH="${WORK}/bin:${PATH}"

  # 419: 2 ページ（Codex 消費 1 件・無関係 2 件）、450: 1 ページ（Codex 消費 1 件）
  printf '%s' '[[{"body":"Codex 消費: t1 1000"},{"body":"develop 開始\nCodex 消費: tx 9"}],[{"body":"仕様化判断: する"}]]' > "${STUB}/419.json"
  printf '%s' '[[{"body":"Codex 消費: t2 -\n補足"}]]' > "${STUB}/450.json"
}

teardown() {
  rm -rf "$WORK"
}

@test "all numbers fetched: writes the records and exits 0" {
  run "$SCRIPT" --repo o/r --out "$OUT" 419 450
  [ "$status" -eq 0 ]
  [ "$(cat "$OUT")" = "$(printf 't1 1000\nt2 -')" ]
  grep -qF -- '--paginate' "${STUB}/calls"
  grep -qF -- '--slurp' "${STUB}/calls"
  grep -qF 'repos/o/r/issues/419/comments' "${STUB}/calls"
}

@test "no Codex comment: writes an empty file and exits 0" {
  printf '%s' '[[{"body":"hello"}]]' > "${STUB}/7.json"
  run "$SCRIPT" --repo o/r --out "$OUT" 7
  [ "$status" -eq 0 ]
  [ -f "$OUT" ]
  [ ! -s "$OUT" ]
}

@test "first number fails: exit 1 and no file" {
  touch "${STUB}/419.fail"
  run "$SCRIPT" --repo o/r --out "$OUT" 419 450
  [ "$status" -eq 1 ]
  [ ! -e "$OUT" ]
}

@test "a later page fails after the first page was printed: exit 1 and no file" {
  touch "${STUB}/419.fail"
  printf '%s' '[[{"body":"Codex 消費: t1 1000"}]' > "${STUB}/419.partial"
  run "$SCRIPT" --repo o/r --out "$OUT" 419
  [ "$status" -eq 1 ]
  [ ! -e "$OUT" ]
}

@test "the next number fails: exit 1 and no file with only the first records" {
  touch "${STUB}/450.fail"
  run "$SCRIPT" --repo o/r --out "$OUT" 419 450
  [ "$status" -eq 1 ]
  [ ! -e "$OUT" ]
}

@test "gh exits 0 with non-JSON output: exit 1 and no file" {
  printf '%s' '<html>502 Bad Gateway</html>' > "${STUB}/419.json"
  run "$SCRIPT" --repo o/r --out "$OUT" 419
  [ "$status" -eq 1 ]
  [ ! -e "$OUT" ]
}

@test "a failure removes the file left by the previous measurement" {
  printf 't0 5\n' > "$OUT"
  touch "${STUB}/419.fail"
  run "$SCRIPT" --repo o/r --out "$OUT" 419
  [ "$status" -eq 1 ]
  [ ! -e "$OUT" ]
}

@test "missing arguments: exit 1 and no file" {
  printf 't0 5\n' > "$OUT"
  run "$SCRIPT" --out "$OUT" 419
  [ "$status" -eq 1 ]
  [ ! -e "$OUT" ]
  printf 't0 5\n' > "$OUT"
  run "$SCRIPT" --repo o/r --out "$OUT"
  [ "$status" -eq 1 ]
  [ ! -e "$OUT" ]
  run "$SCRIPT" --repo o/r 419
  [ "$status" -eq 1 ]
  run "$SCRIPT" --repo o/r --out "$OUT" abc
  [ "$status" -eq 1 ]
  [ ! -e "$OUT" ]
}

@test "gh is not on PATH: exit 1 and no file" {
  mkdir -p "${WORK}/nogh"
  ln -s "$(command -v jq)" "${WORK}/nogh/jq"
  printf 't0 5\n' > "$OUT"
  PATH="${WORK}/nogh:/usr/bin:/bin" run "$SCRIPT" --repo o/r --out "$OUT" 419
  [ "$status" -eq 1 ]
  [ ! -e "$OUT" ]
}

@test "collect && budget: a fetch failure never yields a within-cap JSON" {
  REPO="${WORK}/repo"
  git init -q "$REPO"
  mkdir -p "${WORK}/projects"
  printf '%s' '[[{"body":"Codex 消費: t1 30000001"}]]' > "${STUB}/419.json"
  cd "$REPO"
  run bash -c '"$1" --repo o/r --out "$2" 419 && "$3" 419 --projects "$4" --cap 30000000 --codex-records "$2"' _ \
    "$SCRIPT" "$OUT" "$BUDGET" "${WORK}/projects"
  [ "$status" -eq 2 ]
  echo "$output" | grep -qF '"total_tokens": 30000001'

  touch "${STUB}/419.fail"
  run bash -c '"$1" --repo o/r --out "$2" 419 && "$3" 419 --projects "$4" --cap 30000000 --codex-records "$2"' _ \
    "$SCRIPT" "$OUT" "$BUDGET" "${WORK}/projects"
  [ "$status" -eq 1 ]
  echo "$output" | grep -qF 'total_tokens' && return 1
  [ ! -e "$OUT" ]
}
