## Context

`plugins/dev-workflow/scripts/codex-worker.py` の `submit`（`command()` の中、`codex-worker.py:659`）は `subprocess.Popen(..., start_new_session=True)` で `_worker` を起こす。起こされた `worker(directory, job)`（`codex-worker.py:436`）は台帳 `ledger.sqlite` の行を `queued` → `running` に取り、`ownership.sqlite` の全体予約（`reserve_global`）で account の同時実行枠と cwd の排他を取り、ターンの完了を `while True` で待つ。このループには全体の時間上限が無い。呼んだセッションが消えても親子関係が切れているので止まらず、`running` のまま利用枠を使い続ける。

ターン実行の部分は台帳の読み書きと絡んでいる。`rpc.tick` に差す `heartbeat()` は毎 RPC で `jobs.status` を読んで `ledger_no_longer_running` を投げ、ループの先頭でも同じ読み取りをし、`observe_execution(db, job, ...)` と `update(db, job, ...)` が thread/turn の観測値と usage を行へ書く。app-server との会話そのもの（`initialize` → `account/read` → `advertised_model` → `account/rateLimits/read` → `thread/start` → `turn/start` → 完了待ち）は台帳と独立している。

`Rpc`（`codex-worker.py:360`）は app-server を `start_new_session` なしで起こすので、worker のプロセスグループに属する。`Rpc.close()` は stdin を閉じて 3 秒待ち、`terminate()` で 3 秒、`kill()` で 3 秒の段階的な後始末を既に持つ（最大 9 秒）。ターン中断の猶予は 20 秒で、超えると `interrupt_unconfirmed` になる。

アカウント名から CODEX_HOME への対応表は台帳の `accounts` テーブルにしかない。`codex-develop.py` の `registered_accounts(worker_state)`（`codex-develop.py:204`）も `ledger.sqlite` を読んでいる。`--state-dir` は `codex-worker.py:686` でグローバルの必須オプションになっており、どのサブコマンドでも台帳のパスを要求する。

Claude 側の対応物: 本体は Agent ツールでサブエージェントを背景実行し、ハーネスの完了通知で結果を受け取り、TaskStop で止める。セッションが終われば一緒に終わる。台帳も継続記録も無い。

## Goals / Non-Goals

**Goals:**

- Codex に 1 回のターンを実行させる前景コマンド（`run`）を足し、結果を stdout の 1 行 JSON で返して終了する
- そのコマンドが、呼んだプロセスの消失と SIGTERM / SIGINT の両方で、app-server の子プロセスごと 30 秒以内に終わる
- 台帳（`ledger.sqlite`）と所有権の記録（`ownership.sqlite`）を作らず、読まない経路にする
- ターン実行の本体を記録先から切り離し、前景経路と既存の台帳経路が同じコードを通る形にする
- 呼び出し側の手順書を「指示をファイルに書く → 前景コマンドを背景実行で起動 → 完了通知で結果を読む」の 3 手順にする

**Non-Goals:**

- 古い経路（`submit` / `status` / `result` / `ack` / `cancel` / `retry` / `register` / `reap` と台帳・所有権）を消すこと。消すのはエピック #345 の後続の子
- 前景経路に同時実行の枠管理・cwd の排他・継続記録・resume / live steering を持ち込むこと（Claude のサブエージェントに対応物が無い）
- 砂場の水準・`approvalPolicy`・model / effort の検証・読む役の読み取り専用の強制を変えること

## Decisions

### 親の消失は、起動時に控えた親 PID と `os.getppid()` の変化で検知する

macOS には Linux の `PR_SET_PDEATHSIG`（親が死んだら子にシグナル）が無い。代わりに、起動時に `os.getppid()` を控え、1 秒間隔の監視スレッドで同じ値を読み直す。親が消えると再親付けが起きて値が変わる（通常は 1 か launchd）。変化そのものを合図にするので、PID が再利用されて別のプロセスが同じ番号を持つ場合でも誤検知にならない（再利用は「親が消えたあと」にしか起きない）。

代案は 2 つ検討して採らない。stdin の EOF を見る方法は、本体が Bash の背景実行で起こすと stdin が `/dev/null` になるため合図にならない。呼び出し側にパイプの保持を要求する方法は、Claude のサブエージェントには無い決まりごとを呼び出し側に足すことになり、「投げ先が変わるだけで呼び出し側の作りは変わらない」という方針に反する。

### 30 秒の予算は「検知 1 秒 + 中断の猶予 10 秒 + 後始末 9 秒 = 20 秒」で組む

受け入れ条件は合図から 30 秒以内にコマンドと app-server の両方が消えることを求める。現行の中断確認の猶予は 20 秒（`interrupt_unconfirmed`）で、`Rpc.close()` の段階的な待ちが最大 9 秒ある。検知の 1 秒を足すと 30 秒ちょうどになり、余裕が無い。前景経路の中断猶予だけを 10 秒に縮めて 20 秒に収める。台帳経路の 20 秒は変えない（回収する人がいる前提の経路なので、確認を待つ価値がある）。

### 停止の合図を 1 本にまとめる。シグナルハンドラは RPC を送らない

親の消失・SIGTERM・SIGINT・サーバーからの想定外要求（`rpc.unsupported`）を、すべて「停止要求」を表す 1 つのフラグに集める。ターン待ちのループはそのフラグを見て `turn/interrupt` を 1 回送り、猶予の中で `turn/completed` を待ち、来なければ後始末に入る。シグナルハンドラの中では RPC を送らずフラグを立てるだけにする（ハンドラは待ち受けスレッドと別の文脈で走るので、そこから app-server と会話すると stdin の書き込みが途中の JSON と混ざる）。

### ターン実行を「記録先を差し替えられる形」に分け、前景経路は台帳を開かない

`worker()` から、app-server と会話してターンを完走させる部分を関数として切り出す。台帳に触れていた 4 種類の呼び出し（毎 RPC のハートビートと中止判定、thread / turn の ID の記録、実効設定の観測、usage の更新）を、呼び出し側が渡す記録先オブジェクトのメソッドにする。台帳経路の記録先は今の `db` 操作をそのまま行い、前景経路の記録先はメモリに貯めて最後に JSON を組み立てる。中止判定は、台帳経路では `jobs.cancel` 列、前景経路では停止要求のフラグを返す。

代案として「`run` が台帳を一時ディレクトリに作って `_worker` を呼ぶ」が考えられる。採らない。受け入れ条件 1 が「台帳ファイルを作らずに完走する」と測るうえ、一時的でも台帳を作れば所有権の予約・ack・cwd ロックの状態遷移が残り、どこかで回収されないまま溜まる。

### アカウントは依頼に載せた CODEX_HOME で固定し、照合は自己整合で行う

account 名から CODEX_HOME への対応表は台帳の `accounts` テーブルにしかないので、前景経路では引けない。依頼ファイルに CODEX_HOME のパスを直接載せ、名前の解決は呼び出し側に残す。account 名も依頼に載せるが、それは結果の記録に使うラベルであって、照合の材料ではない。

照合は「app-server の `account/read` が返した email が、渡された CODEX_HOME の `auth.json` の email と一致する」という自己整合で行う（台帳経路が `accounts.identity` と突き合わせているところを、渡された home 自身と突き合わせる形に置き換える）。runtime の `auth.json` が実行中に差し替えられていないかの確認（`runtime_identity_matches` に相当）は、比較先を渡された home にして残す。

**この決定で失われるもの**: 登録済み account だけに実行先を縛る性質が前景経路には無くなる。どの CODEX_HOME を使うかは呼び出し側の責任になる。代案の「台帳を読み取り専用で開いて対応表だけ引く」は、台帳ファイルの存在と `register` 済みであることを前景経路の前提として残してしまうので採らない。

### 利用枠の確認は残し、同時実行の枠管理と cwd の排他は持たない

`thread/start` の前に `account/rateLimits/read` を呼んで枠を確認する手順は前景経路にも残す（使い切った状態で投げないため）。ただし `occupied_slots` は `ownership.sqlite` を開いて数えるので使えず、同時に走っている件数（`inflight`）は 1 固定になる。余裕率（`quota_margin_pct`）は台帳の account 行ではなく依頼の値（既定 5）を使う。

account ごとの同時実行上限（`max_concurrent`）と cwd の排他は前景経路には無い。本体が 1 つの worktree に 1 件ずつ割り当てることで担保する（Claude のサブエージェントと同じ条件）。これは受け入れる違いとして仕様に書く。

### `--state-dir` を台帳サブコマンド側へ移す

グローバル必須のままだと `run` にも台帳のパスを渡すことになり、「台帳に触れない」がコードを読まないと分からない。`--state-dir` を台帳を使うサブコマンド（`register` / `submit` / `status` / `result` / `cancel` / `ack` / `send` / `reap` / `_worker`）の引数に移し、`run` は受け取らない形にする。構造で保証できるぶん、テストで固定する項目が 1 つ減る。

この移動でコマンドの並び（`--state-dir` がサブコマンドの前か後か）が変わるので、`codex-develop.py` の `worker()` の呼び出しと、`scripts/CODEX-WORKER.md` / `docs/codex-develop.md` の例を同時に直す。

### runtime CODEX_HOME は `run` 自身が作り、終了時に片付ける

台帳経路の `runtime_home()` は `<state-dir>/runtimes/<job>` に 0700 のディレクトリを作り、`auth.json` の symlink と `config.toml` を置く。前景経路は state-dir を持たないので、同じ内容を自分で作った一時ディレクトリに置き、終了時に `auth.json` の symlink を外してディレクトリごと消す。一時領域そのもの（`TMPDIR`）は親の値をそのまま使う（#338 で決めた形）。project 設定層の拒否（`unsupported_project_config`）は前景経路でも同じに効かせる。

### stdout は成功も失敗も同じ 1 行 JSON にし、失敗の exit code は 2 に揃える

出す項目は、最終回答のテキスト・`status`・`usage`・要求した executor / account / model / effort・観測した model / effort とその観測元・`thread_id` / `turn_id` / `error_kind`。失敗時は観測できたところまでを埋め、残りを `null` にして `error_kind` に理由を入れる。exit code は既存の `command()` の失敗（2）に揃える。本体は JSON の 1 行だけを読めばよく、Claude のサブエージェントの返り値と同じ扱いができる。

### 前景経路は継続記録を作らない

継続記録（`<!-- codex-develop-continuation:v1|v2 ... -->`）は run-dir と worker-state を指しており、前景経路にはどちらも無い。セッションをまたいで復元する代わりに、その工程をやり直す。復元できない状態で黙って別経路へ倒さない、という既存の要件（「復元不能時は安全に停止する」）は台帳経路のものとして残す。

### テストは偽 app-server で 3 件、親の終了は中間プロセスを立てて測る

既存テスト（`plugins/dev-workflow/tests/test_codex_worker.py`）の偽 app-server（`FAKE`）を使う。足すのは 3 件。

台帳を作らない完走は、`run` を実行したあとに state-dir に当たるディレクトリが無いこと（`ledger.sqlite` / `ownership.sqlite` が存在しないこと）と、stdout の JSON の項目を見る。親の終了は、`run` を直接起こすのではなく中間の親プロセスを立てて `run` を起こさせ、その中間プロセスを kill してから `os.kill(pid, 0)` が失敗するまでを測る（テスト側の上限は 30 秒、想定は 20 秒以内）。SIGTERM は `run` に直接送り、偽 app-server が `turn/interrupt` を受け取った記録が残ることと、app-server の子プロセスが残らないことを見る。

## Risks / Trade-offs

- [account の同時実行上限が前景経路で効かない] → 受け入れる。本体が worktree を 1 件ずつ割り当てる運用で担保し、枠そのものは `thread/start` の前に毎回確認するので、使い切りは検知できる。上限の管理が実際に要ると分かったら、Codex 側だけに戻すのではなく Claude のサブエージェント側と揃えて入れる
- [同じ worktree に 2 件投げられる（cwd の排他が無い）] → 受け入れる。Claude のサブエージェントは今も同じ条件で、worktree の割り当ては本体の責任になっている
- [登録外の CODEX_HOME を渡せる] → 受け入れる。前景経路には台帳が無いので、課金経路を縛る主体が呼び出し側に移る。`auth.json` の所有者と実行中の差し替えは引き続き検査する
- [親 PID の監視が 1 秒間隔なので、最悪 1 秒の検知遅れが出る] → 予算に組み込み済み（合計 20 秒で 30 秒の条件に収まる）
- [同じターン実行を 2 経路が通るので、片方の都合で直すともう片方に効く] → 狙いどおりだが、台帳経路の既存テストを残して回帰を捕まえる
- [セッション再起動で走行中の仕事が失われる] → 受け入れる違いとして issue でオーナーと合意済み。worktree に書かれた途中のファイルは残る

## Migration Plan

古い経路は残すので、保存済みの台帳スキーマ（`jobs` / `accounts` / `ownership`）は変えない。走行中の job は古いコードのプロセスが最後まで面倒を見る。

破壊的なのは `--state-dir` の位置だけで、`codex-worker.py --state-dir DIR submit ...` の形で直接呼んでいる箇所（`codex-develop.py` の `worker()`、テスト、`scripts/CODEX-WORKER.md` と `docs/codex-develop.md` の例）を同じ変更の中で直す。外部の利用者はいない（このリポジトリの中からしか呼ばれない）。

戻す場合は revert で足りる。前景経路は状態を残さないので、後片付けは要らない。
