## Context

`/api/oauth/usage`（`https://api.anthropic.com/api/oauth/usage`、`Authorization: Bearer <oauth accessToken>` + `anthropic-beta: oauth-2025-04-20`）は認証ユーザーの利用状況を返す。2026-07-22 実測レスポンス（要点）:

```json
{
  "seven_day": { "utilization": 55.0, "resets_at": "2026-07-24T21:59:59+00:00" },
  "limits": [
    { "kind": "weekly_all", "group": "weekly", "percent": 55, "is_active": false, "scope": null },
    { "kind": "weekly_scoped", "group": "weekly", "percent": 73, "is_active": true,
      "scope": { "model": { "display_name": "Fable" } }, "resets_at": "2026-07-24T21:59:59+00:00" }
  ]
}
```

OAuth token の所在は環境で異なる: Linux 等は `~/.claude/.credentials.json`、macOS は Keychain（`security find-generic-password -s "Claude Code-credentials" -w`）。両者とも JSON `.claudeAiOauth.accessToken` を持つ。

## Goals / Non-Goals

**Goals:**

- Fable 週次残量を機械可読に取得し、`FABLE_BUDGET_MODE` を自動導出する（手動宣言の陳腐化を解消）
- probe は best-effort。失敗してもセッション開始・既存 snapshot を壊さない（fail-open）
- snapshot を single source とし、session-tripwires が導出に使う（probe と導出の責務分離）

**Non-Goals:**

- 5 時間セッション枠（`five_hour`）の考慮 — 本 change は週次 Fable 枠のみ
- reserve モードの意味変更 — reserve は据え置き（自動実行のみ制限）。exhausted を別状態として新設
- probe の常時ポーリング — SessionStart 時 + 5 分キャッシュのみ。rate-limit reactive 時に限り即時再フェッチ

## Decisions

1. **Fable 消費率の抽出元**: `limits[]` のうち `.group == "weekly"` かつ `.scope.model.display_name == "Fable"` のエントリの `.percent` を `fable_weekly_pct`、その `.is_active` を `fable_active` とする。該当エントリが無ければ `fable_weekly_pct=null` / `fable_active=false`。パースは python3（既存 hook と同じ依存。jq 追加不要）。

2. **導出式（session-tripwires 側）**: 優先順位は ① 明示 env `FABLE_BUDGET_MODE` → ② snapshot 無し/`fable_weekly_pct` null → `conserve`（既定・安全側）→ ③ `fable_weekly_pct > 90` → `exhausted` → ④ `週経過%` を `weekly_resets_at` から算出（`(7日 - (resets_at - now)) / 7日 * 100`、0..100 clamp）し、`fable_weekly_pct <= 週経過%` なら `abundant`、超なら `conserve`。「消費が時計より遅ければ余裕、速ければ節約」というバーンレート比較。

3. **fail-open の徹底**: probe は認証取得・curl・JSON パースのいずれの失敗でも exit 0 で snapshot を書かない。`set -e` はフェッチ失敗で誤って落ちないよう、フェッチ部を明示的にガードする。snapshot が壊れた JSON でも導出側は読めなければ conserve に倒れる。

4. **5 分キャッシュ**: snapshot の mtime（および `fetched_at`）が TTL（既定 300 秒）以内なら再フェッチしない。SessionStart は頻発しうるため API 負荷とレイテンシを抑える。TTL は `USAGE_PROBE_TTL` で上書き可。

5. **テスト可能性**: probe は `USAGE_PROBE_RESPONSE_FILE`（生 API JSON を注入）・`USAGE_SNAPSHOT`（出力先）・`USAGE_PROBE_TTL`・`USAGE_PROBE_NOW`（現在 epoch 上書き）を env で受ける。本番はいずれも未設定で Keychain/credentials + curl 経路を通る。これにより live 認証なしで bats がキャッシュ・fail-open・スキーマ・導出を検証できる。

6. **exhausted と reserve の差**: reserve は「人間用に温存」で自動実行のみ Fable 禁止（interactive は自由）。exhausted は「枠が実際に無い」ため interactive を含む全経路で Fable 禁止・Opus 上限。加えて rate-limit 実エラーで reactive に Opus 降格する。両者は意味が異なるので別状態として持つ。

7. **rate-limit reactive 降格**: 予測的トリップワイヤー（消費率の閾値判定）とは別系統。Fable 実行が 429 / weekly-limit エラーを返した時、その場で Opus に降格して作業継続（成果引き継ぎ）し、probe を再実行して snapshot を更新する。

## Risks / Trade-offs

- [API レスポンス形状の将来変更] → 抽出は「weekly かつ Fable scope」の条件マッチで、フィールド欠損時は null→conserve に fail-open するため破綻しても安全側。bats が snapshot スキーマを固定する
- [Keychain アクセスのプロンプト] → `security find-generic-password -w` は同一ユーザーの login keychain 読み取りで通常プロンプト無し。失敗すれば fail-open
- [週経過%の時刻依存] → `USAGE_PROBE_NOW` で決定論的にテスト可能。本番は `date +%s`
- [SessionStart レイテンシ] → 5 分キャッシュでフェッチは最大 5 分に 1 回。キャッシュヒット時は curl を打たない
