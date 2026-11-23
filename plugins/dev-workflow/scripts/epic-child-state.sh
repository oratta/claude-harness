#!/usr/bin/env bash
# Child-only turn input/Stop entry. Parent state fields remain owned by epic-dispatch.
# The dependency predicate shares exactly the Stop status-line grammar.
set -uo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=plugins/dev-workflow/scripts/epic-state.sh
source "$DIR/epic-state.sh"
PY_SRC=""
IFS= read -r -d '' PY_SRC <<'PY' || true
import datetime, json, os, re, sys

VALUES = ('主の返事待ち', '作業報告', '完了')
def status(text):
    lines = text.splitlines()
    while lines and not lines[-1].strip():
        lines.pop()
    if not lines:
        return None
    fence = None
    for line in lines[:-1]:
        m = re.match(r'^\s*(`{3,}|~{3,})', line)
        if m:
            ch = m[1][0]
            if fence is None:
                fence = (ch, len(m[1]))
            elif ch == fence[0] and len(m[1]) >= fence[1]:
                fence = None
    m = re.fullmatch(r'状態: (主の返事待ち|作業報告|完了) — (.+)', lines[-1])
    if fence or not m or not m[2].strip():
        return None
    return m[1], m[2].strip()

def text_of(row):
    c = row.get('message', {}).get('content')
    if isinstance(c, str):
        return c
    if isinstance(c, list):
        texts = [b['text'] for b in c if isinstance(b, dict) and b.get('type') == 'text' and isinstance(b.get('text'), str)]
        return '\n'.join(texts) if texts else None
    return None

def integer(v, minimum):
    return type(v) is int and v >= minimum

def nonempty(v):
    return isinstance(v, str) and bool(v)

def utc(v):
    if not isinstance(v, str) or not re.fullmatch(r'\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ', v):
        return False
    try:
        datetime.datetime.strptime(v, '%Y-%m-%dT%H:%M:%SZ')
        return True
    except ValueError:
        return False

def extension(r):
    if 'turn_input' not in r and 'turn_state' not in r:
        return
    i, s = r.get('turn_input'), r.get('turn_state')
    ok = (isinstance(i, dict) and integer(i.get('generation'), 1)
          and nonempty(i.get('session_id')) and i.get('sender') in ('owner', 'parent', 'startup')
          and utc(i.get('received_at')) and nonempty(i.get('transcript_path'))
          and os.path.isabs(i['transcript_path']) and integer(i.get('transcript_offset'), 0)
          and 'turn_state' in r)
    if not ok:
        raise ValueError('turn_input / turn_state の型が不正です')
    if s is not None:
        ok = (isinstance(s, dict) and integer(s.get('generation'), 1)
              and nonempty(s.get('session_id')) and s.get('value') in VALUES
              and nonempty(s.get('summary')) and bool(s['summary'].strip())
              and '\n' not in s['summary'] and '\r' not in s['summary'] and utc(s.get('recorded_at'))
              and s['generation'] == i['generation'] and s['session_id'] == i['session_id'])
        if not ok:
            raise ValueError('turn_state の型または世代が不正です')

def startup(r, prompt):
    if not isinstance(prompt, str):
        return False
    start = re.match(r'^/develop (?:([^\s#]+)#|#)([0-9]+) （エピック #([0-9]+) の子。([^）]*)）', prompt)
    if (not start or (start[1] is not None and start[1].lower() != r['repo'].lower())
            or start[2] != str(r['number']) or start[3] != r['epic'].rsplit('#', 1)[1]):
        return False
    repo = re.search(r'エピックのリポジトリ ([^。]+)。', start[4])
    return (repo[1].lower() == r['epic'].split('#')[0].lower() if repo
            else r['repo'].lower() == r['epic'].split('#')[0].lower())

def target(r, p, is_input):
    sid = p.get('session_id')
    if not nonempty(sid):
        return False
    if 'turn_input' not in r and 'turn_state' not in r:
        return is_input and startup(r, p.get('prompt'))
    i = r.get('turn_input')
    if not isinstance(i, dict) or not nonempty(i.get('session_id')):
        raise ValueError('turn_input / turn_state の型が不正です')
    return i['session_id'] == sid or (is_input and startup(r, p.get('prompt')))

mode = sys.argv[1]
try:
    data = json.load(sys.stdin)
    if mode == 'dependency':
        text = data.get('text') or ''
        lines = text.rstrip().splitlines()
        if status(text):
            lines.pop()
            while lines and not lines[-1].strip():
                lines.pop()
        tail = lines[-1] if lines else ''
        tail = tail[1:] if tail.startswith(' ') else tail
        raise SystemExit(0 if tail.startswith('止まった理由: 依存待ち: ') else 1)
    r, p, reserved = data['record'], data['payload'], data['reserved']
    # Scope is checked both before acquiring a lock and on the locked input snapshot.
    if not target(r, p, mode in ('input', 'scope-input')):
        action = 'ignore'
        if (mode == 'scope-input' and 'turn_input' not in r and 'turn_state' not in r
                and nonempty(p.get('session_id')) and isinstance(p.get('prompt'), str)
                and p['prompt'] != reserved):
            action = 'notify'
        print(json.dumps({'action': action})); raise SystemExit(0)
    if mode.startswith('scope-'):
        print(json.dumps({'action': 'target'})); raise SystemExit(0)
    extension(r)
    sid, path = p.get('session_id'), p.get('transcript_path')
    if not nonempty(sid) or not nonempty(path) or not os.path.isabs(path):
        raise ValueError('session_id / transcript_path が不正です')
    now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
    i = r.get('turn_input')
    if mode == 'input':
        prompt = p.get('prompt')
        if not isinstance(prompt, str):
            raise ValueError('prompt が文字列ではありません')
        if prompt == reserved:
            print(json.dumps({'action': 'ignore'})); raise SystemExit(0)
        sender = 'owner'
        if (not i or i['session_id'] != sid) and startup(r, prompt):
            sender = 'startup'
        if sender != 'startup' and prompt.startswith(('親エピック #', '主の返事（親エピック #')):
            sender = 'parent'
        try:
            offset = os.path.getsize(path)
        except FileNotFoundError:
            offset = 0
        new_input = dict(generation=(i['generation'] if i else 0) + 1, session_id=sid,
                         sender=sender, received_at=now, transcript_path=path, transcript_offset=offset)
        print(json.dumps({'action': 'input', 'input': new_input}, ensure_ascii=False))
    else:
        if i['session_id'] != sid or i['transcript_path'] != path:
            print(json.dumps({'action': 'ignore'})); raise SystemExit(0)
        rows = []
        with open(path, 'rb') as f:
            while True:
                pos = f.tell()
                raw = f.readline()
                if not raw:
                    break
                row = json.loads(raw)
                if not isinstance(row, dict) or row.get('isSidechain') or row.get('isApiErrorMessage'):
                    continue
                if row.get('sessionId', sid) != sid or row.get('type') not in ('user', 'assistant'):
                    continue
                text = text_of(row)
                if text is not None and text.strip():
                    rows.append((pos, row['type'], text))
        # A reserved user input preserves the original turn, even if its reply deviates.
        users = [row for row in rows if row[1] == 'user']
        if users and users[-1][2] == reserved:
            print(json.dumps({'action': 'ignore'})); raise SystemExit(0)
        assistants = [row for row in rows if row[1] == 'assistant']
        if not assistants:
            raise ValueError('会話ログに現在の発言がありません')
        pos, _, text = assistants[-1]
        payload_text = p.get('last_assistant_message')
        def old(row):
            return row[0] < i['transcript_offset'] or (users and users[-1][0] > row[0])
        if text != payload_text:
            if not any(row[2] == payload_text and old(row) for row in assistants):
                raise ValueError('会話ログの最終発言と last_assistant_message が対応しません')
            print(json.dumps({'action': 'ignore'})); raise SystemExit(0)
        if old(assistants[-1]):
            print(json.dumps({'action': 'ignore'})); raise SystemExit(0)
        parsed = status(text)
        if not parsed:
            print(json.dumps({'action': 'block', 'reason': '最終非空行に 状態: <主の返事待ち|作業報告|完了> — <空でない中身> を、引用・コードの外に書いてください。'}, ensure_ascii=False))
        else:
            print(json.dumps({'action': 'save', 'state': dict(generation=i['generation'], session_id=sid,
                       value=parsed[0], summary=parsed[1], recorded_at=now)}, ensure_ascii=False))
except (ValueError, OSError, TypeError, KeyError) as e:
    print(json.dumps({'action': 'error', 'reason': str(e)}, ensure_ascii=False))
    raise SystemExit(2)
PY
if [ "${1-}" = --dependency-wait ]; then
  python3 -I -c "$PY_SRC" dependency
  exit $?
fi
INPUT="$(cat)"
command -v jq >/dev/null 2>&1 || {
  printf '%s' "$INPUT" | "$DIR/owner-message-number-check.sh"
  exit $?
}
EVENT="$(jq -r '.hook_event_name // ""' <<< "$INPUT" 2>/dev/null)"
OWNER=""; OWNER_RC=0
if [ "$EVENT" = Stop ]; then
  OWNER="$(printf '%s' "$INPUT" | "$DIR/owner-message-number-check.sh")"; OWNER_RC=$?
fi
pass_owner() { [ -z "$OWNER" ] || printf '%s\n' "$OWNER"; exit "$OWNER_RC"; }
block() { jq -cn --arg reason "$1" '{decision:"block",reason:$reason}'; exit 0; }
fail() {
  local reason="${1}: ${RECORD:-$ES_ROOT}"
  if [ "$EVENT" = Stop ]; then
    # Waive only processing failures on retry; preserve the existing guard result.
    if jq -e '.stop_hook_active == true' <<< "$INPUT" >/dev/null 2>&1; then
      printf '%s\n' "$reason" >&2
      pass_owner
    fi
    block "$reason"
  fi
  printf '%s\n' "$reason" >&2
  exit 2
}
case "$EVENT" in UserPromptSubmit|Stop) ;; *) exit 0 ;; esac
jq -e 'type == "object" and (has("agent_id") | not)' <<< "$INPUT" >/dev/null 2>&1 || pass_owner
CWD="$(jq -r '.cwd // ""' <<< "$INPUT")"
TOP="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)" || pass_owner
es_root_init 2>/dev/null || pass_owner
HITS="$(es_find_by_worktree "$TOP" 2>/dev/null)"
[ -n "$HITS" ] || pass_owner
[ "$(printf '%s\n' "$HITS" | wc -l | tr -d ' ')" = 1 ] || fail '対象の子の記録が複数あります'
RECORD="$HITS"
prepare() {
  jq -cn --argjson record "$1" --argjson payload "$INPUT" --arg reserved "${RESERVED-}" \
    '{record:$record,payload:$payload,reserved:$reserved}' | python3 -I -c "$PY_SRC" "$2"
}
CUR="$(es_read "$RECORD")" || fail '対象判定で記録を読めません'
SCOPE=scope-stop
[ "$EVENT" != UserPromptSubmit ] || SCOPE=scope-input
if [ "$EVENT" = UserPromptSubmit ]; then
  RESERVED="$(python3 -I "$DIR/child-log-read.py" --keepalive-text)" || fail '予約文を読めません'
fi
PLAN="$(prepare "$CUR" "$SCOPE")" || fail "$(jq -r '.reason // "対象を識別できません"' <<< "$PLAN")"
[ "$(jq -r .action <<< "$PLAN")" != ignore ] || pass_owner
if [ "$(jq -r .action <<< "$PLAN")" = notify ]; then
  jq -cn --arg path "$RECORD" --argjson record "$CUR" '
    {hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:
      ("記録: " + $path + " / 親: " + $record.epic + " / 子: " + $record.repo + "#" + ($record.number|tostring)
       + "。子セッションは未登録で、入力記録・状態行検査は適用されていない。本来の子として作業中なら、その子のセッションへ一致する起動指示を送り直して登録を確認する。別用途なら対応不要。")}}'
  exit 0
fi
es_check_env || fail '状態保存の設定が不正です'
# Finish the lock failure path before the hook's 30-second timeout.
EPIC_STATE_LOCK_TIMEOUT="$(python3 -I -c 'import sys; print(min(int(sys.argv[1]), 20))' "${EPIC_STATE_LOCK_TIMEOUT-10}")" || fail 'ロック待ち時間を設定できません'
if [ "$EVENT" = Stop ]; then
  RESERVED="$(python3 -I "$DIR/child-log-read.py" --keepalive-text)" || fail '予約文を読めません'
fi
if [ "$EVENT" = UserPromptSubmit ]; then
  es_lock "$RECORD" || fail '入力受付のロックに失敗しました'
  trap 'es_unlock "$RECORD"' EXIT
  CUR="$(es_read "$RECORD")" || fail '入力受付で記録を読めません'
  PLAN="$(prepare "$CUR" input)" || fail "$(jq -r '.reason // "入力情報を検査できません"' <<< "$PLAN")"
  [ "$(jq -r .action <<< "$PLAN")" = ignore ] && exit 0
  NEW="$(jq -c --argjson plan "$PLAN" --arg now "$(es_now)" '.turn_input=$plan.input | .turn_state=null | .updated_at=$now' <<< "$CUR")" || fail '入力情報を作れません'
  es_write "$RECORD" "$NEW" || fail '入力情報を保存できません'
  exit 0
fi
CUR="$(es_read "$RECORD")" || fail 'Stop で記録を読めません'
PLAN="$(prepare "$CUR" stop)"; PLAN_RC=$?
ACTION="$(jq -r '.action // "error"' <<< "$PLAN")"
[ "$ACTION" = ignore ] && pass_owner
REASON="$(jq -r '.reason // ""' <<< "$PLAN")"
if jq -e '.decision == "block"' <<< "$OWNER" >/dev/null 2>&1; then
  ACTION=block
  REASON="$(jq -r .reason <<< "$OWNER")${REASON:+ / $REASON}"
fi
[ "$PLAN_RC" -eq 0 ] || ACTION=error
STATE=null
[ "$ACTION" != save ] || STATE="$(jq -c .state <<< "$PLAN")"
# Compare the whole input snapshot under the same lock used by incoming prompts.
# A late Stop must neither save nor invalidate a newer input.
es_modify "$RECORD" 'if .turn_input == $snapshot then .turn_state=$state else empty end' \
  --argjson snapshot "$(jq -c '.turn_input // null' <<< "$CUR")" --argjson state "$STATE" >/dev/null
RC=$?
[ "$RC" -ne 4 ] || pass_owner
[ "$RC" -eq 0 ] || fail "Stop の保存または無効化に失敗しました${REASON:+ / $REASON}"
case "$ACTION" in
  save) pass_owner ;;
  block) block "$REASON" ;;
  *) fail "$REASON" ;;
esac
