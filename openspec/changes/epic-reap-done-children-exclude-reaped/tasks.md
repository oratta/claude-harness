行番号は仕様づくりの時点（HEAD 86157f82）の値で、前のタスクの編集でずれる。編集の前に該当範囲を読んで確かめる。テストを先に書き、落ちることを見てから実装する。

## 1. テスト

- [ ] 1.1 `skill: Orca route watches for done marks...` のテストの隣に、片付け待ちの子から `reaped`（`branch-kept` を含む）と `gone` を除くこと、片付け待ちが 0 件なら `wait` を呼ばず終えることが SKILL.md に書かれていることを確かめるテストを足す。触る範囲: plugins/dev-workflow/tests/epic-dispatch.bats:1510-1524（`skill: Orca route watches for done marks and reaps marked children` の後ろ）

## 2. 手順書

- [ ] 2.1 SKILL.md「エピックの扱い」「Orca 経路」の手順 2（片付け待ちの子の定義）・手順 3（`reaped`・`gone` を外す）・手順 4（0 件なら `wait` を呼ばない）・手順 7（再開時に外す）を delta spec のとおりに直す。「経路の決め方」の段落と `route` は触らない。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:372-380（手順 2・3・4・7）

## 3. 記録と確認

- [ ] 3.1 変更の記録を書く（版は上げない）。触る範囲: plugins/dev-workflow/changes/827.md（新規）
- [ ] 3.2 `bats plugins/dev-workflow/tests/epic-dispatch.bats` と `bash scripts/test.sh`（`tests/injection-budget.bats` を含む。`tests/injection-budget.txt` は触らない）が exit 0。`openspec validate epic-reap-done-children-exclude-reaped --strict` が exit 0。触る範囲: なし
