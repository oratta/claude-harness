## ADDED Requirements

### Requirement: ゲート合格まで PR を Draft のまま扱い、合格処理で Ready にする
手順 5（合格処理）は、`needs-approval` が付いていないことを Ready 化より前に確認しなければならない（MUST。付いたまま Ready 化だけ済ませると、保留中の PR が Draft でなくなる）。そのうえで、PR が Draft（`gh api repos/$R/pulls/$N --jq .draft` が `true`）なら `gh pr ready` を実行してから `agent-review:passed` を付けなければならない（MUST）。順序は Ready 化 → passed 付与でなければならない（MUST）。passed を先に付けると、その labeled イベントは PR が draft のため auto-merge にスキップされ、Ready 化で CI が走らないリポでは次の判定が日次 schedule まで来ないためである。PR が Draft でなければ `gh pr ready` を実行してはならない（MUST NOT。人間が作った非 Draft の PR をそのまま通す）。合格処理の最後の実測確認には、ラベル 3 点に加えて PR の `draft` が `false` であることを含めなければならない（MUST）。

手順 1 で stale な `agent-review:passed` を外したとき、PR が Draft でなければ `gh pr ready --undo` で Draft に戻さなければならない（MUST）。passed が付いていなかった場合（初回のゲート・failed からの再レビュー・保留からの再開）は Draft に戻してはならない（MUST NOT）。

#### Scenario: Draft の PR は Ready にしてから passed を付ける
- **WHEN** SKILL.md の手順 5 を読む
- **THEN** PR の `draft` を取得し、`true` のときだけ `gh pr ready` を実行する手順が `agent-review:passed` を付ける API 呼び出しより前に書かれている

#### Scenario: 順序の理由が書かれている
- **WHEN** SKILL.md の手順 5 の Ready 化の記述を読む
- **THEN** passed を先に付けると labeled イベントが draft でスキップされ、Ready 化で CI が走らないリポでは日次の判定まで拾われないことが理由として書かれている

#### Scenario: 実測確認に draft が含まれる
- **WHEN** SKILL.md の手順 5 の最後の実測確認の表を読む
- **THEN** `agent-review:passed` がある・`agent-review:pending` がない・`needs-approval` がない、に加えて PR の `draft` が `false` である行がある

#### Scenario: 人間が作った非 Draft の PR では Ready 化を行わない
- **WHEN** Draft でない PR がゲートの手順 5 に来る
- **THEN** SKILL.md は Ready 化を「Draft なら」の条件付きで書いており、非 Draft の PR には `gh pr ready` を実行しない

#### Scenario: 取り直しで stale passed を外すと Draft に戻す
- **WHEN** SKILL.md の手順 1 の stale passed を外す記述を読む
- **THEN** passed を外したときに PR が Draft でなければ `gh pr ready --undo` を実行する手順があり、passed が付いていなかった場合は Draft に戻さないと書かれている

#### Scenario: G の指示書が Ready 化を含む
- **WHEN** `skills/develop/references/roles/gate-runner.md` のやることと passed の return 書式を読む
- **THEN** 手順 5 の要約に Ready 化（Draft なら）が入っており、passed の return に Ready 化の結果（実施した／対象外）を書く欄がある
