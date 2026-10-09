## 1. 変更前の実測（先に取る）

- [x] 1.1 変更前の `backfill.sh` で、SessionStart の後追い 1 回の所要時間（同期部分と、`COST_LEDGER_HOOK_FOREGROUND=1` の裏の処理全体、一覧が空の場合）と `gh` の呼び出し回数を、`plugins/cost-ledger/changes/691.md` の「実測」と同じ方法で各 5 回測って控える。LLM のトークンは使わない。 触る範囲: なし（測るだけ。結果は 760.md に書く）

## 2. 台帳パスの解決（#760）

- [x] 2.1 `backfill.sh` の台帳確認を、解決した値を `COST_LEDGER_PATH` に写して export する 3 行にする。冒頭コメント（`COST_LEDGER_PATH が未設定なら動かない`）も「台帳の場所が未設定なら」に直す。 触る範囲: `plugins/cost-ledger/scripts/backfill.sh:8-9`、`plugins/cost-ledger/scripts/backfill.sh:29`
- [x] 2.2 `backfill.bats` に「`COST_LEDGER_PATH` を外し `CLAUDE_PLUGIN_OPTION_LEDGER_PATH` だけを設定すると候補に行が積まれ、控えが userConfig 側の台帳の隣にできる」テストを 1 本足す。両方を別の場所に設定したときは userConfig が使われる検証も同じテストに入れる。 触る範囲: `plugins/cost-ledger/tests/backfill.bats:469-483`（「台帳が未設定」のテストの隣）
- [x] 2.3 README と `changes/691.md` の「`COST_LEDGER_PATH`」を「解決した台帳のパス」（`CLAUDE_PLUGIN_OPTION_LEDGER_PATH` 優先）に改める。 触る範囲: `plugins/cost-ledger/README.md:312-326`、`plugins/cost-ledger/changes/691.md:3-30`

## 3. 一覧が空で値が無い回（#762）

- [x] 3.1 `sweep()` の末尾に `elif seen_until(read_state(state_path), key) is None: write_seen(state_path, key, since)` を足す。docstring の流れ説明と `backfill.sh` 冒頭には書き足さない（挙動の説明は spec が正本）。 触る範囲: `plugins/cost-ledger/scripts/backfill.py:230-234`
- [x] 3.2 `backfill.bats` に「控えが無く一覧が 0 件の実行のあと、控えの `seen_until` が一覧の `since` と同じ」テストと、「2 回続けても 2 回目の `since` が同じ」テストを足す。既存の「一覧が 0 件なら変えない」テストは値がある場合の検証として名前と注釈を直す。壊れた控えで一覧が 0 件のときに読める形になる検証も足す。 触る範囲: `plugins/cost-ledger/tests/backfill.bats:794-799`
- [x] 3.3 `changes/691.md` の「壊れた控えと空の一覧」の記述を、この change で変わったことが分かるように直す（元の決定は書き換えず、`760.md` へのリンクを添える）。 触る範囲: `plugins/cost-ledger/changes/691.md:22`

## 4. bats の取りこぼし（#764）

現在のファイルでの位置を使う（issue の行番号はレビュー時点の版）。

- [x] 4.1 P5-F1: `[[ "$(body_trigger 2)" == "合計（"* ]]` に `|| return 1` を付ける。 触る範囲: `plugins/cost-ledger/tests/backfill.bats:917`
- [x] 4.2 P5-F2: 同じ形の最後の文の `[[ ]]` に `|| return 1` を付ける。 触る範囲: `plugins/cost-ledger/tests/backfill.bats:1163`
- [x] 4.3 P5-F3: 20 件上限のテストの `seq 1 25` を `seq 25 -1 1` にして、`candidates()` の並べ替えを固定する（期待値は変えない）。`sorted()` を外すと落ちることを確かめる。 触る範囲: `plugins/cost-ledger/tests/backfill.bats:740-755`
- [x] 4.4 P5-F4: `GH_HOST=GitHub.com` を立てる行の次に、gh に `GH_HOST` が渡っていない（`gh.log.env` に `GH_HOST=` が無い）ことを確かめる行を足す。 触る範囲: `plugins/cost-ledger/tests/backfill.bats:508-510`、stub の `.env` 記録 `:94-97`
- [x] 4.5 P5-F5: 使っていない切り替え `FAKE_COMMENTS_FAIL`（既存コメントの取得の失敗）を使うテストを足し、その候補で `seen_until` が止まらないことを確かめる。`FAKE_PATCH_FAIL` は使うテストを足すか、切り替えを消す（`FAKE_POST_FAIL` の既存テスト `:808` と重なるなら消す）。 触る範囲: `plugins/cost-ledger/tests/backfill.bats:808-820`、`:172-195`、`:78-79`
- [x] 4.6 P5-F6: 切り離しのテストが途中で落ちても裏のプロセスが残らないよう、`teardown() { wait_for_workers || true; }` を足す。 触る範囲: `plugins/cost-ledger/tests/backfill.bats:352-358`、`:387-401`

## 5. 検証と記録

- [x] 5.1 `bats plugins/cost-ledger/tests/backfill.bats` と cost-ledger の他の bats、`tests/injection-budget.bats` を流して通す。
- [x] 5.2 変更後に 1.1 と同じ方法で実測し、前後の表（所要時間・`gh` の回数）を `plugins/cost-ledger/changes/760.md` に書く。回数が増えていないこと、hook が出力を出さないことを確かめる（受け入れ条件。上限は置かず結果を記録する）。 触る範囲: `plugins/cost-ledger/changes/760.md`（新規）
- [x] 5.3 `760.md` に #760・#762・#764 をまとめて書く（版は上げない）。PR 本文に `Closes #760` `Closes #762` `Closes #764` と実測の表を書く。
