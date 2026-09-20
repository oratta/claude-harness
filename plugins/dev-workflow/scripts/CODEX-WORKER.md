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

親終了後もworkerは継続し、別プロセスから照会できる。role implement/spec-writeはworkspace-write、review/spec-review/impl-review/deciderはread-only。全roleでnetworkAccess=false、approvalPolicy=neverを維持する。workspace-writeのwritableRootsはcwdとジョブ専用一時領域だけで、excludeSlashTmp/excludeTmpdirEnvVar=true。read-onlyには書き込み許可を追加しない。git metadataの変更（commitなど）はCodex sandboxで拒否されうるため、#707の親処理へ渡す。danger-full-accessへ縮退しない。

workspace-writeは起動元の非空TMPDIR（未設定・空なら`/tmp`）を親として、Git管理領域・cwdの外に所有者一致・0700の一時ディレクトリを新規作成する。TEMP/TMPは参照せず、不適格な親ならフォールバックせず開始を拒否する。App Serverと子ツールのTMPDIRはこの正規化済み絶対パスに置き換え、元TMPDIRや`/tmp`全体は許可しない。zshのhere-document用一時ファイルはTMPDIRではなく`TMPPREFIX`（既定`/tmp/zsh`）に作られるため、`TMPPREFIX`も専用領域内へ向ける。read-onlyにはどちらも渡さない。同じrun内を含め、別jobへの割り当て・再利用はしない。パスと作成時の識別情報はruntimeの`job-tmp.json`に記録する。

成功・失敗・確認済み取消・turn開始前失敗ではackを待たず専用領域を削除する。親やsymlink参照先は削除せず、領域の置き換えや削除失敗は`error_kind=job_tmp_cleanup_failed`（既存エラーがあれば後置）で残す。terminalの記録だけではcleanup完了を保証しないので、workerの終了後に領域不在とerror_kindを確認する。停止未確認のunknown・worker強制終了では領域を保持し、停止済みと推測して削除・再利用しない。運用回復は未実装であり、最終的な自動削除は保証しない。

認証元profileはtokenをコピーせずパスとhashだけ登録する。各jobは0700の専用runtime CODEX_HOMEを作り、auth.jsonだけ認証元へのsymlinkとし最小configを生成する。元profileのMCP/app/plugin設定・履歴は継承しない。project/ancestorの.codex/config.tomlは初版拒否（通常ユーザーglobal設定はruntimeで置換）。子環境変数はPATH/HOME等のallowlistだけで、GH_TOKEN・OPENAI_API_KEY・Git routing等を渡さない。runtime認証symlinkは終了時に削除し、engine refreshが置き換えたcredential fileも保持しない。

profileのID token claim/email hashとaccount/readを照合する。これは署名検証ではなく、account/readはworkspace IDを保証しないため完全な複数workspace識別を主張しない。auth.json全体hashまたはruntime symlinkが変わった場合、未開始は拒否、実行中は中断を要求する。通常のtoken refreshでも止まる保守的制約がある。認証切替・設定書換えは行わない。

各台帳はprivate。別state-dirとの競合も `$HOME/.local/state/claude-harness-codex/ownership.sqlite` で防ぐ。同一OSユーザー・同一HOMEを一つの実行領域とする。異なるHOMEで起動する管理者操作や別ホストの分散排他は対象外。共有所有台帳と参照先job台帳を削除してはいけない。参照先喪失はunknownとして拒否する。

fresh codex quota観測の適用窓が不明・不正・上限到達なら開始しない。手動にバーン時間窓を適用せず、チケットは消費しない。初版はmanualのみ。burn、send/steer、unknown自動復旧は明示unsupported/未実装。

テスト:
```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/dev-workflow/tests -p test_codex_worker.py -v
```

品質判定に渡すtextは一意な`phase=final_answer`のみ。途中のcommentaryは含めない。Codex schema上phaseはnullableなので、欠測を最終回答と推測しない。phase欠測・複数final・空finalはfailed/error_kind＋空text。これは実行terminalを観測した後の結果不適合であり、ack後にfresh担当を起動できる。`error_kind`非空のcompletedも品質承認には使わない（#707側でも拒否する）。
