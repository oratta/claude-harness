#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../scripts/develop-procedure-freshness.py"
  ROOT="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  export HOME="$BATS_TEST_TMPDIR/home" GIT_CONFIG_NOSYSTEM=1
  unset CLAUDE_HARNESS_DEV_DIR
  mkdir -p "$HOME" "$BATS_TEST_TMPDIR/bin"
  export GH_LOG="$BATS_TEST_TMPDIR/gh.json" GH_FAIL=0
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'PY'
#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
p = Path(os.environ['GH_LOG'])
rows = json.loads(p.read_text()) if p.exists() else []
rows.append({'argv': sys.argv[1:], 'body': sys.stdin.read()})
p.write_text(json.dumps(rows))
sys.exit(int(os.environ['GH_FAIL']))
PY
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  REPO="$BATS_TEST_TMPDIR/repo"
  git init -q --bare "$BATS_TEST_TMPDIR/origin.git"
  git init -q -b main "$REPO"
  git -C "$REPO" config user.name Test
  git -C "$REPO" config user.email test@example.com
  git -C "$REPO" remote add origin "$BATS_TEST_TMPDIR/origin.git"
  git -C "$REPO" commit -q --allow-empty -m before-skill
  BEFORE_SKILL=$(git -C "$REPO" rev-parse HEAD)
  PLUGIN="$REPO/plugins/dev-workflow"
  mkdir -p "$PLUGIN/skills/develop/references" "$PLUGIN/references"
  printf 'skill\r\n' > "$PLUGIN/skills/develop/SKILL.md"
  printf 'a\n' > "$PLUGIN/skills/develop/references/a.md"
  printf 'b\n' > "$PLUGIN/references/b.md"
  commit old
  OLD=$(git -C "$REPO" rev-parse HEAD)
  CACHE="$BATS_TEST_TMPDIR/cache-local"
  cp -R "$PLUGIN" "$CACHE"
  RECORD='https://github.com/example/harness/issues/42'
  printf 'new\n' > "$PLUGIN/skills/develop/references/new.md"
  commit new
}

commit() {
  git -C "$REPO" add .
  git -C "$REPO" commit -qm "$1"
  git -C "$REPO" push -q origin HEAD:main
}
check() {
  run python3 "$SCRIPT" check --loaded-plugin-root "$CACHE" --comparison-repo "$REPO" --record "$RECORD" "$@"
}
preview() {
  git -C "$REPO" worktree add -q --detach "$BATS_TEST_TMPDIR/preview" "$OLD"
  PREVIEW="$BATS_TEST_TMPDIR/preview"
  MARK=$(git -C "$PREVIEW" rev-parse --absolute-git-dir)/develop-procedure-preview.json
}
mark() {
  run python3 "$SCRIPT" mark-preview --loaded-plugin-root "$CACHE" --preview-worktree "$PREVIEW" --record "$RECORD"
}

@test "fingerprint byte format, metadata independence, target changes and exclusions" {
  run python3 - "$SCRIPT" "$CACHE" "$BATS_TEST_TMPDIR" <<'PY'
import hashlib, importlib.util, os, shutil, sys
from pathlib import Path
spec = importlib.util.spec_from_file_location('guard', sys.argv[1])
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
p = Path(sys.argv[2]); q = Path(sys.argv[3]) / 'different-sha'
shutil.copytree(p, q)
files = {'skills/develop/SKILL.md': b'skill\r\n', 'skills/develop/references/a.md': b'a\n', 'references/b.md': b'b\n'}
raw = b'develop-procedure-v1\0' + b''.join(k.encode()+b'\0'+hashlib.sha256(v).hexdigest().encode()+b'\n' for k,v in sorted(files.items()))
expected = 'sha256:' + hashlib.sha256(raw).hexdigest()
assert m.fingerprint(p) == expected
for f in q.rglob('*.md'):
    os.chmod(f, 0o600); os.utime(f, (1, 1))
for name in ['docs/x.md', 'scripts/x.py', 'plugin.json', 'changes/x.md', 'skills/develop/migration/x.md']:
    f=q/name; f.parent.mkdir(parents=True, exist_ok=True); f.write_text('ignored')
assert m.fingerprint(q) == expected
for name in files:
    f=q/name; original=f.read_bytes()
    f.write_bytes(original+b' '); assert m.fingerprint(q) != expected
    f.write_bytes(original)
for name in ['skills/develop/references/a.md', 'references/b.md']:
    f=q/name; original=f.read_bytes()
    f.rename(f.with_suffix('.renamed.md')); assert m.fingerprint(q) != expected
    f.with_suffix('.renamed.md').unlink(); assert m.fingerprint(q) != expected
    f.write_bytes(original)
for folder in ['references', 'skills/develop/references']:
    f=q/folder/'added.md'; f.write_text('added'); assert m.fingerprint(q) != expected; f.unlink()
PY
  [ "$status" -eq 0 ]
}

@test "old Git-free content stops; equal content and reverted main continue" {
  check; [ "$status" -eq 1 ]
  [ ! -e "$GH_LOG" ]
  cp "$PLUGIN/skills/develop/references/new.md" "$CACHE/skills/develop/references/"
  check; [ "$status" -eq 0 ]; [[ "$output" == *'same'* ]]
  rm "$PLUGIN/skills/develop/references/new.md" "$CACHE/skills/develop/references/new.md"
  commit revert
  check; [ "$status" -eq 0 ]
}

@test "unknown content records exact body once to issue and PR, without shell expansion" {
  printf 'unknown $(touch SHOULD_NOT_EXIST)\n' >> "$CACHE/skills/develop/SKILL.md"
  for kind in issues pull; do
    RECORD="https://github.com/example/harness/$kind/42/?query=1#fragment"
    check; [ "$status" -eq 0 ]
  done
  python3 - "$GH_LOG" "$CACHE" "$REPO" <<'PY'
import json, sys
from pathlib import Path
rows=json.load(open(sys.argv[1])); assert len(rows)==2
body='手順書の版を確かめられなかった。読込元と origin/main の新旧を証明できないため、develop を続けます。\n読込元: '+str(Path(sys.argv[2]).resolve())+'\n比較元: '+str(Path(sys.argv[3]).resolve())+'\n理由: fingerprint-not-in-main-history'
for row, kind in zip(rows, ['issue','pr']):
    assert row['argv']==[kind,'comment','https://github.com/example/harness/'+('issues' if kind=='issue' else 'pull')+'/42','--body-file','-']
    assert row['body']==body
PY
}

@test "missing comparison, env fallback, fetch failure and failed recording remain distinct" {
  run python3 "$SCRIPT" check --loaded-plugin-root "$CACHE" --record "$RECORD"
  [ "$status" -eq 0 ]; [[ "$output" == *'comparison-repo-unavailable'* ]]
  export CLAUDE_HARNESS_DEV_DIR="$REPO"
  run python3 "$SCRIPT" check --loaded-plugin-root "$CACHE" --record "$RECORD"
  [ "$status" -eq 1 ]
  git -C "$REPO" remote set-url origin "$BATS_TEST_TMPDIR/missing"
  export GH_FAIL=1
  check
  [ "$status" -eq 0 ]; [[ "$output" == *'origin-main-fetch-failed'* ]]
  [[ "$output" == *'"recording": "failed"'* ]]; [[ "$output" == *'投稿失敗'* ]]
  python3 - "$GH_LOG" "$CACHE" "$REPO" <<'PY'
import json,sys
from pathlib import Path
rows=json.load(open(sys.argv[1])); assert len(rows)==2
assert rows[0]['body']=='手順書の版を確かめられなかった。origin/main を取得できなかったため、develop を続けます。\n読込元: '+str(Path(sys.argv[2]).resolve())+'\n比較元: 未設定\n理由: comparison-repo-unavailable'
assert rows[1]['body'].endswith('理由: origin-main-fetch-failed')
assert rows[1]['body'].splitlines()[2]=='比較元: '+str(Path(sys.argv[3]).resolve())
PY
}

@test "second parent only content and shallow missing history do not prove oldness" {
  git -C "$REPO" checkout -qb side "$OLD"
  printf 'side\n' > "$PLUGIN/skills/develop/SKILL.md"
  git -C "$REPO" commit -qam side
  cp "$PLUGIN/skills/develop/SKILL.md" "$CACHE/skills/develop/SKILL.md"
  git -C "$REPO" checkout -q main
  git -C "$REPO" merge -q --no-ff side -m merge
  printf 'post-merge\n' > "$PLUGIN/skills/develop/SKILL.md"
  commit after
  check; [ "$status" -eq 0 ]; [[ "$output" == *'fingerprint-not-in-main-history'* ]]
  git clone -q --depth 1 --branch main "file://$BATS_TEST_TMPDIR/origin.git" "$BATS_TEST_TMPDIR/shallow"
  check --comparison-repo "$BATS_TEST_TMPDIR/shallow"
  [ "$status" -eq 0 ]; [[ "$output" == *'history-incomplete'* ]]
}

@test "history skips a missing SKILL and still finds an older first-parent match" {
  rm "$PLUGIN/skills/develop/SKILL.md"
  commit delete-skill
  printf 'readded\n' > "$PLUGIN/skills/develop/SKILL.md"
  commit readd-skill
  check
  [ "$status" -eq 1 ]; [[ "$output" == *"$OLD"* ]]
}

@test "preview rejects a shared clone git dir and a linked worktree with missing HEAD SKILL" {
  PREVIEW="$REPO"
  CACHE="$PLUGIN"
  mark
  [ "$status" -eq 2 ]
  [ ! -e "$REPO/.git/develop-procedure-preview.json" ]
  git -C "$REPO" worktree add -q --detach "$BATS_TEST_TMPDIR/no-skill" "$BEFORE_SKILL"
  PREVIEW="$BATS_TEST_TMPDIR/no-skill"
  mkdir -p "$PREVIEW/plugins"
  cp -R "$PLUGIN" "$PREVIEW/plugins/dev-workflow"
  mark
  [ "$status" -eq 2 ]
  [ ! -e "$(git -C "$PREVIEW" rev-parse --absolute-git-dir)/develop-procedure-preview.json" ]
}

@test "CLI and unreadable or missing SKILL are input errors" {
  run python3 "$SCRIPT" check; [ "$status" -eq 2 ]
  check --record '42'; [ "$status" -eq 2 ]
  mv "$CACHE/skills/develop/SKILL.md" "$CACHE/skills/develop/SKILL.renamed.md"
  check; [ "$status" -eq 2 ]
  mv "$CACHE/skills/develop/SKILL.renamed.md" "$CACHE/skills/develop/SKILL.md"
  chmod 000 "$CACHE/skills/develop/SKILL.md"
  check; [ "$status" -eq 2 ]
  rm "$CACHE/skills/develop/SKILL.md"
  check; [ "$status" -eq 2 ]
}

@test "preview six fields, private git dir, reusable normalized tuple and direct worktree" {
  preview; mark; [ "$status" -eq 0 ]; [ -f "$MARK" ]
  python3 - "$MARK" "$CACHE" "$PREVIEW" "$OLD" "$RECORD" <<'PY'
import json, sys
from pathlib import Path
m=json.load(open(sys.argv[1]))
assert set(m)=={'schema_version','loaded_plugin_root','worktree_root','worktree_head','procedure_fingerprint','record_url'}
assert m['schema_version']==1 and m['loaded_plugin_root']==str(Path(sys.argv[2]).resolve()) and m['worktree_root']==str(Path(sys.argv[3]).resolve())
assert m['worktree_head']==sys.argv[4] and m['record_url']==sys.argv[5]
assert m['procedure_fingerprint'].startswith('sha256:')
PY
  [ ! -e "$CACHE/develop-procedure-preview.json" ]
  [ ! -e "$REPO/.git/develop-procedure-preview.json" ]
  [ -z "$(git -C "$PREVIEW" status --porcelain)" ]
  RECORD="$RECORD/?q=1#f"
  for i in 1 2; do check --preview-worktree "$PREVIEW"; [ "$status" -eq 0 ]; [[ "$output" == *'preview'* ]]; done
  CACHE="$PREVIEW/plugins/dev-workflow"
  mark; [ "$status" -eq 0 ]
  check --preview-worktree "$PREVIEW"; [ "$status" -eq 0 ]
  printf 'dirty' >> "$CACHE/skills/develop/SKILL.md"
  mark; [ "$status" -eq 2 ]
}

@test "each invalid mark field, unreadable or missing mark warns and falls back to old" {
  preview
  for field in schema_version loaded_plugin_root worktree_root worktree_head procedure_fingerprint record_url; do
    mark; [ "$status" -eq 0 ]
    python3 - "$MARK" "$field" <<'PY'
import json,sys
p=sys.argv[1]; m=json.load(open(p)); m[sys.argv[2]]='invalid'; open(p,'w').write(json.dumps(m))
PY
    check --preview-worktree "$PREVIEW"
    [ "$status" -eq 1 ]; [[ "$output" == *'警告'* ]]
  done
  mark; chmod 000 "$MARK"
  check --preview-worktree "$PREVIEW"; [ "$status" -eq 1 ]; [[ "$output" == *'警告'* ]]
  chmod 600 "$MARK"; printf '{bad' > "$MARK"
  check --preview-worktree "$PREVIEW"; [ "$status" -eq 1 ]; [[ "$output" == *'警告'* ]]
  rm "$MARK"
  check --preview-worktree "$PREVIEW"; [ "$status" -eq 1 ]; [[ "$output" == *'警告'* ]]
}

@test "preview cannot transfer to a different cache, record or worktree" {
  preview; mark; [ "$status" -eq 0 ]
  cp -R "$CACHE" "$BATS_TEST_TMPDIR/other-cache"
  CACHE="$BATS_TEST_TMPDIR/other-cache"
  check --preview-worktree "$PREVIEW"; [ "$status" -eq 1 ]
  CACHE="$BATS_TEST_TMPDIR/cache-local"; RECORD='https://github.com/example/harness/pull/43'
  check --preview-worktree "$PREVIEW"; [ "$status" -eq 1 ]
  RECORD='https://github.com/example/harness/issues/42'
  git -C "$REPO" worktree add -q --detach "$BATS_TEST_TMPDIR/other-worktree" "$OLD"
  other_mark=$(git -C "$BATS_TEST_TMPDIR/other-worktree" rev-parse --absolute-git-dir)/develop-procedure-preview.json
  cp "$MARK" "$other_mark"
  check --preview-worktree "$BATS_TEST_TMPDIR/other-worktree"; [ "$status" -eq 1 ]
  printf 'changed\n' >> "$PREVIEW/plugins/dev-workflow/skills/develop/SKILL.md"
  check --preview-worktree "$PREVIEW"; [ "$status" -eq 1 ]
}

@test "entry contract and change record describe ordering, callers and guarantee limits" {
  run python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); base=root/'plugins/dev-workflow/skills/develop'
skill=(base/'SKILL.md').read_text(); worker=(base/'references/roles/worker/spec.md').read_text()
entry=skill.split('## 入口 0:')[1].split('## worktree')[0]
loop=skill.split('## 1 ループ')[1].split('(2)')[0]
for body in [entry, worker.split('## CI fix')[0]]:
    assert 'develop-procedure-freshness.py' in body
    assert '--loaded-plugin-root' in body and '--record' in body
    assert '仕様化判断' in body and '直後' in body
assert '検査' in loop and '読込元' in loop
for name in ['references/procedure-freshness.md', '../../changes/1864.md']:
    body=(base/name).read_text()
    for term in ['導入前キャッシュ', '強制', '古い', '印', '取得']:
        assert term in body, (name,term)
PY
  [ "$status" -eq 0 ]
}

@test "Draft PR worker returns failed recording body for proxy posting" {
  run python3 - "$ROOT" <<'PYCODE'
from pathlib import Path
import sys
base=Path(sys.argv[1])/'plugins/dev-workflow/skills/develop/references'
worker=(base/'roles/worker/spec.md').read_text().split('## CI fix')[0]
reference=(base/'procedure-freshness.md').read_text()
for body in [worker, reference]:
    for term in ['recording', 'failed', 'body', '全文', 'return', '記録未完了', '代理投稿']:
        assert term in body, term
PYCODE
  [ "$status" -eq 0 ]
}

@test "Draft PR worker launch passes actual loaded plugin root in one line" {
  run python3 - "$ROOT" <<'PYCODE'
from pathlib import Path
import sys
skill=(Path(sys.argv[1])/'plugins/dev-workflow/skills/develop/SKILL.md').read_text()
loop=skill.split('## 1 ループ')[1].split('(2)')[0]
assert any(all(term in line for term in ['Draft PR', '起動指示', '読込元plugin-root:', 'SKILL.md', '1 行']) for line in loop.splitlines())
PYCODE
  [ "$status" -eq 0 ]
}
