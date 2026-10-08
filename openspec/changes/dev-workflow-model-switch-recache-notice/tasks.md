## 1. テストを先に書く

- [ ] 1.1 新規 bats を作り、spec の Scenario を 1 件ずつテストにする（公式ドキュメントの入力例に `systemMessage` だけを返し `decision` も `hookSpecificOutput` も無い、`source` が `picker`・`sdk` でも同じ形、文言が確認を求めない、トークン数と推定費用の両方、片方だけ、`$0.01 未満`、`pricing` の 4 通り、`prompt_cache_warm` のキー無しと非真偽値、モデル名の省略と制御文字、`prompt_cache_warm: false` で無出力、`context_tokens: 0` で無出力、数字が無いと無出力、別イベントで無出力、壊れた入力 5 通りで無出力 exit 0、`python3` が無い PATH で無出力 exit 0、`transcript_path` の有無で出力が同じ、スクリプトに外部通信とファイル操作が無い、実行権限）。出力の検査は `python3` で JSON を読んでキーの集合を比べる。標準出力と標準エラーは分けて受ける（`run --separate-stderr` か、ファイルへのリダイレクト）。`python3` が無い PATH は、一時ディレクトリに `bash`・`cat` など必要なコマンドだけの symlink を置いて作る。入力は here-doc か `printf` で stdin に渡し、引数や環境変数に載せない。この時点で新規テストが落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/model-switch-recache-notice.bats（新規）、plugins/dev-workflow/tests/subagent-start-context.bats:1-40（hook スクリプトの bats の setup の手本）
- [ ] 1.2 同じ bats に hooks.json の検査を書く（`PreModelSwitch` が 1 エントリ・`command` の hook 1 件・`${CLAUDE_PLUGIN_ROOT}` と `scripts/model-switch-recache-notice.sh` を含む・`matcher` と `timeout` のキーが無い）。触る範囲: plugins/dev-workflow/tests/model-switch-recache-notice.bats（新規）、plugins/dev-workflow/tests/context-tripwire.bats:547-590（hooks.json を `python3` で検査する手本）
- [ ] 1.3 hooks.json のイベント名の集合を完全一致で検査している既存テストの期待値に `PreModelSwitch` を足す。触る範囲: plugins/dev-workflow/tests/subagent-stop-guard.bats:465-469（「hooks.json: the pre-existing entries are unchanged」の `assert set(d) == {...}`）

## 2. スクリプトと hook

- [ ] 2.1 `scripts/model-switch-recache-notice.sh` を新規作成する。bash から `python3` を呼び、stdin の JSON をそのまま渡す（スクリプト本体を here-doc で渡すと stdin が塞がるので、`context-tripwire.sh` の fd 3 の形か `python3 -c` で渡す）。`python3` の中で、design.md の Decisions 4（文言と表記）と 5（出さない条件）のとおりに判定し、出すときだけ `json.dumps({"systemMessage": msg}, ensure_ascii=False)` を 1 行で書く。例外はすべて握って無出力にし、`python3` の標準エラーは捨て、シェル側は `|| true` と `exit 0` で終える。ネットワークアクセス・ファイルの読み書きをしない。実行権限を付ける（`chmod +x`）。触る範囲: plugins/dev-workflow/scripts/model-switch-recache-notice.sh（新規）、plugins/dev-workflow/scripts/team-mode-warning.sh:1-27（`systemMessage` を返す hook の手本）、plugins/dev-workflow/scripts/context-tripwire.sh:44-53（stdin を塞がずに payload を渡す前例）
- [ ] 2.2 hooks.json の末尾に `PreModelSwitch` のエントリを足す（`matcher` なし・`timeout` なし、command は `"${CLAUDE_PLUGIN_ROOT}/scripts/model-switch-recache-notice.sh"`）。既存のエントリは 1 文字も変えない。自己統治物件なので PR 本文で主の承認を求める。触る範囲: plugins/dev-workflow/hooks/hooks.json:72-93（SubagentStart・SubagentStop の後ろ）
- [ ] 2.3 1.1〜1.3 のテストがすべて通ることを確かめる（`bats plugins/dev-workflow/tests/model-switch-recache-notice.bats plugins/dev-workflow/tests/subagent-stop-guard.bats`）

## 3. 変更の記録

- [ ] 3.1 変更の記録を書く。何を足したか、出す条件と出さない条件、切替を止めないこと、PreModelSwitch は Claude Code 2.1.251 以降であること、未確認の 2 点（`systemMessage` が確認画面の前後どちらに出るか、2.1.251 より前の版が知らないイベント名をどう扱うか）と、問題が出たときは hooks.json の `PreModelSwitch` のエントリを外せば戻ること、仕様とテストの場所を入れる。触る範囲: plugins/dev-workflow/changes/714.md（新規）、plugins/dev-workflow/changes/827.md:1-8（書式の手本）

## 4. 検証

- [ ] 4.1 `claude plugin validate plugins/dev-workflow`（lint-plugin-validate）が通ることを確かめる。`tests/injection-budget.bats` が通ることを確かめる（`description` を変えていないので測定値は動かない見込み。落ちたら予算ファイルではなく原因を直す）。触る範囲: tests/injection-budget.bats（読むだけ）
- [ ] 4.2 `scripts/test.sh` が exit 0
- [ ] 4.3 公式ドキュメントの入力例をスクリプトに渡した標準出力を控え、(3a) の return に貼る。実際の `/model` 切替での見え方（`systemMessage` が出るか、本体の確認画面との前後）は W が画面で確認せず、return の `画面確認:` 行で「要」と本体に伝える
