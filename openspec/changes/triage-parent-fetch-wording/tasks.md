## 1. 手順書

- [x] 1.1 `stages/triage.md` の段 C の段落を直す: 取得コマンドの末尾に ` 2>&1`、「候補探しの前」を「段 B の前に済ませる」に、やり直しの出力も同じ判定にかける、親の取得が失敗し続けたときの答えは記録先の本文に足す、`sub_issues` に足す要求の形、守備範囲の許す誤りの 2 件（「親が見えず 404 になる場合」と「別リポジトリの親で、すでに親の子である同じ場所の issue があっても新しい子 issue ができること」。今の段 C に許容の文は無いので、条件なしで段 C に spec の守備範囲と同じ語句で追加する）。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:106（段 C の段落）、同:95-99（段 B の「親」の言及。「候補探しの前」が残っていないか確かめる）
- [x] 1.2 `gate-runner.md` の「条件の答えを受け取ったとき」の段落に 1 句足す。触る範囲: plugins/dev-workflow/skills/develop/references/roles/gate-runner.md:119
- [x] 1.3 `reviewer-brief.md` の入口の節に 1 句足す。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/reviewer-brief.md:9

## 2. spec

- [ ] 2.1 main の spec への反映は archive で行う（delta は `specs/dev-workflow-pr-review-gate/spec.md`。要件 3 件の MODIFIED）。手順書の語句と delta の語句を同じにする。触る範囲: openspec/specs/dev-workflow-pr-review-gate/spec.md:2043、同:2134-2149、同:2229

## 3. 検査

- [x] 3.1 bats に、反映した語句ごとの検査を足す（受け入れ条件 3・4 の語句: ` 2>&1`、「段 B の前に済ませる」、「やり直しの出力も同じ判定にかける」、「このときの答えは記録先の本文に足す」、`-X POST repos/<親のリポジトリ>/issues/<親の番号>/sub_issues -F sub_issue_id=<id>`、守備範囲の 2 件（「親が見えず 404 になる場合」を含む）、「親が別リポジトリなら親のリポジトリの本文」が 3 ファイルにある）。triage.md と、反映後の main の spec の両方を見る。触る範囲: plugins/dev-workflow/tests/pr-review-gate-skill.bats:633-700 の近く（段 C の既存の検査の隣）
- [ ] 3.2 `bats plugins/dev-workflow/tests/pr-review-gate-skill.bats` が exit 0
- [x] 3.3 変更の記録 `plugins/dev-workflow/changes/1519.md` を書く（PR 本文に項目 1 の選択理由を 1 行書く）。触る範囲: plugins/dev-workflow/changes/1519.md（新規）
