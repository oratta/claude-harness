実装で触るファイルは 5 個（`cost_ledger.py`・`multiline.bats`（新規）・`README.md`・`changes/695.md`（新規）、必要なら `ledger.bats`）。`helper.bash`・`hooks.json`・`ledger-hook.sh`・`pricing.json`・`gate_report.py` は変えない。行番号は仕様づくりの時点（HEAD f26fbecf の内容）の値で、前のタスクの編集でずれるので、編集前に該当範囲を読んで確かめる。

テストは `helper.bash` の `cl_setup` / `cl_write_log` / `cl_row`（1 応答 = 1 行の合成行を作る）を使い、同じ `requestId` の複数行は `cl_row` を同じ requestId で複数回呼んで作る（`uuid` が `u-<requestId>` 固定なので、後続行用に `uuid` を変える小さな関数を `multiline.bats` の中に置く。`helper.bash` は変えない）。

## 1. 先に確かめる

- [ ] 1.1 実ログで、複数の会話ログに現れる同じ `requestId`（resume・fork による複製）について、後続行の `uuid` が元と同じか違うかを数える。件数だけを記録し、中身は記録先にもリポジトリにも貼らない（読み取りだけ）。違う行が 1 件でもあれば、補足の事実の鍵（design 決定 2）を `uuid` から `timestamp` に変える。結果と決めた鍵を PR に書く。触る範囲: なし（実行だけ）
- [ ] 1.2 変更前の数字を測り、控える（PR に書く）。(a) 全履歴 1 パスの所要時間: `COST_LEDGER_PATH` を設定せず、実ログを読み取りだけで `python3 -B cost_ledger.py facts` 相当を 3 回流した中央値。(b) hook 1 回の所要時間: 実環境の台帳を一時ディレクトリへ写し、会話ログに応答を 1 行足してから `ledger-hook.sh` を 5 回流した中央値（`CLAUDE_CONFIG_DIR` も一時ディレクトリにする）。(c) 回収率: #286 と同じ測り方（main / master 上のコストのうち issue 番号で拾える割合。claude-harness と flatmate の 2 リポジトリ）。(d) `gh` の呼び出し回数: `cl_fake_gh` 相当の stub が記録する回数（`cost_ledger.py cost <番号>` 1 回あたり）。足す前のスクリプトは `git archive origin/main` で一時ディレクトリに取り出して使う。触る範囲: なし（実行だけ）

## 2. テストを先に書く（Red）

- [ ] 2.1 `multiline.bats` を作り、spec `cost-ledger-attribution` の「同じ応答の 2 行目以降の issue と投稿の印」の 6 Scenario を書く。(1) 2 行目にだけ `gh issue view 42` → `facts` の出力に `issues` が `["42"]` の事実がある、(2) 同じ `requestId` の 3 行が同じ `usage` → `cost` / `branch` の金額が 1 行だけの場合と同じ・補足の事実のトークンが 0、(3) 2 行目にだけ `gh pr comment 300` → `intervals` で区間がそこで閉じる、(4) 2 行目以降が `Edit` の本文に `gh issue view 999` を含むだけ → 補足の事実が出ず issue 999 に帰属しない、(5) メッセージ数が応答の数のまま（`branch` の `メッセージ` と `intervals` の `messages`）、(6) 同じ会話ログを 2 回読んでも補足の事実が 1 つ（`ledger-sync` を 2 回）。触る範囲: plugins/cost-ledger/tests/multiline.bats（新規）、plugins/cost-ledger/tests/helper.bash:100-129（`cl_row`。読むだけ）
- [ ] 2.2 `multiline.bats` に spec `cost-ledger-persistence` の Scenario を足す。補足の事実が台帳に書かれ `facts` の直読みと同じになる・補足を足す前の形の台帳（先頭行だけを書いた台帳。台帳に先頭の行だけを手で書いて作る）に `ledger-sync --rescan` を流すと既存の行が 1 バイトも変わらず（`cmp` で先頭の部分が一致）補足の行だけが追記される・`--rescan` を 2 回続けると 2 回目は 0 行・`--rescan` なしの `ledger-sync` は読み終えたファイルを開き直さず 0 行追記（会話ログを書き換えても台帳が変わらないことで確かめる）・会話ログを消してから `--rescan` しても補足は追記されず終了コード 0。触る範囲: plugins/cost-ledger/tests/multiline.bats、plugins/cost-ledger/tests/ledger.bats:62-135（台帳の使い方。読むだけ）
- [ ] 2.3 `bats plugins/cost-ledger/tests/multiline.bats` を流し、足したテストが落ち、既存の `facts.bats`・`ledger.bats`・`intervals.bats`・`attribution.bats` が通ることを確かめる。触る範囲: なし（実行だけ）

## 3. `cost_ledger.py`

- [ ] 3.1 `facts_from_lines` で、既出の `requestId` の行を捨てる代わりに、後続行から補足の事実を作る。行に `"Bash"` の文字列が無ければ走査しない。`scan_tool_calls` で issue か印が出たときだけ、`build_fact` の結果のトークン 5 種（`input_tokens`・`output_tokens`・`cache_write_5m_tokens`・`cache_write_1h_tokens`・`cache_read_tokens`）を 0 にし、`request_id` を `<元>#<uuid>`（決定 2 に従い、1.1 の結果で `timestamp` に変える場合あり）、`continuation: true` にして、`seen` に無ければ足して返す。`request_id` が先頭の鍵のままであること（`LEDGER_ID_PREFIX`）を保つ。`SCAN_STATS` の数え方は変えない。触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:377-414（`facts_from_lines`）、339-365（`build_fact`。読むだけ）、307-336（`scan_tool_calls`。読むだけ）、LEDGER_ID_PREFIX の前後（437-444。読むだけ）
- [ ] 3.2 補足の事実をメッセージ数に数えない（design 決定 3）。`continuation` が真の事実は、`summarise` の `messages` と `per_model[...]["messages"]`、`price_intervals` の `messages`、`cmd_report` の `repo_messages`、`cmd_intervals` の件数に数えず、金額とトークンの合計には（0 なので）そのまま足してよい。判定は小さな関数 1 つにまとめる。`unknown` モデルの件数にも数えない。触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:869-890（`summarise`）、1082-1087（`price_intervals`）、1467-1512（`cmd_report`）、1515-1535（`cmd_intervals`）
- [ ] 3.3 `ledger-sync --rescan` を足す。`_ledger_sync_locked` に `rescan` 引数を渡し、真のときは `previous.get(key, (0, None))` の読み終え位置を使わず `offset = 0` として今の置き場所の会話ログを全部読む（台帳の索引と `seen` はそのまま使う）。読み終え位置の差し替えは今までと同じ。`cmd_ledger_sync` と `build_parser` に `--rescan` を足す。`hook`（`ledger-hook.sh`）は変えない。触る範囲: plugins/cost-ledger/scripts/cost_ledger.py:568-653（`ledger_sync`・`_ledger_sync_locked`）、1668-1682（`cmd_ledger_sync`）、1747-1755（`build_parser` の `ledger-sync`）
- [ ] 3.4 `bats plugins/cost-ledger/tests/multiline.bats` が全部通り、`facts.bats`・`ledger.bats`・`intervals.bats`・`attribution.bats`・`cost-command.bats`・`timeline.bats`・`drift.bats`・`gate-report.bats` が変わらず通ることを確かめる。`facts.bats` の絶対パス検査が `__pycache__` で落ちる場合は #699 の既知の問題なので、`python3 -B` を使うか `__pycache__` を消して再実行する（直さない）。触る範囲: なし（実行だけ）

## 4. 文書と実測

- [ ] 4.1 `README.md` の「帰属の考え方」と「台帳」の節に、同じ応答が複数行に分かれても後続行の issue・投稿の印を拾うこと、補足の行（`continuation: true`・トークン 0）、`ledger-sync --rescan` の使い方（1 回だけ・実行前に台帳の控えを取る・会話ログが消えた期間は補えない）を書く。`plugins/cost-ledger/changes/695.md` を作る（`changes/692.md` の書式に合わせる）。触る範囲: plugins/cost-ledger/README.md:16-31、145-166、plugins/cost-ledger/changes/695.md（新規）
- [ ] 4.2 1.2 と同じ 4 つを変更後に測り直し、前後の表を PR に書く。(a) 全履歴 1 パスの所要時間、(b) hook 1 回の所要時間（1 秒未満を保つこと）、(c) 回収率（issue の acceptance 条件）、(d) `gh` の呼び出し回数（増えないこと）。加えて、実環境の台帳の写し（一時ディレクトリ）に `ledger-sync --rescan` を流して、追記された行数と所要時間を記録する。実環境の台帳そのものには流さない。マージ後に主が 1 回流す手順（実行前の台帳の控え・戻し方）を PR の本文に書く。触る範囲: なし（実行と PR 本文）
