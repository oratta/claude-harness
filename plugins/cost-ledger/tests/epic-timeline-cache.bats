#!/usr/bin/env bats
load helper

setup() {
  cl_setup
  export TMPDIR="$BATS_TEST_TMPDIR/tmp" PYTHONDONTWRITEBYTECODE=1
  mkdir -p "$TMPDIR"
}

@test "cache: storage: fd survives path replacement, files are private, resources close" {
  python3 - "$PLUGIN_DIR/scripts" "$TMPDIR" <<'PY'
import json, os, sys
sys.path.insert(0, sys.argv[1])
import gate_report as g
lock = g.lock('acme/ra', 10)
assert lock is not None
folder = os.path.join(sys.argv[2], 'cost-ledger-timeline')
os.rename(folder, folder + '.old')
os.mkdir(folder, 0o700)
g.cache_write(lock, 'acme/ra', 10, {'nodes': {}})
assert g.cache_read(lock, 'acme/ra', 10) == {'nodes': {}}
files = os.listdir(folder + '.old')
assert any(n.endswith('.json') for n in files)
assert not os.listdir(folder)
for n in files:
    assert os.stat(os.path.join(folder + '.old', n)).st_mode & 0o077 == 0
dir_fd = lock.dir_fd
g.unlock(lock)
for fd in (int(lock), dir_fd):
    try: os.fstat(fd)
    except OSError: pass
    else: raise AssertionError('fd leaked')
PY
}

@test "cache: storage: missing corrupt mismatched unreadable and symlink files are ignored" {
  python3 - "$PLUGIN_DIR/scripts" "$TMPDIR" <<'PY'
import json, os, sys
from unittest.mock import patch
sys.path.insert(0, sys.argv[1])
import gate_report as g
lock = g.lock('acme/ra', 10)
assert g.cache_read(lock, 'acme/ra', 10) is None
g.cache_write(lock, 'acme/ra', 10, {'nodes': {}})
folder = os.path.join(sys.argv[2], 'cost-ledger-timeline')
path = next(os.path.join(folder, n) for n in os.listdir(folder) if n.endswith('.json'))
good = open(path).read()
for bad in ('{', '[]', good.replace('acme/ra', 'other/repo'), good.replace('"version": 1', '"version": 9')):
    open(path, 'w').write(bad)
    assert g.cache_read(lock, 'acme/ra', 10) is None, bad
open(path, 'w').write(good)
os.chmod(path, 0o666)
assert g.cache_read(lock, 'acme/ra', 10) is None
os.chmod(path, 0o600)
with patch.object(g.os, 'open', side_effect=PermissionError):
    assert g.cache_read(lock, 'acme/ra', 10) is None
    g.cache_write(lock, 'acme/ra', 10, {'nodes': {}})
os.rename(path, path + '.victim')
os.symlink(path + '.victim', path)
assert g.cache_read(lock, 'acme/ra', 10) is None
g.cache_write(lock, 'acme/ra', 10, {'nodes': {'changed': True}})
assert open(path + '.victim').read() == good
assert os.path.islink(path)
g.unlock(lock)
PY
}
