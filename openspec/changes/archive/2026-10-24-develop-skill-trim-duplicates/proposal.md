# Proposal

## Why

develop の SKILL.md には、前提が消えてもう起きない分岐と、同じ規則を別のファイルや同じファイルの別の節に二度書いている箇所が残っている（一覧は issue #1239 のコメント https://github.com/oratta/claude-harness/issues/1239#issuecomment-6367437989 ）。読む量が増えるうえ、直すときに片方だけ直し忘れて規則が食い違う原因になる。この change は、一覧のうち SKILL.md と `references/handover.md` に掛かる項目（B1・B2・C1〜C11。C5 は SKILL.md 側だけ）を反映する。

## What Changes

- **形骸化した分岐を消す**
  - B1: 1 ループの (3) の「(3a) の return に PR 番号と仕様宣言のコメント URL が既に揃っていれば (3b) を指示せず (4) へ進む」を消す。古いキャッシュの手順入り `worker.md` を読んだ W が (3) を通しで返す場面のための分岐で、#556（PR #610）で `worker.md` が手順を持たない索引になり、W が `段:` の行の指す段のファイルだけを読むようになって起きなくなった。spec の同じ MUST と Scenario も外す（「自分が指示した工程で決め、文字列照合で決めない」は残す）
  - B2: 「モデル」節の「実行戦略の分岐はもう無く、」を消す（指す先が手順書に無い）
- **重複を正本 1 か所と参照にまとめる**（正本の置き場所は一覧の「正本と根拠」列に従う。他のテストが文面を固定している箇所の扱いは design.md）
  - C1 remote 隔離の禁止と理由 → 正本「worktree の用意」、前提の表は参照
  - C2 Draft PR が記録先のときの PR 本文の書き方 → 正本 `references/roles/worker/spec.md`「記録先の用意」、入口 0 は参照
  - C3 自動選択の margin の求め方と構成の選び方 → 正本 `references/codex-develop.md`、SKILL.md は開始コメントに残す行と記録の義務だけ
  - C4 profile role の再開前の上限の再確認と fresh thread への手渡し → 正本 `references/codex-develop.md`
  - C5（SKILL.md 側）G の起動指示の `レビュー経路: adapter` の行 → SKILL.md の中では 1 か所に寄せる
  - C6 会話で受けた返事を `owner-reply-check.sh` で確かめる括弧書き → 正本 `references/handover.md`、SKILL.md の (4) の保留と再開の手順 2 は参照
  - C7 (2) の 2 周目以降の周の終わりの続行 → 正本 `references/fix-check.md`
  - C8 残量モード・共有枠モードの効果 → 正本 `references/decision-criteria.md` の表
  - C9 失敗ループで一方だけ上げるラダー → 正本 `templates/escalation-tripwires.md`、SKILL.md は 1 か所で参照
  - C10 W の上限は `opus` → 正本は「モデル」節の表、ほかは参照
  - C11 unmanned で複数 change に割れたときの子 issue の作り方 → 正本 `references/roles/worker/spec.md`「分割判定」
- 変更の記録 `plugins/dev-workflow/changes/1239.md` を足す

振る舞いは変えない（本体と W がすることは同じで、どこに書くかだけが変わる）。B1 だけは本体の分岐を 1 つ消すが、その分岐に入る入力がもう来ない。

## Capabilities

### New Capabilities

なし

### Modified Capabilities

- `dev-workflow-develop`: 「W の (3) は 2 回の return に分かれる」から B1 の MUST と Scenario を外す。「役割のモデルは事前分類と残量モードで決める」で、残量モードと共有枠モードの効果を SKILL.md に再掲せず `decision-criteria.md` の表を正本にする（C8）

## Impact

- `plugins/dev-workflow/skills/develop/SKILL.md`（B1・B2・C1〜C11）
- `plugins/dev-workflow/skills/develop/references/handover.md`（C6 の正本を置き、再開の手順 2 を参照にする）
- `plugins/dev-workflow/tests/develop-skill.bats`（B1・C8・C10 の検査を新しい形に合わせる）
- `plugins/dev-workflow/changes/1239.md`（新規）
- 範囲外: `commands/develop.md`・`references/codex-develop.md` の書き換え（#1307）、`references/epic.md`（#1308）、spec が SKILL.md の節を名指ししている件（#1241）
