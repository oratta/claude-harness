## 1. owner-reply-check.sh に --delegated を足す

- [ ] 1.1 冒頭の使い方の説明に `--delegated <セッション ID> <uuid> <委任の記録の作成日時> <委任の記録の URL> <停止の記録の作成日時>` と出力・理由（`not-found`・`not-owner`・`not-after`・`not-asked`・`not-direct`・`not-before`）・終了コードを足す（「3 つ」の数え方も直す） 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:1-53
- [ ] 1.2 引数の解釈に `--delegated` を足す（引数ちょうど 5 個、ID と uuid の UUID の形、URL の `https://`。違えば exit 2） 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:56-98、plugins/dev-workflow/scripts/owner-reply-check.sh:116（python へ渡す引数）
- [ ] 1.3 python 側に委任の確かめを足す。順は design.md D3 の表どおり。URL の境界の正規表現と「URL を書いた最後の親の発言」「あいだの主の発言」の判定は `relayed()` と共有する形にし、`relayed()` の動きは変えない 触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:285-337（`fail`・`relayed`・モードの振り分け）

## 2. テスト

- [ ] 2.1 新しい bats を作り、spec の要件「主の委任の合否を、名指しの許容と混在したログで機械的に固定する」の 3 つの Scenario と、`--delegated` の要件の各 Scenario（引数の不備の exit 2・`not-found`・`not-owner`・許容の語を見ないこと）を固定する。テスト用の会話ログの作り方は既存の relayed のシナリオの bats に倣う 触る範囲: plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats（新規）、plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats:1-91（読むだけ。書き方の手本）
- [ ] 2.2 既存の owner-reply-check の bats が、`--relayed` と既定・`--locate` について変わらず通ることを、触った bats だけ回して確かめる（全体は CI に任せる） 触る範囲: plugins/dev-workflow/tests/owner-reply-check.bats:1-852（読むだけ）

## 3. develop の参照（親と子）

- [ ] 3.1 手順 8 に、主が任せる旨を述べたときの委任の記録の投稿（定型の 1〜4 行目と `きっかけ:`）と、本文での確認の問い（範囲と期間の文・URL・親のタブで直後に答えること）を足す。取り消し（`主の委任: 取り消し`）と、委任が効く条件（最新の `主の委任:`・エピックが開いている）も書く 触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:55（手順 8）
- [ ] 3.2 手順 8 の「主に上げる前に親が自分で記録を照らす」の前に、委任で送る条件（spec の要件「親は有効な委任があり子の推奨が許容のときだけ、委任で許容を送る」）と送る文の書式、エピックへの `主の委任で送った: 子 #<N> <停止の記録の URL>` の 1 行を足す 触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:55（手順 8）
- [ ] 3.3 「親から届いた返事」に、末尾が `[主の委任: …]` の返事の受け取り方（`--delegated`・委任の記録の GitHub の確認・停止の記録の推奨・通らないときの頼み方）を足す。`[主の発言: …]` の経路の文は変えない。書式と真正性確認の正本は pr-review-gate 手順 5 と書く 触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:14
- [ ] 3.4 文面を固定する bats に、3.1〜3.3 で足した文の検査を足す 触る範囲: plugins/dev-workflow/tests/develop-skill.bats:843-884（relayed reply の検査の後ろ）

## 4. pr-review-gate

- [ ] 4.1 手順 5 の合格条件の表に `親経由で受領（委任）` の行を足し、「親経由で受けた許容」の段落のあとに、委任の形の記録の書式と真正性確認（spec の Scenario「委任の形の真正性確認」の各項目、`真正性確認: 済 …（owner-reply-check.sh --delegated 終了コード 0）`、落ちたときの扱い、守備範囲）を足す 触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:64（表）、plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:109-132（親経由で受けた許容の真正性確認）
- [ ] 4.2 手順 3-c の条件 3 と 1 行目の書式に委任の形と、引き継ぎの時点で委任が有効かを確かめ直すことを足し、手順 6 の復帰手順の表のリスク許容待ちの行に委任の形の追記を足す 触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:39（3-c 条件 3）、plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:51（1 行目の書式）、plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:67（復帰手順の表）
- [ ] 4.3 文面を固定する bats に、4.1・4.2 で足した文の検査を足す 触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:1568-1637（relayed reply の検査の後ろ）

## 5. 仕上げ

- [ ] 5.1 変更の記録を書く 触る範囲: plugins/dev-workflow/changes/1293.md（新規）
- [ ] 5.2 公開版の検査を通す（オーナーの固有名・アカウント名・PC の絶対パスを足していないこと。新しい bats はスクリプトの部品の表の対象かを docs/public-private-split.md で確かめ、要れば表を直す） 触る範囲: docs/public-private-split.md（確かめるだけ。要れば直す）、plugins/dev-workflow/scripts/forbidden-words-check.sh（回すだけ）
