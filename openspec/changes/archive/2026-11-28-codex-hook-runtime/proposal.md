# Proposal

## Why

#1862 の Codex 拒否判定は fixture で検証済みだが、本体・native subagent・worker への配布と信頼は未接続である。#1863（元 #1858 の G003）として実際の起動に接続し、拒否と未実行の証拠を対象別に残す。

## What Changes

- 一時 CODEX_HOME 向けの配布入口を作り、既存 adapter と依存判定を worker の App Server 起動に接続する。
- 管理 hook と invocation 限定の hook trust bypass を隔離環境で比較し、採用理由を記録してから起動方式を確定する。
- 本体への導入は主の承認後の手順とする。実ホームは本 change の作業で変更しない。
- 3対象の実機確認・未取得理由・主の再現手順を一覧と共用変更記録へ反映する。

## Capabilities

### New Capabilities

- `codex-hook-runtime`: 配布、起動時の信頼、隔離した実機検証と対象別証跡。

### Modified Capabilities

- `codex-worker`: 一時領域の例外に runtime 用 hook 設定を含める。TMPDIR/TMPPREFIX と account の既存契約を保つ。

## Impact

`scripts/codex-worker.py`、新規配布 helper と回帰テスト、`scripts/CODEX-WORKER.md`、`docs/codex-develop.md`、`docs/codex-hook-inventory.md`、`changes/1858.md`。既存 `codex-hook-coverage` の対象別更新契約を使い、`codex-pretool-guards` の判定要件は変えない。hooks 配下・既存判定・権限設定・実ホーム・版は変更しない。#1856 等の兄弟、秘密環境全般の整理、未確認質問経路の adapter 拡張は範囲外。
