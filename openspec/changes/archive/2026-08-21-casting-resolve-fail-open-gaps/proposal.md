## Why

#136（resolve の fail-closed 化 / #117）のレビューで、**同じ「壊れた配役表なのに exit 0 で解決結果が出る」クラスの経路が4本残っている**ことを origin/main 上で実測した（oratta/claude-harness#139）。resolve の出力は flatmate の burn-mode 論点ゲートが自走可否の判定根拠に使うため、担い手を誤ってエージェント側に解決すると、主に上げるべき論点が無人でマージされる。

実測した4経路:

1. セル内に `|` が紛れて6列以上に割れる行が malformed 判定されない（判定が `pipe_count < 6` の片側だけ）。`cut` の列位置が右へずれ、人間が書いた「既定の担い手: 主」が消えて隣のセルが担い手として出力される
2. `.claude/casting/` に配役表が1枚も無い対象・存在しないパスでも exit 0 でカタログ既定14行が返る（検証関数がすべて `[ -f "$file" ] || return 0`）。repo ルートの打ち間違えと「検証を通った解決結果」を呼び出し側が区別できない
3. 閉じ忘れの `<!--` があると `stripped_copy` の `sed '/<!--/,/-->/d'` が EOF まで削り、その repo の上書き行が全滅して「全部カタログ既定」に化けるが検出は0件
4. `resolve` は `$1` にあるときしかサブコマンドと認識されず、`--catalog <path> resolve <repo>` は exit 0・stdout 空で黙って check モードに落ちる

## What Changes

- **列数判定を両側にする**: `pipe_count != 6` を malformed-row にする（有効行も区切り行も `|` はちょうど6個）。6列以上は「セル内の `|` が列をずらす」旨のメッセージで報告し、`table_rows` も有効値として採らない
- **配役表ゼロを解決結果と区別する**: project.md も local.md も無い対象では resolve が合成表を出さず exit 3（専用コード）＋ stderr で理由と対処（行を持たない project.md を置く）を出す。対象 repo ルート自体が存在しない場合は check / resolve とも exit 2（使い方エラー）
- **閉じられていない HTML コメントを検出する**: 対応する `-->` が無いままファイル末尾に達した `<!--` を `unclosed-comment` として findings に積む（配役表2層は resolve でも fail-closed、precedents.md は check モードで報告）。判定は開閉の「個数」ではなく、パース側のコメント除去と同一の走査で行う — 個数比較は本文の対応先の無い `-->` だけで正常な配役表を止め、その `-->` が本物の閉じ忘れと釣り合うと検出を落とす
- **引数を順不同で受ける**: `resolve` をループ内でも受け、positional は1個に限定。超過・不明オプション・`--catalog` の値欠落は usage を出して exit 2（旧実装は後勝ちで黙って上書きしていた）
- **テストの穴を塞ぐ**: 壊れた `local.md` 経由の fail-closed、起案シグナル2フィクスチャへの有効な project.md 同居（配役表ゼロ経路で素通りしていたため検証になっていなかった）

## Capabilities

### Modified Capabilities

- `casting-project-files`: Requirement「casting-check.sh の検出項目」に列数の両側判定とコメント開閉不一致を追加。Requirement「resolve による有効な配役表の合成表示」に配役表ゼロ・引数順・exit code 体系の MUST を追加

## Impact

- `plugins/casting/scripts/casting-check.sh` — 引数パーサの書き直し、`check_unclosed_comment` 追加、列数判定を `-ne 6` に、resolve の配役表ゼロ分岐と対象不在チェックを追加
- `plugins/casting/tests/casting-resolve.bats` / `casting-check.bats` — 4経路の退行テストと local.md 経由の fail-closed テストを追加。spec 参照を archive 後のパスへ修正
- `plugins/casting/tests/fixtures/` — `over-column` / `unclosed-comment` / `no-casting-tables` / `local-malformed` を新設、`catalog-external-precedent` / `repeated-not-issue` に有効な project.md を同居
- `plugins/casting/.claude-plugin/plugin.json` — version 0.2.2 → 0.2.3
- `plugins/casting/skills/casting/SKILL.md`・`plugins/casting/README.md` — 検出項目と exit code 体系を追記
- 呼び出し側（flatmate burn-mode 論点ゲート）— exit 2 / 3 は「検証が通らなかった」側として扱えばよく、既存の「exit 0 を必須とする」規定のままで安全側に倒れる
