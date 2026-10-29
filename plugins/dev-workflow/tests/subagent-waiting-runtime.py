"""Execute the canonical launch/poll snippets with bounded, isolated fake processes."""

import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time


def block(text, step):
    heading = text.index(f"# 手順 {step}:")
    start = text.rfind("```", 0, heading)
    end = text.index("```", heading)
    return text[text.index("\n", start) + 1:end]


def wait_for(predicate, description):
    deadline = time.monotonic() + 5
    while not predicate():
        assert time.monotonic() < deadline, f"timed out: {description}"
        time.sleep(0.01)


def main():
    canon, root, mode, rc = sys.argv[1:]
    root = Path(root)
    text = Path(canon).read_text()
    env = dict(os.environ, TMPDIR=str(root))
    step1 = subprocess.run(["bash", "-c", block(text, 1)], env=env,
                           capture_output=True, text=True, timeout=5, check=True)
    values = dict(line.split("=", 1) for line in step1.stdout.splitlines())
    nonce = values["nonce"]
    marker = f"__CODEX_DONE_{nonce}__"
    payload = {
        "newline": "review output\n", "no-newline": "review output",
        "other-nonce": f"__CODEX_DONE_other{nonce}__ rc=0\n",
        "prefix": f"body mentions {marker} rc=0\n",
        "missing-rc": f"{marker}\n",
        "suffix": f"{marker} rc=0 trailing text\n",
        "fixed": "__CODEX_DONE__ rc=0\n",
    }[mode]
    env.update(FAKE_ROOT=str(root), FAKE_PAYLOAD=payload, FAKE_RC=rc)
    bindir = root / "bin"
    bindir.mkdir()
    # No shell descendants in these fakes; the driver reaps each process group.
    for name, source in {
        "codex": '''import os, pathlib, sys, time
root = pathlib.Path(os.environ["FAKE_ROOT"])
(root / "codex.pid").write_text(str(os.getpid()))
print(os.environ["FAKE_PAYLOAD"], end="", flush=True)
(root / "ready").touch()
while not (root / "release").exists():
    time.sleep(0.01)
(root / "finished").touch()
sys.exit(int(os.environ["FAKE_RC"]))
''',
        "sleep": '''import os, pathlib, time
with (pathlib.Path(os.environ["FAKE_ROOT"]) / "ticks").open("a") as f:
    f.write("tick\\n")
time.sleep(0.02)
''',
    }.items():
        path = bindir / name
        path.write_text(f"#!{sys.executable}\n" + source)
        path.chmod(0o755)
    env["PATH"] = f"{bindir}:{env['PATH']}"

    def literal(script):
        return script.replace("<dir>", values["dir"]).replace("<nonce>", nonce)

    launch = literal(block(text, 2))
    command = re.search(r"^command: (.+)$", block(text, 3), re.M)
    assert command, "step 3 command not found"
    poll = literal(command[1])
    processes = []
    try:
        with (root / "launch.out").open("w") as launch_out, (root / "poll.out").open("w") as poll_out:
            job = subprocess.Popen(["bash", "-c", launch], env=env,
                                   stdout=launch_out, stderr=subprocess.STDOUT, start_new_session=True)
            processes.append(job)
            wait_for(lambda: (root / "ready").exists(), "fake codex startup")
            waiter = subprocess.Popen(["bash", "-c", poll], env=env,
                                      stdout=poll_out, stderr=subprocess.STDOUT, start_new_session=True)
            processes.append(waiter)
            # Require actual polling progress, then a bounded negative observation.
            def polling():
                assert waiter.poll() is None, f"poll completed before codex: {mode}"
                return (root / "ticks").exists() and len((root / "ticks").read_text().splitlines()) >= 3
            wait_for(polling, "three polling iterations")
            time.sleep(0.1)
            assert waiter.poll() is None, f"poll completed before codex: {mode}"
            assert job.poll() is None, "launch finished while fake codex was blocked"
            os.kill(int((root / "codex.pid").read_text()), 0)
            assert not (root / "finished").exists()
            (root / "release").touch()
            job.wait(timeout=5)
            assert (root / "finished").exists()
            assert waiter.wait(timeout=5) == 0
        log = Path(values["dir"], "review.log").read_text()
        matching = re.findall(rf"^{marker} rc=([0-9]+)$", log, re.M)
        assert matching == [rc], f"expected exactly one line-start marker rc={rc}: {log!r}"
        assert log.startswith(payload), f"codex stdout lost: {log!r}"
        assert f"{marker} rc={rc}" in (root / "poll.out").read_text()
    finally:
        # Kill groups even if a shell exited first, then reap the direct children.
        for process in reversed(processes):
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=5)


if __name__ == "__main__":
    main()
