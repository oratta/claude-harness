## Why

Claude アカウントの使用量は、今は非公開の使用量 API（`/api/oauth/usage`）を叩く `usage-probe.sh` だけから取っている。API の回数制限は公開されておらず、2026-09 にはアカウント A で 429 が返り続けて自動選択と枠の残量モードの判定が「データなし」に倒れ続けた（User-Agent の応急処置は #416 で入れたが、枠の扱いはいつ変わってもおかしくない）。一方、各セッションのステータスラインには会話の応答に付いてくる `rate_limits`（5 時間枠と週次の使用率・リセット時刻）が毎回渡されており、API を叩かずに得られる。これをアカウント別に記録して主な情報源にし、API は補助に下げる（記録先: issue #417）。

## What Changes

- statusline は、stdin の `rate_limits` を**起動アカウント別の記録**（`${CLAUDE_CONFIG_DIR:-~/.claude}/.usage-sessions/<アカウント鍵>.json`）に書く。アカウント鍵は `CLAUDE_SECURESTORAGE_CONFIG_DIR` から Keychain サービス名と同じ導出で決める（未設定は `default`、それ以外は NFC 正規化した値の sha256 先頭 8 桁）。自分の起動環境だけから鍵を決めるので、B のセッションが A の記録を書くことは起きない（flatmate#605 の読み違えの対策を、書かないことから分けて書くことに置き換える）。既存の `~/.claude/.rate-limit-snapshot` は外部の読み手のために今までどおり書く。
- 読み手は「300 秒より古い値は使えない」をやめ、**リセット時刻で判断する**。リセット時刻を過ぎた窓は 0% とみなし、過ぎていなければ古い値を「少なくともこれだけ使った」下限として使う。セッション記録と usage-probe の snapshot の両方があれば、同じ窓の値は大きい方を取る。
- 上の判断を dev-workflow 内の 1 か所（`plugins/dev-workflow/scripts/usage_view.py`）に置き、`select-account.sh`・`session-tripwires.sh`（`FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` の導出）・`agent-model-guard.sh`（fork の共有枠判定）・`codex-develop.py`（Claude 側の自動選択）がそこから値を読む。statusline は他プラグインに依存しない規則に従い、同じ規則を自分で実装して非 active 行の表示に使う。
- **BREAKING（内部契約）**: `usage-probe.sh` を補助に下げる。snapshot の mtime による 300 秒 TTL をやめ、スロットごとに「セッション記録が無いか 3 時間より古い、または snapshot の同スロットの取得時刻が 3 時間より古い（Fable 週次は記録に入らないため）」ときだけ、前回の試行から 3 時間以上空いていれば取りに行く。マシン全体で 1 本だけ走るようロックを取り、429 が返ったスロットは間隔を倍にして空ける（上限 24 時間）。試行の状態は `~/.claude/.usage-probe-state` に置く。
- `select-account.sh` の理由行から `stale` がなくなる（値が 1 つも無いスロットだけが `missing`）。

## Capabilities

### New Capabilities

- `usage-session-records`: セッションのステータスラインが起動アカウント別に書く使用量の記録（置き場所・形式・アカウント鍵の導出・原子的な書き込み）と、記録と usage-probe snapshot から「いま使ってよい値」を求める規則（リセット時刻による 0% 扱い・下限としての古い値・2 つの情報源の合わせ方）。

### Modified Capabilities

- `usage-account-registry`: 自動選択の候補判定を、300 秒の鮮度からセッション記録を含む実効値（リセット時刻で判断）に変える。
- `dev-workflow-escalation-tripwires`: usage-probe の実行条件（TTL → スロット別の間隔・対象の絞り込み・マシン全体で 1 本・429 の間隔延長）と、残量モードの導出元（snapshot のトップレベル → active スロットの実効値）を変える。
- `statusline-multi-account-usage`: セッション記録の書き込みを足し、非 active スロットの行をセッション記録と snapshot の新しい方から描く。
- `codex-role-profiles`: 自動選択の Claude 側の鮮度判定を実効値に変え、「Codex と同じ 300 秒境界」の要件を外す（Codex 側の 300 秒は変えない）。

## Impact

- `plugins/statusline/scripts/statusline.sh`・`plugins/statusline/README.md`・`plugins/statusline/tests/`（`statusline-multi-account.bats` ほか）・`plugins/statusline/.claude-plugin/plugin.json`
- `plugins/dev-workflow/scripts/usage_view.py`（新規）・`select-account.sh`・`usage-probe.sh`・`session-tripwires.sh`・`agent-model-guard.sh`・`codex-develop.py`
- `plugins/dev-workflow/tests/`（`account-selector.bats`・`usage-probe.bats`・`usage-probe-multi-account.bats`・`tripwire-hook.bats`・`test_codex_develop.py`、新規 `test_usage_view.py`）・`plugins/dev-workflow/skills/develop/references/decision-criteria.md`（usage snapshot 契約の説明）・`plugins/dev-workflow/.claude-plugin/plugin.json`
- 受け入れるリスク（issue #417 に記載どおり）: 記録を更新するのはこの PC で会話しているセッションだけなので、別の PC や claude.ai の Web 画面でしか使っていないアカウントは実際より空いて見える。低頻度の usage-probe がこのずれを拾う。
