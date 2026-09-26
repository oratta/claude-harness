# statusline

使用量が一目で分かる Claude Code のステータスライン。

```
.../workspaces/flatmate/clone-origin-main-repo-sync  Opus 5 (1M context)  oratta/clone-origin-main-repo-sync
Context 91%  │  API ¥1,446,038/mo  │  Session ¥1,240
5h       ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂    3%  ~4h 13m
7d All   ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂   25%/29%   Fable ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂    7%/29%  ~4d 22h
```

| 行 | 内容 |
|---|---|
| 1 | カレントディレクトリ / モデル / git ブランチ（未コミット変更は `✱`） |
| 2 | コンテキスト残量 / 直近30日の使用量を API 従量課金に換算した月額ペース / このセッションの API 換算コスト |
| 3 | 5時間ウィンドウのレートリミット消化率 |
| 4 | 7日ウィンドウのレートリミット消化率（全体 + Fable） |

`Session` は、このセッションのメイン会話と、このセッションが立ち上げたサブエージェントを合算した API 換算コスト。Claude Code がステータスラインに渡す `cost.total_cost_usd`（セッション内のすべての API 呼び出しを定価で見積もった値）をそのまま円に換算している。`/clear` で 0 に戻る。30日の数字は ccusage がログから計算したものなので、料金表の違いで両者は多少ずれることがある。為替は30日コストの背景更新が保存したレートを読むだけで、まだ無ければ USD（`Session $1.23`）で出す。

## バーの読み方

普通の使用量バーは「どれだけ使ったか」しか分からない。25% 使っていても、それが週の初日なのか最終日なのかで意味が正反対になる。このバーは**クォータの消化率と、その窓の時間の経過率を同じ1本に重ねる**。

```
▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂
■■■■□□□□□□□□□□□□   ← セルの背景色 = クォータ消化率（バー本体）
▔▔▔▔▔░░░░░░░░░░░   ← セル下端 1/8 の細線 = 日程消化率（今どこまで来たか）
        25%/29%    ← 分子 = クォータ消化率、分母 = 日程消化率（＝細線の先端）
```

- **細線がバーより先に伸びている** → 日程が先行している。まだ余裕がある
- **バーが細線を追い越している** → リセット前に枯れるペース

色もこの比で決まるので、見た目と意味が食い違わない:

| バーの色 | 条件 | 意味 |
|---|---|---|
| 緑 | 消化率 ÷ 日程消化率 < 85% | 日程どおりかそれより余裕がある |
| 黄 | 85% 以上 | 日程に対して少し先行して使っている |
| 赤 | 100% 以上 | リセットまで持たないペース |

日程が取れない 5h 窓（セッション頭で一気に使うのが普通なので、経過率と比べても意味がない）だけは、残量の絶対値（50% / 80%）で色を決め、分母も出さない。

## 導入

```
/statusline:setup
```

`scripts/statusline.sh` と `scripts/statusline-codex.py` を `~/.claude/` にコピーし、`~/.claude/settings.json` の `statusLine` をそこに向ける。既存の `statusLine` があれば置き換え前に確認し、`settings.json` はバックアップを取る。

- `/statusline:setup --dry-run` — 何が変わるかだけ表示する
- `/statusline:setup --uninstall` — `settings.json` から `statusLine` を外す

プラグイン本体を直接指さずコピーを配るのは、marketplace dir がプラグイン自動更新で再 clone されるため。そこを settings.json から指すと、更新のたびに色や幅の調整が消える。プラグインを更新したら `/statusline:setup` を再実行する。

### 前提

| | 必須 | 無い場合 |
|---|---|---|
| `jq` | ○ | 動かない |
| Pro / Max プラン | | レートリミットの行（3〜4行目）が出ない。Claude Code が入力 JSON に値を渡さないため |
| `bunx` または `npx` | | 2行目の API 換算コストが出ない |
| `dev-workflow` プラグイン | | `Fable` セグメントと複数アカウント表示が出ない（後述） |

### Fable セグメントについて

Fable の週次消化率は Claude Code がステータスラインに渡してくれないので、`~/.claude/.usage-snapshot` から読む。このファイルを書いているのは同じ marketplace の **`dev-workflow` プラグイン**（`scripts/usage-probe.sh` を SessionStart フックで実行し、OAuth の usage API を叩く）。

`dev-workflow` を入れていない、あるいは snapshot が6時間以上古い場合は Fable セグメントを黙って省く。

逆方向に、このステータスラインは描画のたびに受け取った 5 時間枠と全体の週次を、起動アカウント別の記録 `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.usage-sessions/<アカウント鍵>.json`（`USAGE_SESSIONS_DIR` で上書き可）に書き出す。アカウント鍵は `CLAUDE_SECURESTORAGE_CONFIG_DIR`（下記）が未設定なら `default`、設定されていれば Keychain のサービス名の末尾と同じ 8 桁で、レジストリや snapshot の `active` からは決めない（別アカウントの値を取り違えないため）。`dev-workflow` の残量モードの判定・アカウント選択・複数アカウント表示の非 active 行はこの記録を主な情報源にし、usage API の snapshot は Fable 週次と記録の無いアカウントの補助に使う。書けなかったときは黙って諦め、表示は変えない。

あわせて、5h の枠値と空でない `session_id` がある既定アカウントの描画では、`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.rate-limit-snapshot` に rate snapshot を書く。`CLAUDE_SECURESTORAGE_CONFIG_DIR` が非空のセッションでは書かない。`ts`・`observed_at` は枠値と出所が最後に変わった時刻で、同じ値を再表示しても進まない。`written_at` は書込時刻。JSON には 5h / 7d の使用率・リセット時刻、`obs_sig`、`host`、`storage_binding`、入力の `session_id` を含む。`$HOME/.claude.json` の `oauthAccount.accountUuid` が有効な場合だけ `account_id` も含む。欠けた任意の枠値は `null` とする。書込は同じディレクトリの一時ファイルから原子的に置き換える。

共有先を設定すると `<共有先>/<host>.json` にローカルと同じ JSON を書く。`FLATMATE_RATE_SHARE_DIR` が定義されていればその値を使い、空文字なら共有を無効にする。未定義なら `FLATMATE_RATE_SHARE_CONF`（既定 `$HOME/.claude/flatmate-rate-share`）の先頭の非コメント・非空行を使う。設定ファイルのパスは前後空白を除き、先頭の `~` を HOME に展開する。共有先に書けなくてもローカルの保存と表示は続く。

writer の `CLAUDE_CONFIG_DIR` を非既定にして保存先を変える場合、reader 側の `RATE_GUARD_SNAPSHOT` を同じファイルに合わせる必要がある。共有先の環境変数名と設定ファイル名は flatmate reader と共通。

## 複数アカウントを並べて表示する

`CLAUDE_SECURESTORAGE_CONFIG_DIR` を設定すると、`CLAUDE_CONFIG_DIR`（設定・履歴・プラグイン）を共有したまま Keychain の認証情報だけを別枠にできる。この仕組みで複数の Claude アカウントを使い分けている場合、アカウントごとにレートリミットを 2 行ずつ並べられる。

```
▸ A  5h      ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂   55%          ~4h 12m
▸ A  7d All  ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂   82%/74%   Fable ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂   94%   ~2d 3h
  B  5h      ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂    3%
  B  7d All  ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂    1%/0%    Fable ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂    0%   2h前
```

行頭の `▸` が**いま使っているアカウント**。その行の label は他の行より明るく描く。

**Codex 表示が無効なら、アカウントレジストリを作らないかぎり、Claude の表示も挙動も変わらない。** レジストリが無ければ既定アカウント 1 つとして扱われ、出力は 1 バイトも変わらない（左端のラベル列も出ない）。

### レジストリの作り方

登録先は `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/accounts.json`（`CLAUDE_ACCOUNTS_FILE` で上書き可）。**登録したいアカウントのシェルで** `dev-workflow` の生成スクリプトを実行する:

```bash
# 既定アカウント（CLAUDE_SECURESTORAGE_CONFIG_DIR を設定していないシェル）で
~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/scripts/accounts-init.sh --id a --label A

# もう一方のアカウントのシェルで
~/.claude/plugins/marketplaces/oratta-claude-harness/plugins/dev-workflow/scripts/accounts-init.sh --id b --label B
```

パスを手で書き写さずこのスクリプトを使うこと。`securestorage` には `CLAUDE_SECURESTORAGE_CONFIG_DIR` の**実値をそのまま**書き出す必要がある。末尾スラッシュや `~` 展開が 1 文字でも違うと、Claude Code 本体にとっては別の Keychain 項目になり、そのアカウントの残量が取れなくなる。

できあがる形は次のとおり。手で書いてもよい:

```json
{
  "schema": 1,
  "accounts": [
    { "id": "a", "label": "A", "securestorage": null },
    { "id": "b", "label": "B", "securestorage": "/Users/example/.claude-b" }
  ]
}
```

| フィールド | 規則 |
|---|---|
| `id` | 英数字とハイフン、1〜32 文字。全スロットで一意。snapshot のキーになる |
| `label` | 左端に出す短いラベル。省略すると `id` を使う。表示幅 8 桁（全角 4 文字）を超えると切り詰める。全角でも列は揃う |
| `securestorage` | そのアカウントの `CLAUDE_SECURESTORAGE_CONFIG_DIR` の値。`null` / 空文字は既定アカウント |

トップレベルは必ずオブジェクト（裸の配列は不正）。`id` を欠くスロット・重複した `id`・9 個目以降のスロット・`label` や `securestorage` に制御文字（タブや改行）を含むスロットは黙って捨てる。ファイル全体が壊れていれば既定アカウント 1 つに縮退するだけで、ステータスラインは止まらない。

### 表示の読み方（複数アカウント時）

- **いま使っているアカウント**は行頭に `▸` が付き、label が通常の明るさになる。値は Claude Code から渡るライブ値で描き、Fable セグメントには従来どおり 6 時間の鮮度ゲートが効く
  - 記号と明るさの両方で示すのは、片方が落ちる環境があるため。スクリーンショットやログに貼ると色（明るさ）が失われ、フォントに `▸` が無い端末では記号が豆腐になる。どちらか一方でも残れば、どちらのアカウントの数字を見ているかは分かる
  - 記号を差し替えるなら East Asian Width が Neutral のものにすること（`▹` U+25B9 / `›` U+203A など）。`▶` `●` `◆` `·` はいずれも Ambiguous で、曖昧幅を全角にする設定の端末では `▸` の行だけ 1 桁右にずれ、その差が label 以降のすべての列に伝播する
- **それ以外のアカウント**は行頭が半角スペース 2 つになり、そのアカウントのセッション記録（上記の `.usage-sessions/`）と snapshot の値のうち、同じ窓なら大きい方・窓が違えばリセット時刻が後の方で描き（全体の週次はリセット時刻が 1 時間を超えてずれたら、記録のリセット時刻がまだ来ていない限り記録の方）、行末に採った値の取得時刻からの経過時間（`2h前`）を添える。リセット時刻を過ぎた値も 0% に読み替えず、そのまま描く。こちらには鮮度ゲートを効かせない。使っていないアカウントは OAuth トークンが期限切れで更新できないのが普通で、ゲートを効かせると 6 時間後に行が消えてしまうため
- 値がまだ一度も取れていないアカウントは行を出さない
- リセット時刻を過ぎた窓は、日程分母（`82%/74%` の右側）と残り時間を出さない

いま使っているアカウントの判定は、`CLAUDE_SECURESTORAGE_CONFIG_DIR` から導出した Keychain のサービス名と一致するスロットを探し、見つからなければ snapshot が記録している値、それも無ければ最初のスロット、の順に決める。環境変数が未設定のときは「既定アカウント」を指しているものとして扱うので、`securestorage` が `null` のスロットがあればそこに一致する。ステータスラインのサブプロセスに環境変数が渡るかは Claude Code 側の実装に依存するため、snapshot へのフォールバックを併せ持っている。

## カスタマイズ

`~/.claude/statusline.sh` を直接編集してよい（プラグイン更新では消えない。ただし `/statusline:setup` を再実行すると上書きされ、`.bak-<timestamp>` が残る）。環境変数でも変えられる:

| 変数 | 既定 | 効果 |
|---|---|---|
| `STATUSLINE_BAR_WIDTH` | `16` | バーのセル数 |
| `STATUSLINE_BAR_GLYPH` | `▂` | 日程線の太さ。細い順に `▁` `▂` `▃` `▄` |
| `STATUSLINE_API_PACE` | `1` | `0` で API 換算コスト表示を止める |
| `STATUSLINE_SESSION_COST` | `1` | `0` でセッションコスト表示を止める |
| `STATUSLINE_CURRENCY` | `JPY` | API 換算コスト（30日・セッションとも）の通貨。`USD` なら為替変換なし |
| `CLAUDE_CONFIG_DIR` | `~/.claude` | 設定ディレクトリ |

色を変えたい場合はスクリプト先頭付近の `C_EMPTY_N`（未消化部分）・`C_TRACK_N`（日程線）と `usage_color_num()` の返す色番号（256色パレット）を書き換える。

## 動作環境

macOS と Linux。`stat` / `date` は BSD 系と GNU 系の両方にフォールバックする。表示には 256 色と Unicode ブロック文字（`▂`）を出せるターミナルが要る。

## テスト

```bash
bats plugins/statusline/tests/
python3 -m pytest plugins/statusline/tests/
```

`statusline.bats` は 1 スロット時の退行ガード、`statusline-multi-account.bats` は複数スロットの描画と `origin/main` 版との出力バイト一致の検証。`statusline-rate-snapshot.bats` と `test_rate_snapshot_writer.py` は writer の保存契約を検証する。

## Codex の利用上限

Codex CLI に ChatGPT アカウントでログイン済みなら、Claude アカウントの下に `Codex` を1行追加する。`CODEX_HOME`（既定 `~/.codex`）の `auth.json` を使う CLI アカウントが対象。別のアカウントでログインしているアプリや、Keychain のみの認証・API キーだけの認証は対象外。

```text
▸ A      5h       …
▸ A      7d All   …
  B      5h       …
  B      7d All   …
  Codex  7d All   ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂  45%/60%  ~2d 19h  0m前
```

表示例の値はダミー。バー・色・日程線は Claude と共通で、通常 Codex 枠の返却された期間だけを表示する。週間枠しか無ければ5時間枠は作らない。複数の期間があれば同じ行に並べる。Spark の別枠は含めない。

Python 3 helper が [Codex App Server](https://learn.chatgpt.com/docs/app-server) の `account/rateLimits/read` で取得する。描画は `${CLAUDE_CONFIG_DIR:-~/.claude}/.statusline-codex` のキャッシュを読み、180秒経過後の描画でバックグラウンド更新を開始する。失敗後は60秒待って再試行する。取得できない間は前回値に取得時刻からの経過時間を添え、初回は `取得待ち`。認証ファイルが変わると旧アカウントのキャッシュを無効化する。認証情報や生の応答はキャッシュへ保存しない。

- `STATUSLINE_CODEX=0`: Codex 行・取得を無効化
- `STATUSLINE_CODEX_BIN`: Codex CLI の実行ファイルを指定（既定 `codex`）
- `CODEX_HOME`: 表示する CLI の設定・認証ディレクトリ

起動直後に Claude のライブ値がまだ無い場合も、複数アカウントなら使用中のアカウントを `▸ A  取得待ち` のように示す。snapshot の値でライブ値を補完しない。

### リセット権の有効期限

Codex 行の末尾に `リセット3回・最短あと3日21h` のように残数と取得できた権利の最短有効期限を表示する。期限まで3日以内は黄色、24時間以内は赤色。失敗時は前回取得時刻を維持し、キャッシュの期限を過ぎた場合は `期限経過（更新待ち）` と表示する。残数だけ取得できた場合は `期限不明` とし、欠測を0回として扱わない。通常の利用枠のリセット時刻とは別の情報。

権利の使用は行わず、`account/rateLimits/read` の `rateLimitResetCredits` を同じキャッシュに保存して表示する。キャッシュには権利IDを保存しない。
