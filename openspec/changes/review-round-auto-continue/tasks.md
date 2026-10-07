## 1. テストを先に書く（TDD。どれも最初は落ちる）

- [ ] 1.1 `spec-decision-and-review.bats` の 2 周キャップのテストを書き換える: `3 ?周目.*(例外|設けない)` の存在検査を「無いこと」の検査に変え、`spec-reviewer.md` と develop SKILL.md の (2) に「直し方が決まっている」「主に聞かず次の周を回す」「方針の選び直し」「`pr-token-budget.sh` が exit 2」の 4 語があることを固定する。unmanned のサイクル終了・AskUserQuestion・`needs-approval` の検査は残す（選び直しのときの経路として） 触る範囲: plugins/dev-workflow/tests/spec-decision-and-review.bats:103-111
- [ ] 1.2 `develop-skill.bats` に、SKILL.md の節「レビューの周を主に聞かずに続ける（直し方の判定）」があり、その中に `subagent_type: dev-workflow:decider`・定義の 3 条件・返答の 1 行目 3 形（`裁定: 可` / `裁定: 否` / `不足:`）・判定の記録の正規表現 `^直し方の判定: (決まっている|選び直しが要る)$` と項目（`対象:` `周:` `判定役:` `指摘ごとの判定:` `入力不足:`）・事後報告の正規表現 `^主に聞かずに回した周: [0-9]+ 周目$` と項目（`対象:` `残っていた指摘:` `判定の根拠:` `使ったトークン:` `周の結果:`）・主に聞く条件 2 つ（「方針の選び直し」と `pr-token-budget.sh` の exit 2）があることを固定するテストを足す。(4) に `needs-fix-check →` の行があり、判定の記録を本体が投稿して照合と振り分けの G を起こすと書かれていることも固定する 触る範囲: plugins/dev-workflow/tests/develop-skill.bats（末尾に追加）
- [ ] 1.3 `pr-review-gate-skill.bats` に次を足し、既存の `3周目を自動で開けない` の検査（392 行付近）を「3 周目以降を開ける 3 条件」の検査に書き換える: 収束ルールに直し方の判定・主の回答・順 6 の裁定の 3 条件があること、周の終わりの段落に「順 6 を除いた全件が 1 周目なら順 2〜4」の条件と `needs-fix-check` があること、`### needs-fix-check のとき` 節があること、順 6 との混在の処理順（判定を先にする）が書かれていること、triage.md に `^直し方の判定:` と `^主に聞かずに回した周:` の書式定義が無く develop SKILL.md の節を指していること、仕分け表が 6 行のままであること 触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:385-436、plugins/dev-workflow/tests/pr-review-gate-skill.bats（末尾に追加）
- [ ] 1.4 `develop-roles.bats` の gate-runner の検査に、Status 行に `needs-fix-check` があること、`次の段:` の表で `needs-fix-check` が `照合と振り分け` を指すことを足す 触る範囲: plugins/dev-workflow/tests/develop-roles.bats:604-610

## 2. develop SKILL.md（正本の節と本体の手順）

- [ ] 2.1 節「レビューの周を主に聞かずに続ける（直し方の判定）」を「PR トークン上限」の節のあと・「保留で止まるときの引き継ぎ」の前に新設する。中身は delta spec `dev-workflow-develop` の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement どおり（規則・判定役・定義の 3 条件・入力・返答の 1 行目と不足時の 1 回の依頼し直し・判定の記録の書式・続行と事後報告の書式とトークンの 2 つの値の取り方・主に聞くとき・守備範囲）。書式は 1 行目の正規表現と `項目名: 値` の表で示す 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:201-203（新設）
- [ ] 2.2 1 ループの (2) の 2 周キャップの行を、「既定 2 周。2 周目以降の周の終わりに BLOCKER が残れば節『レビューの周を主に聞かずに続ける（直し方の判定）』の判定を通し、決まっていて PR トークン上限の内側なら主に聞かず W を `段: spec` で再開 → R1 に差分再レビュー、選び直しが要るなら needs-approval と引き継ぎ」に書き換える 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:89-95
- [ ] 2.3 (4) の Status の列挙に `needs-fix-check` を足し、failed の行の「2 周キャップ。範囲と 3 周目の扱いは…」はそのまま残したうえで、`needs-decider →` の段落の前に `needs-fix-check →` の段落を足す（PR トークン上限を測る → 決める役を起こす → 判定の記録を記録先に投稿 → 判定と URL を渡して照合と振り分けの G を起こす。本体は自分でラベルを付け替えず W も再開しない。周の結果を受け取ったら事後報告） 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:122、plugins/dev-workflow/skills/develop/SKILL.md:156-158
- [ ] 2.4 「保留で止まるときの引き継ぎ」の場面の説明で、「レビューの 2 周キャップ超え」が「直し方の判定が選び直しが要るとされたとき」を指すことを 1 句添える（待ち理由の値 `2 周キャップ超え` は変えない） 触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:205-207

## 3. spec-reviewer.md（R1 の往復の上限）

- [ ] 3.1 「往復の上限」を書き換える: 既定 2 周・3 周目以降も差分再レビュー・2 周目以降の周の終わりに BLOCKER が残ったら本体が直し方の判定を通し、残った BLOCKER がすべて直し方の決まったもので PR トークン上限の内側なら主に聞かず次の周を回す（R1 は次の周も差分再レビューで応じる）・主に聞くのは方針の選び直しが要るときと `pr-token-budget.sh` が exit 2 のときだけ・選び直しのときは従来どおり `needs-approval`（interactive は AskUserQuestion、unmanned はサイクル終了）。判定と書式は develop SKILL.md の節を指す。「3 周目の例外は設けない」の行は消す。結果コメントの例の周回数が 3 周目以降もありうることが分かるよう、書式の説明の「周回数」はそのままでよい 触る範囲: plugins/dev-workflow/skills/develop/references/roles/spec-reviewer.md:80-84

## 4. pr-review-gate の triage.md（G の手順）

- [ ] 4.1 周の終わりの段落（表の直後）を、「同じ型の再発は順 6、それ以外は全件が 1 周目なら順 2〜4 に当たるときだけ直し方の判定（`needs-fix-check`）、そうでなければ順 5」に書き換える。表の 6 行は変えない 触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:32
- [ ] 4.2 混在の段落のあとに、直し方の判定と順 6 が混ざったときの処理順（判定を先にする → 決まっているなら `needs-decider` → 裁定後に 1 回の failed。選び直しなら既存の順 5・6 の混在の処理順）を足す 触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:34-41
- [ ] 4.3 収束ルールを書き換える: 「3周目を自動で開けない」を 3 条件（直し方の判定の「決まっている」で PR トークン上限の内側／主の「この PR で直す」／順 6 の「全部列挙してから直す」）に置き換え、2周目の終わりにやることの手順 3 を「順 6・直し方の判定・順 5」に、決める役の段落を「順 6 の方式と直し方の判定の 2 つだけを裁定する」に改める。判定の記録と事後報告の書式は develop SKILL.md の節を指すだけにする 触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:63-76
- [ ] 4.4 「G として動くとき（develop）」に `### needs-fix-check のとき` を足し（本体に渡すもの: 判定に回す指摘ごとの仮の順と根拠、仕分けの PR コメント URL、順 6・未裁定の指摘があればその一覧）、return の書式の見出しに `needs-fix-check` を足す。「この段で起こされたときの入力」に「直し方の判定の受領」（URL を仕分け欄に書き、決まっているなら仮の順で W に戻す・順 6 が未裁定なら `needs-decider`、選び直しなら順 5）を足し、「W の修正後の再レビュー」の「3 周目に入るのは主の回答または決める役の裁定があったときだけ」を 3 条件に直す 触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:109-139

## 5. gate-runner.md（G の Status と表）

- [ ] 5.1 Gate Result の Status に `needs-fix-check` を足し、`周回:` の「3以降（主の回答または決める役の裁定あり）」を「3以降（直し方の判定・主の回答・決める役の裁定のどれかあり）」にする。`次の段:` の表の `needs-reviewer / needs-decider` の行に `needs-fix-check` を足す。Status ごとの欄の置き場の文に `needs-fix-check` は `stages/triage.md` と足す。段ごとの表の照合と振り分けの行に、起こす時点「直し方の判定を受け取ったとき」・渡すもの「直し方の判定と判定の記録の URL」・返しうる Status `needs-fix-check` を足す 触る範囲: plugins/dev-workflow/skills/develop/references/roles/gate-runner.md:60-93

## 6. 記録と確認

- [ ] 6.1 変更の記録 `plugins/dev-workflow/changes/722.md` を書く（何が変わったか・受け入れたリスク（主が見ないまま 3 周目以降の修正が進み、止めるのはトークン上限と方針の選び直しの判定だけ。2026-10-07 に主が認めた）・判定役に決める役を選んだ理由） 触る範囲: plugins/dev-workflow/changes/722.md（新規）
- [ ] 6.2 `scripts/test.sh spec-decision-and-review develop-skill` が exit 0、`scripts/test.sh pr-review-gate-skill` が exit 0、`scripts/test.sh dev-workflow` が exit 0 であることを確かめる（文言の変更で落ちた既存テスト（例: `develop-roles.bats` の gate-runner の検査、`model-escalation-policy.bats` の `2 周キャップ`）は、この change の要件に合わせて直す。期待を緩めるだけの書き換えはしない） 触る範囲: scripts/test.sh（実行のみ）
- [ ] 6.3 `openspec validate review-round-auto-continue --strict` が exit 0 であることを確かめる 触る範囲: openspec/changes/review-round-auto-continue/（実行のみ）
