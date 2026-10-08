## 1. テストを先に書く

- [ ] 1.1 新規 bats を作り、spec の Scenario を 1 件ずつテストにする（`0.82` → `Cache 82%`、四捨五入、0 と 1、並び順、Context 無し、色が値で変わらない、`prompt_cache` 無しで区画なし、`null`・壊れた形で `prompt_cache` 無しと出力が完全一致、原因の対応表 4 件、複数原因の `+1`、対応表に無い原因と 16 文字切り、`last_miss_cause` の `null` とキー無しが同じ出力、原因の形が壊れているとヒット率だけ、付随する数値を出さない、`STATUSLINE_PROMPT_CACHE=0`、README と冒頭コメントに変数が載っている、書かれるファイルが増えない）。`setup` は `statusline.bats` に揃える（`HOME` と `CLAUDE_CONFIG_DIR` を一時ディレクトリへ向け、`STATUSLINE_API_PACE=0`・`STATUSLINE_CODEX=0`、`CLAUDE_ACCOUNTS_FILE` と `CLAUDE_SECURESTORAGE_CONFIG_DIR` を unset）。1 行目は一時ディレクトリの乱数パスを含むので、`Cache` や `miss:` の有無は 2 行目以降（`tail -n +2`）で見る。完全一致の比較は同じテストの中で 2 回描画して比べる（`session_id` と `rate_limits` を入力に入れず、描画ごとに変わる値を避ける）。並び順のテストは `STATUSLINE_CURRENCY=USD` と `STATUSLINE_API_PACE=0` を明示する。**否定検査（`! grep …`・`! [[ … ]]`）と単独の文として置く `[[ … ]]` には、テスト本文の最後の文であっても必ず `|| return 1` を付ける**（`openspec/specs/bats-assertion-guard/spec.md`。付け忘れると `scripts/test.sh` が落ちる。複数行にまたがる否定検査や here-doc の中の `! ` で始まる行も書かない）。「付随する数値は出さない」の検査は、2 行目全体ではなく `│` で区切ったキャッシュの区画の文字列に対して行う（入力に `Context 91%` があると 2 行目全体には `9` が含まれる）。この時点で新規テストが落ちることを確かめる。触る範囲: plugins/statusline/tests/statusline-prompt-cache.bats（新規）、plugins/statusline/tests/statusline.bats:7-40（setup・`strip_ansi` の手本）、plugins/statusline/tests/statusline.bats:107-172（項目が無いときに出さない検査の手本）

## 2. statusline.sh に区画を足す

- [ ] 2.1 `STATUSLINE_PROMPT_CACHE` が `0` でないとき、`jq` 1 回で `prompt_cache` からヒット率（`hit_ratio` が 0 以上 1 以下の数値のときだけ `. * 100 | round`）と原因の表示文字列（`causes` の先頭を対応表で短くし、表に無ければ 16 文字で切り、`[A-Za-z0-9_]` 以外を含めば空、2 件以上なら `+<残りの件数>`）を取り出す。原因の取り出しは型を確かめてから行う（`last_miss_cause` がオブジェクトか、`causes` が配列で 1 件以上か、先頭が文字列か を `type` で見てから中身に触る）。`causes` が文字列や数値でも `jq` の式全体をエラーにせず、ヒット率は出して原因だけ空にする。`jq` の標準エラーは捨て、`jq` 自体が失敗したら両方とも空にする。触る範囲: plugins/statusline/scripts/statusline.sh:33-42（stdin の JSON を読む箇所）
- [ ] 2.2 ヒット率が空でなければ `cache_info` を組み立てる（ヒット率は `CYAN`、原因があれば空白 1 つを置いて `YELLOW` の `miss:<短い名前>`）。色の変数（`CYAN` など）の定義より後に置く。触る範囲: plugins/statusline/scripts/statusline.sh:244-257（Context 区画の直後）
- [ ] 2.3 2 行目の連結ループの対象の先頭に `cache_info` を足す（`Context` の直後、`api_pace_info` の前）。触る範囲: plugins/statusline/scripts/statusline.sh:936-950（2 行目の連結）
- [ ] 2.4 冒頭コメントの「2行目」の説明にキャッシュヒット率を足し、環境変数一覧に `STATUSLINE_PROMPT_CACHE` を足す。「Build status line」のコメントの Line 2 も直す。触る範囲: plugins/statusline/scripts/statusline.sh:5-27（冒頭コメント）、plugins/statusline/scripts/statusline.sh:927-930（Line 2 のコメント）
- [ ] 2.5 1.1 のテストがすべて通ることを確かめる（`bats plugins/statusline/tests/statusline-prompt-cache.bats`）

## 3. README と変更の記録

- [ ] 3.1 README の表示例の 2 行目に `Cache 82%` を足し、行の内容の表の 2 行目にキャッシュヒット率を足し、`Cache` の読み方を 1 段落で書く（メイン会話のセッション累計のヒット率であること、`miss:` は直近のミスの原因で次のミスまで出続けること、短い名前の対応、`prompt_cache` を渡さない版と最初の API 応答の前は出ないこと、原因は 2.1.260 以降、`caching_observed` は見ないので、キャッシュのトークン数を報告しないプロバイダやゲートウェイでは `Cache 0%` と出ること、消したいときは `STATUSLINE_PROMPT_CACHE=0`）。環境変数の表に `STATUSLINE_PROMPT_CACHE` を足す。触る範囲: plugins/statusline/README.md:5-19（表示例・行の表・`Session` の説明の前後）、plugins/statusline/README.md:152-159（環境変数の表）
- [ ] 3.2 変更の記録を書く。何を足したか、仕様とテストの場所、**動いているのはコピー先の `~/.claude/statusline.sh` なので、プラグインを更新したあと `/statusline:setup` を再実行するまで表示されない**という注意書きを入れる。触る範囲: plugins/statusline/changes/714.md（新規）、plugins/statusline/changes/692.md:1-10（書式の手本）

## 4. 検証

- [ ] 4.1 statusline の既存スイートが通ることを確かめる（`scripts/test.sh statusline`）。1 件だけ落ちたら、そのテストを単独で再実行して判定する（statusline のテストは単発で落ちることがある）
- [ ] 4.2 `scripts/test.sh` が exit 0
- [ ] 4.3 公式ドキュメントの入力例（`hit_ratio: 0.91`、`last_miss_cause.causes: ["tools_changed"]`）を `bash plugins/statusline/scripts/statusline.sh` に渡した出力を控え、(3a) の return に貼る。実際の Claude Code の画面での確認は W が行わず、return の `画面確認:` 行で要否を本体に伝える
