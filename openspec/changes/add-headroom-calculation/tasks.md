## 1. Codex のリセット権をキャッシュに足す（codex-role-profiles の変更）

- [x] 1.1 `test_codex_develop.py` に、`rateLimitResetCredits` を持つ応答で cache が `version: 2` になり `resets`（`available_count` と available の `expires_at` だけ。id なし）を持つテストと、欄が無い・`availableCount` が整数でない応答で `resets` を書かないテストを足し、落ちることを確かめる。触る範囲: plugins/dev-workflow/tests/test_codex_develop.py:528-556（複数 account の cache のテストの近く）
- [x] 1.2 `probe_codex_account` で `rateLimitResetCredits` を正規化して返し、`_update_codex_cache` が `version: 2` と `resets` を書くようにする（取得失敗時は前回値を保つ今の振る舞いのまま）。`usage_margin` は変えない。触る範囲: plugins/dev-workflow/scripts/codex-develop.py:174-249（`_quota_windows`・`probe_codex_account`・`_update_codex_cache`）
- [x] 1.3 `test_codex_develop.py` 全体（構成選択と `.statusline-codex` を参照しない検査を含む）が通ることを確かめる。触る範囲: plugins/dev-workflow/tests/test_codex_develop.py:991-1046（`DocumentationContracts`）

## 2. headroom.py の計算（dev-workflow-headroom）

- [x] 2.1 `test_headroom.py` を作り、flatmate の `test_account_allocation.py` の `Surplus`・`TicketSurplus` と同じ入力（使用率・週次リセット・リセット権・天井・ペース）を、Claude は一時ディレクトリの `accounts.json`・`.usage-snapshot`（`reset_grants`）で、Codex は一時の `CODEX_HOME` と `codex-usage/<hash>.json` で与えるテストを書き、`surplus_pct` の一致・Claude の `capacity_pct` 100/200/300/100 と `rocket` null/1/2/null・Codex の `ticket_expiry` の期限を確かめる（落ちることを確かめる）。触る範囲: plugins/dev-workflow/tests/test_headroom.py（新規）
- [x] 2.2 `headroom.py` に設定の解決（`HEADROOM_7D_CAP_PCT`・`HEADROOM_NORMAL_RATE_PCT_PER_DAY`、不正値は例外）と `segment_surplus`・`counted_tickets` を移し、Claude の行（`usage_view.build_view` と `read_slots`、`reset_grants` の読み方は flatmate の `_saved_reset_grants`・`_claude_credits` に合わせる）を数える。触る範囲: plugins/dev-workflow/scripts/headroom.py（新規）、plugins/dev-workflow/scripts/usage_view.py:56-95（`read_slots`。読むだけ）、plugins/dev-workflow/scripts/usage_view.py:246-263（`build_view`。読むだけ）
- [x] 2.3 Codex の行を足す: `codex-develop.py` を `importlib` で遅延読み込みし、`default_automatic_account_home`・`_cache_path`・`_auth_identity` で `current` のキャッシュを読み、`usage_margin` と同じ規則で週次窓を読む。`codex.enabled: false` は `off`。触る範囲: plugins/dev-workflow/scripts/headroom.py（新規）、plugins/dev-workflow/scripts/codex-develop.py:47-74（`usage_margin`。読むだけ）、plugins/dev-workflow/scripts/codex-develop.py:215-218（`_cache_path`。読むだけ）、plugins/dev-workflow/scripts/codex-develop.py:369-374（`default_automatic_account_home`。読むだけ）
- [x] 2.4 項目（`elapsed_pct`・`left_pct`・`forecast`・`margin`・`tickets`・`status` の 4 区分）と `best`・`best_by_provider`（5 時間 90% 以上を除く・同点は Claude 先・宣言順）を実装し、`test_headroom.py` に status（古い値は ok・未来の取得は stale・オフ）・best・天井を変えると `surplus_pct` と `best` が変わる・`compute` の引数が `now` だけ・`--cap` を拒否する、のテストを足す。触る範囲: plugins/dev-workflow/scripts/headroom.py（新規）、plugins/dev-workflow/tests/test_headroom.py（新規）

## 3. 書き出しと書く時機

- [x] 3.1 `headroom.py` に CLI（`write [--refresh-codex] [--now EPOCH]`・`--json [--now EPOCH]`、不正な設定と未知の引数は終了コード 2 で何も書かない）と、`${CLAUDE_CONFIG_DIR:-~/.claude}/.headroom.json` への一時ファイル＋rename の書き込みを足す。`--refresh-codex` は Codex がオンで既定の home があるときだけ `read_codex_usages` を呼ぶ。`test_headroom.py` に schema 1 のキーの検査と書き込みのテストを足す。触る範囲: plugins/dev-workflow/scripts/headroom.py（新規）、plugins/dev-workflow/tests/test_headroom.py（新規）
- [x] 3.2 `usage-probe-headroom.bats` を作り、テスト用の応答ファイルで probe を走らせると `.headroom.json` が schema 1 で書かれること、`HEADROOM_7D_CAP_PCT` が不正でも probe が 0 で終わり snapshot だけが書かれること、snapshot を書かない実行（全スロット失敗で、既存 snapshot に `reset_grants` が無い。`reset_grants` があると snapshot が書き直されて headroom も呼ばれる）では `.headroom.json` を書かないことを確かめる（Codex は `CODEX_HOME` を存在しないディレクトリにして取りに行かせない）。触る範囲: plugins/dev-workflow/tests/usage-probe-headroom.bats（新規）、plugins/dev-workflow/tests/usage-probe.bats（書き方の参考。読むだけ）
- [x] 3.3 `usage-probe.sh` の snapshot の置き換えに成功した直後に `python3 -I "<scripts のディレクトリ>/headroom.py" write --refresh-codex` を出力を捨てて呼び、終了コードを伝えないようにする。冒頭の契約のコメントに書く時機を 1 行足す。触る範囲: plugins/dev-workflow/scripts/usage-probe.sh:1-30（契約のコメント）、plugins/dev-workflow/scripts/usage-probe.sh:627-637（原子的書き込み）。#1256 が先にマージされていたら、その変更に合わせて位置を取り直す

## 4. 仕上げ

- [ ] 4.1 `plugins/dev-workflow/changes/1300.md` に変更の記録を書く（`.headroom.json` の schema 1・`HEADROOM_*`・Codex の cache の version 2・読む側の切り替えは #1301・#1302・flatmate#1772 で行うこと）。触る範囲: plugins/dev-workflow/changes/1300.md（新規）
- [ ] 4.2 `python3 -m unittest`（`test_headroom.py`・`test_codex_develop.py`）と bats（`usage-probe*.bats`・`account-selector.bats`）、`openspec validate add-headroom-calculation --type change --strict` を通す。触る範囲: plugins/dev-workflow/tests/（実行のみ）
