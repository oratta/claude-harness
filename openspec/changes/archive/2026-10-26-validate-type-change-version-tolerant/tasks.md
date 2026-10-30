## 1. テストを先に直す（bats）

- [x] 1.1 実測テスト「openspec CLI: a change with only a delta spec needs --type change to validate」の名前を「...validates with --type change on every openspec version」に変え、`--type change` 付きは終了コード 0 を必須、付けない形は「終了コード 0」か「終了コード 1 かつ `Unknown item`」のどちらでも通す形にする。確かめ方: openspec 1.14.1 で `bats plugins/dev-workflow/tests/spec-wording-sync-light-path.bats` が全件 ok。触る範囲: plugins/dev-workflow/tests/spec-wording-sync-light-path.bats:372-407
- [x] 1.2 文言を見るテスト「worker/implement: wording-sync path ...」は `Unknown item`・`--changes`・`チェックボックスの確認は行わない` の語が残る形のまま通ることを確かめる（直すなら新しい文言に合わせる）。触る範囲: plugins/dev-workflow/tests/spec-wording-sync-light-path.bats:160-165

## 2. 指示書の文を直す

- [x] 2.1 `worker/implement.md` の文言合わせの通し方の括弧書きを、`--type change` を付けない形の結果は版で変わる（`Unknown item` で終了コード 1 の版も、終了コード 0 の版もある）、`--changes --strict` はこの change を検査しない版があるので使わない、に直す。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker/implement.md:11
- [x] 2.2 `worker/spec.md` の「（`--type change` が無いと change を見つけられない）」を、版で結果が変わるが付ければ版によらず change として検証される、に直す。触る範囲: plugins/dev-workflow/skills/develop/references/roles/worker/spec.md:92
- [x] 2.3 `SKILL.md` 122 行目は `--type change` を付ける指示だけで断定が無いので変えない（確認のみ）。触る範囲: plugins/dev-workflow/skills/develop/SKILL.md:122

## 3. 確認

- [x] 3.1 `openspec validate validate-type-change-version-tolerant --strict` と `bats plugins/dev-workflow/tests/spec-wording-sync-light-path.bats` を通す。`grep -rn "見つけられ" plugins/dev-workflow/skills | grep -v "版"` が 0 行（版に触れない古い断定が残っていない）
- [x] 3.2 `plugins/dev-workflow/changes/1269.md` に変更の記録を書く
