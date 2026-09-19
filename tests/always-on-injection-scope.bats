#!/usr/bin/env bats
# always-on-injection-scope.bats — 常時注入に残すと決めた指示の退行を止める（issue #260）
#
# spec always-on-injection-scope の要件「常時性を手放してはいけないルールを縮約対象から外す」は、
# 縮約したルールの中でも、読むべき瞬間に目に入らないと効かない一文を短い形で残すことを求める。
# ここでは残すと決めた指示ごとに、その指示の文にしか現れない語句（目印）を選び、該当ルールの
# 本文にあることを検査する。単語 1 つ（例: fetch）を目印にすると、同じファイルの別の文に同じ語が
# あるだけで通ってしまうので、目印は文の一部を切り出した語句にし、ファイル内で 1 回しか
# 現れないことも検査する。指示の文言を変えたときは、ここの目印も同じ変更で直す。
#
# テスト名は ASCII のみ（bats はマルチバイトのテスト名を扱えない。既存スイートと同じ制約）。

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  TMPD="$(mktemp -d)"
}

teardown() {
  rm -rf "$TMPD"
}

# 目印の一覧。1 行 1 件で「rules/ 配下のファイル名 <TAB> 目印の語句」。
markers() {
  cat <<'EOF'
perspective-casting.md	回復不能側に倒す
perspective-casting.md	担い手が主の観点が1つでもあれば主へ上げる
perspective-casting.md	全観点を移譲済みなら独断せず
perspective-casting.md	読み取り不能は主へ上げる
perspective-casting.md	裁定は実行し、主へは事後報告する
perspective-casting.md	そのターンで配役表の該当行を更新し
communication-style.md	テストの実行が遅い件
communication-style.md	コスト20%削減
communication-style.md	センターピン
communication-style.md	見出しや表で番号を振るのは構わない
communication-style.md	ひとつの説明に複数混ぜない
communication-style.md	専門用語は初出で一言の言い換えを添える
communication-style.md	これを飲めるならAで進める
communication-style.md	読み手の側にしかない情報
communication-style.md	他の資料を見に行かないと判断できない書き方はしない
communication-style.md	前置きと注意書きは短くする
communication-style.md	AskUserQuestion
communication-style.md	仮説が立った段階で
communication-style.md	装飾は足さない
communication-style.md	原則を増減させたときは両方を直す
git-commit-policy.md	過去 PR あり
git-commit-policy.md	`gh pr create` まで自律実行してよい
git-commit-policy.md	作業完了＋archive（`/opsx:archive` / `/wt-clean` 完了 = テスト・lint 済みのシグナル）後
git-commit-policy.md	feature → main のマージと `git push origin main` は明示承認
git-commit-policy.md	などの直接マージは、どちらの運用でも明示承認なしに実行しない
git-commit-policy.md	ゲート通過後に commit を積んだら取り直す
plugin-editing.md	パスを文書やスクリプトに固定で書かない
plugin-editing.md	`git fetch origin` してから
plugin-editing.md	そちらのリポジトリに Draft PR が作られる
plugin-editing.md	Draft PR まで作る
plugin-editing.md	手動で削除しない
one-off-no-script.md	汎用ツールを作ろうとしているサイン
subagent-model-selection.md	FABLE_BUDGET_MODE
destructive-git-guard.md	例外なく事前承認
destructive-git-guard.md	`git reset --hard`
destructive-git-guard.md	`git push <remote> main|master`（remote 名を問わない）
link-when-requesting-review.md	`）` まで URL に含まれて 404 になる
dev-server.md	他プロジェクトのプロセスを kill してポートを確保するのは絶対禁止
browser-infra-env-capture.md	表示された次のアクションで
EOF
}

# missing_markers <rules_dir> — 目印が本文に無い行を「ファイル名 <TAB> 目印」で出力する。
# すべて揃っていれば何も出力しない。
missing_markers() {
  local dir="$1" file marker
  while IFS=$'\t' read -r file marker; do
    LC_ALL=C grep -qF -- "$marker" "$dir/$file" || printf '%s\t%s\n' "$file" "$marker"
  done < <(markers)
}

# count_occurrences <file> <marker> — 目印がファイル内に何回現れるか（同じ行に 2 回でも 2）。
count_occurrences() {
  LC_ALL=C grep -oF -- "$2" "$1" | wc -l | tr -d '[:space:]'
}

@test "every kept instruction is still in its rule" {
  run missing_markers "$REPO_ROOT/rules"
  [ "$status" -eq 0 ]
  if [ -n "$output" ]; then
    echo "常時注入に残すと決めた指示が見当たらない（ファイル名 / 目印）:" >&2
    printf '%s\n' "$output" >&2
  fi
  [ -z "$output" ]
}

@test "each marker appears exactly once in its rule" {
  local file marker n bad=""
  while IFS=$'\t' read -r file marker; do
    n=$(count_occurrences "$REPO_ROOT/rules/$file" "$marker")
    [ "$n" = "1" ] || bad="${bad}${file}	${marker}	${n}"$'\n'
  done < <(markers)
  if [ -n "$bad" ]; then
    echo "目印がその指示の文にしか現れない語句になっていない（ファイル名 / 目印 / 出現回数）:" >&2
    printf '%s' "$bad" >&2
  fi
  [ -z "$bad" ]
}

@test "removing any single kept instruction makes the check fail" {
  local file marker content
  while IFS=$'\t' read -r file marker; do
    rm -rf "$TMPD/rules"
    cp -R "$REPO_ROOT/rules" "$TMPD/rules"
    content=$(cat "$TMPD/rules/$file"; printf 'X')
    content=${content%X}
    printf '%s' "${content//"$marker"/}" >| "$TMPD/rules/$file"
    run missing_markers "$TMPD/rules"
    [ "$output" = "${file}	${marker}" ] || {
      echo "目印を消しても検査が落ちない: ${file} / ${marker} / 出力: ${output}" >&2
      false
    }
  done < <(markers)
}

@test "every rule the spec names for kept instructions carries a marker" {
  local f
  for f in perspective-casting.md communication-style.md git-commit-policy.md \
           plugin-editing.md one-off-no-script.md subagent-model-selection.md \
           destructive-git-guard.md dev-server.md browser-infra-env-capture.md; do
    markers | cut -f1 | grep -qx -- "$f" || { echo "目印が 1 件も無い: $f" >&2; false; }
  done
}

@test "the three always-on rules are real files without a paths frontmatter" {
  local f
  for f in destructive-git-guard.md dev-server.md browser-infra-env-capture.md; do
    [ -f "$REPO_ROOT/rules/$f" ]
    [ ! -L "$REPO_ROOT/rules/$f" ]
    ! grep -q '^paths:' "$REPO_ROOT/rules/$f"
  done
}
