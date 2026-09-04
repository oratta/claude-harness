# usage-snapshot-multi-account — 使用量観測を複数 Claude アカウント対応にする

## Why

Claude Code は環境変数 `CLAUDE_SECURESTORAGE_CONFIG_DIR` を設定すると、`CLAUDE_CONFIG_DIR`（設定・履歴・プラグイン）を共有したまま Keychain の認証情報だけを別枠にできる。これにより 1 台のマシンで複数アカウントを使い分けられるが、使用量の観測系がこれに追随していない。

`plugins/dev-workflow/scripts/usage-probe.sh` は Keychain サービス名を `Claude Code-credentials` にハードコードしているため、複数アカウント運用をしても常に既定アカウントの使用量しか取れない。結果として `scripts/session-tripwires.sh` が導出する `FABLE_BUDGET_MODE` は既定アカウントの残量に固定され、別アカウントで作業していても誤ったモードでモデル選択が行われる。statusline も 1 アカウント分のレートリミットしか表示できず、どちらのアカウントの数字を見ているのか判別できない。

## What Changes

- **アカウントレジストリの新設**: `~/.claude/accounts.json`（`CLAUDE_ACCOUNTS_FILE` で上書き可）にスロット（id / label / securestorage パス）を列挙する。**ファイルが無ければ既定スロット 1 つだけとして扱い、現行と完全に同一の挙動・表示に落ちる**（これが最優先の受け入れ条件）。
- **usage-probe.sh の複数スロット化**: レジストリの全スロットをループし、スロットごとに Keychain サービス名を導出してフェッチする。サービス名の導出は Claude Code 本体（v2.1.259）と同じロジック — securestorage パスが null / 空なら `Claude Code-credentials`、それ以外は `Claude Code-credentials-` + `sha256(NFC 正規化したパス)` の先頭 8 桁。
- **snapshot schema 2**: `accounts` にスロットごとの値（`five_hour` / `seven_day` / Fable weekly / 取得時刻）、`active` に現在のスロット id を持つ。これまでパースしていなかった `five_hour`（消化率・resets_at）も取得対象に加える。
- **後方互換のトップレベルミラー**: 従来キー（`fable_weekly_pct` / `fable_active` / `weekly_all_pct` / `weekly_resets_at` / `weekly_resets_epoch`）は active スロットの値をミラーして残す。`session-tripwires.sh` の `FABLE_BUDGET_MODE` 導出を無改修で動かすため。
- **fail-open をスロット単位にする**: あるスロットのフェッチが失敗しても、そのスロットは既存 snapshot の前回値を引き継いで保持し、他スロットの新しい値は書く。非 active アカウントは OAuth アクセストークンが期限切れでフェッチが落ちるのが常態のため（トークンのリフレッシュは、そのアカウントで Claude Code を動かしたときにしか起きない）。既存の全体 fail-open（パース失敗時に snapshot 全体を壊さない）契約は維持する。
- **refresh_token によるトークン更新は実装しない**: Claude Code 本体のリフレッシュと競合してトークンを無効化するリスクがあるため、意図的に非対応とする。非 active アカウントの鮮度は「取得からの経過時間の表示」で補う。
- **statusline のアカウント別表示**: レートリミット行をアカウントごとに 2 行（`5h` / `7d All` + `Fable`）にし、左端にスロット label を置く。active スロットは stdin のライブ値、非 active スロットは snapshot の値＋取得からの経過時間。**スロットが 1 つのときは label 列も出さず、現行と 1 バイトも変わらない出力にする**。

## Capabilities

### New Capabilities

- `usage-account-registry`: 複数アカウントのスロット定義（`~/.claude/accounts.json`）と、スロットから Keychain サービス名を導出する規則。レジストリ不在時の既定スロットへの縮退を含む。
- `statusline-multi-account-usage`: statusline のレートリミット表示をスロット別に描画する要件。1 スロット時の現行同一出力、非 active スロットの経過時間併記、active スロット判定のフォールバックを含む。

### Modified Capabilities

- `dev-workflow-escalation-tripwires`: Requirement「usage-probe と snapshot 契約」を schema 2（`accounts` / `active` / `five_hour`）とスロット単位 fail-open に合わせて改訂する。トップレベル従来キーのミラーによる後方互換も要件化する。

## Impact

- **コード**: `plugins/dev-workflow/scripts/usage-probe.sh`（複数スロット化・schema 2）、`plugins/statusline/scripts/statusline.sh`（アカウント別描画。バー描画の `bar_seg` / `bar2` は不変）。
- **設定ファイル（新規）**: `~/.claude/accounts.json`。リポジトリには雛形と生成手順のみを置き、実ファイルは各環境で作る。
- **層間契約**: snapshot は dev-workflow（生産者）と statusline（消費者）に跨るスキーマ。schema 2 は追加のみで、既存の読み手（`session-tripwires.sh`）は無改修で動く。
- **spec**: `dev-workflow-escalation-tripwires` の delta と、新規 capability 2 本。
- **バージョン**: `plugins/dev-workflow/.claude-plugin/plugin.json`・`plugins/statusline/.claude-plugin/plugin.json`・ルートの `.claude-plugin/marketplace.json` を同時更新（バージョン同期ルール）。
- **docs**: `plugins/statusline/README.md`（新レイアウトとレジストリの説明）。
- **対象外**: `~/.claude/.rate-limit-snapshot`（statusline が書くだけで読み手が存在しない。grep 確認済み）。
