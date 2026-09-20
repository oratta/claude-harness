# Codex手動worker（初版）

```sh
python3 plugins/dev-workflow/scripts/codex-worker.py --state-dir "$HOME/.local/state/claude-harness-codex/jobs" register --account personal --codex-home "$HOME/.codex" --max-concurrent 3 --quota-margin-pct 5
python3 plugins/dev-workflow/scripts/codex-worker.py --state-dir "$HOME/.local/state/claude-harness-codex/jobs" submit --request request.json
python3 plugins/dev-workflow/scripts/codex-worker.py --state-dir "$HOME/.local/state/claude-harness-codex/jobs" result --job example-1
python3 plugins/dev-workflow/scripts/codex-worker.py --state-dir "$HOME/.local/state/claude-harness-codex/jobs" reap --account personal
```

request.json:
```json
{"request_id":"example-1","origin":"manual","account":"personal","cwd":"/absolute/linked-worktree","model":"explicit-model-id","role":"implement","prompt":"The complete bounded task and acceptance criteria"}
```

request_id=job_id。同一ID同一入力は再実行しない。status/result/cancel/ackには`--job ID`。stdout JSON、拒否exit2。`result.text`は最終出力、usage欠落はnull。完了と品質承認は別。結果回収後にackし、次工程は新IDでsubmitする。unknownはackも新規投入も拒否し、手動で台帳を消して再投入してはいけない。停止証拠を伴う運用回復は未実装。

親終了後もworkerは継続し、別プロセスから照会できる。role implement/spec-writeはworkspace-write、review/spec-review/impl-review/deciderはread-only。全roleでnetworkAccess=false、approvalPolicy=never、追加writableRootsはcwdのみ、/tmp追加許可なし。git metadataの変更（commitなど）はCodex sandboxで拒否されうるため、#707の親処理へ渡す。danger-full-accessへ縮退しない。

認証元profileはtokenをコピーせずパスとhashだけ登録する。各jobは0700の専用runtime CODEX_HOMEを作り、auth.jsonだけ認証元へのsymlinkとし最小configを生成する。元profileのMCP/app/plugin設定・履歴は継承しない。project/ancestorの.codex/config.tomlは初版拒否（通常ユーザーglobal設定はruntimeで置換）。子環境変数はPATH/HOME等のallowlistだけで、GH_TOKEN・OPENAI_API_KEY・Git routing等を渡さない。runtime認証symlinkは終了時に削除し、engine refreshが置き換えたcredential fileも保持しない。

profileのID token claim/email hashとaccount/readを照合する。これは署名検証ではなく、account/readはworkspace IDを保証しないため完全な複数workspace識別を主張しない。auth.json全体hashまたはruntime symlinkが変わった場合、未開始は拒否、実行中は中断を要求する。通常のtoken refreshでも止まる保守的制約がある。認証切替・設定書換えは行わない。

各台帳はprivate。別state-dirとの競合も `$HOME/.local/state/claude-harness-codex/ownership.sqlite` で防ぐ。同一OSユーザー・同一HOMEを一つの実行領域とする。異なるHOMEで起動する管理者操作や別ホストの分散排他は対象外。共有所有台帳と参照先job台帳を削除してはいけない。参照先を失ったときの扱いは2つに分かれる。作業ディレクトリ側は従来どおり`global_owner_unknown`で投入を拒否する。アカウント側のスロットは占有中として飛ばすだけで（他に空きがあれば投入は通る）、空きとして再利用せず、`reap`でも解放しない。

同一アカウントの同時実行はスロット数で決まる。`register --max-concurrent N`（既定3、1以上の整数）が同時本数の上限、`--quota-margin-pct P`（既定5、0以上100以下）が1本あたりの見込み消費率。どちらも省略すると既定値で上書きされ、前の値は残らないので、変えた値は再登録のたびに明示する。registerは未受領jobがあると`account_has_unacknowledged_jobs`で拒否されるため、上限の変更は全件ackの後にしか打てない（走行中には下げられない）。別state-dirが別の上限を登録していても整合は取らない。

拒否理由。同一台帳内で同じcwdに未受領jobがあれば`cwd_locked`、別台帳のjobがそのcwdを持っていれば`global_cwd_locked`、アカウントのスロットが上限まで埋まっていれば`account_slots_exhausted`。残枠は`usedPercent>=100`なら従来どおり`quota_exhausted`、100%未満でも`usedPercent + P × 占有スロット数 > 100`なら`quota_headroom_insufficient`で開始しない（占有スロット数は自分を含む）。`thread/start`/`turn/start`にサーバーがid付きのエラー応答を返した場合はターン未受理の証拠なのでfailed＋`server_rejected_start_<コード>`。ターン受理後のエラー応答と、応答が無いままの切断・タイムアウトは従来どおりunknown。**同時実行を理由とする拒否を判別する規則は無い**。Codex app-serverが同時実行を拒むときに返すコードとメッセージが未確認のため、全件をエラーコードごと`server_rejected_start_<コード>`として残す。判別できるようになったら、対象コードとメッセージの一致条件をここに書き、`server_rejected_concurrent_turn`に置き換える。再試行も別アカウントへの振り替えも行わない。

`reap [--older-than <秒>] [--account <名前>]`が外すのはアカウント側のスロットだけで、`owners`の作業ディレクトリ行にも台帳のackedにも触らない。解放するのはTERMINALかつ受領済み（`acked`）と、TERMINALかつ未受領で最終更新から`--older-than`（既定86400秒）を超えたもの（`stale_unacked`）の2つだけで、解放しなかったスロットも理由（`unknown`／`ledger_missing`／`not_stale`／`active`）付きで出力に載る。同じ作業ディレクトリへ再投入するには従来どおり結果を回収してackする。スロットの判定は他のstate-dirの台帳を読み取り専用で開くため、status/result照会の側にある「30秒更新が無いqueued/runningをunknownへ昇格させる」規則を適用できない。workerプロセスが死んだrunningのスロットは`active`のまま残り`reap`でも外れないので、その台帳を持つ側でstatus/resultを引いてunknownへ昇格させ、ackする。

古い版の`codex-worker.py`を同じHOMEで併用しない。新しい版は`account_slots`でアカウント側を排他し、古い版は`owners`の`account:`行しか見ないため、同時に走らせるとアカウント側の排他が壊れる。

fresh codex quota観測の適用窓が不明・不正・上限到達なら開始しない。手動にバーン時間窓を適用せず、チケットは消費しない。初版はmanualのみ。burn、send/steer、unknown自動復旧は明示unsupported/未実装。

テスト:
```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py -v
```

品質判定に渡すtextは一意な`phase=final_answer`のみ。途中のcommentaryは含めない。Codex schema上phaseはnullableなので、欠測を最終回答と推測しない。phase欠測・複数final・空finalはfailed/error_kind＋空text。これは実行terminalを観測した後の結果不適合であり、ack後にfresh担当を起動できる。`error_kind`非空のcompletedも品質承認には使わない（#707側でも拒否する）。
