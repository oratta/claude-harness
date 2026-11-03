## Context

余りの数え方は今、読む側ごとに別にある。

| 読む側 | 今の数え方 |
|---|---|
| `select-account.sh`（`cld`） | margin = 週の経過率 − 使用率、最大を選ぶ |
| `codex-develop.py` の構成選択 | Claude・Codex それぞれの margin ≥ 0 |
| ステータスライン | 使用率と経過率を重ねたバー。リセット権は別の欄に残数と期限だけ |
| flatmate のバーン・配分（`account_allocation.py`） | 天井までの残りを通常のペースで期限まで使った残り（surplus）。リセット権込み |

設計の正本 genetta-inc/flatmate#1711 の設計のコメントで、計算を dev-workflow の `headroom.py` 1 か所に置き、結果を `.headroom.json` にも書くと決めた。数え方の移植元は flatmate の `scripts/account_allocation.py`（`evaluate_accounts`・`segment_surplus`・`counted_tickets`）、Claude のリセット権の読み方は flatmate の `scripts/dashboard/account_quota.py`（`_saved_reset_grants`・`_claude_credits`）、Codex のリセット権の読み方は flatmate の `scripts/reset_tickets.py`（`normalize_reset_credits`）。

入力の今の置き場:

- Claude の使用率: `usage_view.build_view`（セッション記録と `.usage-snapshot` から実効値を出す。取得の古さは見ない。週次リセットを過ぎた値は 0% として読み、リセットを週単位で先へ送る）。スロットのオン・オフは `usage_view.read_slots`
- Claude のリセット権: `.usage-snapshot` の `accounts.<id>.reset_grants`（`resets_left`・`ends_at`（ISO 8601 か null）・`paused` を API の値のまま写した配列）
- Codex の使用率: `codex-develop.py` の `read_codex_usages` が account ごとに `codex-usage/<hash>.json`（version 1、`identity`・`fetched_at`・`windows`）に書くキャッシュ。account の対応は自動選択の既定（`default_automatic_account_home`。`CODEX_HOME` か `~/.codex` を `current` とする）
- Codex のリセット権: まだどこにも保存していない（`account/rateLimits/read` の応答の `rateLimitResetCredits` に入っている）

## Goals / Non-Goals

**Goals:**

- 余りの計算を `headroom.py` の 1 か所にまとめ、`compute(now)` と `.headroom.json`（schema 1）の 2 つの読み方を用意する
- flatmate の `evaluate_accounts` と同じ入力から同じ `surplus_pct` を出す
- リセット権を使える量と期限に入れる（Claude は量、Codex は期限）
- `.headroom.json` の書式をこの change で確定する（oratta/claude-harness#1302 が待つ）

**Non-Goals:**

- 読む側の切り替え（`select-account.sh`・`codex-develop.py` の構成選択は #1301、ステータスラインは #1302、flatmate は genetta-inc/flatmate#1772・#1773）。この change では `codex-develop.py` の `usage_margin` と `claude_usage_evidence` を残す
- 複数の Codex account（`--account-home` / `--account-home-file` で渡す対応表）。headroom が見る Codex は自動選択の既定の `current` だけにする（下の決定 6）
- flatmate の候補判定（`ACCOUNT_ALLOC_MIN_SURPLUS_PCT` 未満を外す等）と、役割の配分。headroom は数と `best` だけを出す

## Decisions

### 1. 置き場と呼び方: `headroom.py` の `compute(now)` と `write` サブコマンド

`compute(now)` は辞書を返す純粋に近い関数（入力ファイルと環境変数を読むが、書かない・Codex の取得をしない）。`headroom.py write [--refresh-codex] [--now EPOCH]` は、`--refresh-codex` のときだけ先に Codex の使用量を取り直し（`read_codex_usages`）、`compute` の結果を `${CLAUDE_CONFIG_DIR:-~/.claude}/.headroom.json` に一時ファイル＋rename で書く。`headroom.py --json [--now EPOCH]` は書かずに標準出力に 1 行で出す（確認とテスト用）。

`compute` の引数は `now` だけにする。天井やペースを呼び手から渡す引数・CLI オプションは作らない（決定 4）。

- 代わりの案: 計算結果を `.usage-snapshot` に書き足す → snapshot は schema 2 の層間契約で読み手が多く、Codex の値を Claude の snapshot に混ぜることになるので採らない

### 2. `codex-develop.py` の読み込みは遅延させる

headroom は Codex のキャッシュの場所（`_cache_path`）と取り直し（`read_codex_usages`）を `codex-develop.py` から借りる。#1301 で `codex-develop.py` が headroom を読み込む予定なので、headroom はモジュールの読み込み時に `codex-develop.py` を読まず、Codex の行を数えるときに `importlib` でファイルから読み込む（循環の読み込みを作らない）。Codex の週次窓の読み方（`minutes == 10080` の窓、リセットを過ぎたら 0% でリセットを週単位で先へ送る、取得の古さでは外さない）は `usage_margin` と同じ規則を headroom 側に置き（未来の取得時刻の扱いだけは決定 5 の 60 秒の規則にする）、#1301 で `usage_margin` を消して headroom に寄せる。

- 代わりの案: Codex の取得を新しいモジュール `codex_usage.py` に切り出す → `test_codex_develop.py` が `m.read_codex_usages` などを差し替えている箇所が多く、この change の範囲が広がるので採らない

### 3. 数え方（flatmate の `evaluate_accounts` を移す）

アカウントごとに、週次の使用率 `used`・週次リセット `reset_at`・残り時間 `hours_left = (reset_at − now) / 3600` から:

- `to_cap = (100 − used) − (100 − cap7)`、`rate`（%/時）= 上書きがあれば `HEADROOM_NORMAL_RATE_PCT_PER_DAY / 24`、無ければ `used / max(168 − hours_left, 24)`
- 数えるリセット権 = 失効が `now` より後かつ `reset_at` より前のもの（`counted_tickets`。失効ごとに枚数をまとめて昇順）
- Claude: 最初に切れるリセット権の失効（無ければ `reset_at`）までの区間の余り `max(0, to_cap − rate × 区間の時間)` に、数えるリセット権 1 枚ごとに `cap7` を足したものを `surplus_pct` にする
- Codex: 期限 = `min(reset_at, 最初に切れるリセット権の失効)`。`surplus_pct = max(0, to_cap − rate × (期限 − now) / 3600)`。リセット権の枚数では足さない
- リセット権が分からない（Claude は `reset_grants` の欄が無い・形が読めない、Codex はキャッシュに `resets` が無い）ときは、リセット権 0 枚と同じ数え方になる（`tickets` は null）

出す項目の定義:

| 項目 | 定義 |
|---|---|
| `used_pct` | 週次の実効の使用率 |
| `elapsed_pct` | 週次の経過率 `100 × (1 − (reset_at − now) / 604800)`（0〜100 に丸める）。Codex で期限がリセット権の失効のときは、週の始まり `reset_at − 604800` から期限までに対する経過率 |
| `weekly_reset_at` | 週次リセットの epoch 秒 |
| `rocket` | 数えるリセット権の `{count, earliest_expiry}`。無ければ null |
| `tickets` | 持っているリセット権（停止中・残り 0・失効済みを除く）の `{count, earliest_expiry}`。分からなければ null |
| `capacity_pct` | Claude は `100 + 100 × rocket.count`、Codex は 100 |
| `left_pct` | Claude は `(100 − used) + 100 × rocket.count`、Codex は `100 − used` |
| `deadline_at` / `deadline_reason` | Claude は `reset_at` / `weekly_reset`。Codex はリセット権の失効が早ければその時刻 / `ticket_expiry` |
| `forecast` | 期限までに `rate` で使った見込み `left_pct − rate × 残り時間` が 0 以上なら `{kind: "spare", pct}`、負なら `{kind: "exhaust", at: now + left_pct / rate × 3600}`（epoch 秒） |
| `surplus_pct` | 上の数え方。天井の分を引くので `forecast` の spare より小さい |
| `margin` | `週次の経過率 − used_pct`（期限ではなく週次で測る。今の select-account と codex-develop の値と同じ定義。丸めない） |

`capacity_pct` と `left_pct` は画面の目盛り（1 枚 100%）、`surplus_pct` は配分の判断（1 枚 `cap7`）で、リセット権 1 枚の重みが違う。flatmate の数え方と画面のサンプル（genetta-inc/flatmate#1711 の 2026-10-21 のオーナーの決定）の両方に合わせるため、この違いを残す。

数は丸めずに出す（`margin` の同点判定と flatmate との一致の確認に丸めが入らないようにする）。

### 4. 設定は headroom の中で 1 か所から解決する

`HEADROOM_7D_CAP_PCT`（既定 90、0〜100）と `HEADROOM_NORMAL_RATE_PCT_PER_DAY`（既定なし、0〜100）を `compute` の中で読む。不正な値（数でない・範囲外）は既定値に倒さず例外にし、CLI は終了コード 2 で何も書かない（flatmate の `load_config` と同じ）。解決した値は出力の `settings` に載せる。5 時間の使用率で `best` から外す線（90%）は環境変数にせず定数にする（本文の規則のまま）。

- 理由: 呼び手ごとに天井が違うと、同じ snapshot から選ばれる `best` がずれる（設計の正本の決めごと）

### 5. `status` の区分と `best`

| status | 意味 | 数を出すか |
|---|---|---|
| `ok` | 週次の実効値（使用率とリセット時刻）が読める。取得の古さと、リセットを過ぎて 0% に読み替えたことは問わない | 出す |
| `stale` | 週次の値はあるが、取得時刻が今より 60 秒を超えて未来（時計のずれ） | `observed_at`・`five_hour_pct`・`used_pct`・`elapsed_pct`・`weekly_reset_at` は出し、余りの項目（`rocket` から `margin` まで）は null |
| `missing` | 週次の値が読めない（記録も snapshot も無い・形が壊れている・Codex のキャッシュが無い・認証の主体が食い違う） | 出さない（null） |
| `off` | レジストリでオフ（Claude はスロットの `enabled: false`、Codex は `codex.enabled: false`） | 出さない（null） |

`stale` の線を 60 秒にするのは、取得した機械と数える機械の時計の小さなずれを許すため（60 秒以内の未来は `ok` として数える）。`codex-develop.py` の `usage_margin`（`codex-develop.py:57-58`、`fetched_at` が 1 秒でも未来なら None）の厳密な判定は headroom に写さず、#1301 で `usage_margin` を headroom に寄せるときにこの規則に揃える。

古い値を `ok` に入れるのは、今の実効値の規則（usage-session-records と codex-role-profiles の「前回値の古さでは除外しない」）に合わせるため。非 active の Claude スロットはトークン切れで取り直せないのが普通で、古さで外すと `cld` がそのスロットへ切り替えなくなる（#1301 で `best` を使うときに今の選び方から外れる）。

`best` は、`status` が `ok` で `surplus_pct` が数で、5 時間の使用率が 90% 未満（分からないときは候補に残す）のアカウントのうち、`surplus_pct` が最大のもの。同点は Claude を先、同じ provider の中は宣言順（Claude はレジストリの順）で先のもの。`{provider, account}` か null。`cld` は Claude しか選べないので、provider ごとの最大も `best_by_provider: {claude, codex}` に出す（#1301 が数え直さずに読めるようにする）。

### 6. Codex の account の範囲

headroom が見る Codex は、`codex-develop.py` の自動選択の既定（`default_automatic_account_home`）が返す `current` だけ。既定の Codex home が無ければ Codex の行は出さない。`codex.enabled: false` なら `current` を `off` で出す（取得もしない）。

- 理由: 複数の Codex account の対応表は `codex-develop.py` の起動ごとの引数で、常駐の置き場が無い。置き場を決めるのはこの change の範囲を超える
- 代わりの案: 対応表のファイルを環境変数で渡す → 読む側（flatmate）が複数 Codex account を使う必要が出たら、別 issue で足す

### 7. Codex のリセット権をキャッシュに足す

`probe_codex_account` が `account/rateLimits/read` の応答から `rateLimitResetCredits` を読み、`{availableCount, credits: [{id, status, expiresAt, …}]}` の形が合えば `resets: {"available_count": <int>, "expires_at": [<status が available の各 credit の expiresAt。整数でないもの（null・文字列など）は null として持つ>]}` をキャッシュに足す。形が合わない・欄が無いときは `resets` を書かない（分からない）。キャッシュの `version` を 2 に上げる。生の応答・credit の id は保存しない。取得に失敗したときは今と同じく前回値（`resets` を含む）を保つ。`usage_margin` は `version` を見ないので、version 1 のキャッシュも 2 のキャッシュも今までどおり読める。

### 8. 書く時機: `usage-probe.sh` の末尾

`usage-probe.sh` が `.usage-snapshot` の rename に成功した直後に、同じディレクトリの `headroom.py write --refresh-codex` を `python3 -I` で呼ぶ。標準出力・標準エラーは捨て、終了コードを probe の終了コードに伝えない（probe は今までどおり 0 で終わる）。呼ぶかどうかは snapshot を書いたかどうかだけで決める。テスト経路（`USAGE_PROBE_RESPONSE_FILE` か `USAGE_PROBE_RESPONSE_FILE_<ID>` を設定した実行）では、それに加えて `USAGE_PROBE_HEADROOM` が空でないときだけ呼ぶ（それを設定しないテストが本物の `~/.claude/.headroom.json` と `~/.codex` の cache に触れないため）。全スロットが失敗しても、試みて失敗したスロットの `reset_grants` を除いて snapshot を書き直したとき（`usage-probe.sh:580-595`、dev-workflow-escalation-tripwires の「全スロットの取得が失敗したときの例外」）は呼ぶ。snapshot を書かなかった実行（全スロットの失敗で除く欄も無かったとき・取得の間隔内・ロックを取れない）では呼ばない。`--refresh-codex` は Codex がオフのときと既定の Codex home が無いときは何もしない。

## `.headroom.json`（schema 1）

```json
{
  "schema": 1,
  "computed_at": 1800000000,
  "settings": {"cap_7d_pct": 90, "normal_rate_pct_per_day": null},
  "best": {"provider": "claude", "account": "a"},
  "best_by_provider": {"claude": {"provider": "claude", "account": "a"}, "codex": null},
  "accounts": [
    {
      "provider": "claude", "account": "a", "label": "A", "status": "ok",
      "observed_at": 1799990000, "five_hour_pct": 10,
      "used_pct": 40, "elapsed_pct": 85.7, "weekly_reset_at": 1800086400,
      "rocket": {"count": 1, "earliest_expiry": 1800043200},
      "tickets": {"count": 3, "earliest_expiry": 1800043200},
      "capacity_pct": 200, "left_pct": 160,
      "deadline_at": 1800086400, "deadline_reason": "weekly_reset",
      "forecast": {"kind": "spare", "pct": 153.3},
      "surplus_pct": 136.7, "margin": 45.7
    }
  ]
}
```

`accounts` の並びは Claude（レジストリの順）→ Codex。キー名と値の型はこの版で固定し、キーを消す・意味を変えるときは `schema` を上げる（キーを足すだけなら上げない）。

## Risks / Trade-offs

- [`.headroom.json` は probe が snapshot を書いたときだけ新しくなる（取得の間隔の既定は 3 時間）。ステータスラインのセッション記録で Claude の使用率が先に進んでも、ファイルの数は次の probe まで古い] → `computed_at` を出して読む側が古さを判断できるようにする。新しい数が要る読む側（#1301 の `cld`・develop）は `compute(now)` を呼ぶ
- [Claude の `reset_grants` は取得を試みなかったスロットでは前回の値が残るので、その間に使ったリセット権を数え続けうる] → 取得を試みて失敗したスロットは probe が欄を消す（既存の契約）。失効済みのものは時刻で外れる
- [`usage-probe.sh` の実行が Codex の取得ぶん長くなる。app-server への要求 3 つにそれぞれ 15 秒の待ちがあり、終了に 2 秒かかるので、Codex の応答が遅い回は最大 47 秒前後（Claude の取得 1 スロット 10 秒に足して）] → snapshot を書いた後に呼ぶので、snapshot の更新は遅れない。probe はロックを持ったまま待つが、ロックの取り直しの閾値（120 秒）より短い。`codex-develop.py` が probe を待つ上限は 20 秒から 90 秒に上げた（20 秒のままだと、応答が遅い回に probe が途中で止められ、終了時の後始末が走らずロックが 120 秒残る）
- [`usage-probe.sh` は #1256 も触る] → 末尾の書き込みの直後だけを触り、#1256 の取得の判定とは重ならない。先にマージされた方に合わせて rebase する

## Migration Plan

読む側はまだ無いので、置くだけで今の振る舞いは変わらない。Codex のキャッシュは次の取得で version 2 になり、version 1 のまま残っていても読める。戻すときはこの change を revert すればよく、残った `.headroom.json` と version 2 のキャッシュは今のコードから無視・そのまま読まれる。

## Open Questions

なし（status の区分・`best_by_provider`・Codex の範囲は上の決定 5・6 で決めた。記録先 #1300 の本文に無い選択なので、仕様レビューで確かめてもらう）。
