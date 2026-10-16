## 1. 手順書と仕様の文言を広げる

- [ ] 1.1 SKILL.md 手順 6 末尾の「`--watch-done` 付きの `wait` が stdout に何も出さず exit 1 で終わった」を「`--watch-done` か `--watch-stopped` を付けた `wait` が…」に直す。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:432-432（手順 6 の末尾 1 文）
- [ ] 1.2 `openspec/specs/dev-workflow-develop/spec.md` の同じ文（要件「Orca 経路の本体は印が付いた子のワークスペースを片付ける」）を直し、シナリオを 1 件足す。触る範囲: openspec/specs/dev-workflow-develop/spec.md:1719-1719
- [ ] 1.3 `bats plugins/dev-workflow/tests/epic-dispatch.bats` を通す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats（実行のみ）
