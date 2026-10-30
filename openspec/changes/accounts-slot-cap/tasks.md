## 1. 実装とテスト
- [x] 1.1 `accounts.sh add`: id の位置のハイフン始まりの引数を `die_usage` で拒否する（`-h|--help` は従来どおり使い方を出して exit 0。既存の `--label` 専用の case は `-*)` に一般化する）。8 個以上の上限を python 側の `add` で、既存 id の検査の後・`os.makedirs` の前に検査して exit 2 にする。ヘッダコメント（12-17 行）と usage に上限を 1 行書く 触る範囲: plugins/dev-workflow/scripts/accounts.sh:12-17, plugins/dev-workflow/scripts/accounts.sh:68-73, plugins/dev-workflow/scripts/accounts.sh:165-177
- [x] 1.2 `accounts-init.sh`: 配列が 8 要素以上で新しい id のとき、書き込みの前に stderr へ理由を出して exit 2 にする（既存 id の上書きは許す。for/else の else 側）。72 行目の `python3 <<'PY' || exit 1` を `|| exit $?` に変え、python の exit 2 を保つ（壊れた JSON の exit 1 はそのまま）。ヘッダコメントと usage に上限を 1 行書く 触る範囲: plugins/dev-workflow/scripts/accounts-init.sh:72, plugins/dev-workflow/scripts/accounts-init.sh:95-105
- [x] 1.3 bats（`CLAUDE_ACCOUNTS_FILE` と `CLAUDE_ACCOUNTS_HOME` を一時ディレクトリに向ける）: (a) 8 個登録済みで `accounts.sh add z` が exit 2・登録簿不変・ディレクトリ無し (b) 8 個登録済みで `accounts-init.sh --id z` が exit 2（1 でないこと）・登録簿不変 (c) 8 個登録済みでも既存 id の `accounts-init.sh` は通る (d) 7 個から 8 個目が `accounts.sh add` でも `accounts-init.sh` でも足せる (e) 9 要素の登録簿への新しい id の追加が両スクリプトで exit 2・不変 (f) `accounts-init.sh` の壊れた JSON は従来どおり exit 1・不変（終了コードの区別を守る） (g) `add` の id の位置のハイフン始まり（`--lable` `--version` `-H` `--` `-`）が exit 2・不変・ディレクトリ無し 触る範囲: plugins/dev-workflow/tests/accounts-command.bats:284-293（add の末尾のテストの後ろに追加）

## 2. 文書
- [x] 2.1 `plugins/dev-workflow/README.md` の add の説明に、上限 8 個の拒否（exit 2）と id の位置のハイフン始まりの拒否を足す 触る範囲: plugins/dev-workflow/README.md:98
- [x] 2.2 変更記録 `plugins/dev-workflow/changes/1031.md` を書く（上限の拒否、ハイフン始まりの id が `add` で登録できなくなること、戻し方） 触る範囲: plugins/dev-workflow/changes/1031.md（新規）

## 3. spec
- [ ] 3.1 `openspec/specs/usage-account-registry/spec.md` に change の delta を取り込む（archive で反映） 触る範囲: openspec/specs/usage-account-registry/spec.md:361-371
