# Codex手動worker（初版）

経路は2つある。台帳（state-dir）に仕事を積んで別プロセスから照会する**台帳経路**と、台帳を持たず1回の呼び出しで完走する**前景実行**（`run`）。`--state-dir` は台帳を使うサブコマンド（`register` / `submit` / `status` / `result` / `cancel` / `ack` / `send` / `reap`）の引数で、サブコマンドの**後ろ**に置く。

## 台帳経路

```sh
python3 plugins/dev-workflow/scripts/codex-worker.py register --state-dir "$HOME/.local/state/claude-harness-codex/jobs" --account personal --codex-home "$HOME/.codex" --max-concurrent 3 --quota-margin-pct 5
python3 plugins/dev-workflow/scripts/codex-worker.py submit --state-dir "$HOME/.local/state/claude-harness-codex/jobs" --request request.json
python3 plugins/dev-workflow/scripts/codex-worker.py result --state-dir "$HOME/.local/state/claude-harness-codex/jobs" --job example-1
python3 plugins/dev-workflow/scripts/codex-worker.py reap --state-dir "$HOME/.local/state/claude-harness-codex/jobs" --account personal
```

request.json:
```json
{"request_id":"example-1","origin":"manual","account":"personal","cwd":"/absolute/linked-worktree","model":"explicit-model-id","effort":"high","role":"implement","prompt":"The complete bounded task and acceptance criteria"}
```

`effort`は省略可能な非空文字列。workerはrequestの静的検証後、App Serverのinitializeと全ページの`model/list`を使い、`thread/start`前にmodelと広告されたeffortの組合せを検証する。`thread/start`と`turn/start`の両方へmodelを渡し、effortは`turn/start`だけへ渡す。未知値や一覧取得失敗はturnを開始せずfailedとして残す。

request_id=job_id。同一ID同一入力は再実行しない。status/result/cancel/ackには`--job ID`。stdout JSON、拒否exit2。`result.text`は最終出力、usage欠落はnull。公開`execution`には要求値と、thread/turn通知から観測できた実効model/effort・観測元・job/thread/turn IDを載せる。未観測値はnullであり要求値から補完しない。完了と品質承認は別。結果回収後にackし、次工程は新IDでsubmitする。unknownはackも新規投入も拒否し、手動で台帳を消して再投入してはいけない。停止証拠を伴う運用回復は未実装。

親終了後もworkerは継続し、別プロセスから照会できる。role implement/spec-writeは砂場なし（`thread/start`のsandbox=`danger-full-access`、turnのsandboxPolicy=`{'type':'dangerFullAccess'}`）、review/spec-review/impl-review/deciderはread-only。approvalPolicy=neverは全roleで維持する。砂場なしのpolicyは項目を持たないため、書く役にwritableRoots・excludeSlashTmp・excludeTmpdirEnvVar・networkAccessは渡らない。read-onlyには書き込み許可を追加せず、networkAccessはroleごとに分ける（review/spec-review/impl-reviewはtrue、deciderはfalse）。

書く役を砂場なしにしたのは、Claudeのサブエージェントに対応する隔離が無く、workspace-writeではlinked worktreeのcommitが成立しないため。第1段（workspace-write＋networkAccess=true＋writableRootsにGit共通ディレクトリを追加）では`git switch -c`が`HEAD.lock`、`git commit`が`index.lock`の`Operation not permitted`で拒否され、どちらもexit 128だった。境界を1か所ずつ測るとGit共通ディレクトリ直下・`refs/`・`worktrees/`直下には書けるのに、cwdの`.git`が指す`worktrees/<このworktree>/`だけが読み取り専用で、`WorkspaceWriteSandboxPolicy`にこれを解く項目は無い（`writableRoots`/`networkAccess`/`excludeSlashTmp`/`excludeTmpdirEnvVar`の4つだけ、`turn/start`に`permissionProfile`も無い）。環境変数の引き継ぎは同じjobで確認済みなので、原因は砂場の拒否である。

実測はimplement roleで行った。spec-writeはpolicyがimplementと同一なので同じ結果が当てはまる（未実測ではなく、同一policyの帰結）。実測で揃わなかった項目は無い: ループバックへのHTTP（http_code=200）・`git switch -c`・`git commit`・`git push -u`・`gh pr create --draft`→`gh pr close`・`gh issue comment`・外部repoのテストスクリプト完走（PASS=261 FAIL=0、exit 0）がすべてworkerの中でexit 0。`gh`の認証はキーチェーン経由で届き、`GH_TOKEN`は親に無くても`gh`は動く。砂場が無いので`/tmp`と呼び出し元`TMPDIR`への書き込みも通る（第1段では拒否されていた）。

App Serverと子ツールのTMPDIR・TMPPREFIXは、roleによらず起動元の値をそのまま引き継ぐ。workerはjob専用の一時ディレクトリを作らず、TMPDIRを差し替えず、親に値が無ければ子にも現れない（既定値も補わない。mktemp・Pythonのtempfile・zshはそれぞれ自分で`/tmp`に倒れる）。Claudeのサブエージェントと同じ形にした結果、次の2つは失われている: 同時に走るjobの一時ファイルが同じ親の一時領域に混ざりうること、jobが残した一時ファイルの出どころをworkerが記録しないこと（`job-tmp.json`は無い）。この追跡が必要になったらCodex側だけに戻さず、Claude側にも同じ仕組みを入れて揃える。

認証元profileはtokenをコピーせずパスとhashだけ登録する。各jobは0700の専用runtime CODEX_HOMEを作り、auth.jsonだけ認証元へのsymlinkとし最小configを生成する。元profileのMCP/app/plugin設定・履歴は継承しない。project/ancestorの.codex/config.tomlは初版拒否（通常ユーザーglobal設定はruntimeで置換）。子環境変数は親の環境をそのまま引き継ぎ、落とすのは11個だけ: `CODEX_HOME`（workerが自分で決める値）、`OPENAI_API_KEY`・`CODEX_API_KEY`・`OPENAI_BASE_URL`・`CODEX_AUTH_JSON`・`OPENAI_ORGANIZATION`・`OPENAI_PROJECT`（認証と接続先をすり替える値）、`GIT_DIR`・`GIT_WORK_TREE`・`GIT_COMMON_DIR`・`GIT_INDEX_FILE`（子のgitをcwd以外のcheckoutへ向ける値）。`GH_TOKEN`は渡る。Codexの`shell_environment_policy`は実測では絞らず、名前にKEY/SECRET/TOKENを含む変数も子に届いたので、runtime `config.toml`に引き継ぎ設定は書かない。worker自身のgit呼び出し（依頼の検査・runtimeの場所の算出）は親の環境を使わず、固定allowlistの最小環境で行う。runtime認証symlinkは終了時に削除し、engine refreshが置き換えたcredential fileも保持しない。

profileのID token claim/email hashとaccount/readを照合する。これは署名検証ではなく、account/readはworkspace IDを保証しないため完全な複数workspace識別を主張しない。auth.json全体hashまたはruntime symlinkが変わった場合、未開始は拒否、実行中は中断を要求する。通常のtoken refreshでも止まる保守的制約がある。認証切替・設定書換えは行わない。

各台帳はprivate。別state-dirとの競合も `$HOME/.local/state/claude-harness-codex/ownership.sqlite` で防ぐ。同一OSユーザー・同一HOMEを一つの実行領域とする。異なるHOMEで起動する管理者操作や別ホストの分散排他は対象外。共有所有台帳と参照先job台帳を削除してはいけない。参照先の台帳ファイルが無い、または読めないときの扱いは2つに分かれる。作業ディレクトリ側は従来どおり`global_owner_unknown`で投入を拒否する。アカウント側のスロットは占有中として飛ばすだけで（他に空きがあれば投入は通る）、空きとして再利用せず、`reap`でも解放しない。

同一アカウントの同時実行はスロット数で決まる。`register --max-concurrent N`（既定3、1以上の整数）が同時本数の上限、`--quota-margin-pct P`（既定5、0以上100以下）が1本あたりの見込み消費率。どちらも省略すると既定値で上書きされ、前の値は残らないので、変えた値は再登録のたびに明示する。registerは未受領jobがあると`account_has_unacknowledged_jobs`で拒否されるため、上限の変更は全件ackの後にしか打てない（走行中には下げられない）。別state-dirが別の上限を登録している場合、上限の登録値どうしの整合は取らないが、投入する側は自分の上限を、番号に関わらず実際に占有されている全スロット数と突き合わせる（他方がより大きい上限で埋めたぶんも数に入る）。

拒否理由。同一台帳内で同じcwdに未受領jobがあれば`cwd_locked`、別台帳のjobがそのcwdを持っていれば`global_cwd_locked`、アカウントのスロットが上限まで埋まっていれば`account_slots_exhausted`。残枠は`usedPercent>=100`なら従来どおり`quota_exhausted`、100%未満でも`usedPercent + P × 占有スロット数 > 100`なら`quota_headroom_insufficient`で開始しない（占有スロット数は自分を含む）。`thread/start`/`turn/start`にサーバーがid付きのエラー応答を返した場合はターン未受理の証拠なのでfailed＋`server_rejected_start_<コード>`。ターン受理後のエラー応答と、応答が無いままの切断・タイムアウトは従来どおりunknown。**同時実行を理由とする拒否を判別する規則は無い**。Codex app-serverが同時実行を拒むときに返すコードとメッセージが未確認のため、全件をエラーコードごと`server_rejected_start_<コード>`として残す。判別できるようになったら、対象コードとメッセージの一致条件をここに書き、`server_rejected_concurrent_turn`に置き換える。再試行も別アカウントへの振り替えも行わない。

`reap [--older-than <秒>] [--account <名前>]`が外すのはアカウント側のスロットだけで、`owners`の作業ディレクトリ行にも台帳のackedにも触らない。解放するのはTERMINALかつ受領済み（`acked`）と、TERMINALかつ未受領で最終更新から`--older-than`（既定86400秒）を超えたもの（`stale_unacked`）の2つだけで、解放しなかったスロットも理由（`unknown`／`ledger_missing`／`not_stale`／`active`）付きで出力に載る。同じ作業ディレクトリへ再投入するには従来どおり結果を回収してackする。スロットの判定は他のstate-dirの台帳を読み取り専用で開くため、status/result照会の側にある「30秒更新が無いqueued/runningをunknownへ昇格させる」規則を適用できない。workerプロセスが死んだrunningのスロットは`active`のまま残り`reap`でも外れないので、その台帳を持つ側でstatus/resultを引くとunknownへ昇格するが、unknownはackできないので、スロットも作業ディレクトリも解放されない（停止証拠を伴う運用回復は未実装）。

古い版の`codex-worker.py`を同じHOMEで併用しない。新しい版は`account_slots`でアカウント側を排他し、古い版は`owners`の`account:`行しか見ないため、同時に走らせるとアカウント側の排他が壊れる。

fresh codex quota観測の適用窓が不明・不正・上限到達なら開始しない。手動にバーン時間窓を適用せず、チケットは消費しない。初版はmanualのみ。burn、send/steer、unknown自動復旧は明示unsupported/未実装。

## 前景実行（`run`）

台帳を作らず読まない1回きりの実行。依頼ファイルを渡して呼び、結果を標準出力で受け取る。

```sh
python3 plugins/dev-workflow/scripts/codex-worker.py run --request /absolute/private/request.json
```

依頼のキーは台帳経路の request.json と同じで、`codex_home`（0700で用意する認証元profileの絶対パス）を必須に加える。account名からCODEX_HOMEへの解決は呼び出し側（`codex-develop.py request`）が済ませる。`run` は `--state-dir` を受け取らず、与えれば引数エラーで終わる。cwdの検査（所有者・repo root・feature branch・linked worktree）・静的検証・`model/list`による開始前検証・runtime CODEX_HOMEの用意と後片付けは台帳経路と同じ。

結果は標準出力の1行JSON（`text` / `status` / `usage` / `execution` / `thread_id` / `turn_id` / `error_kind`）で、成功はexit 0、それ以外はexit 2。job IDもackも無いので、後から照会・再取得・受領はできない。同じ工程をやり直すときは依頼ファイルの作成からもう一度行う。完了と品質承認が別であること、`error_kind`非空のcompletedを成功と扱わないことは台帳経路と同じ。

`run` は親終了後も走り続けない。起動時に控えた祖先プロセスの連鎖を1秒間隔で辿り直し、食い違ったら停止要求を立てる（直接の親のPIDだけを見ない）。SIGTERM / SIGINT もハンドラで同じ停止要求を立てるだけで、RPCはハンドラから送らない。停止要求は毎RPCの入口で確認し、ターン待ちのループは `turn/interrupt` を1回送る。**猶予の起点はinterruptを送った時刻**で、前景経路の締切は10秒（台帳経路の猶予20秒・応答後起点とは別）。残り0なら応答を待たずに後始末へ進み、app-serverの子プロセスは残さない。

台帳に触れないため、同時実行のスロット管理（`account_slots` / `account_slots_exhausted`）も作業ディレクトリの排他（`cwd_locked` / `global_cwd_locked`）も行わない。同じアカウント・同じ作業ディレクトリへ2本同時に投げないのは呼び出し側の責任である。ターン開始前の利用枠確認だけは残り、同時に走っている件数は1固定、余裕率は依頼の `quota_margin_pct`（既定5）を使う（`occupied_slots` / `reserve_global` は呼ばない）。アカウントの照合は自己整合で行い、`account/read` が返したemailを渡されたCODEX_HOMEの `auth.json` と突き合わせる。観測した実行中アカウントは `effective.account`、依頼のaccount名は `requested.account` に入り、要求名を `effective` へ写さない。

テスト:
```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p 'test_*.py' -v
```

品質判定に渡すtextは一意な`phase=final_answer`のみ。途中のcommentaryは含めない。Codex schema上phaseはnullableなので、欠測を最終回答と推測しない。phase欠測・複数final・空finalはfailed/error_kind＋空text。これは実行terminalを観測した後の結果不適合であり、ack後にfresh担当を起動できる。`error_kind`非空のcompletedも品質承認には使わない（#707側でも拒否する）。
