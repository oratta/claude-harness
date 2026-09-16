#!/usr/bin/env bats
#
# サブエージェントの待ち方の契約の退行検出（issue #254）
#
# spec: dev-workflow-subagent-waiting, dev-workflow-develop, dev-workflow-pr-review-gate
#
# この change の成果物は手順書の文言なので、退行検出も文言に対して grep で行う。
# テスト名は ASCII のみ。

setup() {
  PLUGIN_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  CANON="${PLUGIN_DIR}/references/subagent-waiting.md"
  ROLES="${PLUGIN_DIR}/skills/develop/references/roles"
  GATE="${PLUGIN_DIR}/skills/pr-review-gate/SKILL.md"
  WORKER="${ROLES}/worker.md"
  REVIEWER="${ROLES}/spec-reviewer.md"
  RUNNER="${ROLES}/gate-runner.md"
  README="${PLUGIN_DIR}/README.md"

  ROLE_FILES=("$WORKER" "$REVIEWER" "$RUNNER")
  # 禁止語の検査対象＝サブエージェント（W / R1 / G）が手順として読む文書。
  SUBAGENT_DOCS=("$WORKER" "$REVIEWER" "$RUNNER" "$GATE")

  # Claude Code の Bash ツールの前景 1 回あたりの上限（ミリ秒）。
  # ハーネス側の上限が変わったら、この 1 行だけを直せば検査 2 全体が追随する。
  FOREGROUND_LIMIT_MS=600000

  # 正本の「手順 1」の雛形を実際に走らせて検査するため、毎テストで抽出しておく。
  SNIP="${BATS_TEST_TMPDIR}/step1.sh"
  extract_step1 "$CANON" "$SNIP"
}

# 正本の「手順 1:」を含む ```bash ブロックを取り出す（push-guard-setup.bats と同じ手口）。
# 雛形は「読まれる文書」であると同時に「実行されるコード」なので、文言検査だけでは
# 16 文字を 1 文字に弱めるような改悪が素通りする。抽出して走らせて初めて落ちる。
extract_step1() {
  python3 - "$1" "$2" <<'PY'
import sys, re
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding="utf-8").read()
i = text.find("手順 1:")
assert i >= 0, "step 1 heading not found"
j = text.rfind("```bash", 0, i)
assert j >= 0, "no bash block encloses step 1"
m = re.search(r"```bash\n(.*?)```", text[j:], re.S)
assert m, "bash block not closed"
open(dst, "w", encoding="utf-8").write(m.group(1))
PY
}

# --- 検査 1: 待ちを完了通知 / Monitor に委ねる指示が残っていないこと ---
#
# 除外規定はこの検査 1 だけに掛ける。正本（references/subagent-waiting.md）と本テスト自身は
# 「何が禁止か」を説明するために禁止語をそのまま含むため、禁止語スキャンの対象にしない。
# 検査 2（待ち値が前景上限未満）は正本にも掛ける — 正本に 900000 を書き戻したら落ちる。
#
# 禁止語のブラックリストは既知の言い換えを止めるだけで、意味を保った別の言い回しは素通りする
# （grep で意味は見られない）。網羅性を担うのは下の構造検査のほうで、ブラックリストはその補助:
#   - background 起動を書いている文書は前景ポーリングと禁止 1 行と正本参照を必ず併記していること
#   - 待ちの雛形・待ち値・上限回数は正本にしか現れないこと（再掲を許すと片方だけ古くなる）

@test "no subagent handbook delegates the wait to a completion notification or Monitor" {
  for f in "${SUBAGENT_DOCS[@]}"; do
    for pat in '完了通知を待' '通知を待って' 'Monitor ツール' 'Monitor に任せ' '待つのは companion に任せる' '完了したら再開'; do
      if grep -qF "$pat" "$f"; then
        echo "hint: ${f} contains the banned phrase '${pat}'."
        echo "hint: 待ちは同一ターン内の前景ポーリングで行う（正本: plugins/dev-workflow/references/subagent-waiting.md）"
        return 1
      fi
    done
  done
}

@test "handbooks that launch background jobs also show the foreground polling that waits" {
  for f in "${SUBAGENT_DOCS[@]}"; do
    grep -qE 'run_in_background|--background' "$f" || continue
    grep -q '前景' "$f" || {
      echo "hint: ${f} launches a background job but never shows how to wait in the foreground"
      return 1
    }
    grep -qE 'ターンを終え(ない|てはならない)' "$f" || {
      echo "hint: ${f} launches a background job but does not ban ending the turn on the wait"
      return 1
    }
    grep -qF 'references/subagent-waiting.md' "$f" || {
      echo "hint: ${f} launches a background job but does not point at the canonical waiting contract"
      return 1
    }
  done
}

# --- 検査 1b: 待ちの手順を正本以外に再掲していないこと ---
#
# 「正本 1 本・各指示書は禁止 1 行」の設計を機械で守る。2026-09-09 のレビューで、
# gate-runner に再掲していた companion の判定方法（exit code で区別する）が事実と
# 食い違ったまま残っていたため、再掲そのものを落とす。

@test "the waiting templates and values appear only in the canonical contract" {
  for f in "${SUBAGENT_DOCS[@]}"; do
    if grep -qF '__CODEX_DONE' "$f"; then
      echo "hint: ${f} restates the completion marker template"
      echo "hint: 待ちの雛形は正本（references/subagent-waiting.md）にだけ置き、指示書からは参照する"
      return 1
    fi
    if grep -qE '(--timeout-ms|timeout:)[[:space:]]*[0-9]+' "$f"; then
      echo "hint: ${f} restates a concrete wait value"
      echo "hint: 具体の待ち値は正本にだけ置く（指示書は「正本に従う」と書く）"
      return 1
    fi
    if grep -qE '(27 分|3 回 = )' "$f"; then
      echo "hint: ${f} restates the total wait cap"
      echo "hint: 上限の回数と分数は正本にだけ置く"
      return 1
    fi
  done
}

# --- 検査 2: 待ち値が前景上限未満であること ---

@test "every wait value in dev-workflow docs is below the foreground limit" {
  # 見るのは `--timeout-ms <数値>` と `timeout: <数値>` の 2 パターンだけ。
  # 裸の timeout は無関係な出現（timeout(1) に依存しない旨の説明など）が大半なので対象にしない。
  bad=0
  while IFS= read -r doc; do
    [ -n "$doc" ] || continue
    while IFS= read -r value; do
      [ -n "$value" ] || continue
      if [ "$value" -ge "$FOREGROUND_LIMIT_MS" ]; then
        echo "hint: ${doc} specifies ${value} ms, which is not below the foreground limit ${FOREGROUND_LIMIT_MS} ms"
        echo "hint: dev-workflow の既定は 540000（9 分）。1 回で終わらなければ同じ呼び出しを繰り返す"
        bad=1
      fi
    done <<< "$(grep -oE '(--timeout-ms|timeout:)[[:space:]]*[0-9]+' "$doc" | grep -oE '[0-9]+$')"
  done <<< "$(find "$PLUGIN_DIR" -name '*.md' -type f)"
  [ "$bad" -eq 0 ]
}

# --- 検査 3: 各役割の指示書に禁止 1 行と正本への参照があること ---

@test "each role handbook bans ending the turn on a wait and points at the canonical contract" {
  for f in "${ROLE_FILES[@]}"; do
    grep -qE 'ターンを終え(ない|てはならない)' "$f" || {
      echo "hint: ${f} lacks the ban on ending the turn while waiting"
      return 1
    }
    grep -qF 'references/subagent-waiting.md' "$f" || {
      echo "hint: ${f} does not reference plugins/dev-workflow/references/subagent-waiting.md"
      return 1
    }
  done
}

# --- 正本の中身（禁止・許可・完了シグナル・上限・単位・置き場） ---

@test "the canonical contract covers the ban, what stays allowed, and the polling template" {
  [ -f "$CANON" ]
  grep -q 'ターンを終え' "$CANON"
  grep -qF 'run_in_background' "$CANON"
  grep -qE 'until' "$CANON"
  grep -qF 'timeout: 540000' "$CANON"
  grep -qF 'timeout(1)' "$CANON"
  grep -q 'メインセッション' "$CANON"
}

@test "the canonical contract defines a completion signal per launch path" {
  # (a) codex exec 直叩き: マーカーは実行ごとに一意（nonce）で、照合は両端をアンカーした完全な形。
  # 固定文字列＋部分一致だと、レビュー対象の文書がその文字列を含むだけでポーリングが誤成立する。
  grep -qF '__CODEX_DONE_<nonce>__' "$CANON"
  grep -qF 'nonce' "$CANON"
  grep -qF "'^__CODEX_DONE_<nonce>__ rc=[0-9]+\$'" "$CANON"
  if grep -qE "grep -q[a-zA-Z]* '__CODEX_DONE" "$CANON"; then
    echo "hint: 完了マーカーの照合が行頭アンカー無しの部分一致になっている"
    return 1
  fi
  # 起動側で出力ファイルを作る手順があること（雛形どおりに実行して未定義変数にならないこと）
  grep -qF 'out="<dir>/review.log"' "$CANON"
  grep -qF ': > "$out"' "$CANON"

  # (b) companion 経路: exit code では区別できず、--json の waitTimedOut で判定する。
  grep -qF 'status <job-id> --wait --timeout-ms 540000' "$CANON"
  grep -qF 'waitTimedOut' "$CANON"
  grep -qF 'exit code ではタイムアウトと完了を区別できない' "$CANON"
  if grep -q 'exit code で区別する' "$CANON"; then
    echo "hint: companion の status --wait はタイムアウトでも完了でも 0 を返す（2026-09-09 実測）"
    return 1
  fi
}

# --- nonce の作り方（衝突・正規表現の誤マッチ・無言の縮退をまとめて止めること） ---
#
# 2 周目のゲート指摘: `date +%s` は秒精度なので、G / W / R1 が並行して走ると同じ秒に衝突し、
# 一方の完了マーカーが他方の未完了ジョブを完了扱いにする。さらに nonce は未エスケープのまま
# 拡張正規表現に埋まるので、メタ文字（`.` 等）を含む nonce は別の文字列に誤マッチする
# （`nonce="a.b"` が `axb` に一致することを実測）。
#
# 3 周目のゲート指摘: `uuidgen` が無い環境のフォールバック `$RANDOM` は、同一プロセスの
# 複数のコマンド置換サブシェルが同じ乱数状態を継承するため 5 回とも同じ値になった。乱数は
# 「たぶん被らない値」を作るだけで、被っていないことを誰も確認していない。確定形は一意性を
# 排他生成（`mktemp -d` = `mkdtemp(3)` の `O_EXCL`）に置き、フォールバック経路を持たない。

@test "the canonical contract derives the nonce from an exclusive directory creation" {
  grep -qF 'mktemp -d "${TMPDIR:-/tmp}/codex-XXXXXXXXXXXXXXXX"' "$CANON"
  grep -qF '[A-Za-z0-9]' "$CANON"

  # `date +%s` と `$RANDOM` が nonce の作り方として例示されていないこと。
  # 「使わない」「してはならない」「置かない」と禁じる文の中に現れるのは許す
  # （なぜ使わないかを書くために必要）。
  for banned in 'date +%s' '$RANDOM'; do
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      case "$line" in
        *使わない*|*してはならない*|*置かない*) continue ;;
      esac
      echo "hint: ${CANON} presents '${banned}' as a way to make a nonce: ${line}"
      echo "hint: 一意性は排他生成（mktemp -d）で担保する。乱数や秒精度の値は衝突を誰も確認していない"
      return 1
    done <<< "$(grep -nF "$banned" "$CANON")"
  done
}

@test "the canonical contract keeps the prompt and the log under the generated directory" {
  # 固定パスは並行ジョブ間で上書きし合う。ディレクトリ自体が一意なら中の名前は固定でよい。
  for pat in '/tmp/codex-prompt-' '/tmp/codex-review-'; do
    if grep -qF "$pat" "$CANON"; then
      echo "hint: ${CANON} still uses the fixed path '${pat}'"
      echo "hint: プロンプトとログは mktemp -d で作った専用ディレクトリの配下に置く"
      return 1
    fi
  done
  grep -qF 'out="<dir>/review.log"' "$CANON"
  grep -qF '"${dir}/prompt.txt"' "$CANON"
}

# --- 雛形を実際に走らせる検査（文言検査だけでは落ちない改悪を落とす） ---
#
# 「雛形は実行されるものなのに、実行して確かめていない」ことが、テンプレートの X を
# 16 個から 1 個に減らすような弱体化を素通りさせた原因。ここは文字列ではなく挙動を見る。
#
# 同一プロセス内で 10 回走らせるのは、乱数状態の継承（3 周目の事故: 複数のコマンド置換
# サブシェルが同じ状態を継承して 5 回とも同じ nonce になった）が同一プロセス内でしか
# 現れないから。抽出したブロックを 10 個連結した 1 本のスクリプトを 1 回実行する形にする。
#
# 重複検査が乱数版を落とすかどうかは、走らせるシェルで変わる。16 文字ちょうどに整えた
# $RANDOM 版を 10 個連結して 1 プロセスで走らせた 2026-09-09 の実測では、sh と bash
# （3.2.57）はコマンド置換のサブシェルごとに RANDOM を再シードするので 10 個とも別の値に
# なり、この検査は落ちなかった。一方 zsh（5.9）は 10 個とも完全に同じ値を返し、この検査で
# 落ちた。そしてサブエージェントが実際に走らせる Claude Code の Bash ツールのシェルは zsh
# （`ps -p $$ -o comm=` が `/bin/zsh`）。**zsh を対象から外すと、実行環境そのもので起きる
# 重複を誰も見ていないことになる。**
#
# 対象シェルは sh / bash / zsh。雛形は POSIX 構文（case / ${#var} / ${var##*/} /
# ${var#prefix}）だけなのでいずれでも完走する。入っていないシェルはそれ 1 つだけ飛ばす
# （テスト全体を skip にすると、zsh が無い環境で他の 2 つの検査まで消える）。

@test "step 1 template yields a distinct 16+ char alphanumeric nonce on every call in one process" {
  for shell_bin in sh bash zsh; do
    if ! command -v "$shell_bin" >/dev/null 2>&1; then
      echo "note: ${shell_bin} が無いのでこのシェルだけ飛ばす" >&3
      continue
    fi
    driver="${BATS_TEST_TMPDIR}/driver-${shell_bin}.sh"
    : > "$driver"
    for _ in 1 2 3 4 5 6 7 8 9 10; do cat "$SNIP" >> "$driver"; done
    TMPDIR="$BATS_TEST_TMPDIR" run "$shell_bin" "$driver"
    [ "$status" -eq 0 ]
    nonces="$(printf '%s\n' "$output" | sed -n 's/^nonce=//p')"
    [ "$(printf '%s\n' "$nonces" | wc -l | tr -d ' ')" -eq 10 ]
    while IFS= read -r n; do
      [ "${#n}" -ge 16 ] || { echo "hint: nonce shorter than 16 (${shell_bin}): ${n}"; return 1; }
      case "$n" in *[!A-Za-z0-9]*) echo "hint: non-alphanumeric nonce (${shell_bin}): ${n}"; return 1 ;; esac
    done <<< "$nonces"
    [ "$(printf '%s\n' "$nonces" | sort -u | wc -l | tr -d ' ')" -eq 10 ] || {
      echo "hint: 同一プロセス内の複数回呼び出しで nonce が重複した（${shell_bin}）"
      echo "hint: 一意性は排他生成（mktemp -d）で担保する。乱数に戻すとここで落ちる"
      return 1
    }
  done
}

@test "step 1 template fails loudly instead of degrading when the temp dir cannot be created" {
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  printf '#!/bin/sh\nexit 1\n' > "${BATS_TEST_TMPDIR}/bin/mktemp"
  chmod +x "${BATS_TEST_TMPDIR}/bin/mktemp"
  PATH="${BATS_TEST_TMPDIR}/bin:${PATH}" TMPDIR="$BATS_TEST_TMPDIR" run sh "$SNIP"
  [ "$status" -ne 0 ]
  ! printf '%s\n' "$output" | grep -q '^nonce='
}

@test "step 1 template writes the prompt under the generated directory, not a fixed path" {
  TMPDIR="$BATS_TEST_TMPDIR" run sh "$SNIP"
  [ "$status" -eq 0 ]
  d="$(printf '%s\n' "$output" | sed -n 's/^dir=//p')"
  [ -d "$d" ]
  [ -f "${d}/prompt.txt" ]
  case "$d" in
    "${BATS_TEST_TMPDIR}"/*) ;;
    *) echo "hint: TMPDIR を無視して固定パスに書いている: ${d}"; return 1 ;;
  esac
}

# --- レビュー指示の渡し方（引数埋め込みではなく標準入力） ---
#
# 2 周目のゲート指摘: `codex exec ... "<レビュー指示>"` の形だと、指示文の `"` / ` / $(...) で
# 引数が壊れるか意図しないコマンドが実行される。`codex exec` は `-` で標準入力から指示を読む
# （`codex exec --help` の [PROMPT] の記述、および 2026-09-09 の実測）。

@test "the canonical contract feeds the review prompt through stdin, not the command line" {
  grep -qF 'codex exec -c approval_policy=never -c model_reasoning_effort=medium - < "<dir>/prompt.txt"' "$CANON"
  grep -qF "<<'PROMPT_EOF'" "$CANON"

  for f in "$CANON" "${SUBAGENT_DOCS[@]}"; do
    if grep -qE 'codex exec[^`]*"<レビュー指示>"' "$f"; then
      echo "hint: ${f} embeds the review prompt in the command line"
      echo "hint: 指示文はファイルに保存し codex exec ... - < <プロンプトファイル> で渡す"
      return 1
    fi
  done
}

@test "the canonical contract caps the total wait and defines the fallback trigger" {
  grep -qE '3 回' "$CANON"
  grep -qE '27 分' "$CANON"
  grep -qF 'needs-reviewer' "$CANON"
  grep -q 'タイムアウト' "$CANON"
}

@test "plugin README lists the canonical waiting contract in the references table" {
  grep -qF 'references/subagent-waiting.md' "$README"
}

# --- 手順書側の書き換え ---

@test "gate-runner names both codex launch paths and defers the wait to the canonical contract" {
  # 起動の事実（どのコマンドをどう呼ぶか）は G の指示書に残す
  grep -qF 'codex exec -c approval_policy=never -c model_reasoning_effort=medium' "$RUNNER"
  grep -qF 'codex-companion.mjs' "$RUNNER"
  # 待ち方は正本に委ね、上限に達したときの G 固有の分岐だけを持つ
  grep -qF 'references/subagent-waiting.md' "$RUNNER"
  grep -qE 'ターンを終え(ない|てはならない)' "$RUNNER"
  grep -qF 'needs-reviewer' "$RUNNER"
  grep -q '総待ちの上限' "$RUNNER"
}

@test "spec-reviewer notes that the decider path carries no waiting work" {
  grep -qF 'decider' "$REVIEWER"
  grep -q '待ち' "$REVIEWER"
}

@test "pr-review-gate splits the waiting rule by reader" {
  grep -q 'メインセッション' "$GATE"
  grep -q 'サブエージェント' "$GATE"
  grep -q '前景' "$GATE"
  grep -qF 'references/subagent-waiting.md' "$GATE"
  # 前景上限を超える待ちを散文で示唆する記述を残さない
  ! grep -qF '最長 15 分' "$GATE"
}
