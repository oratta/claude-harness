## 1. テストを先に書く（Red）

- [ ] 1.1 `plugins/dev-workflow/tests/pr-token-budget.bats` を作る。setup で一時ディレクトリに `git init` したリポジトリ（と `git worktree add` した副 worktree）、別リポジトリ、`projects/<slug>/<session>/subagents/` の固定の meta.json / jsonl を作る（cwd はテスト時に一時パスを埋める）
- [ ] 1.2 固定入力: `#288` の名前なし R1（meta に name 無し）、`#288` の worktree 隔離 W（副 worktree・再開分を含む複数リクエスト・同じ requestId の重複行・壊れた行・usage が文字列の行）、`#2880` の 1 体、別リポジトリの `#288` の 1 体、作業ディレクトリが存在しない `#288` の 1 体、`#400 (#288)` の G
- [ ] 1.3 spec の各 Scenario を bats のテストにする（合計・体数の手計算の期待値、`#2880` 不一致、二重計上なし、別リポジトリ除外、`unresolved`、`skipped_lines`、`--cap` 超過で exit 2、0 体で exit 0、不正な `--cap` で exit 1、`DEV_WORKFLOW_PR_TOKEN_CAP` の反映と `--cap` がそれより優先されること）
- [ ] 1.4 SKILL.md の手順を検査するテスト（`pr-token-budget.sh`・exit 2 で spawn / SendMessage / Codex への委譲をしない・`続けるか、範囲外として閉じるか`・description の `#N` 規約・codex executor が上限の外であること・`PR トークン上限:` の文字列）を `tests/develop-skill.bats` に足す

## 2. スクリプトの実装（Green）

- [ ] 2.1 `plugins/dev-workflow/scripts/pr-token-budget.sh` を実装する（引数解析は `subagent-context.sh` に合わせる。集計は python3。ヘッダコメントに用途・出力・exit code・紐付けの規約を書く）
- [ ] 2.2 リポジトリ識別（`git rev-parse --path-format=absolute --git-common-dir`）を作業ディレクトリごとにキャッシュして呼ぶ
- [ ] 2.3 bats を通す

## 3. 本体手順の追記

- [ ] 3.1 `plugins/dev-workflow/skills/develop/SKILL.md` に次を書く: その記録先のための spawn / SendMessage / Codex executor への委譲の直前に役割と executor を問わず毎回 `pr-token-budget.sh` を実行し、exit 2 なら止まる手順／問いに合計・体数・上限・残工程・推奨を添えること／description に記録先番号 `#N` を入れる規約（役割を問わない）／executor が `codex` の役割の消費はこの上限の外で、`codex-standard` のように W が Codex の profile では累計の歯止めが無いこと／「続ける」後の `PR トークン上限: <合計＋直前の上限>` コメントと `--cap`／「範囲外として閉じる」後の扱い／exit 1 のコメントは同じ記録先・同じ理由で 1 サイクル 1 回まで（1 ループの (1)〜(4) の各 spawn / 再開の位置から参照できる形で 1 箇所にまとめる）
- [ ] 3.2 `plugins/dev-workflow/.claude-plugin/plugin.json` のバージョンを上げ、`plugins/dev-workflow/CHANGELOG.md` に記載する

## 4. 検証

- [ ] 4.1 `scripts/test.sh` 全件 pass（exit code を記録する）
- [ ] 4.2 実データで `pr-token-budget.sh 288` を実行し、出力の形と所要時間を確認する
- [ ] 4.3 `openspec validate add-pr-token-budget --strict`
