# Tasks

行番号は HEAD 333b8419 時点の値。前のタスクの編集でずれるので、編集する前に該当範囲を読んで確かめる。`触る範囲:` のパスは `plugins/dev-workflow/` からの相対（`openspec/` だけはリポジトリ直下）。確認のコマンドはリポジトリ直下で打つ。bats は `npx --yes bats@1.10.0` で回す。各項目の中身（何を残し何を外すか）は design.md の項目ごとの表が正本。

## 1. 変更前の記録

- [x] 1.1 変更前の字数（`python3 -c 'print(len(open(p).read()))'`）を SKILL.md と handover.md で測って控え、`npx --yes bats@1.10.0 tests/`（リポジトリ直下、328 件全通過）と `npx --yes bats@1.10.0 plugins/dev-workflow/tests/develop-*.bats`（331 件全通過）の件数を控える。確認: 控えた 4 つの値が手元にある。触る範囲: skills/develop/SKILL.md（全体・読むだけ）、skills/develop/references/handover.md（全体・読むだけ）

## 2. 消す項目（B1・B2）

- [x] 2.1 B1: (3) の「(3a) の return に PR 番号と仕様宣言のコメント URL が既に揃っていれば…(4)（G の工程）へ進む」の 2 行を消し、「自分が (3a) を指示したか (3b) を指示したかで決め、工程名の文字列照合では決めない」は残す。develop-skill.bats の「loop: main routes stage 3 by what it instructed…」の 2 本目の grep を、その文が無いことを見る否定の検査に置き換える。確認: `npx --yes bats@1.10.0 plugins/dev-workflow/tests/develop-skill.bats`（以下 develop-skill.bats）が通る。触る範囲: skills/develop/SKILL.md:133-135（1 ループ (3)）、tests/develop-skill.bats:271-278
- [x] 2.2 B2: 「モデル」節の 1 文目から「実行戦略の分岐はもう無く、」を消す。確認: `grep -c '実行戦略の分岐' plugins/dev-workflow/skills/develop/SKILL.md` が 0、develop-skill.bats が通る。触る範囲: skills/develop/SKILL.md:260（モデル節の冒頭）

## 3. 「モデル」節を正本＋参照にする（C8・C9・C10）

- [x] 3.1 C8: 残量モードの段落を、`FABLE_BUDGET_MODE`・`SHARED_BUDGET_MODE` の名前と「効果は `references/decision-criteria.md` の残量モードと共有枠モードの表が正本で、ここに再掲しない」の 1 文にする。develop-skill.bats の「model: reserve only for automatic runs…」と「model: shared budget mode sets the floor…」を、「モデル」節に 2 つの名前と `references/decision-criteria.md` があり `abundant`・`reserve`・`exhausted`・`throttled`・`depleted` の 5 値のどれについても効果の文が無いこと、効果の文が `decision-criteria.md` にあることを見る検査にする。spec の差分「役割のモデルは事前分類と残量モードで決める」（作成済み）と文面が合っていることを確かめる。確認: develop-skill.bats が通る。触る範囲: skills/develop/SKILL.md:272（モデル節の残量モードの段落）、tests/develop-skill.bats:297-303、tests/develop-skill.bats:313-319、openspec/changes/develop-skill-trim-duplicates/specs/dev-workflow-develop/spec.md:58-80（読むだけ）
- [x] 3.2 C9: 昇格トリップワイヤーの段落を、発火の条件・決める役と実行役のどちらか一方だけを上げる（両方同時に上げない）・判断側なら `dev-workflow:decider`、実行側なら W を `opus`・ラダーの正本は `templates/escalation-tripwires.md`・「W の上限は『モデル』節の表の W の行（`opus`）」の 1 句（3.3 の C10 で残す）だけにし、判断側と実行側の言い換えと `opus` → `fable` の段を外す。(4) の failed の括弧書きを「どちらを上げるかは『モデル』節の昇格トリップワイヤーの段落」の参照にする（「実装品質起因のときだけ」「一方だけ」「dev-workflow:decider」は残す）。コンテキスト上限と規模超過の文は残す。確認: develop-skill.bats が通る。触る範囲: skills/develop/SKILL.md:274（モデル節の昇格トリップワイヤーの段落）、skills/develop/SKILL.md:179-182（1 ループ (4) の failed）
- [x] 3.3 C10: (1) の spawn の行と (4) の failed から「W の上限は opus」「W を fable にはしない」を外し、(1) は「model は『モデル』節の表の W の行」の参照にする。昇格トリップワイヤーの段落は「W を fable にはしない」などの言い換えを外し、「W の上限は『モデル』節の表の W の行（`opus`）」の 1 句を残す（spec の Scenario「失敗ループでは片方だけ上げる」が実行役の上限 `opus` を求めるため）（`references/pre-classification.md` の「1 周目」列を指す部分は残す）。表の W の行と、その下の上限を `opus` にした理由の段落はそのまま。develop-skill.bats の「loop: G failed raises only the cause side (never W to fable)…」の `W を fable にはしない` の grep を、failed の行が「モデル」節を指していることの検査に置き換え、「モデル」節の昇格トリップワイヤーの段落に `W の上限は『モデル』節の表の W の行（`opus`）` があることの検査を足す。確認: `grep -c 'W を fable にはしない' plugins/dev-workflow/skills/develop/SKILL.md` が 0、develop-skill.bats が通る。触る範囲: skills/develop/SKILL.md:103（1 ループ (1)）、skills/develop/SKILL.md:179-182、skills/develop/SKILL.md:274、tests/develop-skill.bats:177-187

## 4. 前提・入口・Role profile を正本＋参照にする（C1〜C5）

- [ ] 4.1 C1: 前提の表の Agent ツールの行から remote 隔離の禁止と理由を外し、「隔離の決まりは『worktree の用意』」の参照にする。「worktree の用意」の本文は変えない。確認: `npx --yes bats@1.10.0 plugins/dev-workflow/tests/develop-roles.bats` と develop-skill.bats が通る。触る範囲: skills/develop/SKILL.md:42（前提の表 Agent ツールの行）
- [ ] 4.2 C2: 入口 0 の 2 つの箇条を、受け入れ条件を PR 本文に書く・`Closes #N` / `Fixes #N` / `Refs #N` を書かない、の名前を残した 1 文の参照にまとめ、正本 `references/roles/worker/spec.md`「記録先の用意」を指す。develop-skill.bats の入口 0 の検査に、`worker/spec.md` の「記録先の用意」を指していることの検査を足す。確認: develop-skill.bats が通る。触る範囲: skills/develop/SKILL.md:84-85（入口 0）、tests/develop-skill.bats:113-117
- [ ] 4.3 C3: 「Role profile の選択」の 1 段落目から margin の式と構成の選び方を外し、正本 `references/codex-develop.md`「起動と role 解決」への参照にする。記録の義務（構成名 3 つ・reason・両 provider の margin / fetched_at・代表 Codex account・欠測は `missing`）と `実行モード:`・`チャンネルの返事の確認:` の行は残す。確認: `python3 -m pytest plugins/dev-workflow/tests/test_codex_develop.py`（pytest が無ければ `python3 -m unittest` で同じファイル）と `npx --yes bats@1.10.0 plugins/dev-workflow/tests/develop-channel-mode.bats` が通る。触る範囲: skills/develop/SKILL.md:22（Role profile の選択の 1 段落目）
- [ ] 4.4 C4: 「Role profile の選択」の最後の段落を、正本 `references/codex-develop.md`「本体が行う操作」への参照 1 文（`FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` の上限の再確認・SendMessage しない・工程完了か停止確認・requested tuple を変えない・fresh thread の名前を残す）と、「以下の spawn / SendMessage 表記は profile 利用時にこの規則を適用した provider 操作を意味する」の 1 文にする。確認: test_codex_develop.py が通る。触る範囲: skills/develop/SKILL.md:28（Role profile の選択の最後の段落）
- [ ] 4.5 C5: 「Role profile の選択」節の `レビュー経路` の段落は変えない。(4) の起動指示の行の括弧書きから「Codex の G では request の instructions にも」を外し、「理由と書き方の細目は『Role profile の選択』節」の参照にする。「常に `レビュー経路: adapter`」「`レビュー経路: 従来` は書かない」は残す。確認: `npx --yes bats@1.10.0 plugins/dev-workflow/tests/develop-adapter-review-routing.bats` が通る。触る範囲: skills/develop/SKILL.md:142-143（1 ループ (4) の起動指示）

## 5. 保留の返事の日時の手順を handover.md の 1 か所にする（C6）

- [ ] 5.1 C6: handover.md の「保留で止まるときの引き継ぎ」節に、会話で受けた返事の日時を `owner-reply-check.sh` で取る手順（MATCH: 行の timestamp・複数出たとき・出ないとき・終了コード 1・2）を、太字の見出し「**会話で受けた返事の日時の取り方**」の段落として置く。SKILL.md の (4) の保留の行と handover.md の再開の手順 2 から同じ手順の文を外す。保留の行は「`owner-reply-check.sh` を回す前に `references/handover.md` の『会話で受けた返事の日時の取り方』を Read する」の指示の形にし、手順 2 はその段落を名前で指す。保留の行の「リスク許容を会話で受けたら主に PR へのコメントを求めず」「エピックの子が親経由で」「『親から届いた返事』」と、手順 2 の `CLAUDE_CODE_SESSION_ID` は残す。develop-skill.bats に、保留の行に `owner-reply-check.sh` を回す前にその段落を Read する指示があることと、手順 2 がその段落の名前を指していることと、`MATCH: が複数出たら` の文が handover.md に 1 か所だけあることの検査を足す。確認: develop-skill.bats と `npx --yes bats@1.10.0 plugins/dev-workflow/tests/develop-handover.bats` が通る。触る範囲: skills/develop/references/handover.md:37-39（37 行の段落と 39 行の `### 新しいセッションでの再開` のあいだに新しい段落）、skills/develop/references/handover.md:46（再開の手順 2）、skills/develop/SKILL.md:184（1 ループ (4) の保留の行）、tests/develop-skill.bats（入口 0 の検査の近くか (4) の保留の検査の近くに追加）

## 6. unmanned の分割の段落を参照にする（C11）

- [ ] 6.1 C11: 「実行モード」節の unmanned の分割の段落を、正本 `references/roles/worker/spec.md`「分割判定」への参照 1 文にする。子 issue・`blocked_by`・サイクルを終える、の語は残し、「Discord で質問し」の文は外す。確認: develop-skill.bats が通る。触る範囲: skills/develop/SKILL.md:284（実行モード節の unmanned の分割の段落）

## 7. 変更の記録

- [ ] 7.1 `changes/1239.md` を新しく作り、何を消し何を参照にしたか（B1・B2・C1〜C11）と、C5・C7 を一覧の判定どおりにまとめなかった理由（固定しているテスト・C7 は #1222 の意図）を書く。確認: ファイルがあり、既存の `changes/*.md` と同じ形式になっている。触る範囲: changes/1239.md（新規）

## 8. 全体の確認と PR 本文への記録

- [ ] 8.1 変更後の字数（SKILL.md と handover.md、python の len）と、`npx --yes bats@1.10.0 tests/`（リポジトリ直下）と `npx --yes bats@1.10.0 plugins/dev-workflow/tests/develop-*.bats` の変更後の結果を測り、1.1 の変更前の値（328 件全通過・331 件全通過）と並べて PR 本文に記録する。C5・C7 で残した重複と残す理由、範囲外として本体に返す件（固定しているテストの書き換え）も PR 本文に書く。確認: 両方の bats が変更前と同じく全通過し、`npx --yes bats@1.10.0 plugins/dev-workflow/tests/spec-decision-and-review.bats` と test_codex_develop.py も通り、PR 本文に変更前後の字数と件数がある。触る範囲: PR 本文（(3b) で作る PR）

## Workflow follow-up

- archive と PR の作成は (3b) で行う
