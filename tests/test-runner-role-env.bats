#!/usr/bin/env bats
setup() {
  unset DEVELOP_ROLE
  bats_require_minimum_version 1.5.0
  ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
}
@test "runner clears role only inside each Bats launch branch" {
  # Exercise the actual function body with a fake Bats executable. The guarded
  # branch uses real perl/ps; two fallbacks force missing libexec and failed ps.
  run --separate-stderr python3 - "$ROOT/scripts/test.sh" "$BATS_TEST_TMPDIR" <<'PY'
import os, pathlib, subprocess, sys
source=pathlib.Path(sys.argv[1]).read_text()
root=pathlib.Path(sys.argv[2]); binary=root/'bin'; binary.mkdir()
bats=binary/'bats'
bats.write_text('#!/bin/sh\n[ -z "${DEVELOP_ROLE+x}" ] || exit 73\nDEVELOP_ROLE=implement sh -c \'[ "$DEVELOP_ROLE" = implement ]\'\n')
bats.chmod(0o755)
function=source[source.index('run_bats_guarded() {'):source.index('\nrun_bats_guarded\n')]
helpers=source[source.index('is_bats_command() {'):source.index('run_bats_guarded() {')]
for branch in ('missing-libexec','failed-ps','guarded'):
 script='''ROOT="$1"; SUITES=fixture; RESIDUAL_GRACE=2
 RESIDUAL_BATS_LIBEXEC="$1/bin"
 process_listing_works() { return 0; }
 '''+helpers+function
 if branch=='missing-libexec': script+='\nRESIDUAL_BATS_LIBEXEC=/does-not-exist\n'
 if branch=='failed-ps': script+='\nprocess_listing_works() { return 1; }\n'
 script+='\nrun_bats_guarded\nst=$?\n[ "$st" -eq 0 ] && [ "$DEVELOP_ROLE" = implement ]\n'
 result=subprocess.run(['bash','-c',script,'fixture',str(root)],
   env=dict(os.environ, PATH=str(binary)+os.pathsep+os.environ['PATH'], DEVELOP_ROLE='implement'),
   capture_output=True,text=True,timeout=15)
 assert result.returncode==0, (branch,result.stdout,result.stderr)
PY
  [ "$status" -eq 0 ]
}
