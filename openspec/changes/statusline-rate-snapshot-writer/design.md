## Context

harness は `CLAUDE_CONFIG_DIR`（既定 `$HOME/.claude`）の `.rate-limit-snapshot` に `ts` と 4 つの枠値を書き、非既定の `CLAUDE_SECURESTORAGE_CONFIG_DIR` では書かない。flatmate には statusline writer の実装と writer / reader が混在する spec があるが、そのスクリプトは実機に配線されていない。issue #517 は writer の責務だけを harness に移す。

## Goals / Non-Goals

**Goals:** harness がローカルと任意の共有ディレクトリに同じ観測 JSON を原子的に書き、観測の帰属と時刻を正しく表す。既存の表示と非既定アカウントの書込抑止を維持する。

**Non-Goals:** flatmate の reader 適格性・最新選択・burn 判定、flatmate 側の撤去や spec 書換え、実機の `statusLine.command` 配線、為替キャッシュ出力。

## Decisions

1. **ローカル保存先は harness の `CLAUDE_CONFIG_DIR/.rate-limit-snapshot` を維持する。** flatmate writer の `RATE_GUARD_SNAPSHOT` override を移す案は、issue の列挙した移行機能に含まれず、harness の既存設定・テストと異なる保存先を増やすため採らない。通常の既定パスは `$HOME/.claude/.rate-limit-snapshot` のままになる。既存の両 reader は `RATE_GUARD_SNAPSHOT`、未設定なら `$HOME/.claude/.rate-limit-snapshot` を読み、`CLAUDE_CONFIG_DIR` は参照しない。writer の `CLAUDE_CONFIG_DIR` が非既定で保存先が変わる運用では、reader 側の `RATE_GUARD_SNAPSHOT` をそのファイルに合わせる必要がある。
2. **同じ観測かどうかは前回ファイルの `obs_sig` と `storage_binding` と `session_id` を併せて判定する。** 数値を前回 JSON から再文字列化すると `12.0` と `12` の表記差で観測時刻を進めるため、flatmate writer と同じく書込予定値から署名を作る。3 条件のいずれかが欠ける・異なるときは新規観測とする。`ts` は `observed_at` に揃える。
3. **共有先は writer 側で設定解決し、各ホストのファイルに同一 JSON を独立して原子的に書く。** 同一ファイルへの PC 間競合を避ける。環境変数が定義されていれば空文字でも設定ファイルより優先する。共有への失敗は statusline 表示とローカル保存に波及させない。
4. **帰属は入力 `session_id`、保存先印、`$HOME/.claude.json` の `oauthAccount.accountUuid` のみで表す。** 保存先印とアカウント ID の形式は flatmate の writer 契約を維持する。資格情報や他の個人情報は取得しない。アカウント ID は読めないとき省略するが、session_id が無いときは新規 snapshot を書かない。

## Risks / Trade-offs

- `session_id` のない旧テスト入力は新規 snapshot を作らない → snapshot を検査する fixture に session_id を加え、表示だけを検査するケースと分ける。
- 現行テストには 5 キー固定の形状検査がある → 新しい writer 契約のキー集合へ期待値を更新し、表示の回帰検査は継続する。
- ホスト名を安全文字へ置換すると別名が衝突しうる → flatmate の既存規則に合わせ、共有ファイル名は正規化した `hostname -s` とし、同一ホスト名の運用上の識別はこの change では追加しない。

## Migration Plan

writer と tests / docs を同じ変更で更新する。新形式は旧形式と同じ `five_hour_*` / `seven_day_*` を保持し、`ts` を `observed_at` に一致させる。既存の旧形式ファイルには署名・帰属が無いため、初回の新形式書込では観測時刻を引き継がず原子的に置き換える。flatmate 側の撤去と spec 参照の変更は flatmate#936 で行う。

## Open Questions

なし。
