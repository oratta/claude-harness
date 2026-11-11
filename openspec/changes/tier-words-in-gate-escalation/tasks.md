## 1. 文言とテスト

- [ ] 1.1 triage.md の 2-2 の節（表・実行役の上限・フォールバック・事前分類の段落）と 185 行目の判断側の提案を、`--failure executor` / `first` / `judgment` と `request` が返した model で書く。Claude の値は括弧書きの例にする。触る範囲: plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:142-169、plugins/dev-workflow/skills/pr-review-gate/stages/triage.md:185
- [ ] 1.2 develop SKILL.md (4) の failed 分岐を判断側 `first|judgment` に揃える。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:187
- [ ] 1.3 README の failed 昇格の説明を格の言葉に揃える。触る範囲: plugins/dev-workflow/README.md:149-150
- [ ] 1.4 bats を直し、2-2 の節が `--failure executor` と `--failure judgment`（1 回目は `--failure first`）を名指しし、`opus` で spawn が 0 件であることを固定する。触る範囲: plugins/dev-workflow/tests/model-escalation-policy.bats:136-176、plugins/dev-workflow/tests/develop-roles.bats:419 付近
- [ ] 1.5 `bats plugins/dev-workflow/tests` が exit 0 で、`openspec validate tier-words-in-gate-escalation --type change --strict` が通る
