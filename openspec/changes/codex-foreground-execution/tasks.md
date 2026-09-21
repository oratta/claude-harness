## 1. ターン実行を記録先から切り離す（既存経路を壊さない）

- [x] 1.1 `plugins/dev-workflow/scripts/codex-worker.py` の `worker()` から、app-server と会話してターンを完走させる部分（`initialize` → `account/read` → `advertised_model` → `account/rateLimits/read` → `thread/start` → `turn/start` → 完了待ち）を関数として切り出す
- [x] 1.2 切り出した関数が台帳に直接触れないようにする。台帳の読み書きだった 4 種（毎 RPC のハートビートと中止判定、thread / turn の ID の記録、実効設定の観測、usage の更新）を、呼び出し側が渡す記録先オブジェクトのメソッドにする
- [x] 1.3 台帳経路の記録先を既存の `db` 操作（`heartbeat` の `ledger_no_longer_running` / `update(db, job, ...)` / `observe_execution(db, job, ...)` / `jobs.cancel` の読み取り）で実装し、`worker()` がそれを渡す形に直す
- [x] 1.4 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py` を実行し、既存テストが全件通ること（回帰なし）を exit code 付きで確認する

## 2. 前景実行のテストを先に書く（Red）

- [ ] 2.1 偽 app-server（`test_codex_worker.py` の `FAKE`）を使って前景実行の依頼ファイルを組み立てるヘルパを足す（役割・cwd・model・effort・CODEX_HOME・prompt を載せる）
- [ ] 2.2 台帳を作らずに完走することを固定するテストを足す（実行後に `ledger.sqlite` と `ownership.sqlite` がどこにも存在しないこと、stdout の 1 行 JSON に最終回答・終了状態・使用量・要求した model / effort・観測した model / effort と観測元・thread / turn の ID が入ること、exit code が 0 であること）
- [ ] 2.3 呼び出し元の消失で 30 秒以内に終わることを固定するテストを足す。実際の起動経路を写した 3 段（テスト → 中間プロセス → `sh -c 'python3 codex-worker.py run …'` → `run`）で組み、`run` の直接の親が shell である状態のまま**中間プロセス**を終了させてから、`run` と app-server の両方の PID について `os.kill(pid, 0)` が失敗するまでの時間を測る
- [ ] 2.4 SIGTERM で止まることを固定するテストを足す（偽 app-server に `turn/interrupt` が届いた記録が残ること、app-server の子プロセスが残らないこと）
- [ ] 2.5 ターン開始前の失敗（アカウント照合の不一致・利用枠の使い切り・サーバーが thread / turn の開始をエラー応答で拒否）でも同じ形の JSON が出て、`error_kind` にサーバーのエラーコードを含む理由が入り、exit code が非ゼロになることを固定するテストを足す
- [ ] 2.6 前景実行が `--state-dir` を受け取らないことを固定するテストを足す（引数エラーで終わる）
- [ ] 2.8 結果 JSON の `effective.account` に app-server が返した実行中アカウントが入り、依頼の account 名（`requested.account`）と別に扱われることを固定するテストを足す（偽 app-server が要求名と違う email を返す場合に食い違いが JSON から分かる）
- [ ] 2.7 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py` を実行し、足したテストが落ちること（Red）を出力で確認する

## 3. 前景実行の入口を足す（Green）

- [ ] 3.1 `codex-worker.py` にサブコマンド `run` を足す。依頼ファイルを読み、必須項目（role / cwd / model / prompt / codex-home）と任意項目（effort / account / request_id / quota-margin-pct）を検証し、cwd の検査（所有者・repo root・feature branch・linked worktree）は台帳経路と同じものを使う
- [ ] 3.2 runtime の CODEX_HOME を `run` 自身が 0700 のディレクトリに用意する（`auth.json` の symlink と `config.toml`、project 設定層の拒否は台帳経路と同じ）。置き場は親に `TMPDIR` があればその配下、無ければ実行環境の既定の一時領域。app-server と子に渡す `TMPDIR` / `TMPPREFIX` は作りも書き換えもしない。終了時に symlink を外してディレクトリごと片付ける
- [ ] 3.3 アカウントの照合を自己整合で行う。app-server の `account/read` が返した email が、渡された CODEX_HOME の `auth.json` の email と一致することを確認し、実行中の link の差し替えも同じ home を比較先にして検査する。観測した実行中アカウント（email かその digest）を `effective.account` に入れ、依頼の account 名は `requested.account` に留める（要求名を `effective` へ写さない）
- [ ] 3.4 ターン開始前の利用枠確認を残す。同時に走っている件数は 1 固定、余裕率は依頼の `quota-margin-pct`（既定 5）を使い、`occupied_slots` / `reserve_global` を呼ばない
- [ ] 3.5 停止要求を表すフラグを 1 つ用意し、SIGTERM / SIGINT のハンドラはそのフラグを立てるだけにする（ハンドラから RPC を送らない）
- [ ] 3.6 起動時に `os.getppid()` から PID 1 まで辿った祖先の連鎖を控え、1 秒間隔で `ps -o ppid= -p <pid>` を使って辿り直すスレッドを足す。控えた連鎖と食い違ったら停止要求のフラグを立てる（直接の親の PID だけを比べない）
- [ ] 3.7 停止要求を app-server への毎 RPC の入口で確認し、立っていれば要求を送らずに中止として抜ける形にする。ターン待ちのループは停止要求を見て `turn/interrupt` を 1 回送る。**猶予の起点は interrupt を送った時刻**にし、interrupt 自身の応答待ちも `turn/completed` の待ちも残り猶予で切り詰めて 1 つの締切に統一する（残り 0 で応答を待たずに後始末へ進む）。前景経路の締切は 10 秒とし、台帳経路の猶予 20 秒と応答後起点は変えない
- [ ] 3.8 結果を標準出力の 1 行 JSON で出す。キーは `text` / `status` / `usage` / `execution`（`version=1` の `role` / `requested` / `effective` / `evidence`）/ `thread_id` / `turn_id` / `error_kind` とし、取得できなかった項目は `null` にする。失敗は exit code 2 で終わる。thread / turn の開始をサーバーがエラー応答で拒否したら、そのエラーコードを含む理由を `error_kind` に入れて非ゼロで終わる（再試行しない・別アカウントへ振り替えない）
- [ ] 3.9 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py` を実行し、全件通ること（Green）を exit code 付きで確認する

## 4. `--state-dir` を台帳サブコマンド側へ移す

- [ ] 4.1 `codex-worker.py` の `main()` で `--state-dir` をグローバルから外し、台帳を使うサブコマンド（`register` / `submit` / `status` / `result` / `cancel` / `ack` / `send` / `reap` / `_worker`）の引数にする
- [ ] 4.2 `submit` が `_worker` を起こす `subprocess.Popen` の引数の並びを、サブコマンドの後に `--state-dir` が来る形へ直す
- [ ] 4.3 `plugins/dev-workflow/scripts/codex-develop.py` の `worker(state, *args)` が組み立てるコマンドの並びを同じ形へ直す
- [ ] 4.4 既存テストの中で `--state-dir` をグローバル位置に置いている呼び出しをすべて直す
- [ ] 4.5 `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py` を実行し、全件通ることを exit code 付きで確認する

## 5. 依頼ファイルの組み立てを codex-develop.py から使えるようにする

- [ ] 5.1 `codex-develop.py` に、前景実行の依頼ファイルを書くサブコマンドを足す。`resolve_execution` で役割別の executor / account / model / effort を解決し、`prompt` で指示文を組み立てる
- [ ] 5.2 そのサブコマンドが run-dir と worker-state を要求しないようにする（前景経路は台帳も run も持たない）。account 名から CODEX_HOME への対応表を引数で受け取り（`--account-home NAME=PATH` の繰り返し、または `--account-home-file PATH` の JSON。JSON は名前をキー・CODEX_HOME の絶対パスを値とする平らなオブジェクト 1 つ）、役割の account 名をそこから解決して依頼へ載せる。2 つの与え方の併用は拒否する（合成も優先もしない）
- [ ] 5.3 profile の読み込みで登録済み account の確認（`registered_accounts`）が台帳を読む点を、前景経路では対応表による確認に置き換える（対応表に載っている account 名だけを受け付け、CODEX_HOME は対応表が解決した値を正とする）
- [ ] 5.4 組み立てた依頼ファイルがそのまま `run` に通ること（役割・model・effort・CODEX_HOME・prompt が一致すること）を固定するテストを足し、通ることを exit code 付きで確認する
- [ ] 5.5 対応表に無い account 名を profile が指しているとき、依頼ファイルを作らずに拒否し、既定や別の CODEX_HOME へ倒さないことを固定するテストを足す
- [ ] 5.6 `--account-home` と JSON ファイルを同時に与えたら依頼ファイルを作らずに拒否することと、JSON の値が絶対パスでない / 存在しないときに拒否することを固定するテストを足す

## 6. 手順書とバージョン

- [ ] 6.1 `plugins/dev-workflow/references/codex-develop.md` の呼び出し手順を「指示をファイルに書く → 前景コマンドを背景実行で起動 → 完了通知で結果を読む」の 3 手順に書き換える。`ack` / `retry` / `run-dir` / `worker-state` と継続記録の節を消す
- [ ] 6.2 `grep -nwE "ack|retry|run-dir|worker-state" plugins/dev-workflow/references/codex-develop.md` と `grep -n "継続記録" plugins/dev-workflow/references/codex-develop.md` がどちらも 0 件（exit 1）になることを確認する
- [ ] 6.3 `plugins/dev-workflow/docs/codex-develop.md` の導入手順を、前景実行の呼び方と CODEX_HOME の渡し方に合わせて直す
- [ ] 6.4 `plugins/dev-workflow/scripts/CODEX-WORKER.md` に前景実行の節（結果の JSON・親と一緒に終わる・SIGTERM・台帳に触れない・同時実行の枠管理と cwd 排他が無いこと）を足し、`--state-dir` の位置の変更を反映する
- [ ] 6.5 `plugins/dev-workflow/skills/develop/SKILL.md` と `plugins/dev-workflow/commands/develop.md` の Codex 経路の案内を、前景実行の呼び方へ直す
- [ ] 6.6 `plugins/dev-workflow/.claude-plugin/plugin.json` と `.claude-plugin/marketplace.json` の dev-workflow のバージョンを `2.13.13` にする（他プラグインのバージョンは触らない）

## 7. 検証

- [ ] 7.1 `openspec validate codex-foreground-execution --strict` が通ることを確認する
- [ ] 7.2 `bash scripts/test.sh` を全件実行し、成功件数・総件数・exit code を記録する
- [ ] 7.3 実際の Codex アカウントで read-only の役割を 1 件、本体の Bash ツールの背景実行で呼び、起動直後に `ps -o ppid=,comm=` で `run` の直接の親が何か（shell の wrapper が挟まっているか）を記録したうえで、完了通知で結果の JSON を受け取れたことを、コマンド・出力の要点・exit code・対象 HEAD とともに PR 本文に記録する
- [ ] 7.4 `grep -rn "state-dir" plugins/ docs/ 2>/dev/null` で、グローバル位置に `--state-dir` を置いたままの呼び出しが残っていないことを確認する
