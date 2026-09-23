## 1. テストを先に書く（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/pr-token-budget.bats` を作る。setup で一時ディレクトリに `git init` したリポジトリ（と `git worktree add` した副 worktree）、別リポジトリ、`projects/<slug>/<session>/subagents/` の固定の meta.json / jsonl を作る（cwd はテスト時に一時パスを埋める）
- [ ] 1.2 固定入力: `#288` の名前なし R1（meta に name 無し）、`#288` の worktree 隔離 W（副 worktree・再開分を含む複数リクエスト・同じ requestId の重複行・壊れた行・usage が文字列の行）、`#2880` の 1 体、別リポジトリの `#288` の 1 体、作業ディレクトリが存在しない `#288` の 1 体、`#400 (#288)` の G。Codex 側: `--codex-records` のファイル（トークン数付きの thread・同じ thread の重複行・`-` の thread・どこにも rollout が無い `-` の thread・書式に合わない行）と、`--codex-home` を 2 つ（`sessions/YYYY/MM/DD/rollout-*-<thread_id>.jsonl` に、累計が増える行・同じ累計の繰り返し行・`info` が null の行・`token_count` 以外の行を含む固定の rollout を置く。うち 1 件は 2 つ目の CODEX_HOME にだけ置く）
- [ ] 1.3 spec の各 Scenario を bats のテストにする（合計・体数の手計算の期待値、`#2880` 不一致、二重計上なし、別リポジトリ除外、`unresolved`、`skipped_lines`、`--cap` 超過で exit 2、0 体で exit 0、不正な `--cap` で exit 1、`DEV_WORKFLOW_PR_TOKEN_CAP` の反映と `--cap` がそれより優先されること、`claude_tokens`・`codex_tokens` の内訳と `total_tokens` がその和であること、Codex 分を足して初めて上限を超える場合の exit 2、同じ thread の二重計上なし、rollout の最大累計の採用、2 つ目の CODEX_HOME の探索、`codex_unresolved`、Codex 記録ファイルの書式違反行の `skipped_lines`）
- [ ] 1.4 SKILL.md の手順を検査するテスト（`pr-token-budget.sh`・exit 2 で spawn / SendMessage / Codex への委譲をしない・`続けるか、範囲外として閉じるか`・description の `#N` 規約・`Codex 消費:` コメントの投稿と `--codex-records` / `--codex-home` の受け渡し・`PR トークン上限:` の文字列）を `tests/develop-skill.bats` に足す。`gate-runner.md` に G が Codex の thread_id を return に書く手順があることの検査も足す

## 2. スクリプトの実装（Green）

- [ ] 2.1 `plugins/dev-workflow/scripts/pr-token-budget.sh` を実装する（引数解析は `subagent-context.sh` に合わせる。集計は python3。ヘッダコメントに用途・出力・exit code・紐付けの規約を書く）
- [ ] 2.2 Codex 分の集計（`--codex-records` の読み込み・thread_id での重複排除・`-` の thread の rollout 探索と最大累計の採用・`codex_unresolved`）を実装する。rollout は 1 thread あたりファイル名の glob 1 回で探し、全 rollout を走査しない
- [ ] 2.3 リポジトリ識別（`git rev-parse --path-format=absolute --git-common-dir`）を作業ディレクトリごとにキャッシュして呼ぶ
- [ ] 2.4 bats を通す

## 3. 本体手順の追記

- [ ] 3.1 `plugins/dev-workflow/skills/develop/SKILL.md` に次を書く: その記録先のための spawn / SendMessage / Codex executor への委譲の直前に役割と executor を問わず毎回 `pr-token-budget.sh` を実行し、exit 2 なら止まる手順／問いに合計・体数・上限・残工程・推奨を添えること／description に記録先番号 `#N` を入れる規約（役割を問わない）／Codex を呼んだら記録先に `Codex 消費: <thread_id> <tokens>` を投稿すること（codex-worker の結果 JSON の `thread_id` と `usage.total.totalTokens`、G が Bash から呼んだ分は G の return の thread_id と `-`）／計測の直前に渡すすべての記録先番号の `Codex 消費:` コメントを集めて `--codex-records` のファイルを作り、account 対応表の全 CODEX_HOME と本体の `${CODEX_HOME:-$HOME/.codex}` を `--codex-home` で渡すこと（計測と記録は SKILL.md に置き、`references/codex-develop.md` と `codex-worker.py` には置かない）／問いに Claude 分と Codex 分の内訳を添えること／「範囲外として閉じる」後は Codex にも委譲しないこと／「続ける」後の `PR トークン上限: <合計＋直前の上限>` コメントと `--cap`／「範囲外として閉じる」後の扱い／exit 1 のコメントは同じ記録先・同じ理由で 1 サイクル 1 回まで（interactive では本体の 1 セッション、unmanned では loop-dev-agent の 1 サイクル）（1 ループの (1)〜(4) の各 spawn / 再開の位置から参照できる形で 1 箇所にまとめる）
- [ ] 3.2 `plugins/dev-workflow/skills/develop/references/roles/gate-runner.md` に、full レビューで Codex を呼んだら thread_id（`codex exec` の出力ヘッダの `session id:`、companion の結果の `threadId`）を return に書く手順を足す
- [ ] 3.3 `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョンを上げ、`plugins/dev-workflow/CHANGELOG.md` に記載する

## 4. 検証

- [ ] 4.1 `scripts/test.sh` 全件 pass（exit code を記録する）
- [ ] 4.2 実データで `pr-token-budget.sh 288`（`--codex-records` に実在の rollout の thread_id を `-` で 1 件入れる）を実行し、出力の形と所要時間を確認する
- [ ] 4.3 `openspec validate add-pr-token-budget --strict`
