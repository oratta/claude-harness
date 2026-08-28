#!/usr/bin/env bats
#
# Tests for change-1 (infra-fixes).
# specs: infra-env-file-scheme / infra-secrets-consistency / infra-actions-freshness / infra-doc-integrity
# plan.md 付録 A findings 1-9, 受け入れ条件 5-6, 15.
#
# These tests grep/parse the Markdown agent instructions and workflow templates
# directly (there is no runtime for this plugin outside an actual Claude Code
# session), matching the "参照ゼロ検証" style already used by plan.md 受け入れ条件.

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
  P5="${PLUGIN_DIR}/agents/infra-phase-5-finalize.md"
  P4="${PLUGIN_DIR}/agents/infra-phase-4-github-actions.md"
  P3="${PLUGIN_DIR}/agents/infra-phase-3-vercel.md"
  P2="${PLUGIN_DIR}/agents/infra-phase-2-supabase.md"
  P1="${PLUGIN_DIR}/agents/infra-phase-1-hearing.md"
  SKILL="${PLUGIN_DIR}/skills/infra-setup/SKILL.md"
  README="${PLUGIN_DIR}/README.md"
  PLUGIN_JSON="${PLUGIN_DIR}/.claude-plugin/plugin.json"
  WORKFLOWS_DIR="${PLUGIN_DIR}/templates/workflows"
  TEMPLATES_DIR="${PLUGIN_DIR}/templates"
}

# --- infra-env-file-scheme (S1-S5) ---

@test "S1/S5: no comment-based prod value expectation remains in Phase 5" {
  run grep -n "コメントアウト" "$P5"
  [ "$status" -ne 0 ]
}

@test "S2: Step 2 explicitly checks .env.production.local" {
  grep -q '\.env\.production\.local' "$P5"
}

@test "S3: goal description no longer says prod side is commented out" {
  ! grep -q 'prod 側はコメントアウト状態' "$P5"
  grep -q '\.env\.production\.local' "$P5"
}

@test "S4: cautions section reflects two-file scheme" {
  ! grep -q 'prod系がコメントアウトで保存されている前提' "$P5"
  grep -q '\.env\.production\.local.*に prod 値が分離保存されている前提' "$P5"
}

# --- infra-secrets-consistency (S6-S12) ---

@test "S6: every active templates secrets.* (except GITHUB_TOKEN) has a gh secret set line in Phase 4" {
  # Exclude commented-out lines (design.md D2: SUPABASE_SERVICE_ROLE_KEY only appears
  # in ci.yml.template's commented-out E2E block, which is inactive and out of scope).
  names="$(grep -rhoE '^[^#]*secrets\.[A-Z_]*' "$TEMPLATES_DIR" | grep -o 'secrets\.[A-Z_]*' | sort -u | sed 's/^secrets\.//')"
  for name in $names; do
    [ "$name" = "GITHUB_TOKEN" ] && continue
    if ! grep -q "gh secret set ${name}" "$P4"; then
      echo "missing gh secret set for: $name" >&2
      return 1
    fi
  done
}

@test "S7: EDGE_CONFIG_ID documented as optional with example command" {
  grep -q 'EDGE_CONFIG_ID' "$P4"
  grep -q 'メンテナンスモードを使う場合のみ必要' "$P4"
  grep -q 'gh secret set EDGE_CONFIG_ID' "$P4"
}

@test "S8: Phase 2 extracts service_role key alongside anon" {
  grep -q 'anon' "$P2"
  grep -q 'service_role' "$P2"
}

@test "S9: service_role key written only to .env.production.local, not .env.local" {
  # Extract the Step 11 (.env.local) and Step 11.5 (.env.production.local) blocks
  step11="$(awk '/### Step 11: /{flag=1} /### Step 11\.5:/{flag=0} flag' "$P2")"
  step115="$(awk '/### Step 11\.5:/{flag=1} /### Step 12:/{flag=0} flag' "$P2")"
  echo "$step115" | grep -qi 'service_role'
  ! echo "$step11" | grep -qi 'service_role'
}

@test "S10: state file write step does not record the raw service_role key value" {
  step13="$(awk '/### Step 13: /{flag=1} /### Step 14:/{flag=0} flag' "$P2")"
  ! echo "$step13" | grep -qiE 'service_role_key: \{|service_role: \{[A-Za-z_]*_KEY\}'
}

@test "S11: Phase 4 reads PROD_SUPABASE_URL/ANON_KEY/SERVICE_ROLE_KEY from .env.production.local" {
  step6="$(awk '/### Step 6: /{flag=1} /### Step 7:/{flag=0} flag' "$P4")"
  echo "$step6" | grep -q 'PROD_SUPABASE_URL'
  echo "$step6" | grep -q 'PROD_SUPABASE_ANON_KEY'
  echo "$step6" | grep -q 'PROD_SUPABASE_SERVICE_ROLE_KEY'
  echo "$step6" | grep -q '\.env\.production\.local'
}

@test "S12: Phase 4 reads NEXT_PUBLIC_SUPABASE_URL/ANON_KEY from .env.local" {
  step6="$(awk '/### Step 6: /{flag=1} /### Step 7:/{flag=0} flag' "$P4")"
  echo "$step6" | grep -q 'NEXT_PUBLIC_SUPABASE_URL'
  echo "$step6" | grep -q 'NEXT_PUBLIC_SUPABASE_ANON_KEY'
  echo "$step6" | grep -qE '\.env\.local[^.]'
}

# --- infra-actions-freshness (S13-S20) ---

@test "S13: no stale v4 pins for checkout/setup-node" {
  run grep -rn "actions/checkout@v4\|actions/setup-node@v4" "$WORKFLOWS_DIR"
  [ "$status" -ne 0 ]
}

@test "S14: no stale v4 pin for upload-artifact" {
  run grep -rn "actions/upload-artifact@v4" "$WORKFLOWS_DIR"
  [ "$status" -ne 0 ]
}

@test "S15: no stale v7 pin for github-script" {
  run grep -rn "actions/github-script@v7" "$WORKFLOWS_DIR"
  [ "$status" -ne 0 ]
}

@test "S16: no stale v1 pin for supabase/setup-cli" {
  run grep -rn "supabase/setup-cli@v1" "$WORKFLOWS_DIR"
  [ "$status" -ne 0 ]
}

# S16a 本体。引数のディレクトリ配下の *.yml.template から `uses:` 行を全数抽出し、
# actions/* 以外が「40 桁コミット SHA ＋ 同一行のバージョンコメント」で固定されているか検査する。
# 可変タグ／ブランチ参照（例: supabase/setup-cli@v2 は tag ではなくブランチ）は、上流の push だけで
# 展開先の production ジョブが別コードを実行しうる。方針は oratta/claude-harness#138 / #162 / #176。
#
# 戻り値: 0=合格 / 1=違反あり（違反行を stderr に出す）/ 2=抽出 0 件
# テスト関数から分離してあるのは、本物のテンプレート（正例）と、すり抜けを狙った
# フィクスチャ（負例）の両方に同じ検査を当てるため。
check_third_party_pins() {
  local dir="$1"
  local total=0
  local unpinned=""
  local line value body

  while IFS= read -r line; do
    total=$((total + 1))

    # `grep -rn` の出力には `<パス>:<行番号>:` が前置される。コメント形の検査を
    # YAML 本文だけに当てるため、ここで剥がす（パス側の `#` が版数コメントに化けるのを防ぐ）。
    # 前置が付いていない形（パスに `:` を含む等）では sed が何もしないので、
    # 剥がし損ねても検査が緩む方向には動かない。
    body="$(printf '%s' "$line" | sed -E 's/^([^:]+):([0-9]+)://')"

    # `uses:` の「値」だけを切り出してから公式判定する（#176 その2）。
    # 行全体の部分一致で `actions/` を探すと、コメント中の文字列
    # （例: `uses: evil/action@v1 # mimics uses: actions/cache@v4`）にも当たって
    # 第三者 action が公式扱いでスキップされる。grep -o は行内の全一致を順に返すので、
    # 先頭の 1 件＝キーとしての `uses:` を取る（コメント側は 2 件目以降になる）。
    value="$(printf '%s\n' "$body" \
      | grep -oE 'uses[[:space:]]*:[[:space:]]*[^[:space:]]+' \
      | head -n 1 \
      | sed -E 's/^uses[[:space:]]*:[[:space:]]*//')"
    # YAML の引用符は値の一部ではないので剥がす（`uses: 'owner/action@sha'` 形の偽陽性を除く）
    value="${value#\'}"; value="${value%\'}"
    value="${value#\"}"; value="${value%\"}"

    # actions/* は GitHub 公式所有なので #138 の方針どおり対象外
    case "$value" in
      actions/*) continue ;;
    esac

    # 値そのものが `<owner>/<action>@<40 桁 hex>` であること。
    # `<owner>/` を必須にしてあるのは spec の字面に合わせるため（#180 レビュー指摘 A）。
    # owner を落とした `uses: evil@<40hex>` は GitHub 上の第三者 action を指し得ないが、
    # 検査が素通りさせると spec が保証すると読める形を実装が見ていないことになる。
    # `<action>` 側は `owner/repo/subdir@<sha>` のサブパス形を許すため `/` を含んでよい。
    if ! printf '%s' "$value" | grep -qE '^[^@[:space:]/]+/[^@[:space:]]+@[0-9a-f]{40}$'; then
      unpinned="${unpinned}${line}"$'\n'
      continue
    fi

    # 同じ行のコメントが「バージョンらしい」こと（#176 その1）。
    # `#` の後に非空白が 1 文字でもあれば通す旧判定だと `# TODO` でも合格してしまい、
    # spec の「その SHA が指すバージョンを同じ行のコメントに併記」と字面が合わない。
    # SHA とバージョンの対応そのものはオフラインで検証できないので、形だけ縛る。
    # 終端を空白で締めるのは、`# v1evil` / `# 1.` / `# 2026-08-22` /
    # 行内の別の `#176` のような「バージョンに見えるだけ」の形を弾くため。
    # 行末を表すのに `(...|$)` を使わず末尾に空白 1 個を足しているのは、
    # 括弧内の `$` をアンカーとして扱うかが grep 実装で揺れるのを避けるため。
    if ! printf '%s ' "$body" | grep -qE '#[[:space:]]*v?[0-9]+(\.[0-9]+)*[[:space:]]'; then
      unpinned="${unpinned}${line}"$'\n'
    fi
    # 抽出パターンが `uses[[:space:]]*:` なのは、YAML として有効な `uses : owner/action@v1`
    # （コロン前に空白）が密着形の grep から丸ごと漏れるのを防ぐため（#176 その3）。
  done < <(grep -rnE --include='*.yml.template' '^[[:space:]]*-?[[:space:]]*uses[[:space:]]*:' "$dir")

  # テンプレートの改名・移動で走査対象が 0 件になり、テストが無言で pass するのを防ぐ
  if [ "$total" -eq 0 ]; then
    printf 'no `uses:` lines extracted from %s\n' "$dir" >&2
    return 2
  fi

  if [ -n "$unpinned" ]; then
    printf 'unpinned third-party action(s):\n%s' "$unpinned" >&2
    return 1
  fi
  return 0
}

# 引数の各 `uses:` 行を 1 本のテンプレートに詰めた一時 dir を作り、そのパスを stdout に返す。
# 負例／正例テストの共通ヘルパー。
write_uses_fixture() {
  local dir="$BATS_TEST_TMPDIR/fixture"
  local step
  rm -rf "$dir"
  mkdir -p "$dir"
  {
    printf 'jobs:\n'
    printf '  build:\n'
    printf '    steps:\n'
    for step in "$@"; do
      printf '      - %s\n' "$step"
    done
  } > "$dir/fixture.yml.template"
  printf '%s\n' "$dir"
}

# 検査対象が 1 件以上ある「普通のテンプレート」を装うための、正しく固定された行。
# 負例に混ぜることで、旧実装が総数ガード（total > 0）で偶然 fail するのではなく
# 本当にすり抜けていたことを負例テストが突けるようにする。
PINNED_OK='uses: supabase/setup-cli@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf # v2.1.1'

@test "S16a: third-party actions are pinned to a 40-hex SHA with a version comment" {
  run check_third_party_pins "$WORKFLOWS_DIR"
  [ "$status" -eq 0 ]
}

@test "S16a-1: a non-version comment on a SHA-pinned third-party action is rejected" {
  # 旧判定（`#` の後に非空白が 1 文字あれば通る）はこの形を PASS させていた
  run check_third_party_pins "$(write_uses_fixture \
    'uses: supabase/setup-cli@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf # TODO' \
    "$PINNED_OK")"
  [ "$status" -eq 1 ]
  [[ "$output" == *"# TODO"* ]]
}

@test "S16a-2: 'uses: actions/' inside a comment does not exempt a third-party action" {
  # 旧判定（行全体の部分一致）はこの形を公式 action と誤認してスキップしていた
  run check_third_party_pins "$(write_uses_fixture \
    'uses: evil/action@v1 # mimics uses: actions/cache@v4' \
    "$PINNED_OK")"
  [ "$status" -eq 1 ]
  [[ "$output" == *"evil/action@v1"* ]]
}

@test "S16a-3: 'uses :' with a space before the colon is still extracted and checked" {
  # 旧抽出（密着形の `uses:` のみ）はこの行を検査対象から丸ごと落としていた。
  # 正しく固定された行を並べてあるので、旧実装は総数ガードにも掛からず PASS していた。
  run check_third_party_pins "$(write_uses_fixture \
    'uses : evil/action@v1' \
    "$PINNED_OK")"
  [ "$status" -eq 1 ]
  [[ "$output" == *"evil/action@v1"* ]]
}

@test "S16a-4: a properly pinned third-party action passes (quoted form included)" {
  run check_third_party_pins "$(write_uses_fixture "$PINNED_OK")"
  [ "$status" -eq 0 ]

  run check_third_party_pins "$(write_uses_fixture \
    "uses: 'supabase/setup-cli@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf' # v2.1.1")"
  [ "$status" -eq 0 ]
}

@test "S16a-5: official actions/* stay exempt from the SHA requirement" {
  run check_third_party_pins "$(write_uses_fixture 'uses: actions/checkout@v7')"
  [ "$status" -eq 0 ]
}

@test "S16a-6: an empty template dir fails instead of silently passing" {
  local dir="$BATS_TEST_TMPDIR/empty"
  rm -rf "$dir"
  mkdir -p "$dir"
  run check_third_party_pins "$dir"
  [ "$status" -eq 2 ]
}

@test "S16a-7: a value without an <owner>/ prefix is rejected" {
  # spec の Scenario は値が `<owner>/<action>@<40 桁 16 進数>` であることを要求している。
  # `/` を見ない実装だと owner の無い `evil@<40hex>` が素通りし、spec の字面と実装がズレる。
  run check_third_party_pins "$(write_uses_fixture \
    'uses: evil@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf # v1' \
    "$PINNED_OK")"
  [ "$status" -eq 1 ]
  [[ "$output" == *"evil@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf"* ]]
}

@test "S16a-8: comments that only look like a version are rejected" {
  # 終端境界の無い判定だと、下の 4 形はいずれも「バージョンコメントあり」で通ってしまう。
  local bad
  for bad in \
    'uses: supabase/setup-cli@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf # v1evil' \
    'uses: supabase/setup-cli@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf # 1.' \
    'uses: supabase/setup-cli@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf # TODO (#176)' \
    'uses: supabase/setup-cli@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf # 2026-08-22'
  do
    run check_third_party_pins "$(write_uses_fixture "$bad" "$PINNED_OK")"
    [ "$status" -eq 1 ] || { echo "not rejected: $bad"; return 1; }
  done
}

@test "S16a-9: the grep -rn path prefix does not satisfy the comment check" {
  # 検査対象は YAML 本文であって `grep -rn` が前置する `<パス>:<行番号>:` ではない。
  # 前置を剥がさないと、パスに含まれる `# v9` がバージョンコメントの代わりを務めてしまう。
  local dir="$BATS_TEST_TMPDIR/dir # v9"
  rm -rf "$dir"
  mkdir -p "$dir"
  printf 'jobs:\n  build:\n    steps:\n      - %s\n' \
    'uses: supabase/setup-cli@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf # TODO' \
    > "$dir/fixture.yml.template"
  run check_third_party_pins "$dir"
  [ "$status" -eq 1 ]
}

@test "S16a-10: a sub-path action reference stays valid when SHA-pinned" {
  # `owner/repo/subdir@<sha>` は GitHub 上で有効な参照形。`<owner>/` 必須化で
  # これを巻き込んで落とすと、正しく固定された action が使えなくなる。
  run check_third_party_pins "$(write_uses_fixture \
    'uses: aws-actions/aws-cli/setup@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf # v2.1.1')"
  [ "$status" -eq 0 ]
}

@test "S16a-11: a quoted 'uses' key is still extracted and checked" {
  # 旧抽出（素のキー形のみ）は `- "uses": ...` を検査対象から丸ごと落としていた（#182）。
  # 正しく固定された行を並べてあるので、旧実装は総数ガードにも掛からず PASS していた。
  run check_third_party_pins "$(write_uses_fixture \
    '"uses": evil/action@v1' \
    "$PINNED_OK")"
  [ "$status" -eq 1 ]
  [[ "$output" == *"evil/action@v1"* ]]

  run check_third_party_pins "$(write_uses_fixture \
    "'uses': evil/action@v1" \
    "$PINNED_OK")"
  [ "$status" -eq 1 ]
  [[ "$output" == *"evil/action@v1"* ]]
}

@test "S16a-12: a flow-mapping step is still extracted and checked" {
  # `- { uses: ... }` は YAML として有効だが、行頭キー形の旧抽出には一致しない（#182）。
  run check_third_party_pins "$(write_uses_fixture \
    '{ uses: evil/action@v1 }' \
    "$PINNED_OK")"
  [ "$status" -eq 1 ]
  [[ "$output" == *"evil/action@v1"* ]]

  # 密着形＋ uses が先頭キーでない形（値の直後に `}` が密着する）
  run check_third_party_pins "$(write_uses_fixture \
    '{name: deploy, uses: evil/action@v1}' \
    "$PINNED_OK")"
  [ "$status" -eq 1 ]
  [[ "$output" == *"evil/action@v1"* ]]
}

@test "S16a-13: properly pinned quoted-key and flow-mapping forms pass" {
  run check_third_party_pins "$(write_uses_fixture \
    '"uses": supabase/setup-cli@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf # v2.1.1')"
  [ "$status" -eq 0 ]

  # flow mapping の中にはコメントを置けない（`#` 以降はコメントになり `}` が閉じない）ので、
  # バージョンコメントは閉じ括弧の後に置く
  run check_third_party_pins "$(write_uses_fixture \
    '{ uses: supabase/setup-cli@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf } # v2.1.1')"
  [ "$status" -eq 0 ]

  run check_third_party_pins "$(write_uses_fixture \
    '{uses: "supabase/setup-cli@3c2f5e2ae34c34e428e8e206e2c4d21fa2d20fbf"} # v2.1.1')"
  [ "$status" -eq 0 ]
}

@test "S17: all five workflow templates parse as YAML" {
  for f in "$WORKFLOWS_DIR"/*.yml.template; do
    ruby -ryaml -e "YAML.load_file('$f')" || return 1
  done
}

@test "S18: Vercel Token CLI investigation note present in Phase 4" {
  grep -q 'tokens' "$P4"
  grep -qE 'CLI 化|CLI 不可|CLI 化不可' "$P4"
}

@test "S19: Vercel Token CLI investigation note present in SKILL.md" {
  grep -qE 'CLI 化|CLI 不可|CLI 化不可' "$SKILL"
}

@test "S20: Step 5 fallback logic keeps the 2-branch structure (auto/manual)" {
  grep -q '自動モード（Playwright MCP 利用可）' "$P4"
  grep -q '手動モード' "$P4"
}

# --- infra-doc-integrity (S21-S31) ---

@test "S21: SKILL.md and Phase 5 document preview as label opt-in" {
  grep -q 'preview` ラベル' "$SKILL"
  grep -q 'preview` ラベル' "$P5"
  # 「Ready for review にすると Preview deploy が走る」旧仕様の記述が残っていないこと
  run grep -n 'Ready for review にすると Preview deploy\|Ready for review で Preview deploy' "$SKILL" "$P5" "$README"
  [ "$status" -ne 0 ]
}

@test "S22: SKILL.md keeps Draft-skip/Ready-for-review CI wording; Phase 5 states label add/remove steps" {
  grep -q 'Draft 中は' "$SKILL"
  grep -q 'Ready for review' "$SKILL"
  grep -q '剥がし' "$P5"
  grep -q '貼っ' "$P5"
}

@test "S23: README.md documents the preview label opt-in" {
  grep -q 'preview` ラベル' "$README"
  grep -q 'opt-in' "$README"
}

@test "S23a: deploy-preview template triggers on labeled/synchronize only" {
  local tpl="${WORKFLOWS_DIR}/deploy-preview.yml.template"
  grep -qE '^\s+types: \[labeled, synchronize\]' "$tpl"
  # 旧仕様のトリガーが残っていないこと
  run grep -nE '^\s+types:.*(opened|ready_for_review)' "$tpl"
  [ "$status" -ne 0 ]
}

@test "S23b: deploy-preview gates on the 'preview' label, not on draft state" {
  local tpl="${WORKFLOWS_DIR}/deploy-preview.yml.template"
  grep -q "github.event.label.name == 'preview'" "$tpl"
  grep -q "contains(github.event.pull_request.labels.\*.name, 'preview')" "$tpl"
  # draft ガードは撤去済み（Draft のままでもラベルで発火させるため）
  run grep -n 'pull_request.draft == false' "$tpl"
  [ "$status" -ne 0 ]
}

@test "S23c: Phase 4 creates the 'preview' label so users can apply it" {
  grep -q 'gh label create preview' "$P4"
}

@test "S24: Phase 1 references correct Phase 2 step numbers (11 / 11.5)" {
  grep -q 'Step 11' "$P1"
  grep -q 'Step 11\.5' "$P1"
}

@test "S25: no stale step-number references remain in Phase 1" {
  run grep -n "Step 10\.5\|の Step 10）" "$P1"
  [ "$status" -ne 0 ]
}

@test "S26: vercel link troubleshooting note is scoped to the re-link case" {
  grep -q '既存プロジェクトへの再リンク時のみ' "$P3"
}

@test "S27: Step 3 and troubleshooting vercel link text no longer conflict unqualified" {
  grep -q '既存プロジェクトへの再リンク時のみ' "$P3"
  grep -q '新規作成には使えない' "$P3"
}

@test "S28: architecture diagram Phase 4 line mentions deploy-preview" {
  grep -E 'infra-phase-4-github-actions.*deploy-preview' "$SKILL"
}

@test "S29: SKILL.md frontmatter version matches plugin.json version" {
  skill_version="$(grep -m1 '^version:' "$SKILL" | sed 's/^version: *//')"
  plugin_version="$(grep -m1 '"version"' "$PLUGIN_JSON" | sed -E 's/.*"version": *"([^"]+)".*/\1/')"
  [ -n "$skill_version" ]
  [ -n "$plugin_version" ]
  [ "$skill_version" = "$plugin_version" ]
}

@test "S30: no personal Dropbox path remains" {
  run grep -rn "/Users/oratta" "$PLUGIN_DIR" --exclude-dir=tests
  [ "$status" -ne 0 ]
}

@test "S31: plugin.json version is bumped above 0.2.0" {
  plugin_version="$(grep -m1 '"version"' "$PLUGIN_JSON" | sed -E 's/.*"version": *"([^"]+)".*/\1/')"
  [ "$plugin_version" != "0.2.0" ]
  # crude semver compare: split into major.minor.patch and compare numerically
  IFS='.' read -r a b c <<< "$plugin_version"
  [ "$a" -gt 0 ] || { [ "$a" -eq 0 ] && { [ "$b" -gt 2 ] || { [ "$b" -eq 2 ] && [ "$c" -gt 0 ]; }; }; }
}

@test "all touched JSON parses (jq)" {
  jq empty "$PLUGIN_JSON"
}
