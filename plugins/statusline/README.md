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
| `dev-workflow` プラグイン | | `Fable` セグメントが出ない（後述） |

### Fable セグメントについて

Fable の週次消化率は Claude Code がステータスラインに渡してくれないので、`~/.claude/.usage-snapshot` から読む。このファイルを書いているのは同じ marketplace の **`dev-workflow` プラグイン**（`scripts/usage-probe.sh` を SessionStart フックで実行し、OAuth の usage API を叩く）。

`dev-workflow` を入れていない、あるいは snapshot が6時間以上古い場合は Fable セグメントを黙って省く。逆方向に、このステータスラインは毎回 `~/.claude/.rate-limit-snapshot` を書き出しており、`dev-workflow` のセッション tripwire がそれを読んで残量モードを決めている。

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
bats plugins/statusline/tests/statusline.bats
```
