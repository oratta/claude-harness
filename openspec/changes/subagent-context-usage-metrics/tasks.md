## 1. テスト fixture と失敗するテスト（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/subagent-context-audit.bats` を新規作成し、`$BATS_TEST_TMPDIR` に fixture の projects ディレクトリを組み立てるヘルパを書く（実機の `~/.claude` を読まず `--projects` で差し替える。テスト名は ASCII のみ）
- [ ] 1.2 fixture: 名前付きサブエージェント（`<proj>/<uuid>/subagents/agent-W-1-xxxx.jsonl`）を 3 件、うち 1 件は最終コンテキストが 150000 超になる usage を入れる
- [ ] 1.3 fixture: worktree 隔離（`<proj>--claude-worktrees-agent-abc123/<uuid>.jsonl`）を 1 件
- [ ] 1.4 fixture: 期間外（mtime を 30 日前に `touch -t` で戻したファイル）を 1 件
- [ ] 1.5 失敗するテストを書く: 出力 JSON が `count` / `first_median` / `first_max` / `last_median` / `last_max` / `over_cap_pct` / `cap` / `days` / `sources` / `generated_at` を持ち exit 0
- [ ] 1.6 失敗するテストを書く: worktree 隔離の 1 件が `sources.worktree` に数えられ `count` に含まれる
- [ ] 1.7 失敗するテストを書く: 期間外のファイルが `count` に含まれない
- [ ] 1.8 失敗するテストを書く: `over_cap_pct` が上限超の件数から正しく出る（`--cap` で閾値を差し替えて検証）
- [ ] 1.9 失敗するテストを書く: 空ディレクトリ / 存在しない `--projects` で `count` 0 かつ exit 0（fail-open）
- [ ] 1.10 失敗するテストを書く: 壊れた JSON 行を含むトランスクリプトがあっても他の件が集計され exit 0

## 2. 集計スクリプトの実装（Green）

- [ ] 2.1 `plugins/dev-workflow/scripts/subagent-context-audit.sh` を新規作成し、`subagent-context.sh` に倣ったヘッダコメント（用途・出力・exit code・正本への参照）を書く
- [ ] 2.2 引数パース: `--days N`（既定 14）/ `--cap N`（既定 `DEV_WORKFLOW_CONTEXT_CAP` → 150000）/ `--projects DIR`（既定 `CLAUDE_PROJECTS_DIR` → `~/.claude/projects`）/ `--cache FILE` / `--refresh` / `-h|--help`。引数エラーのみ exit 1
- [ ] 2.3 キャッシュ: `${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}` の mtime が `SUBAGENT_CONTEXT_AUDIT_TTL`（既定 21600 秒）以内ならその内容を出して終了。`--refresh` で無視
- [ ] 2.4 走査: 名前付き（`*/*/subagents/agent-*.jsonl`）と worktree 隔離（`*--claude-worktrees-agent-*/*.jsonl`）の 2 系統を glob し、mtime で期間内に絞る
- [ ] 2.5 初回コンテキスト: 先頭から読み、最初の `usage` 付き assistant レコードで打ち切る（全文を読まない）
- [ ] 2.6 最終コンテキスト: 末尾から 256 KiB の窓を読んで後ろ向きに探索。見つからなければ 4 MiB まで窓を倍加。それでも無ければその件を最終側の集計から除く
- [ ] 2.7 集計: `count` / 初回・最終の中央値（偶数件は中央 2 値の平均を四捨五入）と最大 / `over_cap_pct` / `sources` の内訳を組み立て、1 行 JSON で stdout に出し、同じ内容をキャッシュに atomic に書く
- [ ] 2.8 fail-open: `python3` 不在・projects 不在・0 件・読み取り例外はすべて `count` 0 の結果＋`note` を出して exit 0
- [ ] 2.9 実行ビットを立てる（`chmod +x`）
- [ ] 2.10 1.5〜1.10 のテストが全部通ることを確認する（exit code と出力を貼る）

## 3. session-tripwires.sh への注入（Red → Green）

- [ ] 3.1 `plugins/dev-workflow/tests/` の既存スイート（`prompt-tripwires-refresh.bats` 等）の書き方に合わせ、注入テストを追加する: 集計が `count` 1 以上を返すとき `additionalContext` に実測行が 2 行以内で載る
- [ ] 3.2 失敗するテストを追加: 集計スクリプトが存在しない / `count` 0 のとき実測行は載らず、残量モードブロックと昇格トリップワイヤーの注入は従来どおりで exit 0
- [ ] 3.3 `session-tripwires.sh` に best-effort 呼び出しを足し、結果を python 側に環境変数で渡して `lines` に 2 行以内で追加する（既存の「サブエージェントのコンテキスト上限」の行の直後）
- [ ] 3.4 既存の `FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` 導出に一切触れていないことを diff で確認する
- [ ] 3.5 3.1〜3.2 のテストが通ることを確認する

## 4. 実機での確認と後始末

- [ ] 4.1 実機の `~/.claude/projects` に対して `subagent-context-audit.sh` を `--refresh` で 1 回実行し、出力 JSON と所要時間を記録する（#257 の実測値 W 初回中央値 54,300〜58,000 / 最終中央値 W 168,017・G 153,524 と桁が合うか）
- [ ] 4.2 2 回目の実行がキャッシュヒットで即返ることを確認する
- [ ] 4.3 `plugins/dev-workflow/.claude-plugin/plugin.json` の version を上げる
- [ ] 4.4 `scripts/test.sh` を全件実行し、exit code と結果サマリを記録する（push 前の規約）
- [ ] 4.5 `openspec/changes/subagent-context-usage-metrics` を archive し、`openspec/specs/dev-workflow-execution-strategy/spec.md` に要件が反映されたことを確認する（delta 見出しが正本に残っていないこと。`tests/openspec-specs-format.bats`）
