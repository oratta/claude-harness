## 1. 実効値の計算（dev-workflow、テスト先行）

- [ ] 1.1 `plugins/dev-workflow/tests/test_usage_view.py` を新規に作り、`usage-session-records` の「記録と snapshot から実効値を求める」の全シナリオ（B の記録が A として読まれない・リセット時刻を過ぎたら 0% と週次の 7 日繰り上げ／5 時間枠の `null`・リセット前の古い値は下限・同じ窓は大きい方・新しい窓を優先・両方無ければ欠測・使用率が 0..100 の外なら無い扱い・全体の週次のリセット時刻が 1 時間を超えてずれたら記録側（記録がリセット済みなら規則どおり））と、守備範囲で通すと決めた入力（未来の `observed_at`・ファイル内 `key` とファイル名の不一致・7 日より先のリセット時刻）がそのまま通ることと、Fable が snapshot だけから求まること、`--json` の出力形（`now` / `active` / `accounts`）をテストにする（Red）
- [ ] 1.2 `plugins/dev-workflow/scripts/usage_view.py` を作る。レジストリ解決は `select-account.sh` と同じ規則、鍵の導出は Keychain サービス名と同じ導出、active は `usage-account-registry` の判定規則、記録ディレクトリは `USAGE_SESSIONS_DIR` → `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.usage-sessions`、snapshot は `USAGE_SNAPSHOT`、現在時刻は呼び出し側から渡せるようにする（Green）
- [ ] 1.3 `scripts/test.sh` が `test_usage_view.py` を拾うことを確認する（拾わなければ足す）

## 2. statusline の書き手と非 active 行

- [ ] 2.1 `plugins/statusline/tests/` に、`usage-session-records` の「ステータスラインが起動アカウント別の記録を書く」の全シナリオ（default に書く・B は B の鍵だけ・未登録でも自分の鍵・rate_limits 無しは書かない・書けなくても出力不変）と、`.rate-limit-snapshot` の既存挙動が変わらないことのテストを足す（Red）
- [ ] 2.2 `plugins/statusline/scripts/statusline.sh` に記録の書き込みを足す。`CLAUDE_SECURESTORAGE_CONFIG_DIR` が空なら python3 を起動せず `default`、非空のときだけ python3 で鍵を導出する。一時ファイル＋`mv` で書く（Green）
- [ ] 2.3 `statusline-multi-account.bats` に「非 active スロットはセッション記録の新しい値で描く」「記録が無ければ従来どおり snapshot と経過時間」「リセット時刻が過去の値は読み替えずに描き、分母と残り時間を出さない」「リセット時刻が 1 時間を超えて違えば記録側で描く」のテストを足し（Red）、非 active 行の値の選び方を実装する（Green）。1 スロット構成の出力が変わらないことを既存テストで確かめる
- [ ] 2.4 `plugins/statusline/README.md` の `.rate-limit-snapshot` の説明（「dev-workflow のセッション tripwire がそれを読んで」）を実態に直し、`.usage-sessions/` の記録を説明する

## 3. dev-workflow の読み手

- [ ] 3.1 `plugins/dev-workflow/tests/account-selector.bats` の 300 秒・`stale` 前提のテストを実効値の規則に書き換え、「セッション記録だけで選ぶ」「古いがリセット前の値で選ぶ」「リセットを過ぎた値は 0%」「429 が続いても記録で選ぶ（理由行に `missing` が無い）」「B の記録が A として読まれない」を足す（Red）
- [ ] 3.2 `plugins/dev-workflow/scripts/select-account.sh` を `usage_view` の実効値で判定するよう直す（Green）。明示選択（引数 1 個）の挙動は変えない
- [ ] 3.3 `plugins/dev-workflow/tests/tripwire-hook.bats` に「セッション記録から共有枠 `depleted`」「古い snapshot の Fable はリセット時刻で読む」「snapshot も記録も無ければ conserve」と、agent-model-guard の fork 判定が記録を使うテストを足す（Red）
- [ ] 3.4 `plugins/dev-workflow/scripts/session-tripwires.sh` と `plugins/dev-workflow/scripts/agent-model-guard.sh` を active スロットの実効値で導出するよう直す（Green）。導出の式と文言は変えない
- [ ] 3.5 `plugins/dev-workflow/tests/test_codex_develop.py` の Claude 側 300 秒前提のテストを書き換え、「429 が続いてもセッション記録で評価する（証跡の `fetched_at` は記録の `observed_at`）」「Claude の古い値はリセット前なら使う」を足す。Codex 側の 300/301 秒境界のテストは残す（Red）
- [ ] 3.6 `plugins/dev-workflow/scripts/codex-develop.py` の `claude_usage_evidence` を `usage_view` の実効値から margin を求めるよう直す。Codex 側の `usage_margin(..., codex=True)` は変えない（Green）

## 4. usage-probe を補助に下げる

- [ ] 4.1 `plugins/dev-workflow/tests/usage-probe.bats` / `usage-probe-multi-account.bats` の「5 分キャッシュ」テストを外し、実行条件のシナリオ（記録と snapshot の両方が新しいスロットはフェッチしない・記録は新しいが snapshot の `fetched_at` が古い（または無い）スロットはフェッチする・間隔内は叩かない・全スロット失敗の直後に叩き直さない・429 の倍々の待ち・200 で回数が戻る・ロックが取れなければ何もしない・古いロックは取り直す）をテストにする。HTTP ステータスはテスト用の応答で 429 を返せるようにする（Red）
- [ ] 4.2 `plugins/dev-workflow/scripts/usage-probe.sh` に実行条件（`USAGE_PROBE_STALE` / `USAGE_PROBE_INTERVAL` / `USAGE_PROBE_STATE` / `USAGE_PROBE_LOCK`）と試行状態の記録・429 の待ち・ロックを実装し、mtime の TTL を外す。snapshot の形とスロット単位 fail-open は変えない（Green）
- [ ] 4.3 既存の probe テスト（snapshot の形・fail-open・エラーレスポンス・User-Agent）が全件通ることを確かめる。テストが試行状態・ロック・記録ディレクトリを一時ディレクトリに向けていることを確かめる（実環境の `~/.claude` を触らない）

## 5. 文書・版・全体確認

- [ ] 5.1 `plugins/dev-workflow/skills/develop/references/decision-criteria.md` の「`FABLE_BUDGET_MODE` の自動導出（usage snapshot 契約）」と、`usage-probe.sh` の冒頭コメントの契約の説明を、セッション記録が主・probe が補助・実効値の規則に合わせて直す。`plugins/dev-workflow/.claude-plugin/plugin.json` の description の usage-probe の説明（5 分キャッシュの記述があれば）も直す。あわせて `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`（126 行目「usage snapshot…が新鮮で」）・`plugins/dev-workflow/README.md`・`plugins/dev-workflow/templates/escalation-tripwires.md`・`plugins/statusline/commands/setup.md` を `usage-snapshot` / `usage-probe` / `300` / `5 分` / `TTL` で grep し、300 秒・5 分キャッシュ・TTL を前提にした記述を新しい実行条件と実効値の規則に合わせて直す
- [ ] 5.2 `plugins/dev-workflow/.claude-plugin/plugin.json` と `plugins/statusline/.claude-plugin/plugin.json` の version を上げ、両プラグインの CHANGELOG があれば追記する
- [ ] 5.3 `scripts/test.sh` を全件実行し、exit code と失敗件数を記録する（`statusline-multi-account.bats` の単発の失敗は単独再実行で判定する）。`tests/injection-budget.bats` が description の変更で落ちないことを確かめる
- [ ] 5.4 `openspec validate usage-from-session-records --strict` が通ることを確かめる
