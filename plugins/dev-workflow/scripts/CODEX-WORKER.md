# Codex手動worker（初版）

```sh
python3 plugins/dev-workflow/scripts/codex-worker.py --state-dir "$HOME/.local/state/claude-harness-codex/jobs" register --account personal --codex-home "$HOME/.codex"
python3 plugins/dev-workflow/scripts/codex-worker.py --state-dir "$HOME/.local/state/claude-harness-codex/jobs" submit --request request.json
python3 plugins/dev-workflow/scripts/codex-worker.py --state-dir "$HOME/.local/state/claude-harness-codex/jobs" result --job example-1
```

request.json:
```json
{"request_id":"example-1","origin":"manual","account":"personal","cwd":"/absolute/linked-worktree","model":"explicit-model-id","role":"implement","prompt":"The complete bounded task and acceptance criteria"}
```

request_id=job_id。同一ID同一入力は再実行しない。status/result/cancel/ackには`--job ID`。stdout JSON、拒否exit2。`result.text`は最終出力、usage欠落はnull。完了と品質承認は別。結果回収後にackし、次工程は新IDでsubmitする。unknownはackも新規投入も拒否し、手動で台帳を消して再投入してはいけない。停止証拠を伴う運用回復は未実装。

親終了後もworkerは継続し、別プロセスから照会できる。role implement/spec-writeはworkspace-write、review/spec-review/impl-review/deciderはread-only。全roleでnetworkAccess=false、approvalPolicy=never、追加writableRootsはcwdのみ、/tmp追加許可なし。git metadataの変更（commitなど）はCodex sandboxで拒否されうるため、#707の親処理へ渡す。danger-full-accessへ縮退しない。

認証元profileはtokenをコピーせずパスとhashだけ登録する。各jobは0700の専用runtime CODEX_HOMEを作り、auth.jsonだけ認証元へのsymlinkとし最小configを生成する。元profileのMCP/app/plugin設定・履歴は継承しない。project/ancestorの.codex/config.tomlは初版拒否（通常ユーザーglobal設定はruntimeで置換）。子環境変数はPATH/HOME等のallowlistだけで、GH_TOKEN・OPENAI_API_KEY・Git routing等を渡さない。runtime認証symlinkは終了時に削除し、engine refreshが置き換えたcredential fileも保持しない。

profileのID token claim/email hashとaccount/readを照合する。これは署名検証ではなく、account/readはworkspace IDを保証しないため完全な複数workspace識別を主張しない。auth.json全体hashまたはruntime symlinkが変わった場合、未開始は拒否、実行中は中断を要求する。通常のtoken refreshでも止まる保守的制約がある。認証切替・設定書換えは行わない。

各台帳はprivate。別state-dirとの競合も `$HOME/.local/state/claude-harness-codex/ownership.sqlite` で防ぐ。同一OSユーザー・同一HOMEを一つの実行領域とする。異なるHOMEで起動する管理者操作や別ホストの分散排他は対象外。共有所有台帳と参照先job台帳を削除してはいけない。参照先喪失はunknownとして拒否する。

fresh codex quota観測の適用窓が不明・不正・上限到達なら開始しない。手動にバーン時間窓を適用せず、チケットは消費しない。初版はmanualのみ。burn、send/steer、unknown自動復旧は明示unsupported/未実装。

テスト:
```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py -v
```
