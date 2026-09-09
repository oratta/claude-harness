## 1. テスト fixture と失敗するテスト（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/subagent-context-audit.bats` を新規作成し、`$BATS_TEST_TMPDIR` に fixture の projects ディレクトリを組み立てるヘルパを書く（実機の `~/.claude` を読まず `--projects` で差し替える。テスト名は ASCII のみ）
- [ ] 1.2 fixture: 隔離なしのサブエージェント（`<proj>/<uuid>/subagents/agent-aW-1-xxxx.jsonl` ＋ `spawnedWithWorktree` を持たない meta.json）を 3 件、うち 1 件は最終コンテキストが 150000 超になる usage を入れる
- [ ] 1.3 fixture: 隔離ありのサブエージェント（同じ `subagents/` に `agent-abc123def456.jsonl` ＋ `spawnedWithWorktree: true` の meta.json）を 1 件。**同じディレクトリに置く**（置き場所は隔離で変わらない）
- [ ] 1.4 fixture: 期間外（mtime を 30 日前に `touch -t` で戻したファイル）を 1 件
- [ ] 1.4b fixture: サブエージェントでないもの 2 件 —（a）`<proj>--claude-worktrees-agent-abc123/<uuid>.jsonl`（worktree 内から起動された入れ子の `claude` セッション）、（b）`<proj>/<uuid>.jsonl`（メインセッション）。どちらも集計に入ってはいけない
- [ ] 1.4c fixture: meta.json が無い 1 件と、meta.json が壊れている 1 件
- [ ] 1.5 失敗するテストを書く: 出力 JSON が `count` / `first_median` / `first_max` / `last_median` / `last_max` / `over_cap_pct` / `cap` / `days` / `sources` / `generated_at` を持ち exit 0
- [ ] 1.6 失敗するテストを書く: 隔離ありの 1 件が `count` に含まれ、`sources.isolated` と `sources.non_isolated` がそれぞれ `count` / `first_median` / `last_median` / `over_cap_pct` を持つ
- [ ] 1.6b 失敗するテストを書く: 1.4b の 2 件（入れ子の `claude` セッション・メインセッション）が `count` にも `sources` のどちらにも含まれない
- [ ] 1.6c 失敗するテストを書く: meta.json が無い / 壊れている件も `count` に残り、判定できなければ `sources.non_isolated` に数えられる
- [ ] 1.7 失敗するテストを書く: 期間外のファイルが `count` に含まれない
- [ ] 1.8 失敗するテストを書く: `over_cap_pct` が上限超の件数から正しく出る（`--cap` で閾値を差し替えて検証）
- [ ] 1.9 失敗するテストを書く: 空ディレクトリ / 存在しない `--projects` で `count` 0 かつ exit 0（fail-open）
- [ ] 1.10 失敗するテストを書く: 壊れた JSON 行を含むトランスクリプトがあっても他の件が集計され exit 0

## 2. 集計スクリプトの実装（Green）

- [ ] 2.1 `plugins/dev-workflow/scripts/subagent-context-audit.sh` を新規作成し、`subagent-context.sh` に倣ったヘッダコメント（用途・出力・exit code・正本への参照）を書く
- [ ] 2.2 引数パース: `--days N`（既定 14）/ `--cap N`（既定 `DEV_WORKFLOW_CONTEXT_CAP` → 150000）/ `--projects DIR`（既定 `CLAUDE_PROJECTS_DIR` → `~/.claude/projects`）/ `--cache FILE` / `--refresh` / `-h|--help`。引数エラーのみ exit 1
- [ ] 2.3 キャッシュ: `${SUBAGENT_CONTEXT_AUDIT_CACHE:-~/.claude/.subagent-context-audit}` の mtime が `SUBAGENT_CONTEXT_AUDIT_TTL`（既定 21600 秒）以内ならその内容を出して終了。`--refresh` で無視
- [ ] 2.4 走査: `*/*/subagents/agent-*.jsonl` の 1 経路だけを glob し（`.meta.json` は除く）、mtime で期間内に絞る。`subagents/` の外は走査しない
- [ ] 2.4b 分類: 各ファイルの隣の `agent-<id>.meta.json` を読み、`spawnedWithWorktree` が `true` なら `isolated`、それ以外は `non_isolated`。meta.json が無い / 壊れているときはファイル名のパターン（名前が入っているか）で判定し、それも無理なら `non_isolated`。どの場合も全体の `count` からは落とさない
- [ ] 2.5 初回コンテキスト: 先頭から読み、最初の `usage` 付き assistant レコードで打ち切る（全文を読まない）
- [ ] 2.6 最終コンテキスト: 末尾から 256 KiB の窓を読んで後ろ向きに探索。見つからなければ 4 MiB まで窓を倍加。それでも無ければその件を最終側の集計から除く
- [ ] 2.7 集計: `count` / 初回・最終の中央値（偶数件は中央 2 値の平均を四捨五入）と最大 / `over_cap_pct` を全体と隔離別（`sources.isolated` / `sources.non_isolated` がそれぞれ `count` / `first_median` / `last_median` / `over_cap_pct`）で組み立て、1 行 JSON で stdout に出し、同じ内容をキャッシュに atomic に書く
- [ ] 2.8 fail-open: `python3` 不在・projects 不在・0 件・読み取り例外はすべて `count` 0 の結果＋`note` を出して exit 0
- [ ] 2.9 実行ビットを立てる（`chmod +x`）
- [ ] 2.10 第 1 章で書いたテスト（1.5〜1.10 と 1.6b / 1.6c）が全部通ることを確認する（exit code と出力を貼る）

## 3. キャッシュ動作のテストと監査手順の文書

- [ ] 3.1 `subagent-context-audit.bats` に失敗するテストを足す: キャッシュファイルの mtime が TTL 以内なら、トランスクリプトを差し替えても出力が変わらない（走査していないことの検証）
- [ ] 3.2 `subagent-context-audit.bats` に失敗するテストを足す: `--refresh` は TTL を無視して再走査し、キャッシュファイルの内容が更新される
- [ ] 3.3 3.1〜3.2 が通るまで 2.3 / 2.7 のキャッシュ実装を仕上げる
- [ ] 3.4 `plugins/dev-workflow/docs/usage-audit.md` を新規作成する（`docs/auto-merge-deployments.md` の書き方に合わせる）。内容は ① 実行コマンド（`--days` / `--cap` / `--refresh`）② 出力キーの意味 ③ 何を見たら固定分が増えたと判断するか（全体の `first_median` を主系列に見て、動いたら `sources` で母集団の構成変化と切り分ける）④ キャッシュファイルの場所、の 4 点
- [ ] 3.5 `session-tripwires.sh` を含む既存スクリプトを 1 行も変更していないことを `git diff --stat` で確認する（主の指示。#253 が `session-tripwires.sh` を編集中のため）

## 4. 実機での確認と後始末

- [ ] 4.1 実機の `~/.claude/projects` に対して `subagent-context-audit.sh` を `--refresh` で 1 回実行し、出力 JSON と所要時間を記録する（#257 の実測値 W 初回中央値 54,300〜58,000 / 最終中央値 W 168,017・G 153,524 と桁が合うか。#257 の集計は `subagents/agent-*.jsonl` を母集団にしていたので、全体値でそのまま照合できる）
- [ ] 4.2 2 回目の実行がキャッシュヒットで即返ることを確認する
- [ ] 4.3 main を取り込んだ上で `plugins/dev-workflow/.claude-plugin/plugin.json` の version を **2.6.2 に固定する**（主による事前割当。#253 が 2.6.1、#261 が 2.7.0 を取り、この change は #261 より先にマージする前提）。この worktree は現在 2.5.0 で main（2.6.0）より後ろにあるため、素直に「上げる」と 2.6.0 系を飛ばして main と衝突する。`tests/marketplace-sync.bats` の S131 は merge-base からの bump しか見ないので、テストが通っても衝突は防げない
- [ ] 4.4 `scripts/test.sh` を全件実行し、exit code と結果サマリを記録する（push 前の規約）
- [ ] 4.5 `openspec/changes/subagent-context-usage-metrics` を archive し、`openspec/specs/dev-workflow-execution-strategy/spec.md` に要件が反映されたことを確認する（delta 見出しが正本に残っていないこと。`tests/openspec-specs-format.bats`）
