"""Writer cases adapted from flatmate's burn account integration test."""

import json
import os
from pathlib import Path
import subprocess
import time

import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/statusline.sh"


def make_writer(tmp_path):
    home = tmp_path / "home"
    config = tmp_path / "config"
    home.mkdir()
    config.mkdir()
    env = os.environ.copy()
    env.pop("CLAUDE_SECURESTORAGE_CONFIG_DIR", None)
    env.pop("FLATMATE_RATE_SHARE_DIR", None)
    env.update(HOME=str(home), CLAUDE_CONFIG_DIR=str(config),
               FLATMATE_RATE_SHARE_CONF=str(tmp_path / "no-conf"),
               STATUSLINE_API_PACE="0", STATUSLINE_CODEX="0")
    snap = config / ".rate-limit-snapshot"
    reset_base = int(time.time())

    def run(*, session="writer-a", pct=50, limits=True, share=None):
        data = {"session_id": session, "workspace": {"current_dir": str(tmp_path)},
                "model": {"display_name": "Opus"},
                "rate_limits": {"five_hour": {"used_percentage": 10, "resets_at": reset_base + 7200},
                                "seven_day": {"used_percentage": pct, "resets_at": reset_base + 36000}}}
        if not limits:
            data.pop("rate_limits")
        if share is not None:
            env["FLATMATE_RATE_SHARE_DIR"] = str(share)
        result = subprocess.run(["bash", str(SCRIPT)], input=json.dumps(data), text=True,
                                capture_output=True, env=env)
        assert result.returncode == 0, result.stderr
        assert "Opus" in result.stdout
        return json.loads(snap.read_text()) if snap.exists() else None

    return tmp_path, home, env, snap, run


def check_writer_redraw_source_and_relogin_limit(writer):
    _, _, _, snap, run = writer
    first = run()
    assert first["storage_binding"] == "storage-v1:default"
    assert first["session_id"] == "writer-a"
    assert first["ts"] == first["observed_at"]
    assert first["written_at"] >= first["observed_at"]
    assert first["obs_sig"]
    first["ts"] = first["observed_at"] = 1
    snap.write_text(json.dumps(first))
    same = run()
    assert same["observed_at"] == 1
    assert same["written_at"] > 1
    other = run(session="writer-b")
    assert other["observed_at"] > 1
    for field in ("storage_binding", "session_id", "obs_sig"):
        altered = dict(other, observed_at=1, ts=1)
        altered[field] = "different" if field != "session_id" else "writer-old"
        snap.write_text(json.dumps(altered))
        assert run(session="writer-b")["observed_at"] > 1


def check_writer_records_account_id_only_when_valid(writer, value, valid):
    _, home, _, _, run = writer
    (home / ".claude.json").write_text(json.dumps({"oauthAccount": {"accountUuid": value}}))
    observed = run()
    if valid:
        assert observed["account_id"] == value.strip()
    else:
        assert "account_id" not in observed


def check_writer_handles_missing_or_broken_account_file(writer):
    _, home, _, _, run = writer
    assert "account_id" not in run()
    (home / ".claude.json").write_text("{")
    assert "account_id" not in run()


def check_writer_shared_body_and_atomic_replacement(writer):
    tmp, _, _, snap, run = writer
    share = tmp / "share"
    first = run(share=share)
    remote = share / f"{first['host']}.json"
    assert remote.read_bytes() == snap.read_bytes()
    assert list(snap.parent.glob(".rate-limit-snapshot.*")) == []
    assert list(share.iterdir()) == [remote]
    second = run(pct=90, share=share)
    assert second["seven_day_pct"] == 90
    assert remote.read_bytes() == snap.read_bytes()
    assert list(share.iterdir()) == [remote]


def check_writer_normalizes_host_for_shared_filename(writer):
    tmp, _, env, snap, run = writer
    bin_dir = tmp / "bin"
    bin_dir.mkdir()
    hostname = bin_dir / "hostname"
    hostname.write_text("#!/bin/sh\nprintf 'pc bad/名前\\n'\n")
    hostname.chmod(0o755)
    env["PATH"] = f"{bin_dir}:{env['PATH']}"
    share = tmp / "share"
    observed = run(share=share)
    assert observed["host"] == "pc_bad___"
    assert (share / "pc_bad___.json").read_bytes() == snap.read_bytes()


def check_writer_missing_source_or_limits_does_not_replace(writer, session, limits):
    _, _, _, snap, run = writer
    run()
    before = snap.read_bytes()
    assert run(session=session, limits=limits) is not None
    assert snap.read_bytes() == before


def check_writer_zero_and_special_session_and_missing_seven_day(writer):
    tmp, _, env, snap, _ = writer
    payload = {"session_id": 'quote"\n', "workspace": {"current_dir": str(tmp)},
               "model": {"display_name": "Opus"},
               "rate_limits": {"five_hour": {"used_percentage": 0}}}
    result = subprocess.run(["bash", str(SCRIPT)], input=json.dumps(payload), text=True,
                            capture_output=True, env=env)
    assert result.returncode == 0
    observed = json.loads(snap.read_text())
    assert observed["session_id"] == payload["session_id"]
    assert observed["five_hour_pct"] == 0
    assert observed["five_hour_resets_at"] is None
    assert observed["seven_day_pct"] is None
    assert observed["seven_day_resets_at"] is None


def check_writer_nondefault_account_changes_neither_destination(writer):
    tmp, _, env, snap, run = writer
    share = tmp / "share"
    first = run(share=share)
    local_before = snap.read_bytes()
    remote = share / f"{first['host']}.json"
    remote_before = remote.read_bytes()
    env["CLAUDE_SECURESTORAGE_CONFIG_DIR"] = str(tmp / "other")
    run(pct=99, share=share)
    assert snap.read_bytes() == local_before
    assert remote.read_bytes() == remote_before


class RateSnapshotWriterTests(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.writer = make_writer(Path(self.temp_dir.name))

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_redraw_source_and_relogin_limit(self):
        check_writer_redraw_source_and_relogin_limit(self.writer)

    def test_account_id_validation(self):
        cases = [(" acct-a ", True), ("acct-a", True), (None, False),
                 ("", False), ("   ", False), ("a\nb", False),
                 ("x" * 257, False), (42, False)]
        for value, valid in cases:
            with self.subTest(value=value):
                check_writer_records_account_id_only_when_valid(self.writer, value, valid)

    def test_missing_or_broken_account_file(self):
        check_writer_handles_missing_or_broken_account_file(self.writer)

    def test_shared_body_and_atomic_replacement(self):
        check_writer_shared_body_and_atomic_replacement(self.writer)

    def test_host_normalization(self):
        check_writer_normalizes_host_for_shared_filename(self.writer)

    def test_missing_source_or_limits(self):
        for session, limits in [(None, True), ("", True), (42, True),
                                ("writer-a", False)]:
            with self.subTest(session=session, limits=limits):
                check_writer_missing_source_or_limits_does_not_replace(
                    self.writer, session, limits)

    def test_zero_special_session_and_missing_seven_day(self):
        check_writer_zero_and_special_session_and_missing_seven_day(self.writer)

    def test_nondefault_account_changes_neither_destination(self):
        check_writer_nondefault_account_changes_neither_destination(self.writer)
