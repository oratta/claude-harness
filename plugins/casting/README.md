# casting — 「観点の配役」フレームワーク

意思決定移譲のフレームワーク「観点の配役」（正本: claude.ai artifact、2026-08-17 主承認済み）を harness の資産として実体化するプラグイン。

主に上げてよい論点は「主の視線が加わると結論が変わるもの」だけ、かつその観点が未移譲のとき。過剰エスカレーション（下限違反）は過小と同格以上のプロセス違反として扱う。移譲は「観点を担う仕組み（方針文等）の実装が伴って初めて成立」する。

## 構成

| パス | 役割 |
|---|---|
| `catalog/catalog.md` | 観点カタログの唯一の正本（version front matter・列定義・3グループ14観点・横断軸2・変更手続き・変更記録） |
| `skills/casting/SKILL.md` | 配役表の3層・判例の書き方・カタログ変更手続きの手順正本 |
| `commands/init.md` | `/casting:init` — 対象 repo に `.claude/casting/` 一式を雛形から生成 |
| `templates/project.md` | プロジェクト既定表の雛形（カタログの既定の担い手をコピーした5列表） |
| `templates/precedents.md` | 判例台帳の雛形（4フィールドの記入例つき） |
| `scripts/casting-check.sh` | 壊れた表行・コメントの閉じ忘れ・語彙 lint ＋起案シグナル検出＋相談判例の事後報告5要素チェック（7項目）と `resolve`（有効配役表の合成。詳細は SKILL.md） |
| `tests/` | bats テスト一式（`casting-check.bats` / `casting-init.bats`） |

毎ターン効くべき返信前チェック5手順だけは、このプラグインの外の `rules/perspective-casting.md`（常時ロード層）に置く。カタログ本文の複製はしない。

## 使い方

対象 repo で `/casting:init` を実行すると `.claude/casting/project.md` と `.claude/casting/precedents.md` が生成され、`.gitignore` に `.claude/casting/local.md` が追記される。以降の判断手順・判例の書き方は `skills/casting/SKILL.md` を参照。

```sh
plugins/casting/scripts/casting-check.sh [--catalog <path>] [<repo-root>]           # 検査（7項目）
plugins/casting/scripts/casting-check.sh resolve [--catalog <path>] [<repo-root>]   # 有効配役表の合成
```

`resolve` は出力前に project.md / local.md へ check モードと同じ検証（表行が5列ちょうどに割れるか・HTML コメントの閉じ忘れ・語彙・catalog_version）を通す。検証を通らない配役表では合成表を出力せず、理由を stderr に出して exit 1 する（fail-closed）。サブコマンドとオプションの順序は問わない。

exit code の意味は次のとおり。**呼び出し側は exit 0 以外の出力を担い手解決の根拠に使ってはならない。**

| code | 意味 |
|---|---|
| 0 | 検出なし（`resolve` は合成表を出力した） |
| 1 | 検出あり（`resolve` は合成表を出力していない） |
| 2 | 使い方エラー（catalog 不在・対象 repo ルート不在・引数過多・不明オプション） |
| 3 | `resolve` のみ: 配役表（project.md / local.md）が1枚も無いため解決していない |

## テスト

```sh
bats plugins/casting/tests/
```
