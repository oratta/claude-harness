## Context

C5 の正本は SKILL.md の (4) ではなく「Role profile の選択」節にある（#1239 で、`develop-adapter-review-routing.bats` がその節の全文を固定しているため）。

## Decisions

- **C12 の正本は `codex-develop.md`**。commands 側は「対応表の渡し方は `references/codex-develop.md`、本体は依頼本文から分離して `codex-develop.py request` へ渡す」とだけ書く。`--account-home` / `--account-home-file` の併用拒否・既定 `current` の規則は本文に書き直さない。
- **C5 は義務の文だけを参照にする**。bats が needs-reviewer の行に `G を段ごとに新しく起こし（Claude の G も再開しない）`・`起動指示に行が無い G は従来経路`・`Claude の G は Codex を直接呼ぶ`・`Codex の G は prompt の禁止により呼ばない`・`` `レビュー経路: adapter` `` を求めるため、これらは残し、「すべての起動指示（Codex の G では request の instructions）に常に書く」の義務を述べる部分を参照（SKILL.md『Role profile の選択』節・gate-runner.md『レビュー経路の判別』）に置き換える。
- 不採用: 行ごと削除。spec の要件が codex-develop.md の従来経路の説明を求めており、bats も固定しているため。

## Risks

- 参照先の節名が変わると参照が切れる。節名は bats が固定している。
