#!/usr/bin/env python3
"""Read a child's conversation log for epic-dispatch.sh (wait, pending-owner, child-log).

  child-log-read.py <dir>            print one JSON object, or exit 1 when no log is readable
  child-log-read.py --keepalive-text print the fixed keepalive request

<dir> is the child worktree's transcript directory. Only *.jsonl directly under it that
have a line with entrypoint == "cli" are logs; the newest by last timestamp is read
(hook-started sessions share the directory). Subagent logs under <dir>/<session>/subagents/
count for the last activity only. Nothing is written and no model is called.

The format is Claude Code's private one, so lines are picked by kind, never by position:
a turn ends at a system/turn_duration line, a background task starts at
toolUseResult.backgroundTaskId (Bash) or status async_launched + agentId (Agent) and ends
at a <task-notification> with its <task-id>.

An input is an owner's or parent's message or the answer to a question tool. The keepalive
round trip and background notifications are not inputs and do not end a turn.
An unanswered AskUserQuestion is the child's latest statement: uuid and at come from its
line, while text stays the last text the child wrote.

JSON keys: session, uuid, at, text, questions, turn_ended, bg_running, last_input_at,
input_after, last_activity_at, last_activity_epoch, owner ({at, text} or null).
Empty values are "" (null for owner). input_after compares line order, not timestamps.

The spec is dev-workflow-develop "wait・pending-owner・child-log は子の会話ログを同じ読み取りで読む".
"""
import datetime
import glob
import json
import os
import re
import sys

DEFINITION = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "references", "child-cache-keepalive.json"
)
TASK_ID = re.compile(r"<task-id>([^<]+)</task-id>")


def load_keepalive():
    with open(DEFINITION, encoding="utf-8") as f:
        return json.load(f)


def keepalive_request(definition):
    shape = definition["separator"].join(
        [definition["reply_prefix"]] + [field + " <値>" for field in definition["fields"]]
    )
    return definition["request_template"].format(reply_format=shape)


def keepalive_reply(definition, s):
    if "\n" in s or "\r" in s:
        return False
    parts = s.split(definition["separator"])
    if len(parts) != len(definition["fields"]) + 1 or parts[0] != definition["reply_prefix"]:
        return False
    for part, field in zip(parts[1:], definition["fields"]):
        label = field + " "
        if not part.startswith(label):
            return False
        value = part[len(label):]
        if not value.strip() or definition["separator"].strip() in value:
            return False
    return True


def parse(ts):
    try:
        t = datetime.datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except Exception:
        return None
    if t.tzinfo is None:
        t = t.replace(tzinfo=datetime.timezone.utc)
    return t


def text_of(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list) and content and all(isinstance(b, dict) and b.get("type") == "text" for b in content):
        return "\n".join(str(b.get("text", "")) for b in content)
    return None


def read_rows(path):
    """(last timestamp, whether a cli line exists, rows) of one log file."""
    last = None
    cli = False
    rows = []
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                d = json.loads(line)
            except Exception:
                continue
            if not isinstance(d, dict):
                continue
            ts = d.get("timestamp")
            t = parse(ts) if isinstance(ts, str) else None
            if t is not None and (last is None or t > last):
                last = t
            cli = cli or d.get("entrypoint") == "cli"
            if d.get("type") in ("user", "assistant", "system", "queue-operation"):
                rows.append((t, d))
    return last, cli, rows


def newest_log(directory):
    best = None
    for p in glob.glob(os.path.join(directory, "*.jsonl")):
        try:
            last, cli, rows = read_rows(p)
        except OSError:
            continue
        if cli and last is not None and (best is None or last > best[0]):
            best = (last, p, rows)
    return best


def subagent_activity(directory, session):
    best = None
    for p in glob.glob(os.path.join(directory, session, "subagents", "*.jsonl")):
        try:
            last = read_rows(p)[0]
        except OSError:
            continue
        if last is not None and (best is None or last > best):
            best = last
    return best


def is_notification(d, content):
    origin = d.get("origin")
    if isinstance(origin, dict) and origin.get("kind") == "task-notification":
        return True
    return isinstance(content, str) and content.lstrip().startswith("<task-notification")


def owner_text(s):
    """The owner's words in a user message, or None when it is not the owner's."""
    st = s.lstrip()
    m = st.find("主の返事（親エピック #")
    if m > 0:
        return st[m:].split("</command-args>")[0]
    if st.startswith("親エピック #") or "<command-name>" in st or st.startswith("/develop"):
        return None
    return st


def walk(rows, definition):
    keepalive = keepalive_request(definition)
    owner = child = last_input = None
    input_index = -1
    awaiting_keepalive = False
    turn_ended = False
    asked = {}
    started = set()
    finished = set()

    def finish(content):
        if isinstance(content, str):
            finished.update(TASK_ID.findall(content))

    for i, (t, d) in enumerate(rows):
        kind = d.get("type")
        if kind == "queue-operation":
            finish(d.get("content"))
            continue
        if d.get("isSidechain"):
            continue
        if kind == "system":
            if d.get("subtype") == "turn_duration":
                turn_ended = True
            continue
        msg = d.get("message")
        if not isinstance(msg, dict):
            continue
        content = msg.get("content")
        if kind == "user":
            result = d.get("toolUseResult")
            if isinstance(result, dict):
                if isinstance(result.get("backgroundTaskId"), str):
                    started.add(result["backgroundTaskId"])
                if result.get("status") == "async_launched" and isinstance(result.get("agentId"), str):
                    started.add(result["agentId"])
        if t is None or d.get("isMeta") or d.get("isCompactSummary"):
            continue
        if kind == "user":
            if is_notification(d, content):
                finish(content if isinstance(content, str) else text_of(content))
                continue
            if isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "tool_result" and b.get("tool_use_id") in asked:
                        del asked[b["tool_use_id"]]
                        last_input = d["timestamp"]
                        input_index = i
                        turn_ended = False
            s = text_of(content)
            if s is None or not s.strip() or s.lstrip().startswith("<local-command-"):
                continue
            # Exact, unabridged reserved input, including when the owner typed it.
            if s == keepalive:
                awaiting_keepalive = True
                continue
            # A real user turn (including a parent judgment) ends correspondence.
            awaiting_keepalive = False
            last_input = d["timestamp"]
            input_index = i
            turn_ended = False
            said = owner_text(s)
            if said is not None:
                owner = (d["timestamp"], said)
        else:
            if d.get("isApiErrorMessage"):
                continue
            turn_ended = False
            if isinstance(content, list):
                for b in content:
                    if isinstance(b, dict) and b.get("type") == "tool_use" and b.get("name") == "AskUserQuestion":
                        questions = b.get("input", {}).get("questions") if isinstance(b.get("input"), dict) else None
                        asked[b.get("id")] = (
                            i,
                            d.get("uuid") or "",
                            d["timestamp"],
                            [q["question"] for q in questions or [] if isinstance(q, dict) and isinstance(q.get("question"), str)],
                        )
            s = text_of(content)
            if s is None or not s.strip():
                continue
            matched = awaiting_keepalive and keepalive_reply(definition, s)
            awaiting_keepalive = False
            if matched:
                continue
            child = {"index": i, "uuid": d.get("uuid") or "", "at": d["timestamp"], "text": s}

    questions = []
    text = child["text"] if child else ""
    for i, uuid, at, asked_now in sorted(asked.values(), key=lambda v: v[0]):
        questions.extend(asked_now)
        if child is None or i > child["index"]:
            child = {"index": i, "uuid": uuid, "at": at, "text": text}
    return {
        "uuid": child["uuid"] if child else "",
        "at": child["at"] if child else "",
        "text": text,
        "questions": questions,
        "turn_ended": turn_ended,
        "bg_running": bool(started - finished),
        "last_input_at": last_input or "",
        "input_after": child is not None and input_index > child["index"],
        "owner": {"at": owner[0], "text": owner[1]} if owner else None,
    }


def main(argv):
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 1
    definition = load_keepalive()
    if argv[1] == "--keepalive-text":
        print(keepalive_request(definition))
        return 0
    best = newest_log(argv[1])
    if best is None:
        return 1
    last, path, rows = best
    session = os.path.basename(path)[: -len(".jsonl")]
    out = {"session": session}
    out.update(walk(rows, definition))
    sub = subagent_activity(argv[1], session)
    activity = max(last, sub) if sub is not None else last
    stamp = activity.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.")
    out["last_activity_at"] = stamp + "%03dZ" % (activity.microsecond // 1000)
    out["last_activity_epoch"] = int(activity.timestamp())
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
