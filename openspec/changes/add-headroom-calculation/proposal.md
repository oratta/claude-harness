## Why

「どのアカウントが、いつまでに、どれだけ余るか」の数え方が読む側ごとに違う（経過率 − 使用率の差、使用率 ÷ 経過率の比、天井までの残り、リセット権込みの余り）。リセット権を数に入れているのは flatmate の `scripts/account_allocation.py` だけなので、画面では「使いすぎ」に見えるのにバーンは「余る」として起動する食い違いが起きる。設計の正本 genetta-inc/flatmate#1711 で、計算を Claude Harness の dev-workflow の 1 か所に置き、全員がそこを読むと決めた（記録先 oratta/claude-harness#1300）。

## What Changes

- 新しく `plugins/dev-workflow/scripts/headroom.py` を置く。関数 `compute(now)` が Claude の各スロットと Codex の `current` account（自動選択の既定。`CODEX_HOME` か `~/.codex`）について、使用率・経過率・リセット権・使える量・期限・見込み・余り（surplus）・margin を数え、`best`（一番余っているアカウント）を選ぶ。`write` サブコマンドが結果を `${CLAUDE_CONFIG_DIR:-~/.claude}/.headroom.json`（schema 1）に原子的に書く
- 数え方は flatmate の `account_allocation.py` の `evaluate_accounts`（`segment_surplus`・`counted_tickets`）を移す。Claude は次の週次リセットより前に切れるリセット権 1 枚ごとに使える量へ 100%（余りには天井ぶん）を足す。Codex は量を足さず、週次リセットとリセット権の失効の早いほうを期限にする
- 計算の設定（天井 `HEADROOM_7D_CAP_PCT`、通常の消費ペースの上書き `HEADROOM_NORMAL_RATE_PCT_PER_DAY`）は headroom.py の中で 1 か所から解決し、呼び手からは渡せない
- `codex-develop.py` の Codex の使用量の取得（`account/rateLimits/read`）で `rateLimitResetCredits` も読み、account ごとのキャッシュ `codex-usage/<hash>.json` に `resets` として足す（取得は今までどおり account ごと。headroom が読むのは `current` のキャッシュだけ）（キャッシュの `version` を 2 に上げる）。Codex のリセット権の取得元はこの 1 つにする
- `usage-probe.sh` が `.usage-snapshot` を書いた直後に、`headroom.py write --refresh-codex`（Codex の使用量を読み直してから書く）を呼ぶ。headroom の失敗は probe の結果に影響させない

## Capabilities

### New Capabilities
- `dev-workflow-headroom`: 余りの計算（入力・数え方・設定の解決）、`.headroom.json` の書式（schema 1）と書き出し、書く時機（usage-probe からの呼び出し）

### Modified Capabilities
- `codex-role-profiles`: 要件「複数 Codex account を分離して観測し代表 account を固定する」で、account ごとの cache にリセット権（`resets`）を保存することを足す（生 RPC 応答を保存しない制約は保ったまま、正規化した値だけを持つ）

## Impact

- 新規: `plugins/dev-workflow/scripts/headroom.py`、`plugins/dev-workflow/tests/test_headroom.py`、`plugins/dev-workflow/tests/usage-probe-headroom.bats`
- 変更: `plugins/dev-workflow/scripts/codex-develop.py`（取得とキャッシュ）、`plugins/dev-workflow/scripts/usage-probe.sh`（末尾で headroom を呼ぶ。oratta/claude-harness#1256 も同じファイルを触るので、先にマージされた方に合わせる）
- 読む側の切り替えはこの change に含めない: `cld` のアカウント選択と develop の構成選択（oratta/claude-harness#1301）、ステータスライン（oratta/claude-harness#1302。schema 1 を待つ）、flatmate のバーン・ダッシュボード（genetta-inc/flatmate#1772・#1773）
- headroom が見る Codex を `current` に絞った（複数の Codex account は数えない）ことを genetta-inc/flatmate#1772 に伝える
- 変更の記録: `plugins/dev-workflow/changes/1300.md`。版（version）は上げない
