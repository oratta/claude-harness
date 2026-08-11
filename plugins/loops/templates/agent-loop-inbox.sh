#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# agent-loop-inbox.sh — 人間が「これを見てほしい」と印を付けたコメントを検出する
#
# なぜ存在するか: 人間が issue にコメントを書いても、ラベルや Review Queue の State を
# 変えなければループはそれを一生拾わない（選定スクリプトはラベルしか見ない）。
# 結果「質問に答えた」「追加情報を書いた」がループに届かず issue が黙って停滞し、
# 人間は「書いても無駄」と学習する。ここを埋める。
#
# **投稿者アカウントで人間かどうかを判定しない**。エージェントには人間の GitHub トークンも
# 渡してあることが多く、エージェントが人間のアカウントで書き込む運用は普通に起きる。
# したがってアカウント名が分かっても「本当に人間本人が書いたか」は原理的に判別できない。
# 旧実装はこの成立しない前提の上に状態ファイル・持ち越し・identity ガードを積み上げ、
# レビュー3周ぶんの欠陥がすべてその機構の内部から出た。
#
# 検出の定義（本文のマーカーだけを見る）:
#   **コメント本文の「行頭」に ${MARKER}（既定 {{AGENT_MENTION}}）が現れ、
#     かつ「対応済み」リアクションが付いていない** → 未対応。
# 人間が意図して書いたときにだけ付く印なので、誰が投稿したかを一切問わない。
#
# **なぜ「行頭」に限るか（ここを緩めてはならない）**: 単純な部分一致にすると、
#   - 引用返信（`> {{AGENT_MENTION}} これ見て`）で応答コメント自体が次の発火条件になる
#   - **仕組みの説明で言及しただけ**（「`{{AGENT_MENTION}}` マーカーで判定する」等）でも発火する
# の 2 経路で自己発火し、返信が返信を呼ぶ無限ループになる（後者は 2026-08-06 に実測:
# 本機能の設計を説明した PR コメントが自分で pending に入った）。
# 行頭限定なら、引用行は `>` が先に来るため一致せず、地の文の言及も
# バッククォート等が先に来るため一致しない。**呼びかけとして行頭に書いたときだけ**発火する。
#
# 「対応済み」の状態は GitHub 側に置く（**ローカル状態ファイルを持たない**）:
#   対応したらそのコメントに ${DONE_REACTION}（既定 rocket 🚀）を付ける。付いていない
#   マーカー付きコメントだけが未対応。誰が付けたかは問わない（対応時にしか付けないため）。
#   GitHub のリアクションに ✅ は無いので rocket を「対応済み」の機械マーカーに使う
#   （👍 や 👀 は人が気軽に付けるため、機械の状態としては使わない）。
#   → 状態ファイル・watermark・持ち越しが一切要らない。壊れる状態を持たない。
#
# 走査コスト（全件一覧の取得は一切しない）:
#   1. 検索 API 1 回で「マーカーを含む issue/PR」を取る（全期間・PR も同じ
#      エンドポイントに乗る）。
#   2. その item のコメントだけを引き、マーカー ∧ 未リアクションで絞る。
#   → 印が付いていない大半のサイクルは **検索 1 回・LLM トークン 0**。
#
# 出力契約（agent-loop-select.sh と同じ流儀）:
#   stdout に JSON 1 オブジェクト・診断は stderr・**どんな失敗でも exit 0（fail-open）**。
#   {"pending":[{"number":94,"kind":"issue","author":"someone","comment_id":123,
#                "commented_at":"2026-08-04T01:02:03Z","excerpt":"先頭200字"}]}
#   pending は commented_at 昇順（＝最も長く待たされている印が先頭）。
#   author は「どのアカウントから投稿されたか」の参考情報で、**判定には使わない**。
#
# 環境変数:
#   AGENT_INBOX_MARKER         — 検出マーカー（既定 {{AGENT_MENTION}}）
#   AGENT_INBOX_DONE_REACTION  — 対応済みリアクション（既定 rocket）
#   GH_REPO                    — 対象リポジトリ（未設定なら gh repo view で解決）
# ─────────────────────────────────────────────────────────────
set -uo pipefail

MARKER="${AGENT_INBOX_MARKER:-{{AGENT_MENTION}}}"
DONE_REACTION="${AGENT_INBOX_DONE_REACTION:-rocket}"
EXCERPT_LEN=200

# fail-open: 検出できなかったときは「未対応なし」を返して静かに終わる。
# ここを非0で落とすと gate / select がそのサイクルを丸ごと失う（＝ループを止める）。
bail() { [ -n "${1:-}" ] && printf 'agent-loop-inbox: %s\n' "$1" >&2; printf '{"pending":[]}\n'; exit 0; }

command -v jq >/dev/null 2>&1 || bail "jq 未インストール (fail-open)"
command -v gh >/dev/null 2>&1 || bail "gh 未インストール (fail-open)"

REPO="${GH_REPO:-}"
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
fi
[ -n "$REPO" ] || bail "リポジトリを特定できない (fail-open)"

# ── 1. マーカーを含む issue/PR を検索 API 1 回で取る ──────────────────────
# 検索語は `@` を落とした語幹にする（GitHub の検索は `@` を語の一部として扱わないため。
# マーカーそのものの一致は 2. で本文を実測して確かめるので、ここは候補を絞るだけ）。
#
# **state で絞らない**: closed の issue/PR に印を付けるのも正当な使い方
# （「これ直ってない、見て」など）で、open に限ると reopen されるまで恒久的に検出できない。
# 検出できない条件を静かに持たない方を優先する。
#
# **--paginate で全ページ取る**: 上限で切ると、超過分は誰かが再度動かすまで永久に
# 走査されない（検索対象はコメント本文なので、対応して rocket を付けても検索結果からは
# 消えない＝同じ順序なら毎回同じ先頭 N 件しか見ない）。永久滞留を作らないため、
# 切らずに全部見る。候補数は stderr に出して増えすぎに気づけるようにする。
MARKER_TERM="$(printf '%s' "$MARKER" | sed 's/^@//')"
if ! FOUND_RAW="$(gh api --paginate "search/issues?q=repo:$REPO+$MARKER_TERM+in:comments&per_page=100" 2>/dev/null)"; then
  bail "検索 API 失敗 (fail-open)"
fi
# --paginate はページごとの JSON オブジェクトを連結して出すので items を畳んで 1 本にする
FOUND="$(printf '%s' "$FOUND_RAW" | jq -s -c '{ items: (map(.items // []) | add // []) }' 2>/dev/null || true)"
[ -n "$FOUND" ] || bail "検索レスポンスの結合に失敗 (fail-open)"
printf '%s' "$FOUND" | jq -e 'type == "object" and (.items | type) == "array"' >/dev/null 2>&1 \
  || bail "検索 API のレスポンスが想定形でない (fail-open)"

# 除外ラベル（判断の根拠は憲法「ラベル定義」の各行）:
#   human-only … 「ループは触らない（秘密情報・外部アカウント・設計判断など）」。
#                 ここを漏らすと触ってはいけない issue にループが自動返信する。
#   agent-wip  … 「ループが着手中（二重着手防止）」。着手中サイクルが終われば wip が
#                 外れ、次の tick で自然に拾われる（取りこぼしではなく最大1サイクルの遅延）。
# **agent-blocked は意図的に除外しない**: 「2回失敗して隔離。人間の判断待ち」＝まさに
# 人間のコメントが隔離を解く情報である状態で、ここを除外すると最も応答が必要な issue で
# 目的が失われる。needs-approval / agent-proposed / size:large も同様に除外しない
# （「会話してよいか」は「実装に着手してよいか」とは別の判断）。
TARGETS="$(printf '%s' "$FOUND" | jq -r '
  [ .items[]
    | ([.labels[]?.name]) as $l
    | select(($l | index("human-only")) == null)
    | select(($l | index("agent-wip")) == null)
    | [ (.number | tostring), (if .pull_request then "pr" else "issue" end) ]
    | @tsv ]
  | unique | .[]' 2>/dev/null || true)"

# ── 2. 各 item のコメントを引き、マーカー ∧ 未リアクションで絞る ─────────────
REC="$(mktemp 2>/dev/null || printf '')"
[ -n "$REC" ] || bail "一時ファイルを作れない (fail-open)"
trap 'rm -f "$REC"' EXIT

SCANNED=0
FAILED=0
while IFS="$(printf '\t')" read -r n kind; do
  [ -n "$n" ] || continue
  # 取得失敗を握り潰さない: 「未対応なし」と同一視すると、レート制限や 5xx を 1 回
  # 引いただけでその item の印を取りこぼす。件数を stderr に出して運用者が区別できるようにする。
  if ! CMTS="$(gh api --paginate "repos/$REPO/issues/$n/comments?per_page=100" 2>/dev/null)"; then
    FAILED=$((FAILED + 1))
    continue
  fi
  SCANNED=$((SCANNED + 1))
  # --paginate はページごとの配列を連結して出す（`[..][..]`）ので jq -s で 1 本に畳む。
  printf '%s' "$CMTS" | jq -s -c \
    --argjson n "$n" --arg kind "$kind" --arg marker "$MARKER" \
    --arg donereact "$DONE_REACTION" --argjson len "$EXCERPT_LEN" '
    add // []
    | .[]
    # 行頭一致だけを拾う（引用行 `> @marker` と地の文での言及を構造的に除外する）。
    # 動的な正規表現エスケープを避けるため、行の先頭空白だけを固定パターンで落として
    # 素の前方一致で判定する。
    | select(((.body // "") | gsub("\r"; "") | split("\n")
              | map(select(sub("^[ \t]+"; "") | startswith($marker)))
              | length) > 0)
    | select((.reactions[$donereact] // 0) == 0)
    | { number: $n, kind: $kind, author: (.user.login // ""),
        comment_id: (.id // 0), commented_at: (.created_at // ""),
        excerpt: ((.body // "") | gsub("\\s+"; " ") | .[0:$len]) }' 2>/dev/null >> "$REC" || true
done <<EOF
$TARGETS
EOF

OUT="$(jq -s -c 'sort_by((.commented_at // ""), .number, .comment_id) | { pending: . }' "$REC" 2>/dev/null || true)"
[ -n "$OUT" ] || bail "pending の合成に失敗 (fail-open)"

# 失敗件数を必ず出す。ここを黙らせると「本当に未対応 0 件」と「取得できなかったので
# 分からない」が運用者から区別できなくなる。
printf 'agent-loop-inbox: marker=%s 候補=%s件 走査=%s件 取得失敗=%s件 未対応=%s件\n' \
  "$MARKER" \
  "$(printf '%s' "$FOUND" | jq '.items | length' 2>/dev/null || printf '?')" \
  "$SCANNED" "$FAILED" \
  "$(printf '%s' "$OUT" | jq '.pending | length' 2>/dev/null || printf '?')" >&2

printf '%s\n' "$OUT"
