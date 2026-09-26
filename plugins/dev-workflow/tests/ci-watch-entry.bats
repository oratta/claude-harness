#!/usr/bin/env bats
#
# /ci-watch <PR> [--merge]: ゲート未通過の PR の CI を見張る入口。ci-watch.sh target が PR の URL か番号と
# --merge の有無を決め、コマンドの手順は共有 reference（references/ci-watch.md）の見張りを呼ぶ。
# ready のあとは --merge の有無で分かれ、--merge が無ければゲートに進まずに見張りを終える。
#
# spec: openspec/changes/ci-watch-entry（dev-workflow-ci-watch）

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  SCRIPT="${PLUGIN_DIR}/scripts/ci-watch.sh"
  CMD="${PLUGIN_DIR}/commands/ci-watch.md"
  REF="${PLUGIN_DIR}/references/ci-watch.md"
  WORK="$(cd "$(mktemp -d)" && pwd -P)"
  GH_LOG="${WORK}/gh.log"
  mkdir -p "${WORK}/bin"
  # gh の偽物: 呼び出しを記録する。repo view は o/r を返す。pr view は、PR 番号が prs/<repo>/<番号> に
  # あればその PR の JSON を返し、無ければ非 0 で終わる
  cat > "${WORK}/bin/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "${GH_LOG}"
if [ "\$1 \$2" = "repo view" ]; then
  [ -e "${WORK}/norepo" ] && { echo "gh: not a git repository" >&2; exit 1; }
  echo o/r; exit 0
fi
if [ "\$1 \$2" = "pr view" ]; then
  n="\$3"; repo=""
  shift 3
  while [ \$# -gt 0 ]; do [ "\$1" = --repo ] && repo="\$2"; shift; done
  f="${WORK}/prs/\${repo}/\${n}"
  [ -e "\$f" ] || { echo "gh: no pull requests found" >&2; exit 1; }
  jq -cn --argjson n "\$n" --arg u "https://github.com/\${repo}/pull/\${n}" '{number: \$n, url: \$u}'
  exit 0
fi
exit 0
EOF
  chmod +x "${WORK}/bin/gh"
  export PATH="${WORK}/bin:${PATH}"
  mkdir -p "${WORK}/prs/o/r" "${WORK}/prs/acme/tool"
  touch "${WORK}/prs/o/r/5" "${WORK}/prs/acme/tool/12"
}

teardown() {
  rm -rf "$WORK"
}

frontmatter() { awk 'NR==1 && /^---$/{f=1; next} f && /^---$/{exit} f' "$1"; }

# ── ci-watch.sh target ────────────────────────────────────

@test "target: a number resolves against the current repository" {  # 番号は今のリポの PR
  run --separate-stderr "$SCRIPT" target 5
  [ "$status" -eq 0 ]
  [ "$(jq -r .repo <<<"$output")" = o/r ]
  [ "$(jq -r .number <<<"$output")" = 5 ]
  [ "$(jq -r .url <<<"$output")" = https://github.com/o/r/pull/5 ]
  [ "$(jq -r .merge <<<"$output")" = false ]
}

@test "target: a URL resolves against the repository in the URL" {  # URL は URL のリポの PR
  run --separate-stderr "$SCRIPT" target https://github.com/acme/tool/pull/12
  [ "$status" -eq 0 ]
  [ "$(jq -r .repo <<<"$output")" = acme/tool ]
  [ "$(jq -r .number <<<"$output")" = 12 ]
  ! grep -q '^repo view' "$GH_LOG" || return 1
}

@test "target: a URL with a trailing path or fragment still resolves" {  # /files や #issuecomment が付いた URL
  run --separate-stderr "$SCRIPT" target 'https://github.com/acme/tool/pull/12/files#diff-1'
  [ "$status" -eq 0 ]
  [ "$(jq -r .repo <<<"$output")" = acme/tool ]
  [ "$(jq -r .number <<<"$output")" = 12 ]
}

@test "target: --merge before or after the PR sets merge to true" {  # --merge の位置は問わない
  run --separate-stderr "$SCRIPT" target 5 --merge
  [ "$status" -eq 0 ]
  [ "$(jq -r .merge <<<"$output")" = true ]
  run --separate-stderr "$SCRIPT" target --merge https://github.com/acme/tool/pull/12
  [ "$status" -eq 0 ]
  [ "$(jq -r .merge <<<"$output")" = true ]
}

@test "target: free text is not taken as a merge request" {  # 自由文のマージ依頼を --merge として扱わない
  run --separate-stderr "$SCRIPT" target 5 マージして
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  run --separate-stderr "$SCRIPT" target 5 --marge
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "target: an unknown PR stops without output" {  # 解決できない PR では始めない
  run --separate-stderr "$SCRIPT" target 99
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  run --separate-stderr "$SCRIPT" target https://github.com/acme/tool/pull/99
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "target: input that is neither a number nor a PR URL stops without calling gh pr view" {  # 形が違う入力
  local a
  for a in '' abc 'https://github.com/acme/tool/issues/12' 'https://example.com/acme/tool/pull/12' '5 6'; do
    : > "$GH_LOG"
    run --separate-stderr "$SCRIPT" target $a
    [ "$status" -ne 0 ] || { echo "accepted: $a"; return 1; }
    [ -z "$output" ]
    ! grep -q '^pr view' "$GH_LOG" || { echo "gh pr view called for: $a"; return 1; }
  done
}

@test "target: a number outside a repository stops" {  # 今のリポが分からなければ始めない
  touch "${WORK}/norepo"
  run --separate-stderr "$SCRIPT" target 5
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "target: does not touch the state directory" {  # 状態ファイルに触れない
  export DEV_WORKFLOW_PR_STATE_DIR="${WORK}/state"
  run --separate-stderr "$SCRIPT" target 5 --merge
  [ "$status" -eq 0 ]
  [ ! -e "${WORK}/state" ]
}

# ── commands/ci-watch.md ──────────────────────────────────

@test "command: exists with a description and the --merge argument hint" {  # 入口の形
  [ -f "$CMD" ]
  frontmatter "$CMD" | grep -q '^name: ci-watch$'
  frontmatter "$CMD" | grep -q '^description: '
  frontmatter "$CMD" | grep -q '^argument-hint: .*--merge'
}

@test "command: resolves the target with ci-watch.sh target and stops when it fails" {  # 解決と停止
  grep -qF 'ci-watch.sh target' "$CMD"
  grep -qF 'CLAUDE_PLUGIN_ROOT' "$CMD"
  grep -q '非 0 なら.*見張りを始めず' "$CMD"
}

@test "command: reuses the shared reference and has no waiting or sorting rules of its own" {  # 共有手順を使う
  grep -qF 'references/ci-watch.md' "$CMD"
  local w
  for w in 'ci-watch.sh wait' 'ci-watch.sh next' 'run_in_background' 'CI 見張り開始:' 'CI 見張り終了:'; do
    grep -qF -- "$w" "$CMD" || { echo "missing: $w"; return 1; }
  done
  # 待ち方の値や分類の規則を入口で持たない
  ! grep -qE 'DEV_WORKFLOW_CI_WATCH_(INTERVAL|TIMEOUT)|pr-state\.sh (observe|decide)' "$CMD" || return 1
}

@test "command: --unrelated only for checks meeting both conditions, otherwise fix" {  # --unrelated の基準
  grep -q '「5. `--unrelated` を渡す基準」' "$CMD"
  grep -q '2 条件を両方満たすチェックだけ' "$CMD"
  grep -q '判断できなければ.*渡さず.*`fix`' "$CMD"
}

@test "command: fix is done by a sonnet implementer subagent, with --after-fix for an unrelated verdict" {  # 直しの担い手
  grep -q '実装者のサブエージェント（model は sonnet）' "$CMD"
  grep -q 'メインセッションは自分で直さない' "$CMD"
  grep -qF 'next <owner/repo> <PR番号> --unrelated <チェック名> --after-fix' "$CMD"
  grep -q '1 回だけ' "$CMD"
}

@test "command: ready without --merge ends the watch without the gate or label changes" {  # --merge なしの ready
  grep -q '`merge` が `false`.*`ready`.*ゲートを実施しない' "$CMD"
  grep -qF 'CI が通った。マージ依頼が無いのでゲートとマージには進まない' "$CMD"
  grep -q 'PR の URL を添えて.*CI が通ったこと' "$CMD"
}

@test "command: the no-label-change rule is limited to ready and fix follows the shared fixing steps" {  # ラベルを触らない範囲
  grep -q 'ラベルを付け外ししないのは `ready` を受けたときだけ' "$CMD"
  grep -q '`fix` のときは.*「7. 直し方」' "$CMD"
}

@test "command: ready with --merge runs the gate and goes on only after it passes" {  # --merge 付きの ready
  grep -q '`merge` が `true`.*`ready`.*pr-review-gate' "$CMD"
  grep -q '合格が確定するまで.*マージ待ち・マージ依頼に進まない' "$CMD"
  grep -qF '「`ready` を受けたあと」' "$CMD"
}

@test "command: --merge is the only merge request and its scope is limited" {  # 承認範囲
  grep -q 'マージ依頼の有無は `--merge` の有無だけで決め' "$CMD"
  grep -q '会話の文面からマージ依頼を推定しない' "$CMD"
  local w
  for w in 'ゲート省略' '別の PR' '別の HEAD' 'main への直接 push' 'rebase' 'force-push' 'gh pr merge'; do
    grep -qF -- "$w" "$CMD" || { echo "missing: $w"; return 1; }
  done
}

@test "command: the watch runs in the main session and does not use the Skill tool for itself" {  # 本体が待つ
  grep -q 'メインセッション' "$CMD"
  grep -q 'サブエージェントに見張らせない' "$CMD"
}

# ── references/ci-watch.md から入口への参照 ────────────────

@test "reference: points to the entry for ready handling of /ci-watch" {  # reference から入口へ
  grep -qF 'commands/ci-watch.md' "$REF"
  grep -qF 'ci-watch.sh target' "$REF"
}
