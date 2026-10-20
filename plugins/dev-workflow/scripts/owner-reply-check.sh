#!/usr/bin/env bash
# owner-reply-check.sh — 主が会話で返した許容の発言が、そのセッションの会話ログに主の発言として実在するかを確かめる。
#
# 使い方（3 つ）:
#   owner-reply-check.sh <セッション ID> <原文>                 既定の使い方（引数がちょうど 2 個でなければ exit 2）
#   owner-reply-check.sh --locate <セッション ID> <原文>        主の発言の場所（uuid）を引く（エピックの親が使う。issue #1059）
#   owner-reply-check.sh --relayed <セッション ID> <uuid> <停止の記録の作成日時> <停止の記録の URL>
#                                                              親経由の返事を親の会話ログの場所で確かめる（エピックの子と G が使う）
#   --locate と --relayed の引数の数は各自のもの（2 個 / 4 個）で、違えば exit 2。
#   読むのは ${OWNER_REPLY_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}/*/<セッション ID>.jsonl だけ
#   （<セッション ID>/subagents/ の下は読まない）。OWNER_REPLY_PROJECTS_DIR はテスト用の差し替え口。
# 比べ方: 原文と各発言の本文の連続する空白（改行を含む）を 1 個の空白にまとめ、前後の空白を落として部分一致。
# 主の発言として数える行（すべて満たすもの。3 つの使い方で同じ）:
#   1. type が "user"            2. isSidechain が true でない
#   3. isMeta が true でない（4 のチャンネルの行は除かない。実物は isMeta: true で残る）
#   4. origin のキーがあるなら（null を含む）origin.kind が "human"、または "channel" で次のすべてを満たす（issue #1125）:
#      origin.server が空でない文字列／本文が先頭の空白なしに開きタグ <channel( 名前="値")*>＋改行で始まる／
#      属性名に重複が無い／source 属性が origin.server と同じ／user_id 属性が空でない／
#      末尾（後ろの空白を除く）が改行＋</channel>／(origin.server, user_id) が OWNER_REPLY_CHANNEL_SENDERS にある／
#      中身に </channel> や <channel の形のタグが無く（1 行に塊がちょうど 1 つ）、content が文字列か text 部品 1 つの配列。
#      OWNER_REPLY_CHANNEL_SENDERS は <server>=<ID> を空白かカンマで区切って並べる（例 plugin:discord:discord=<主の Discord ID>）。
#      未設定か空ならチャンネルの行は数えない。チャンネルの行は開きタグと閉じタグを外した中身を本文とし、6・7・9 は中身に当てる。
#      照合にユーザー名（user 属性）は使わない。
#   5. message.content が文字列、または type:"text" の要素だけの配列（tool_result を含む配列は数えない）
#   6. 本文が "Another Claude session sent a message" で始まらず、"<teammate-message" を含まない
#   7. 本文が <bash-stdout> / <bash-stderr> / <local-command-stdout> / <local-command-stderr> で始まらない
#   8. isCompactSummary が true でない（会話の圧縮後にモデルが書いた要約の行。本文の書き出しでは判定しない）
#   9. 本文（先頭の空白を除く）が "主の返事（親エピック #" / "親エピック #" で始まらず、<command-args> の中身
#      （先頭の空白を除く）が "#<数字> （エピック #<数字> の子。" で始まらない（エピックの親が子の端末に打ち込んだ返事と、
#      子を起動する指示）。<command-args> の頭の出どころは scripts/epic-dispatch.sh の次の 2 つの文字列で、
#      ここはそれに結び付いている（epic-dispatch.sh の文を変えたらこの条件と bats の入力も直す）:
#        launch（epic-dispatch.sh の cmd_launch の prompt=）:            /develop #$n （エピック #$epic の子。親ワークツリー $parent から Orca で起動）
#        reply --relaunch（epic-dispatch.sh の deliver_reply の prompt=）: /develop #$n （エピック #$epic の子。返事を受けて起動し直し） $msg
#   <command-args>（スラッシュコマンドの引数）と <bash-input>（主が ! で打った入力）は、9 に当たらなければタグごと本文として比べる。
# 出力:
#   既定:      一致した発言ごとに "MATCH: <timestamp> <空白をまとめた本文の全文>"、最後に "MATCHES=<件数>"
#   --locate:  一致した発言ごとに "MATCH: <timestamp> <uuid> <空白をまとめた本文の全文>"（uuid の無い行は出さず数えない）、
#              最後に "MATCHES=<件数>"
#   --relayed: 通れば "MATCH: <timestamp> <空白をまとめた本文の全文>" と "MATCHES=1"。落ちたら "REASON=<理由>" と "MATCHES=0"
#              理由は次の順に確かめる: not-found（その uuid の行が無い）→ not-owner（主の発言の 9 条件を満たさない）
#              → not-after（その行の timestamp が停止の記録の作成日時より後でない）→ not-asked（作成日時より後でその行より前の
#              親の発言（type:"assistant"・isSidechain が true でない）の text の本文に停止の記録の URL が無い）
#              → not-direct（URL を書いた最後の親の発言とその行のあいだに、別の主の発言がある）
# 終了コード: 0 = 一致（--relayed は通った）/ 1 = 一致なし（--relayed は REASON の付く落ち）/
#   2 = 引数の不備・UUID でない ID・空の原文・日時を読めない・https で始まらない URL・会話ログなし・python3 なし・
#       空白をまとめると空になる原文・会話ログを読めない・--relayed で指した行の timestamp を読めない・
#       OWNER_REPLY_CHANNEL_SENDERS に <server>=<ID> の形でない項目がある（空の項目は数えない）
#   （2 は「確かめられない」。呼び出し側は 1 と同じく通さない側に倒す）
#
# 許容の意思は見ない（部分一致なので「許容しない」の一部の「許容」も一致する）。呼び出し側（pr-review-gate 手順 5）が
# MATCH 行の全文で読む。会話ログの改変と、Orca の親セッションが決まった頭を付けずに子のターミナルに打ち込んだ文
# （origin.kind が human で残る）は区別できない（spec の守備範囲を参照）。
set -euo pipefail

UUID_RE='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
mode="default"
case "${1:-}" in
  --locate) mode="locate"; shift ;;
  --relayed) mode="relayed"; shift ;;
esac

excerpt=""; target_uuid=""; stop_at=""; stop_url=""
case "$mode" in
  default|locate)
    if [ "$#" -ne 2 ]; then
      echo "usage: $0 [--locate] <session-id> <excerpt>" >&2
      exit 2
    fi
    session_id="$1"; excerpt="$2"
    ;;
  relayed)
    if [ "$#" -ne 4 ]; then
      echo "usage: $0 --relayed <session-id> <uuid> <stop-record-created-at> <stop-record-url>" >&2
      exit 2
    fi
    session_id="$1"; target_uuid="$2"; stop_at="$3"; stop_url="$4"
    ;;
esac

if ! [[ "$session_id" =~ $UUID_RE ]]; then
  echo "owner-reply-check: session id is not a UUID: $session_id" >&2
  exit 2
fi

if [ "$mode" = "relayed" ]; then
  if ! [[ "$target_uuid" =~ $UUID_RE ]]; then
    echo "owner-reply-check: uuid is not a UUID: $target_uuid" >&2
    exit 2
  fi
  case "$stop_url" in
    https://?*) ;;
    *) echo "owner-reply-check: stop record URL does not start with https://: $stop_url" >&2; exit 2 ;;
  esac
elif [ -z "${excerpt//[[:space:]]/}" ]; then
  echo "owner-reply-check: excerpt is blank" >&2
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "owner-reply-check: python3 not found" >&2
  exit 2
fi

projects_dir="${OWNER_REPLY_PROJECTS_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects}"

logs=()
for f in "$projects_dir"/*/"$session_id".jsonl; do
  [ -f "$f" ] && logs+=("$f")
done
if [ "${#logs[@]}" -eq 0 ]; then
  echo "owner-reply-check: no conversation log for session $session_id under $projects_dir" >&2
  exit 2
fi

PYTHONDONTWRITEBYTECODE=1 python3 -I - "$mode" "$excerpt" "$target_uuid" "$stop_at" "$stop_url" "${logs[@]}" <<'PY'
import datetime
import json
import os
import re
import sys

FORWARD_PREFIX = "Another Claude session sent a message"
OUTPUT_PREFIXES = ("<bash-stdout>", "<bash-stderr>", "<local-command-stdout>", "<local-command-stderr>")
# 9 つ目の条件（issue #1059）。出どころは冒頭の説明（epic-dispatch.sh の cmd_launch / deliver_reply の prompt=）
RELAY_PREFIXES = ("主の返事（親エピック #", "親エピック #")
DISPATCH_ARGS = re.compile(r"<command-args>\s*#\d+\s*（エピック #\d+ の子。")
# チャンネル経由の行（issue #1125）。開きタグは Claude Code がチャンネルプラグインの通知の meta から組み立てて本文の先頭に置く
CHANNEL_OPEN = re.compile(r'<channel((?: [A-Za-z_][A-Za-z0-9_]*="[^"\n]*")*)>\n')
CHANNEL_ATTR = re.compile(r' ([A-Za-z_][A-Za-z0-9_]*)="([^"\n]*)"')
CHANNEL_CLOSE = "\n</channel>"
# 中身にチャンネルのタグがあれば数えない（1 行に塊が 2 つ以上あると、続きの塊の送信者を確かめられないため）
CHANNEL_TAG = re.compile(r"</?channel[\s>]")
SENDERS_ENV = "OWNER_REPLY_CHANNEL_SENDERS"
SENDER_ITEM = re.compile(r"[^=\s,]+=[^=\s,]+")


def load_channel_senders():
    """OWNER_REPLY_CHANNEL_SENDERS を (server, ID) の組の集合にする。形の誤りは exit 2（確かめられない）。"""
    raw = os.environ.get(SENDERS_ENV, "")
    senders = set()
    for item in re.split(r"[\s,]+", raw):
        if not item:
            continue
        if not SENDER_ITEM.fullmatch(item):
            sys.stderr.write("owner-reply-check: %s has a malformed entry (expected <server>=<id>): %s\n" % (SENDERS_ENV, item))
            sys.exit(2)
        server, sender = item.split("=", 1)
        senders.add((server, sender))
    return senders


CHANNEL_SENDERS = load_channel_senders()


def channel_inside(origin, text, part_count):
    """チャンネルの行の送信者が許可されていれば、開きタグと閉じタグを外した中身を返す。読めない・許可されていなければ None。"""
    if part_count != 1:  # content が 2 つ以上の text 部品の配列なら数えない
        return None
    server = origin.get("server")
    if not isinstance(server, str) or not server:
        return None
    head = CHANNEL_OPEN.match(text)
    if head is None:
        return None
    attrs = CHANNEL_ATTR.findall(head.group(1))
    names = [name for name, _ in attrs]
    if len(names) != len(set(names)):
        return None
    attr = dict(attrs)
    if attr.get("source") != server or not attr.get("user_id"):
        return None
    # 末尾（後ろの空白を除く）が改行のあとの </channel>。閉じタグの前の改行は開きタグの行末の改行と兼ねてよい（中身が空のとき）
    full = text.rstrip()
    end = len(full) - len(CHANNEL_CLOSE)
    if not full.endswith(CHANNEL_CLOSE) or end < head.end() - 1:
        return None
    if (server, attr["user_id"]) not in CHANNEL_SENDERS:
        return None
    inside = full[head.end():end]
    if CHANNEL_TAG.search(inside):
        return None
    return inside


def norm(text):
    return re.sub(r"\s+", " ", text).strip()


def owner_text(rec):
    """主の発言なら本文を、そうでなければ None を返す。"""
    if not isinstance(rec, dict) or rec.get("type") != "user":
        return None
    if rec.get("isSidechain") is True:
        return None
    if rec.get("isCompactSummary") is True:  # 会話の圧縮後にモデルが書いた要約（issue #756）
        return None
    channel = None
    if "origin" in rec:
        origin = rec.get("origin")
        if not isinstance(origin, dict) or origin.get("kind") not in ("human", "channel"):
            return None
        if origin.get("kind") == "channel":
            channel = origin
    # isMeta はチャンネルの行だけ見ない（実物のチャンネルの行は isMeta: true で残る。送信者の確かめで代える。issue #1125）
    if channel is None and rec.get("isMeta") is True:
        return None
    message = rec.get("message")
    if not isinstance(message, dict):
        return None
    content = message.get("content")
    if isinstance(content, str):
        text = content
        part_count = 1
    elif isinstance(content, list) and content:
        parts = []
        for item in content:
            if not isinstance(item, dict) or item.get("type") != "text" or not isinstance(item.get("text"), str):
                return None
            parts.append(item["text"])
        text = "\n".join(parts)
        part_count = len(parts)
    else:
        return None
    if channel is not None:
        text = channel_inside(channel, text, part_count)
        if text is None:
            return None
    stripped = text.lstrip()
    if stripped.startswith(FORWARD_PREFIX) or "<teammate-message" in text:
        return None
    if stripped.startswith(OUTPUT_PREFIXES):
        return None
    if stripped.startswith(RELAY_PREFIXES) or DISPATCH_ARGS.search(text):
        return None
    return text


def parse_time(value):
    """ISO 8601 の日時を UTC の aware な datetime にする。読めなければ None（タイムゾーンの無い値も読めない扱い）。"""
    if not isinstance(value, str):
        return None
    text = value.strip()
    if text.endswith(("Z", "z")):
        text = text[:-1] + "+00:00"
    try:
        when = datetime.datetime.fromisoformat(text)
    except ValueError:
        return None
    if when.tzinfo is None:
        return None
    return when.astimezone(datetime.timezone.utc)


def read_records(paths):
    for path in paths:
        try:
            with open(path, encoding="utf-8", errors="replace") as handle:
                for line in handle:
                    try:
                        yield json.loads(line)
                    except ValueError:
                        continue
        except OSError as err:
            sys.stderr.write("owner-reply-check: cannot read %s: %s\n" % (path, err))
            sys.exit(2)


def assistant_texts(rec):
    message = rec.get("message")
    content = message.get("content") if isinstance(message, dict) else None
    if isinstance(content, str):
        return [content]
    texts = []
    if isinstance(content, list):
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text" and isinstance(item.get("text"), str):
                texts.append(item["text"])
    return texts


def fail(reason):
    print("REASON=%s" % reason)
    print("MATCHES=0")
    sys.exit(1)


def relayed(target_uuid, stop_at_text, stop_url, paths):
    stop_at = parse_time(stop_at_text)
    if stop_at is None:
        sys.stderr.write("owner-reply-check: cannot read the stop record time: %s\n" % stop_at_text)
        sys.exit(2)
    records = [rec for rec in read_records(paths) if isinstance(rec, dict)]
    target = next((rec for rec in records if rec.get("uuid") == target_uuid), None)
    if target is None:
        fail("not-found")
    text = owner_text(target)
    if text is None:
        fail("not-owner")
    said_at = parse_time(target.get("timestamp"))
    if said_at is None:
        sys.stderr.write("owner-reply-check: cannot read the timestamp of %s\n" % target_uuid)
        sys.exit(2)
    if not said_at > stop_at:
        fail("not-after")
    # 停止の記録の URL は完全一致で探す。前後が URL を続ける文字のときは別の URL の一部なので数えない
    # （…#issuecomment-123 が …#issuecomment-1234 に部分一致しないように）。文末の . や括弧・句読点は URL を続けない文字として扱う
    url_re = re.compile(r"(?<![A-Za-z0-9_\-.~/:%%?#&=+@])%s(?![A-Za-z0-9_\-~/%%?#&=+@])" % re.escape(stop_url))
    # 結び付けは URL を書いた最後の親の発言の時刻で取り、そこから主の発言までに別の主の発言があれば落とす
    # （親が報告したあとに主が別の件へ返した名指しの無い答えを、この止まりへの返事として通さないため）
    asked_at = None
    for rec in records:
        if rec.get("type") != "assistant" or rec.get("isSidechain") is True:
            continue
        when = parse_time(rec.get("timestamp"))
        if when is None or not (stop_at < when < said_at):
            continue
        if any(url_re.search(part) for part in assistant_texts(rec)):
            asked_at = when if asked_at is None else max(asked_at, when)
    if asked_at is None:
        fail("not-asked")
    for rec in records:
        when = parse_time(rec.get("timestamp"))
        if when is not None and asked_at < when < said_at and owner_text(rec) is not None:
            fail("not-direct")
    print("MATCH: %s %s" % (target.get("timestamp", ""), norm(text)))
    print("MATCHES=1")
    sys.exit(0)


mode, raw_excerpt, target_uuid, stop_at_text, stop_url = sys.argv[1:6]
paths = sys.argv[6:]
if mode == "relayed":
    relayed(target_uuid, stop_at_text, stop_url, paths)

excerpt = norm(raw_excerpt)
if not excerpt:
    sys.stderr.write("owner-reply-check: excerpt is blank after normalizing whitespace\n")
    sys.exit(2)
matches = 0
found = []
for rec in read_records(paths):
    text = owner_text(rec)
    if text is None:
        continue
    body = norm(text)
    if excerpt not in body:
        continue
    if mode == "locate":
        uuid = rec.get("uuid")
        if not isinstance(uuid, str) or not uuid:
            continue
        found.append("MATCH: %s %s %s" % (rec.get("timestamp", ""), uuid, body))
    else:
        found.append("MATCH: %s %s" % (rec.get("timestamp", ""), body))
    matches += 1
for entry in found:
    print(entry)
print("MATCHES=%d" % matches)
sys.exit(0 if matches else 1)
PY
