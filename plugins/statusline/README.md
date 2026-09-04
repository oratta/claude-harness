# statusline

使用量が一目で分かる Claude Code のステータスライン。

```
.../workspaces/flatmate/clone-origin-main-repo-sync  Opus 5 (1M context)  oratta/clone-origin-main-repo-sync
Context 91%  │  API ¥1446038/mo
5h       ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂    3%  ~4h 13m
7d All   ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂   25%/29%   Fable ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂    7%/29%  ~4d 22h
```

| 行 | 内容 |
|---|---|
| 1 | カレントディレクトリ / モデル / git ブランチ（未コミット変更は `✱`） |
| 2 | コンテキスト残量 / 直近30日の使用量を API 従量課金に換算した月額ペース |
| 3 | 5時間ウィンドウのレートリミット消化率 |
| 4 | 7日ウィンドウのレートリミット消化率（全体 + Fable） |

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

`scripts/statusline.sh` を `~/.claude/statusline.sh` にコピーし、`~/.claude/settings.json` の `statusLine` をそこに向ける。既存の `statusLine` があれば置き換え前に確認し、`settings.json` はバックアップを取る。

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

`dev-workflow` を入れていない、あるいは snapshot が6時間以上古い場合は Fable セグメントを黙って省く。逆方向に、このステータスラインは毎回 `~/.claude/.rate-limit-snapshot` を書き出しており、`dev-workflow` のセッション tripwire がそれを読んで残量モードを決めている。

## 複数アカウントを並べて表示する

`CLAUDE_SECURESTORAGE_CONFIG_DIR` を設定すると、`CLAUDE_CONFIG_DIR`（設定・履歴・プラグイン）を共有したまま Keychain の認証情報だけを別枠にできる。この仕組みで複数の Claude アカウントを使い分けている場合、アカウントごとにレートリミットを 2 行ずつ並べられる。

```
A  5h      ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂   55%          ~4h 12m
A  7d All  ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂   82%/74%   Fable ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂   94%   ~2d 3h
B  5h      ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂    3%
B  7d All  ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂    1%/0%    Fable ▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂▂    0%   2h前
```

**アカウントレジストリを作らないかぎり、表示も挙動も一切変わらない。** レジストリが無ければ既定アカウント 1 つとして扱われ、出力は 1 バイトも変わらない（左端のラベル列も出ない）。

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

- **いま使っているアカウント**は Claude Code から渡るライブ値で描く。Fable セグメントには従来どおり 6 時間の鮮度ゲートが効く
- **それ以外のアカウント**は snapshot の値で描き、行末に取得からの経過時間（`2h前`）を添える。こちらには鮮度ゲートを効かせない。使っていないアカウントは OAuth トークンが期限切れで更新できないのが普通で、ゲートを効かせると 6 時間後に行が消えてしまうため
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
| `STATUSLINE_CURRENCY` | `JPY` | API 換算コストの通貨。`USD` なら為替変換なし |
| `CLAUDE_CONFIG_DIR` | `~/.claude` | 設定ディレクトリ |

色を変えたい場合はスクリプト先頭付近の `C_EMPTY_N`（未消化部分）・`C_TRACK_N`（日程線）と `usage_color_num()` の返す色番号（256色パレット）を書き換える。

## 動作環境

macOS と Linux。`stat` / `date` は BSD 系と GNU 系の両方にフォールバックする。表示には 256 色と Unicode ブロック文字（`▂`）を出せるターミナルが要る。

## テスト

```bash
bats plugins/statusline/tests/statusline.bats plugins/statusline/tests/statusline-multi-account.bats
```

`statusline.bats` は 1 スロット時の退行ガード、`statusline-multi-account.bats` は複数スロットの描画と `origin/main` 版との出力バイト一致の検証。
