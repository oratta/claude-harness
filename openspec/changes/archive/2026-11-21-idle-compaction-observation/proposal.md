# Proposal

## Why

#1385 の disk fixture と Bats だけでは、Claude Code の live 設定反映や待機中の compact の有無を証明できない。#1388 の受け入れ条件に従い、主が承認した専用実機セッションで同じ項目を収集し、条件不足を未検証として残せる手順と受動的な収集部品を用意する。

## What Changes

- 実行時に主が起動本数・消費上限・設定適用先を記入する観測手順書を追加する。親・子・単発の実効値確認、親・子の待機観測、通常 compact と再読み込み hook の別区間観測を扱う。
- 既存 JSONL と実行者の観測メタデータから必要な値だけを収集する CLI を追加する。会話量は `subagent-context.sh --file` を再利用し、イベントは JSON の type/subtype で数える。
- 条件不足を未検証とする判定、`LLM_LOG_DIR` の保存先確認、秘密値を出さない出力を fixture ベースの Bats で確かめる。
- 既存の設定・起動・compact 後 hook は変更しない。実機セッション起動や実設定変更、#1385 の実機確認の完了宣言は今回の作成作業に含めない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `dev-workflow-develop`: 既存の実機確認要件を補助する、承認欄付きの再現手順と受動的な観測収集の契約を追加する。既存の #1385 の完了条件は変えない。

## Impact

実装予定は `plugins/dev-workflow/skills/develop/references/idle-compaction-observation.md`、`plugins/dev-workflow/scripts/idle-compaction-observation.py`、`plugins/dev-workflow/tests/idle-compaction-observation.bats`、`plugins/dev-workflow/changes/1388.md` の 4 ファイル。Python 3・既存の Bash 計測部品・Bats を使用し、新しい外部依存や常時注入する説明は追加しない。元のチェックリストは `changes/1385.md`、設定手順の正本は `references/reply-after-idle.md` を参照する。
