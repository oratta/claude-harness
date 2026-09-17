#!/usr/bin/env bats

@test "Codex helper: protocol, timeout, bucket isolation, validation and account switching" {
    run python3 -m unittest discover -s "$BATS_TEST_DIRNAME" -p test_codex.py
    [ "$status" -eq 0 ]
}
