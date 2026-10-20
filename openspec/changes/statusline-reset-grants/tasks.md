## 1. usage-probe.sh（取得と書き出し）

- [ ] 1.1 `ENDPOINT` の既定を `https://api.anthropic.com/api/oauth/usage?cedar_ember=1&skip_spend=1` にし、冒頭コメントの契約の説明に取得先と `reset_grants` の寿命（成功は作り直す／試みて失敗は出さない／試みなかったら保つ）を 1 段落足す。触る範囲: plugins/dev-workflow/scripts/usage-probe.sh:1-30（冒頭の契約コメント）、plugins/dev-workflow/scripts/usage-probe.sh:52（ENDPOINT）
- [ ] 1.2 組み立ての python に `reset_grants(d)` を足し、`parse()` の戻り値に「欄を出す条件を満たすときだけ」`reset_grants` キーを入れる（`cedar_ember` が dict／`eligible is True`／`grants` が list。束は dict のものだけ（`grants` が空でないのに写せる束が 0 件なら欄なし。元から空なら `[]`）、`resets_left`・`ends_at`・`paused` の 3 キーを元の値のまま、元に無いキーは省く）。`FIELDS` には入れない。触る範囲: plugins/dev-workflow/scripts/usage-probe.sh:443-488（`parse()`）
- [ ] 1.3 スロットのループで寿命を実装する: パースできたらその値、パースできず `<raw_dir>/<id>.status` がある（試みた）なら欄なし、`.status` が無い（試みていない）なら `prev_accounts[sid]` に `reset_grants` が list であればそれを引き継ぐ。他の値の引き継ぎ（`FIELDS`）は変えない。触る範囲: plugins/dev-workflow/scripts/usage-probe.sh:507-530（`accounts` の組み立て）
- [ ] 1.3b 全スロット失敗の例外を実装する: 組み立ての python で `fresh` が空のとき、従来の `SystemExit(1)` の前に、既存 snapshot（`prev`）が dict で、試みて失敗したスロット（`<raw_dir>/<id>.status` がある）の `accounts.<id>.reset_grants` を持つものがあれば、その欄だけを除いた `prev` をそのまま出力して書く。除く欄が無い・`prev` が読めないときは従来どおり何も出さない。シェル側の `[ "$any_new" -eq 1 ] || exit 0` はこの経路を通すよう、`.status` が 1 つでもあれば python に進める形に直す。触る範囲: plugins/dev-workflow/scripts/usage-probe.sh:400-404（`any_new` の判定）、plugins/dev-workflow/scripts/usage-probe.sh:531-532（`if not fresh`）
- [ ] 1.4 テスト（`plugins/dev-workflow/tests/usage-probe.bats` に足す）: spec のシナリオ（値を変えずに写す・eligible でない各形で欄なし・元から空配列は `[]`・全要素が不正な grants は欄なし・一部だけ不正なら写せる束だけ・試みて失敗は前回を写し直さない（単一スロット失敗／全スロット失敗で他は変わらない／一部失敗と未試行の混在）・全件失敗で除く欄が無ければ snapshot が書き換わらない・試みなかったスロットは前回を保つ・`cedar_ember` だけの応答は失敗扱い・使用率が一部欠ける応答は従来どおり・既定の取得先にクエリが付く）。応答は `USAGE_PROBE_RESPONSE_FILE[_<ID>]` と `USAGE_PROBE_STATUS` で与え、snapshot は一時ディレクトリに書く。既存のテストは変えずに通る。触る範囲: plugins/dev-workflow/tests/usage-probe.bats（末尾に追記。setup の変数と `write_good_resp` を使う）

## 2. statusline.sh（表示）

- [ ] 2.1 Codex の行の中の残数・期限の整形（`リセットN回`・`期限不明`・`期限経過（更新待ち）`・`あとXdYh`／`あとXhYm`・色）を関数 `fmt_reset_credits <残数> <最短期限 epoch、無ければ 0>` に切り出し、Codex の行からそれを呼ぶ。Codex の行の出力は変えない。触る範囲: plugins/statusline/scripts/statusline.sh:820-840（Codex 行の `resets` の処理）、関数の置き場は `fmt_ago()` の近く（plugins/statusline/scripts/statusline.sh:377 付近）
- [ ] 2.2 snapshot を読む jq に、スロットごとの 2 列（有効な束の残数の和、最短期限の epoch。無ければ空）を足し、`snap_rg_count` / `snap_rg_exp` の配列に入れる（欠け行の穴埋めも合わせる）。欄が無い・配列でない・束がすべて読めないときは 2 列とも空。空配列は残数 0・期限空。`ends_at` は小数秒を落として `fromdateiso8601` に渡し、失敗した値は期限なしにする。触る範囲: plugins/statusline/scripts/statusline.sh:589-620（jq と展開）
- [ ] 2.3 `render_slot` に引数を 2 つ足し（残数・最短期限）、`line_7d`（無ければ `line_5h`）の末尾、`ago` のあとに `  ${DIM}│${RESET}  <色>テキスト${RESET}` を足す。残数が空なら何も足さない。active・非 active の呼び出しの両方から渡す。触る範囲: plugins/statusline/scripts/statusline.sh:721-785（`render_slot`）、plugins/statusline/scripts/statusline.sh:786-814（呼び出し）
- [ ] 2.4 テスト（新規 `plugins/statusline/tests/statusline-reset-grants.bats`。`statusline-multi-account.bats` の setup と同じ流儀で、一時ディレクトリの snapshot を使い `STATUSLINE_CODEX=0`）: 残数 2・3 日 21 時間後で `リセット2回・最短あと3日21h`／2 日後で黄・12 時間後で赤の色コード／paused と 0 回の束を数えない／期限なしは `期限不明`／空配列は `リセット0回`／1 スロットで区画あり・なしの出力の差が区画だけ／欄なし・読めない束のみ・snapshot なしで出力が欄なしの出力と一致／非 active スロットの行にも出る／Codex の行が前と同じ出力。触る範囲: plugins/statusline/tests/statusline-reset-grants.bats（新規）

## 3. 文書と記録

- [ ] 3.1 README の「リセット権の有効期限」節を、Codex と Claude の両方の説明に書き換える（Claude は snapshot の `reset_grants` から、非公開の呼び方で予告なく変わりうること、取得に失敗した間は区画が消えること）。dev-workflow の README に、probe の取得先が変わったことと `reset_grants` を 1 行で足す。触る範囲: plugins/statusline/README.md:247-251（「リセット権の有効期限」）、plugins/dev-workflow/README.md（usage-probe の説明の近く）
- [ ] 3.2 変更の記録 `plugins/dev-workflow/changes/1115.md` と `plugins/statusline/changes/1115.md` を書く（版は上げない）。触る範囲: plugins/dev-workflow/changes/1115.md（新規）、plugins/statusline/changes/1115.md（新規）

## 4. 確認

- [ ] 4.1 `bats plugins/statusline/tests/ plugins/dev-workflow/tests/usage-probe.bats plugins/dev-workflow/tests/usage-probe-multi-account.bats` が exit 0。`openspec validate statusline-reset-grants --type change --strict` が通る
- [ ] 4.2 実機（主）: `cedar_ember=1&skip_spend=1` の応答が、従来の URL の応答と同じ使用率（`five_hour` / `seven_day` / `limits`）を保つこと（保てなければ URL の切り替えを進めず、取得方式を作り直す）と、ステータスラインの値が claude.ai の Settings > Usage と一致することを確かめ、エピック genetta-inc/flatmate#1656 にコメントする
