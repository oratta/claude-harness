## 1. テスト先行（Red）

- [x] 1.1 `tests/usage-probe.bats`（新規）に usage-probe テストを追加（snapshot スキーマ必須フィールド・5 分キャッシュ・fail-open、`USAGE_PROBE_RESPONSE_FILE`/`USAGE_SNAPSHOT`/`USAGE_PROBE_TTL`/`USAGE_PROBE_NOW` 注入）。実行して Red を確認
- [x] 1.2 同 bats に session-tripwires 導出テストを追加（導出モード注入・Fable 残量%・明示 env override・snapshot 無し→conserve でもトリップワイヤーは載る）。Red 確認

## 2. 実装（Green）

- [x] 2.1 `scripts/usage-probe.sh` を新設（Keychain/credentials からトークン取得 → curl → python3 でパース → snapshot 原子的書き込み、5 分キャッシュ、fail-open、実行権限付与）
- [x] 2.2 `scripts/session-tripwires.sh` を拡張（probe best-effort 実行 → snapshot 読取 → 残量モード導出 → 導出ブロック + トリップワイヤー節を additionalContext に注入、明示 env 優先、probe 失敗でもトリップワイヤーは載る）
- [x] 2.3 bats 全 Green + リポジトリ全体の回帰なしを確認

## 3. ドキュメント

- [x] 3.1 `references/decision-criteria.md`: 残量モード表に `exhausted` を追記、自動導出ルール節を追加、abundant の self-contained 委譲条件を追記
- [x] 3.2 `templates/escalation-tripwires.md`: exhausted の Opus 上限（全経路）と rate-limit reactive 降格トリップワイヤーを追加

## 4. リリース

- [x] 4.1 plugin.json v1.3.0、marketplace 同期（dev-workflow 1.3.0 / top-level bump）
- [x] 4.2 `openspec validate dev-workflow-fable-usage-probe --strict` が通ることを確認
- [x] 4.3 commit / push で Draft PR を更新
