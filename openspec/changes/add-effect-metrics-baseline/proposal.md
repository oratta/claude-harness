## Why

jev と開発ワークフローの機械化による効果を、消費量だけでなく PR の速さ・品質・実稼働時間まで同じ期間・同じコマンドで比較できる基準がない。2026-09-01〜09-21 の導入前ベースラインを再現可能な形で固定し、以後の変更が「安く、速く、品質を落とさず」に効いたかを数字で判断できるようにする。

## What Changes

- Claude Code のメイン／サブエージェント履歴を `message.id` 優先で重複排除して消費を集計する一方、稼働時間は usage の有無を問わず JSONL の全行の timestamp から集計する。既存 `/cost` の `requestId` 基準は変更しない。
- サブエージェントを起動プロンプト先頭とファイル名の固定一致規則で `gate-runner` / `worker` / `decider` / `other` に分類する。期間前に起動して継続した transcript は期間内の消費・時間へ含めるが、starts と起動時モデル比率には含めない。
- gate-runner の PR 単位のターン数・読み込み量・所要時間、GitHub 上の Draft 作成からマージまでのリードタイム、期間内マージ本数、マージ後 7 日以内の bug issue 数を集計する。GitHub データは `gh search prs` の 30 件既定や `mergedAt` 欠落に依存せず、REST の全ページから取得する。
- アカウント別 usage snapshot の観測時刻 `accounts.<id>.fetched_at` を日次 JSONL に追記するスクリプトと、launchd 等で利用者が登録するための導入手順を追加する。同じ観測の再記録や欠測を消費 0 とみなさず、実装時に利用者環境へジョブを登録しない。
- `weekly-metrics.sh --since YYYY-MM-DD --until YYYY-MM-DD` が上記を 1 行 JSON で返す契約と fixture ベースのテストを追加する。
- account ごとに十分な日次観測がある reset 窓だけから週次 pace を出す。全 account の有効窓が揃わない期間は `pace.weekly_sum_pct` を常に存在する `null` とし、記録のない 2026-09-01〜09-21 を 0 扱いしない。
- 3 日分以上の実ログ蓄積と epic #360 への実測ベースライン投稿は、コード差分ではなく実装後の運用 handoff として残す。

## Capabilities

### New Capabilities

- `cost-ledger-effect-metrics`: Claude Code 履歴、usage pace ログ、GitHub データを期間指定で集約し、消費・速度・品質・稼働時間の比較可能な 1 行 JSON を出す契約。

### Modified Capabilities

なし。既存の `/cost`、帰属、料金、gate report の外部契約は変更しない。

## Impact

- 主な対象: `plugins/cost-ledger/scripts/`、`plugins/cost-ledger/tests/`、`plugins/cost-ledger/README.md`。
- 既存 `cost_ledger.py` のログ解析・料金計算を再利用可能な境界として使うが、既存 CLI 出力は維持する。
- ローカル入力: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/projects`、usage snapshot、usage pace log。固定された個人パスや認証情報は保存しない。
- 外部入力: 認証済み `gh` による PR / issue メタデータ。GitHub 読み取り失敗や欠測は出力で識別できるようにする。
