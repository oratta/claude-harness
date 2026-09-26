#!/usr/bin/env bats
# #522 の実機確認用の捨てテスト（PR はマージしない）
# 1 回目の実行でだけ落ちる。やり直し経路の実機確認用
@test "e2e-522 ci-watch fixture" {
  [ "${GITHUB_RUN_ATTEMPT:-1}" != 1 ]
}
