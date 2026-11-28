# Proposal

## Why

Claude Code に配布している共通ルールを Codex の指揮役と worker の役が読めず、破壊的 git、コミット・PR、主への聞き方の規約が欠けている。既定の指示容量では flatmate のリポジトリ規約と人格の後半が切れるため、共通ルールの配布と指示全体の容量を一緒に検証する（oratta/claude-harness#1853）。

## What Changes

- 公開版と許可済み個人版の共通ルール、Output Style `readable` の要点、harness の `AGENTS.md` を Codex に読ませる仕組みを追加する。正本は既存の `rules/` のままにし、Codex 用の版を生成する場合は手書きの写しを持たず、正本との差を検知する。
- 指揮役の `~/.codex` と登録済み `CODEX_HOME`、`codex-worker.py` が作る役の一時ホームを配布対象にする。指示容量を設定する方式を採る場合、一時ホームの config にも反映する。
- 共通ルール・リポジトリ規約・人格を合わせた指示容量のテストを追加し、flatmate の住人の組み合わせを少なくとも一つ含める。
- 新しい Codex セッションによる三つの共通ルールの回答、flatmate の人格の最後の節の回答、worker による既存履歴に合う日本語 commit の実機記録を issue に残す。
- 自動メモリの扱いと理由、配布・検証の手順、変更記録を README または docs に残す。

## Capabilities

### New Capabilities

- `codex-shared-instructions`: 共通ルールの正本から Codex の各セッションへの供給、生成物を使う場合の一致検査、指示全体の容量検証、自動メモリの取り扱い。

### Modified Capabilities

- `codex-worker`: 「一時領域は親の環境をそのまま引き継ぐ」が runtime CODEX_HOME の内容を認証リンクと config のみに限定しているため、共通指示も置ける契約に変更する。役への指示と、採用する場合の容量設定を一時ホームに配布する。

## Impact

- 主な対象は `scripts/sync.sh` の配布処理、`plugins/dev-workflow/scripts/codex-worker.py` の runtime 構築、対応するテストと docs。実際の供給方式・容量値・登録済みホームの取得経路・自動メモリの方針は design で確定する。
- 既存の公開版・個人版の正本と overlay の境界を調査し、個人版のルールや人格そのものを公開成果物に含める必要があるかも design で確認する。
- `tests/injection-budget.txt` の値は変更しない。#1850 の develop 手順の Codex 対応、genetta-inc/flatmate#2160 のルート `CLAUDE.md`、起動コマンドや hook の追加は対象外。
- 本 change の仕様化工程では実ホームへ書き込まず、実装と実機検証は後続の工程で行う。
