#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# agent-loop-reply.sh — 応答モード（Step 0.9）の返信を投稿し、対応済みにする
#
# 使い方:
#   scripts/agent-loop-reply.sh <issue/PR番号> <comment_id> <本文ファイル>
#
# なぜスクリプトに閉じ込めるか: 応答モードの自己発火防止を **LLM の自己規律に委ねない** ため。
# 検出（agent-loop-inbox.sh）は投稿者を見ないので、エージェントの返信そのものに行頭マーカーが
# 混ざると、その返信が次サイクルの発火条件になり、返信が返信を呼ぶ無限ループになる。
# 「マーカーを書かない」と手順書に書くだけでは、引用返信やマーカー自体の説明で機械的に踏む
# （2026-08-06 実測: 本機能の設計を説明した PR コメントが自分で pending に入った）。
# ここで **投稿前に本文を機械検査** し、混入していれば投稿せず異常終了する。
#
# もう 1 つの役割: **投稿と rocket 付与を 1 コマンドに束ねる**。別々の手順にすると
# 「返信したが rocket を付け忘れた」で同じ用件が毎サイクル再発火する。
#
# 失敗したら**非 0 で落ちる**（検出側 agent-loop-inbox.sh の fail-open とは逆の設計。
# 投稿は副作用なので、黙って成功したことにしない）。
#
# 環境変数:
#   AGENT_INBOX_MARKER         — 検出マーカー（既定 {{AGENT_MENTION}}。検出側と必ず揃える）
#   AGENT_INBOX_DONE_REACTION  — 対応済みリアクション（既定 rocket）
#   GH_REPO                    — 対象リポジトリ（未設定なら gh repo view で解決）
# ─────────────────────────────────────────────────────────────
set -euo pipefail

MARKER="${AGENT_INBOX_MARKER:-{{AGENT_MENTION}}}"
DONE_REACTION="${AGENT_INBOX_DONE_REACTION:-rocket}"

die() { printf 'agent-loop-reply: %s\n' "$1" >&2; exit 1; }

N="${1:-}"
CID="${2:-}"
BODYFILE="${3:-}"

case "$N" in ''|*[!0-9]*) die "第1引数が issue/PR 番号ではない: '${N}'" ;; esac
case "$CID" in ''|*[!0-9]*) die "第2引数が comment_id ではない: '${CID}'" ;; esac
[ -n "$BODYFILE" ] && [ -f "$BODYFILE" ] || die "第3引数の本文ファイルが無い: '${BODYFILE}'"
[ -s "$BODYFILE" ] || die "本文ファイルが空: ${BODYFILE}"

command -v gh >/dev/null 2>&1 || die "gh 未インストール"

REPO="${GH_REPO:-}"
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"
fi
[ -n "$REPO" ] || die "リポジトリを特定できない"

# ── 自己発火ガード: 行頭マーカーの混入を投稿前に止める ──────────────────
# 検出側と同じ「行頭一致」で判定する（引用行 `> @marker` や地の文での言及は検出側でも
# 拾われないので、ここでも許す。止めるのは**呼びかけとして行頭に書いた場合**だけ）。
# 検出側の規則を変えるときは必ずここも合わせる。
if awk -v m="$MARKER" '{ line = $0; sub(/^[ \t]+/, "", line); if (index(line, m) == 1) { found = 1 } }
                       END { exit(found ? 0 : 1) }' "$BODYFILE"; then
  die "返信本文の行頭に ${MARKER} がある（投稿すると次サイクルで自分の返信に応答し続ける）。引用するなら行頭に > を付けるか、バッククォートで囲むこと"
fi

# ── 返信を投稿する ────────────────────────────────────────────
# -F でファイルを読む（-f = --raw-field は @file を静的文字列として送るため、
# 本文の代わりに文字列 "@file" が投稿される。author は正しいので「応答済み」と
# 判定され、人間への回答が失われたまま消える）
POSTED="$(gh api -X POST "repos/$REPO/issues/$N/comments" -F "body=@$BODYFILE" --jq '.html_url')" \
  || die "返信の投稿に失敗した（issue/PR #${N}）"
[ -n "$POSTED" ] || die "投稿レスポンスから URL を取得できない（投稿できたか不明。手動で確認すること）"

# ── 対応済みにする（これをやらないと同じ用件で毎サイクル再発火する）──────────
gh api -X POST "repos/$REPO/issues/comments/$CID/reactions" -f content="$DONE_REACTION" >/dev/null \
  || die "返信は投稿できたが rocket を付けられなかった（${POSTED}）。手動で付けること: gh api -X POST repos/${REPO}/issues/comments/${CID}/reactions -f content=${DONE_REACTION}"

# 実測確認（gh は静かに失敗しうるので、付いたことを読み直して確かめる）
if ! gh api "repos/$REPO/issues/comments/$CID" --jq ".reactions.${DONE_REACTION}" 2>/dev/null | grep -qvx '0'; then
  die "rocket を付けたはずが実測で 0 件（${POSTED}）。手動で確認すること"
fi

printf '%s\n' "$POSTED"
