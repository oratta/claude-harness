## Why

使っていないアカウントを登録簿（`accounts.json`）に残していると、`cld` の自動選択がそのアカウントを選ぶことがある。自動選択は取得からの経過時間でスロットを外さないので、使っていないスロットは使用率が増えないまま週の経過率だけが進み、余裕が大きく見える（2026-10-12 の実機では `margins=a:25.34,b:28.03` で解約済みの B が選ばれた。再現の記録は issue #976 のコメント）。外すには登録簿からスロットを手で消すしかなく、戻すときは登録をやり直すことになる。

## What Changes

- `accounts.json` の各スロットに `enabled`（真偽値、省略時は `true`）を足す。`schema` は `1` のまま
- `enabled: false` のスロット（オフのスロット）は、起動時の自動選択の候補から外す。理由行の `margins` には `<id>:off` と出す
- オフのスロットを `select-account.sh <id>` で明示指定すると exit 2 になり、標準エラーにオフであることと戻し方を出す
- 全スロットがオフなら既定アカウントへ縮退する。理由は新しい値 `default-due-to-all-off`
- `usage-probe.sh` はオフのスロットの認証情報を読まず、使用量 API も呼ばない。snapshot に残っている値は消さずに引き継ぐ
- ステータスラインは、オフのスロットの行を残し、使用率の代わりに `off` を 1 行出す
- `accounts-init.sh` は、同じ id を上書きするときに既存の `enabled` を消さない
- `enabled` を書いていない登録簿では、自動選択の結果もステータスラインの出力も変わらない

オンとオフを切り替えるコマンド（#977）と Codex 側のオフ（#978）はこの change に含めない。確認は `accounts.json` を手で書き換えて行う。自動選択が経過時間でスロットを外さない規則そのものも変えない。

## Capabilities

### New Capabilities

なし。

### Modified Capabilities

- `usage-account-registry`: スロットの形状に `enabled` を足し、オフのスロットの扱い（自動選択の候補・明示選択・理由行・使用量の取得・生成手段での保持）を定める
- `statusline-multi-account-usage`: オフのスロットの行を `off` の 1 行で描く要件を足す

## Impact

- コード: `plugins/dev-workflow/scripts/usage_view.py`、`select-account.sh`、`usage-probe.sh`、`accounts-init.sh`、`plugins/statusline/scripts/statusline.sh`（登録簿を読む 5 か所すべて）
- テスト: `plugins/dev-workflow/tests/account-selector.bats`、`usage-probe-multi-account.bats`、`test_usage_view.py`、`plugins/statusline/tests/statusline-multi-account.bats`
- 文書: `plugins/statusline/README.md`（登録簿のフィールド表）、`plugins/dev-workflow/README.md`（起動時選択の節）、両プラグインの `changes/976.md`
- 互換性: `enabled` を書いていない登録簿は従来どおりに読まれる。`usage_view.py` の実効値（`build_view` の出力）は変えないので、active スロットだけを読む `session-tripwires.sh` / `agent-model-guard.sh` / `codex-develop.py` には影響しない
- 後続: #977（一覧・追加・オン・オフのコマンド）と #978（Codex をオフにする）がこの change のマージを待っている
