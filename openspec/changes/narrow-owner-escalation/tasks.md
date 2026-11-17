# Tasks

各グループの終わりを return の単位にする（編集するファイルが 5 個を超えるので、W の規模超過のトリップワイヤーが発火する前提。design.md D1）。行番号は仕様づくりの時点の値で、前のタスクの編集でずれうる。編集前に該当範囲を読み直す。

## 1. `--delegated` の並び順の判定（design.md D4。主の確認が要る案 A を前提にする）

- [ ] 1.1 `check_asked_directly` の `not-direct` を `--relayed` のときだけ当て、`--delegated` では挟まった主の発言で落とさないようにする。冒頭の使い方の説明（`--delegated` の確かめる順）も直す。確認: `bats plugins/dev-workflow/tests/owner-reply-check.bats` が exit 0 で、`--relayed` の `not-direct` のテスト（#1059）は今のまま通る。触る範囲: plugins/dev-workflow/scripts/owner-reply-check.sh:43-52（使い方の説明）、plugins/dev-workflow/scripts/owner-reply-check.sh:337-362（`check_asked_directly`）
- [ ] 1.2 `owner-reply-delegated-scenario.bats` の「挟まった発言は not-direct」のテストを、挟まっても exit 0 になるテストに置き換え、2026-11-09 の flatmate #2058 と同じ並び（親が委任の記録の URL を見せる → 主の別の発言 → 主の「任せる。今回の件も許容する。」→ 停止の記録）の会話ログで `--delegated` が exit 0・`MATCHES=1` を返すシナリオを足す。確認: `bats plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats:104-112、plugins/dev-workflow/tests/owner-reply-delegated-scenario.bats:1-40（会話ログの組み立て）
- [ ] 1.3 `owner-reply-relayed-scenario.bats` に、同じ並びの会話ログでも `--relayed` は今どおり `not-direct` で落ちることを確かめるテストを足す（`--relayed` を緩めていないことの固定）。確認: `bats plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/owner-reply-relayed-scenario.bats:1-91

## 2. ゲートの論点なしの経路（design.md D2）

- [ ] 2.1 `declarations.md` の手順 3 の論点なしの説明に、論点なしの宣言は確認者（エピックの子は親、それ以外は決める役）の確認で合格処理に進むこと、確認の記録の行 `論点なしの確認: 通す — 確認者 <確認者> / <日時> 根拠: <1 文>`（行頭を `主の回答:` にしない）、確認者が論点ありと判定したら書き直して主に上げることを書く。後続の表の「主のリスク許容が必要」の行の後続にも論点なしの分かれ道を書く。確認: 2.4 の bats。触る範囲: plugins/dev-workflow/skills/pr-review-gate/declarations.md:22-25（後続の表）、plugins/dev-workflow/skills/pr-review-gate/declarations.md:49-69（雛形と論点の説明）
- [ ] 2.2 `stages/hold.md` の手順 6 に、論点なしの宣言は主に聞く前に確認者に回すこと（develop の G は本体に返して本体が決める役を起こす。3-c の `needs-carryover-judge` と同じ return の形）と、3-c で `論点なしの確認:` の追記を引き継ぎの元にしないことを書く。「主に承認を求めてよい4分類」の 1 番（リスク許容の確認）に論点ありに限る旨を足す。G の return の書式に新しい Status が要るなら同じ節に足す。確認: 2.4 の bats。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:17-66（3-c）、plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:95-116（手順 6）、plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:117-133（4 分類）、plugins/dev-workflow/skills/pr-review-gate/stages/hold.md:134-161（G の return）
- [ ] 2.3 `stages/pass.md` の手順 5 の合格条件の表に「主のリスク許容が必要＋論点なし＋同じ HEAD の `論点なしの確認: 通す`」の行を足す。確認: 2.4 の bats。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:57-75（合格条件の表）
- [ ] 2.4 `pr-review-gate-skill.bats` に、3 ファイルの記述（確認者の 2 通り・記録の行の書式・行頭が `主の回答:` でないこと・論点ありは主に上がること・引き継がないこと・合格条件の表の行）を確かめるテストを足す。確認: `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:2370（末尾に追加）

## 3. 親が通す基準と子の止まり（design.md D3）

- [ ] 3.1 `parent-pass-criteria.md` の「迷ったとき」を「主に上げるとき」に書き換える（3 つの理由のどれかと根拠を `理由:` に示せたときだけ主に上げる、示せなければ通す、委任の無いセッションでは「聖域でない」「戻せる」「実機操作でない」は判断できなければ満たさない側）。守備範囲の「通してよい止まりを判断のモデルが主に上げること」を許す文を消す（「CI の見張りのやり直しの上限」の節の守備範囲の同じ文も）。否定文の形でも「成り立つ側に倒す」の語を残さない。出力の形の `理由:` の説明に根拠を書くことを足す。確認: `grep -n "成り立つ側に倒す" plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md` が 0 件。触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:7-9（原則）、plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:33-35（迷ったとき）、plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:53（CI の節の守備範囲）、plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:90-106（出力の形・守備範囲）
- [ ] 3.2 `parent-pass-criteria.md` に (a)〜(c) の確かめの手順を置き、通らない例に 11/16（調べれば分かる事実を聞いた）・11/12（主の作業でないものを主の作業として転送した）・11/13（推奨のそろった順序の入れ替え）を中身で足す。例の中身は issue #1653 の本文と、必要なら当日の会話ログ（Mac mini の `~/.claude/projects` の flatmate のログ）で確かめ、無い事実を作らない。確認: 3.4 の bats。触る範囲: plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:11-31（通す条件と読み方）、plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md:55-78（例）
- [ ] 3.3 `epic-child-stop.md` の `主に聞く理由:` の書き方に、書く前の (a)〜(c) の確かめと同じ 3 件の例を足す。確認: 3.4 の bats。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:33-35
- [ ] 3.4 `owner-escalation-narrowing.bats` を新しく作り、`parent-pass-criteria.md` に「成り立つ側に倒す」が無いこと・「主に上げるとき」に理由と根拠を求める文があること・委任の無いセッションの 3 条件の歯止めが残ること、両ファイルに (a)〜(c) と 3 件の例があることを確かめる。確認: `bats plugins/dev-workflow/tests/owner-escalation-narrowing.bats` が exit 0。触る範囲: plugins/dev-workflow/tests/owner-escalation-narrowing.bats（新規）

## 4. 委任の範囲・判例・報告（design.md D5・D7・D8）

- [ ] 4.1 `epic.md` の「主の委任」に、委任の記録の種類 `主の委任: 論点なしの止まり` と範囲の文（主の決定の URL を根拠に添える）を足し、「委任が効く止まり」に論点なしの条件（⑤）と新しい種類の条件を足し、「委任で送る」に種類ごとの送り方（リスク許容・マージ待ちの `parent-merge-approved`・聖域の変更と破壊的な git 操作の返事。hook が主の手を求めたら主に上げる）と `委任で送った:` の行への委任の記録の URL を足す。確認: 4.5 の bats。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:90-110（主の委任）
- [ ] 4.2 `pr-review-gate` の `stages/pass.md` の委任の形の真正性確認（手順 3「止まりに委任が効くか」）を、`epic.md` と同じ文（⑤を含む）にそろえる。確認: `grep` で `epic.md` と `stages/pass.md` の「委任が効く止まり」の文が同じ。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/pass.md:137-160（委任の形の真正性確認）
- [ ] 4.3 `epic-child-stop.md` の「親から届いた返事」に、`親エピック #<E> の判断（主の委任による）:` の返事の受け方（委任の記録の確かめは今の委任と同じ・PR に委任の記録の URL を添えた記録を残す）を足す。確認: 4.5 の bats。触る範囲: plugins/dev-workflow/skills/develop/references/epic-child-stop.md:18
- [ ] 4.4 `epic.md` の手順 8 に判例の記録の契機（主に上げた件に主が答えたとき・主の聞き返しを受けたときに、そのターンで `.claude/casting/precedents.md` に 1 判例を追記。書式は casting の SKILL.md「判例の書き方」）を足し、報告の形に「親の判断で通した PR・止まり」の節（1 件 1 行・中身と URL・設計の分かれ目は決めた内容と他の案・0 件なら書かない）を足す。確認: 4.5 の bats。触る範囲: plugins/dev-workflow/skills/develop/references/epic.md:46-57（報告と状態表）、plugins/dev-workflow/skills/develop/references/epic.md:86-89（手順 8）
- [ ] 4.5 `owner-escalation-narrowing.bats` に、`epic.md` の新しい種類の委任・論点ありには効かないこと・委任の無いセッションでは聖域・破壊的操作・マージを通さない文が `parent-pass-criteria.md` に残ること・判例の契機・報告の節を確かめるテストを足す。確認: `bats plugins/dev-workflow/tests/owner-escalation-narrowing.bats` と `bats plugins/dev-workflow/tests/` が exit 0。触る範囲: plugins/dev-workflow/tests/owner-escalation-narrowing.bats（3.4 で作ったもの）

## 5. 論点の定義（design.md D6）

- [ ] 5.1 `output-styles/readable.md` の節 3 に、運用の形・構造の分け方・将来の拡張に効く設計の分かれ目は主の指摘が効く観点で、主に聞く理由にせず、決めた内容と他の案を報告に載せる扱いを足す。主に聞く理由の 3 つは増やさない。確認: 5.3 の bats。触る範囲: output-styles/readable.md:39-90（節 3）
- [ ] 5.2 `rules/communication-style.md` の 3 に同じ内容を 1 文で足す（常時注入。予算の値は動かさない）。確認: `bats tests/injection-budget.bats` が exit 0。触る範囲: rules/communication-style.md:10
- [ ] 5.3 `tests/owner-question-style.bats` に、正本と短い版の両方に主の観点の語と「報告に載せる」扱いがあることを確かめるテストを足す。確認: `bats tests/owner-question-style.bats` が exit 0。触る範囲: tests/owner-question-style.bats:239-246（末尾に追加）

## 6. 変更の記録と全体の確認

- [ ] 6.1 変更の記録を書く（何を変えたか・D4 の緩めた判定・聖域に触れること）。確認: ファイルがあり、版を上げていない（`plugin.json` の `version` を変えていない）。触る範囲: plugins/dev-workflow/changes/1653.md（新規）
- [ ] 6.2 受け入れ条件のコマンドを回す: `bats plugins/dev-workflow/tests/`・`bats tests/owner-question-style.bats`・`bats tests/injection-budget.bats` が exit 0、`grep -n "成り立つ側に倒す" plugins/dev-workflow/skills/develop/references/parent-pass-criteria.md` が 0 件、`openspec validate narrow-owner-escalation --type change --strict` が通る。触る範囲: なし（確認だけ）

## Workflow follow-up

- 受け入れ条件「マージ後 2 週間で precedents.md の `### ` の見出しが 1 件以上増える」は、マージ後に `git log --since=<マージ日> -- .claude/casting/precedents.md` で確かめる（この PR の中では確かめられない）
- 導入後 2 週間の見直しの材料（主があとからひっくり返した設計の分かれ目の数・聞き返しの数）は issue #1653 の備考のとおり会話ログで数える
