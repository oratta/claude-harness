## 1. テスト（Red）

- [x] 1.1 `--refresh` のテストを足す（既存テストは変えない）。spec の scenario に対応させる: 待ち中でないスロットは鮮度と間隔の内側でも取り直す（snapshot の `fetched_at` と試行時刻が実行時刻になる）／429 の待ち中のスロットは叩かず、snapshot の前回値と試行状態ファイルの試行時刻・連続 429 回数が変わらない一方、同じ実行で待ち中でないスロットは取り直す／待ちが明けたスロットは鮮度の内側でも取り直し、200 で連続 429 回数が 0 に戻る／オフのスロットは `--refresh` でも叩かず試行も記録しない。引数なしで間隔内なら叩かない既存テスト（`interval: slots attempted an hour ago ...`）はそのまま残す。触る範囲: plugins/dev-workflow/tests/usage-probe-multi-account.bats:741-850（`condition:`・`interval:`・`429:` の既存テスト群。ここの書き方と `write_two_slot_registry`・`write_resp`・`state_of` を使い、`429: a 200 resets the consecutive count` の直後に足す）、plugins/dev-workflow/tests/usage-probe-multi-account.bats:11-56（setup と補助関数。確認のみ）

## 2. 実装（Green）

- [x] 2.1 `usage-probe.sh` で `$1` が `--refresh` かを読み、`due` の判定に渡す（`REFRESH=1` のような環境変数で python に渡す。外から与える環境変数としては読まない）。`--refresh` のときは鮮度の判定（`old(...)` の行）を飛ばし、連続 429 回数が 0 のスロットは間隔の判定も飛ばす。連続 429 回数が 1 以上のスロットは引数なしと同じ `wait` で待ち中かを判定する。オフのスロットを落とす経路（`slot_pairs` を作るループ）は変えない。触る範囲: plugins/dev-workflow/scripts/usage-probe.sh:160-168（`--print-slots` の分岐。その近くで引数を読む）、plugins/dev-workflow/scripts/usage-probe.sh:206-258（実行条件 `due` の判定）
- [x] 2.2 冒頭の契約コメントに `--refresh` の項目を足す（外す条件・残す条件・1 回の実行にだけ効くこと）。サブコマンドの一覧にも並べる。触る範囲: plugins/dev-workflow/scripts/usage-probe.sh:4-48

## 3. 検証

- [x] 3.1 `bats plugins/dev-workflow/tests/usage-probe-multi-account.bats plugins/dev-workflow/tests/usage-probe.bats plugins/dev-workflow/tests/usage-probe-reset-grants.bats` が通る
- [x] 3.2 `openspec validate usage-probe-refresh-flag --type change --strict` が exit 0

## 4. 変更の記録

- [x] 4.1 変更の記録 `plugins/dev-workflow/changes/1256.md`（新規）を書く（版は上げない）。既存の記録（例: `plugins/dev-workflow/changes/991.md`）の書き方に合わせる。触る範囲: plugins/dev-workflow/changes/1256.md（新規）
