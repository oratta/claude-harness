## 1. 実装とテスト
- [ ] 1.1 `accounts.sh add`: id の位置のハイフン始まりの引数を `die_usage` で拒否する（`-h|--help` は従来どおり使い方を出して exit 0。既存の `--label` 専用の case は `-*)` に一般化する）。8 個の上限を python 側の `add` で、既存 id の検査の後・`os.makedirs` の前に検査する 触る範囲: plugins/dev-workflow/scripts/accounts.sh:65-72, plugins/dev-workflow/scripts/accounts.sh:174-185
- [ ] 1.2 `accounts-init.sh`: 配列が 8 要素で新しい id のとき、書き込みの前に stderr へ理由を出して exit 2 にする（既存 id の上書きは許す）。ヘッダコメントと usage に上限を 1 行書く 触る範囲: plugins/dev-workflow/scripts/accounts-init.sh:110-125（python 部。for/else の else 側）
- [ ] 1.3 bats: (a) 8 個登録済みで `accounts.sh add z` が非 0・登録簿不変・ディレクトリ無し (b) 8 個登録済みで `accounts-init.sh --id z` が非 0・登録簿不変 (c) 8 個登録済みでも既存 id の `accounts-init.sh` は通る (d) 7 個から 8 個目は足せる (e) `add` の id の位置のハイフン始まり（`--lable` `--version` `-H` `--` `-`）が exit 2・不変。テストは `CLAUDE_ACCOUNTS_FILE` と `CLAUDE_ACCOUNTS_HOME` を一時ディレクトリに向ける 触る範囲: plugins/dev-workflow/tests/accounts-command.bats:284-293（add の末尾のテストの後ろに追加）

## 2. spec
- [ ] 2.1 `openspec/specs/usage-account-registry/spec.md` に change の delta を取り込む（archive で反映） 触る範囲: openspec/specs/usage-account-registry/spec.md:361-371
