## 1. spec 本体の更新

- [x] 1.1 `openspec/specs/dev-workflow-develop/spec.md` に差分を反映する（MODIFIED の各要件と、REMOVED の「既存要件が worker.md に置いた内容は移し先のファイルを指す」）。反映は `openspec archive` に任せるか、同じ中身に手で直す。触る範囲: `openspec/specs/dev-workflow-develop/spec.md:97-1433`
- [x] 1.2 `openspec/specs/dev-workflow-spec-review/spec.md` に差分を反映する。触る範囲: `openspec/specs/dev-workflow-spec-review/spec.md:7-134`
- [x] 1.3 `openspec/specs/dev-workflow-pr-review-gate/spec.md` に差分を反映する。触る範囲: `openspec/specs/dev-workflow-pr-review-gate/spec.md:579-1456`
- [x] 1.4 `openspec/specs/dev-workflow-subagent-waiting/spec.md` に差分を反映する。触る範囲: `openspec/specs/dev-workflow-subagent-waiting/spec.md:199-225`
- [x] 1.5 `openspec/specs/loops-longrun-retirement/spec.md` の 1 行を直す。触る範囲: `openspec/specs/loops-longrun-retirement/spec.md:37`

## 2. 索引の表を消す

- [x] 2.1 `plugins/dev-workflow/skills/develop/references/roles/worker.md` の節「旧節の移し先」（見出しと表）を消し、冒頭の「旧節の移し先を引くためのもの」の文言を合わせる。触る範囲: `plugins/dev-workflow/skills/develop/references/roles/worker.md:3`、`:13-29`
- [x] 2.2 `plugins/dev-workflow/changes/1331.md` に変更の記録を書く。触る範囲: `plugins/dev-workflow/changes/1331.md`（新規）

## 3. 確かめる

- [x] 3.1 `grep -rnE '(^|[^/a-z])worker\.md' openspec/specs/` の残りが、索引そのものを指す名指し・`agents/worker.md`・履歴の記述・題名に worker.md を含む Scenario 10 件（題名は archive が突き合わせに使うので変えない）だけであることを確かめる
- [x] 3.2 `grep -n '旧節' plugins/dev-workflow/skills/develop/references/roles/worker.md` が 0 件であること、`scripts/test.sh` が通ることを確かめる
