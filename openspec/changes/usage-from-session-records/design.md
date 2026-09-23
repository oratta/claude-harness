## Context

- Claude Code はステータスラインのコマンドに毎回 JSON を渡し、その `rate_limits.five_hour` / `rate_limits.seven_day` に使用率（`used_percentage`）とリセット時刻（`resets_at`、epoch 秒）が入る。これは通常の会話の応答の見出しから作られており、使用量 API を叩かずに得られる。モデル別（Fable）の週次使用率は入っていない。
- 今の `statusline.sh` はこの値を `~/.claude/.rate-limit-snapshot` に書くが、`CLAUDE_SECURESTORAGE_CONFIG_DIR` が非空（既定以外のアカウント）のセッションでは書かない（flatmate#605: B の値を A の値として読んだ事故の対策）。リポジトリ内にこのファイルの読み手は無い（`plugins/statusline/README.md` の「dev-workflow のセッション tripwire がそれを読んで」は古い記述）。外部（flatmate の rate-guard 等）が読んでいる可能性があるので形と条件は変えない。
- 使用量の読み手はすべて `~/.claude/.usage-snapshot`（schema 2、`usage-probe.sh` が書く）を読む:
  - `select-account.sh`: `accounts[slot]` を `0 <= now - fetched_at < 300` のときだけ使う
  - `codex-develop.py` の自動選択: probe を同期実行してから、起動アカウントの `accounts` entry を `age <= 300` のときだけ使う
  - `session-tripwires.sh`: probe を同期実行してから、トップレベル（active スロットのミラー）の `fable_weekly_pct` / `weekly_all_pct` / `weekly_resets_epoch` で `FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` を導出する（鮮度は見ない）
  - `agent-model-guard.sh`: fork の拒否判定でトップレベルの `weekly_all_pct` / `weekly_resets_epoch` から共有枠モードを導出する
  - `statusline.sh`: 非 active スロットの行を `accounts[slot]` から描き、`fetched_at` からの経過時間を併記する
- `usage-probe.sh` は snapshot の mtime が 300 秒以内なら何もしない。全スロットが失敗すると snapshot を書かないので mtime が進まず、呼ばれるたび（SessionStart ごと・develop の工程ごと）に全スロットへ API を叩き直す。これが 429 を返され続ける状態を長引かせていた。
- 実測（2026-09-23）: アカウント A の `.rate-limit-snapshot` の `seven_day_resets_at` と probe の `weekly_resets_epoch` は同じ値（1790373600）だった。probe の `weekly_resets_*` は Fable の週次枠のリセット時刻を優先して使うが、両者は同じ周期で動いている。

## Goals / Non-Goals

**Goals:**
- A と B の両方でセッションが会話していれば、使用量 API を叩かずに両方の新しい値が自動選択に届く。
- B のセッションが書いた値が A の値として読まれない。
- リセット時刻を過ぎた値は 0% として扱い、過ぎていない古い値は下限として使う。
- 使用量 API が 429 を返し続けても、自動選択と枠の残量モードの判定が続く。
- 使用量 API を叩く回数を、記録で埋まらないアカウントについて数時間に 1 回程度に抑える。

**Non-Goals:**
- Fable の週次使用率をセッションから得ること（`rate_limits` に無い）。Fable は引き続き usage-probe の値だけを使う。
- Codex 側の使用量の取り方と 300 秒の鮮度判定（`codex-role-profiles` の Codex 側）は変えない。
- `.usage-snapshot` の schema 2 のキーを変えること（usage-probe の書く形は同じ）。
- 別の PC や claude.ai の Web 画面での使用量を拾うこと（受け入れるリスク。低頻度の probe だけが拾う）。

## Decisions

### 記録はアカウントごとに別ファイルにし、鍵は書き手の起動環境だけから決める

置き場所は `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.usage-sessions/<鍵>.json`（`USAGE_SESSIONS_DIR` で上書き可）。鍵は `CLAUDE_SECURESTORAGE_CONFIG_DIR` が空・未設定なら `default`、それ以外は NFC 正規化した値の UTF-8 の sha256 先頭 8 桁（Keychain サービス名 `Claude Code-credentials-<8桁>` の末尾と同じ導出）とする。形式:

```json
{"schema": 1, "key": "default", "observed_at": 1790170001,
 "five_hour_pct": 3, "five_hour_resets_epoch": 1790176200,
 "weekly_all_pct": 69, "weekly_resets_epoch": 1790373600}
```

書き込みは同じディレクトリに一時ファイルを作ってから `mv` で置き換える（読み手が書きかけを読まない）。`rate_limits.five_hour.used_percentage` が無いときは書かない。書き込みの失敗は無視する（ステータスラインの表示を止めない）。

採らなかった案:
- **`.usage-snapshot` の `accounts` に書き込む**: 複数のステータスラインと probe が同じファイルを読み書きし、後から書いた側が他のスロットの値を古い内容で上書きする競合が起きる。ロックを取るとステータスラインの描画が待たされる。
- **accounts.json のスロット id を鍵にする**: 書き手が accounts.json を読んで active スロットを判定する必要があり、判定規則の優先順位 2・3（snapshot の `active`・先頭スロット）に落ちると、別アカウントの値を別スロットとして書く flatmate#605 と同じ誤りが起きうる。起動環境だけから決まる鍵なら、書き手が自分以外のアカウントの記録を書く経路が無い。読み手はスロットの `securestorage` から同じ導出で鍵を求めて突き合わせる（登録の変更にも追従する）。

鍵の導出に python3 を使うのは `CLAUDE_SECURESTORAGE_CONFIG_DIR` が非空のときだけにする。既定アカウントの 1 スロット構成ではステータスラインに python3 の起動を増やさない。

### 「いま使ってよい値」（実効値）の規則

窓（5 時間枠・週次・Fable 週次）ごとに、情報源の値 `(pct, resets_epoch, observed_at)` を次のように読む。`now` は読み手の現在時刻。

1. `pct` または `resets_epoch` が有限の数でなければ、または `pct` が 0..100 の外なら、その情報源のその窓は無い扱い（codex-role-profiles の Claude 側の欠測判定と揃える）。ただし 5 時間枠は `pct` が有効ならリセット時刻が `null` でもリセット時刻不明の値として使う（直近 5 時間使っていないアカウントは API が 5 時間枠のリセット時刻を `null` で返しうるので、無い扱いにすると空いているアカウントほど候補から外れる）。
2. `now >= resets_epoch` なら、`pct` を 0 とみなす。週次・Fable 週次は `resets_epoch` を 7 日単位で `now` より後になるまで進める（週次枠は固定周期で回るため）。5 時間枠は次のリセット時刻を不明（`null`）とする（5 時間枠は次に使い始めた時点から数えるため、予測できない）。
3. `now < resets_epoch` なら `pct` をそのまま下限として使う（使用率は使えば増え、減るのはリセットのときだけ）。
4. 情報源が 2 つ（セッション記録と probe snapshot の `accounts[slot]`）あるときは、上の読み替えのあとで、両者のリセット時刻の差が 1 時間以内なら同じ窓とみなして `pct` の大きい方を取り、リセット時刻は `observed_at` の新しい方の値を使う。差が 1 時間を超えるなら、リセット時刻が後の方（新しい窓）を取る。ただし全体の週次は、差が 1 時間を超えたらセッション記録側を取る（probe の `weekly_resets_*` は Fable 枠のリセット時刻を優先するので、周期がずれると全体の週次に Fable のリセット時刻が付き、古い probe の値が「後の窓」として選ばれうるため）。記録側がリセット済み（記録のリセット時刻が過去）なら例外を使わず前の規則どおり。statusline も同じ。片方にしか無ければそれを取る。5 時間枠でリセット時刻が `null` になった側は「0% の新しい窓」として扱い、もう一方がリセット前の値ならそちらを取る。
5. 実効値の `observed_at` は、採った値の情報源の `observed_at`（probe は `fetched_at`）とする。

Fable 週次はセッション記録に無いので probe の `fable_weekly_pct` と `weekly_resets_epoch` だけから 1〜3 で求める。

採らなかった案:
- **新しい方の情報源だけを使う**: 同じ窓の中では値は減らないので、大きい方を取るのが「少なくともこれだけ使った」の下限として正しい。新しい方だけを使うと、probe が後から取った値がセッション記録より小さく見えるずれ（取得タイミングの差）で余裕を多く見積もる。
- **古い値に上限の鮮度（例: 6 時間）を残す**: 下限として正しい値を捨てると、会話していないアカウントが「データなし」になり、自動選択が既定アカウントへ縮退する今の問題が残る。

### 実効値の計算は dev-workflow の 1 か所に置く

`plugins/dev-workflow/scripts/usage_view.py` に、レジストリの解決（既存と同じ規則）・セッション記録と snapshot の読み取り・実効値の計算を置く。Python から import でき（`codex-develop.py`）、`python3 usage_view.py --json` で全スロットの実効値を 1 行 JSON で出す（bash の読み手が使う）。出力の形:

```json
{"now": 1790170100, "active": "a",
 "accounts": {"a": {"five_hour_pct": 3, "five_hour_resets_epoch": 1790176200,
                    "weekly_all_pct": 69, "weekly_resets_epoch": 1790373600,
                    "fable_weekly_pct": 25, "observed_at": 1790170001,
                    "session_observed_at": 1790170001, "probe_fetched_at": 1790169751}}}
```

値が求まらない項目は `null`。`active` は `usage-account-registry` の active スロットの判定規則（起動環境から導出したサービス名との一致を最優先）で求める。

`select-account.sh`・`session-tripwires.sh`・`agent-model-guard.sh` は、今の inline python の中で `usage_view` を import して使う（スクリプトと同じディレクトリから読む）。statusline は他プラグインのスクリプトに依存しない既存の方針（`statusline.sh` 内のレジストリ解決と同じ）に従い、同じ規則を自分で持つ。規則の正本は `usage-session-records` の spec。

### 読み手ごとの変更

- `select-account.sh`: `fetched_at` の 300 秒判定をやめ、実効値の `five_hour_pct`・`weekly_all_pct`・`weekly_resets_epoch` を使う。どれかが `null` なら `missing`。`stale` は無くなる。5 時間枠 90% 以上の除外と、週次余裕の式は変えない。
- `codex-develop.py`: Claude 側は実効値から margin を求める（`usage_margin` の `fetched_at` の 300 秒判定を Claude 側では使わない）。Codex 側は変えない。`fetched_at` の証跡には実効値の `observed_at` を載せる。
- `session-tripwires.sh`: active スロットの実効値から `FABLE_BUDGET_MODE`・`SHARED_BUDGET_MODE` を導出する。導出の式と優先順位は変えない。Fable が求まらないときは今までどおり `conserve`、全体の週次が求まらないときは `ok`。
- `agent-model-guard.sh`: fork の共有枠判定を active スロットの実効値で行う。

### usage-probe は補助に下げる

- **対象の絞り込み**: スロットごとに、セッション記録が無いか記録の `observed_at` が `USAGE_PROBE_STALE`（既定 10800 秒 = 3 時間）より古いとき、または snapshot の同スロットの `fetched_at` が `USAGE_PROBE_STALE` より古い（無い場合を含む）ときだけ API を叩く。後者は、Fable 週次がセッション記録に入らず probe からしか取れないための条件で、これが無いと会話中のアカウントほど Fable の値が止まり、リセット後は 0% と読まれ続けて残量を大きく見積もる（statusline の Fable バーも 6 時間の鮮度ゲートで消える）。会話中のアカウントでも叩くのは 3 時間に 1 回程度（間隔と 429 の待ちは下のとおり）に収まる。
- **間隔**: スロットごとに前回の試行時刻を `~/.claude/.usage-probe-state`（`USAGE_PROBE_STATE` で上書き可）に記録し、`USAGE_PROBE_INTERVAL`（既定 10800 秒）以上空いていなければ叩かない。試行は結果（200・429・その他の失敗）にかかわらず記録する。snapshot の mtime の TTL は使わない（全スロット失敗で mtime が進まず、呼ばれるたびに叩き直すのが 429 を長引かせていたため）。
- **429**: そのスロットの連続 429 回数を数え、次の試行を `interval × 2^(回数-1)`（上限 86400 秒）後まで待つ。200 が返ったら回数を 0 に戻す。
- **マシン全体で 1 本**: `~/.claude/.usage-probe.lock`（`mkdir` で取る）を取れなければ何もせず exit 0 する。ロックが 120 秒より古ければ前の probe が異常終了したとみなして取り直す。
- 呼び出し元（SessionStart の `session-tripwires.sh`、`codex-develop.py` の自動選択）は変えない。対象が無いときは API を叩かずにすぐ終わる。
- snapshot の形（schema 2、スロット単位の fail-open、`fetched_at` は取得時刻）は変えない。

採らなかった案:
- **probe をやめる**: 別の PC や Web 画面での使用を拾う手段が無くなり、受け入れるリスクが大きくなる。
- **cron / launchd で定期実行する**: 配布物がマシンの常駐設定を持つことになり、install / uninstall の手順が増える。呼び出し元を変えず、実行条件で頻度を抑える方が小さい。

## Risks / Trade-offs

- [この PC で会話していないアカウントは実際より空いて見える] → 受け入れるリスク（issue #417）。probe が 3 時間ごとに拾う。429 が続く間は拾えない。
- [Fable 週次はセッション記録に無い] → Fable の残量モードは probe の値（リセット時刻で読み替えた下限）だけから導出する。probe が一度も取れていなければ `conserve`（今と同じ既定）。429 が続いても、一度取れた値はリセットまで下限として、リセット後は 0% として使われる。会話中のアカウントでも probe の実行条件（snapshot の `fetched_at` が 3 時間より古ければ叩く）で Fable の値は 3 時間程度ごとに更新される。
- [probe の `weekly_resets_*` は Fable 枠のリセット時刻を優先する] → 全体の週次枠と周期がずれた場合は、合わせ方の規則 4 の例外（全体の週次は差が 1 時間を超えたらセッション記録側を取る。記録がリセット済みなら規則どおり）で扱う。実測では同じ値だった。
- [入力の検査は守備範囲に書いた壊れ方だけを拾う] → 未来の取得時刻・ファイル内 `key` とファイル名の不一致・7 日より先のリセット時刻は検査せず通す（入力はこのマシンの statusline と probe だけが書くため）。
- [リセット直後は 0% とみなすが、実際にはリセット直後から使っている] → 下限として正しい（実際の値は 0% 以上）。そのアカウントのセッションが会話すれば次の描画で記録が更新される。
- [ステータスラインの描画ごとにファイルを 1 つ書く] → 今の `.rate-limit-snapshot` と同じ頻度。一時ファイル＋`mv` なので読み手は書きかけを見ない。

## Migration Plan

- 既存の `.usage-snapshot` はそのまま読める（読み手は情報源の 1 つとして扱う）。`.usage-sessions/` が無い環境では、今までどおり snapshot だけから（ただし 300 秒ではなくリセット時刻で）判断する。
- `USAGE_PROBE_TTL` は使われなくなる。設定していても無視される。
- 戻すときは両プラグインの前の版に戻せばよい。`.usage-sessions/` と `.usage-probe-state` は残っても前の版は読まない。
