#!/usr/bin/env bats

@test "Codex develop and worker Python regression suite" {
    run python3 -m unittest discover -s "$BATS_TEST_DIRNAME" -p 'test_codex_*.py'
    [ "$status" -eq 0 ]
}
