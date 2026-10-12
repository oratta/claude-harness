行番号は仕様づくりの時点（HEAD 85dd795e）の値。前のタスクの編集でずれるので、編集前に該当範囲を読んで確かめる。テストは各節の実装より先に書き、落ちることを見てから実装する。

## 1. 登録簿の読み取り（usage_view.py）

- [x] 1.1 `plugins/dev-workflow/tests/test_usage_view.py` に、`enabled` が `false` / `true` / 省略 / `"false"` / `0` / `null` の 6 スロットで `false` だけがオフに読まれ 6 つとも残ること、先頭がオフの 9 スロットで先頭 8 個が宣言順に残ること、`read_registry` の戻り値が従来の `[(id, securestorage)]` のままであること、オフのスロットが `build_view` の `accounts` と active 判定に残ることのテストを足す。触る範囲: plugins/dev-workflow/tests/test_usage_view.py:30-317（`EffectiveValues` クラスの後ろに新しいクラスを足す）
- [x] 1.2 `usage_view.py` に、オンかオフかを含めてスロットを返す読み取り関数を足し、`read_registry` はその結果から印を落として返す形にする（戻り値の形は変えない）。オフの判定は `entry.get("enabled") is False` の 1 か所。触る範囲: plugins/dev-workflow/scripts/usage_view.py:57-86（`read_registry`）
- [x] 1.3 `python3 -m pytest plugins/dev-workflow/tests/test_usage_view.py` が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 2. 自動選択と明示選択（select-account.sh）

- [x] 2.1 `account-selector.bats` に次のテストを足す: オフのスロットは週次余裕が最大でも選ばれず `margins` に `b:off` が出る／`enabled` を書いていない登録簿では stdout と理由行が変わらない（既存のテストが通り続けることに加え、`"enabled": true` を書いた登録簿と書かない登録簿で出力が一致することを 1 本で確かめる）／オフのスロットの明示選択は exit 2・stdout 空・stderr に id と `enabled` と登録簿のパス／全スロットがオフなら stdout 空行・exit 0・`selected=a reason=default-due-to-all-off`／オンのスロットが欠測でオフのスロットに値があるとき `reason=default-due-to-missing-usage` と `margins=a:missing,b:off`。`write_registry` は `enabled` を渡せるように引数を足すか、テスト内で登録簿を直接書く。触る範囲: plugins/dev-workflow/tests/account-selector.bats:26-34（`write_registry`）、plugins/dev-workflow/tests/account-selector.bats:239-259（明示選択のテストの並び）、plugins/dev-workflow/tests/account-selector.bats:374-383（末尾に追加）
- [x] 2.2 `select-account.sh` を、タスク 1.2 の読み取り関数でスロットを読むように変える。明示選択はオフなら診断を出して exit 2。自動選択はオフのスロットを実効値を調べる前に `off` として `margins` に積んで飛ばす。候補が無いとき、オンのスロットが 1 つも無ければ理由を `default-due-to-all-off` にする（`selected` の決め方は変えない）。冒頭のコメントに `off` を足す。触る範囲: plugins/dev-workflow/scripts/select-account.sh:39-49（明示選択）、plugins/dev-workflow/scripts/select-account.sh:59-96（自動選択と縮退）
- [x] 2.3 `bats plugins/dev-workflow/tests/account-selector.bats` が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 3. 使用量の取得（usage-probe.sh）

- [ ] 3.1 `usage-probe-multi-account.bats` に次のテストを足す: 本番経路（`curl` と `security` を `PATH` の差し替えで記録するスタブにする。既存の `user-agent:` のテストの足場と同じ形）で、`b` が `enabled: false` のとき `b` のサービス名での `security` の呼び出しと `b` のための `curl` の呼び出しが 0 回で、`a` は取得される／snapshot に `b` の前回値があるとき、`a` の取得後も `accounts.b` が `fetched_at` 込みで前回値のまま／全スロットがオフなら snapshot も試行状態も書き換えられず exit 0／`--print-slots` はオフのスロットも 4 列で出す／試行状態に `b` が記録されない。触る範囲: plugins/dev-workflow/tests/usage-probe-multi-account.bats:515-573（スタブの足場）、plugins/dev-workflow/tests/usage-probe-multi-account.bats:607-650（実行条件のテストの並び）、plugins/dev-workflow/tests/usage-probe-multi-account.bats:806-815（末尾に追加）
- [ ] 3.2 `usage-probe.sh` の `read_slots` が 5 列目にオンかオフかを出すようにし、配列に読み込む。5 列目が無い行（python3 が無いときに出す 4 列の縮退行）はオンと読む。`--print-slots` は 4 列のまま。叩くスロットを選ぶ判定（`due`）でオフのスロットを落とす。snapshot の組み立ては変えない（取得しなかったスロットは前回値を引き継ぐ既存の経路に入る。組み立て側が TSV の先頭 4 列だけを読むことを確かめる）。冒頭の契約コメントにオフのスロットの扱いを 1 項目足す。触る範囲: plugins/dev-workflow/scripts/usage-probe.sh:4-21（契約コメント）、plugins/dev-workflow/scripts/usage-probe.sh:55-146（`read_slots` と配列への展開）、plugins/dev-workflow/scripts/usage-probe.sh:193-241（実行条件）、plugins/dev-workflow/scripts/usage-probe.sh:482-489（組み立て側の TSV の読み方。確認のみ）
- [ ] 3.3 `bats plugins/dev-workflow/tests/usage-probe-multi-account.bats` が exit 0 になることを確かめる。触る範囲: なし（実行のみ）

## 4. 生成手段（accounts-init.sh）

- [ ] 4.1 `usage-probe-multi-account.bats` の `init:` の並びに、`enabled: false` の `b` を `--id b --label B2` で上書きしても `enabled` が `false` のまま残ること、`enabled` の無いスロットの上書きと新しい id の追加では `enabled` が書かれないことのテストを足す。触る範囲: plugins/dev-workflow/tests/usage-probe-multi-account.bats:308-345（`accounts-init.sh` のテストの並び）
- [ ] 4.2 `accounts-init.sh` の上書きの分岐で、既存スロットに `enabled` があればその値を新しいスロットに写す。冒頭のコメントの「同じ id が既にあれば上書きし」に `enabled` は残す旨を足す。触る範囲: plugins/dev-workflow/scripts/accounts-init.sh:15（コメント）、plugins/dev-workflow/scripts/accounts-init.sh:91-97（上書きと追加）

## 5. ステータスライン（statusline.sh）

- [ ] 5.1 `statusline-multi-account.bats` に次のテストを足す: 非 active の `B` が `enabled: false` で snapshot と記録に値があるとき、`B` の行は 1 行だけで ANSI を除くと `  B  off`、`B` の使用率・バー・経過時間が出ない／値が無いオフのスロットも `off` の行を出す／`enabled` を書いていない登録簿と `"enabled": true` を書いた登録簿で出力がバイト単位で一致する（変更前との同一は既存の `byte-identical` のテストが通り続けることで確かめる）／`enabled` が `"false"`・`0`・`null` のスロットは従来どおり描かれる／active のスロットがオフでも `▸ ` とライブ値で描かれ `off` が出ない／オフのスロットの全角 label も列幅に数える／1 スロットだけの登録簿でそのスロットがオフでも出力が変わらない。触る範囲: plugins/statusline/tests/statusline-multi-account.bats:81-91（`write_two_slot_registry`）、plugins/statusline/tests/statusline-multi-account.bats:687-754（バイト同一のテストの足場）、plugins/statusline/tests/statusline-multi-account.bats:885-888（末尾に追加）
- [ ] 5.2 `statusline.sh` の登録簿を読む埋め込み python が 6 列目にオンかオフかを出すようにし（判定は `e.get("enabled") is False`）、`slot_enabled` の配列に読み込む。登録簿が無いときの既定スロットはオン。触る範囲: plugins/statusline/scripts/statusline.sh:393-472（アカウントレジストリの読み取り）
- [ ] 5.3 非 active スロットのセッション記録との突き合わせの引数からオフのスロットを外す。描画のループで、非 active かつオフのスロットは `${prefix}${DIM}off${RESET}` を 1 行足して次のスロットへ進む（active の分岐と 1 スロットの経路は変えない）。触る範囲: plugins/statusline/scripts/statusline.sh:584-590（突き合わせの引数）、plugins/statusline/scripts/statusline.sh:721-761（描画のループ）
- [ ] 5.4 `bats plugins/statusline/tests/statusline-multi-account.bats` が exit 0 になることを確かめる。1 件だけ落ちたときは単独で再実行して判定する（statusline のテストは単発で落ちることがある）。触る範囲: なし（実行のみ）

## 6. 文書と変更の記録

- [ ] 6.1 `plugins/statusline/README.md` の登録簿のフィールド表に `enabled` の行を足し、オフのスロットの表示（`off` の 1 行）と、切り替えは当面 `accounts.json` を手で書き換えることを書く。触る範囲: plugins/statusline/README.md:100-135（「レジストリの作り方」とフィールド表）
- [ ] 6.2 `plugins/dev-workflow/README.md` の「Claude アカウントの起動時選択」に、オフのスロットは自動選択されず `cld-account <id>` では exit 2 になることを 1〜2 文で足す。触る範囲: plugins/dev-workflow/README.md:37-75（「Claude アカウントの起動時選択」）
- [ ] 6.3 変更の記録を `plugins/dev-workflow/changes/976.md` と `plugins/statusline/changes/976.md` に書く（何が変わるか・戻し方）。触る範囲: plugins/dev-workflow/changes/976.md（新規）、plugins/statusline/changes/976.md（新規）

## 7. 全体の確認

- [ ] 7.1 受け入れ条件の 4 つのコマンドを続けて実行し、すべて exit 0 になることを確かめる: `bats plugins/dev-workflow/tests/account-selector.bats`、`bats plugins/dev-workflow/tests/usage-probe-multi-account.bats`、`bats plugins/statusline/tests/statusline-multi-account.bats`、`python3 -m pytest plugins/dev-workflow/tests/test_usage_view.py`。あわせて `usage_view` を使うほかのテスト（`plugins/dev-workflow/tests/usage-probe.bats`、`plugins/dev-workflow/tests/prompt-tripwires-refresh.bats`）と `bats tests/injection-budget.bats` が通ることを確かめる。触る範囲: なし（実行のみ）
- [ ] 7.2 `openspec validate account-enabled-flag --strict` が通ることを確かめる。触る範囲: なし（実行のみ）
- [ ] 7.3 実機の `~/.claude/accounts.json` の B に `"enabled": false` を足し、`select-account.sh` の標準エラーの 1 行（`selected=a`）を issue #976 にコメントする（受け入れ条件の最後の項目。実装後の工程で行い、仕様化と実装の工程ではやらない）。触る範囲: なし（実機の設定ファイルと issue コメント）
