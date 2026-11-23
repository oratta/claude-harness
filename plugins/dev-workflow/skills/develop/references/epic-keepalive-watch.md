# 停止中の子への声かけ（親専用）

予約文・受信契約・child-log は `references/epic-keepalive.md`、固定文・返事の型はプラグイン直下 `references/child-cache-keepalive.json` を読む。

通常の `wait --watch-stopped` は、止まった発言の uuid（`stop_uuid`）か主の返事待ちの停止記録があり未回答、stop=stopped-seen、TTL 1h の子だけへ送る。最後の成功CLIリクエスト（cache-hit含む）から 3000 秒以上 3600 秒未満、止まった時刻（`stop_at`。空なら記録の作成時刻）から `EPIC_DISPATCH_OWNER_WAIT_SEC` 秒（既定 43200 秒。wait上限と同じ）未満。TTLは最後の書き込みから読み、リクエスト時刻と分ける。会話量による再起動対象・計測不能・複数セッション・前の声かけ未回答・実際の回答ありは除外。

既存の一意な前景入力待ち・空欄だけへ送り、起動し直さず、入力を消去しない。声かけや異常な返事で停止印・停止コメント・期限基点を延ばさない。3600秒以上のスリープ復帰・期限後は送らず、実際の返事は `reply-after-idle.md`「そのまま送るか、起動し直すか（子）」へ。

TTL 5m/unknownには送らない。overage等の5mへの切替を観測するまでは検知できず、直後の書き直し費用を防げない場合がある。五分ごとには送らない。

失敗はstderrに残し次の通常ポーリングへ。子の発言を判定せず、声かけの返事で作業を進めない。一回確認（`--interval 0 --timeout 0`）と片付け待ちだけの wait では送らない。親timeout後の同じwaitの一回の掛け直しは `references/epic-loop.md` 手順５に従う。

### マージ後

背景待機の `skipped busy` は正しい非送信。別の会話15万トークン未満・前景が入力待ち・空欄で通常の声かけ条件を満たす子を選ぶ。候補が無ければ実機確認は未完了。

実機send・返事・cacheの証拠は #1728 / #1732 へ。fixture成功やsend exit 0で代替しない。記録・観測・生ログ保存は `plugins/dev-workflow/changes/1752.md` を確認する。非bypassは実画面未確認・未対応（10件すべてbypass）。認識範囲を広げない。
