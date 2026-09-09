## ADDED Requirements

### Requirement: 手順書は途中計測と途中停止を前提に書く

develop の手順書は、コンテキスト計測が「本体が再開前に測る」と「起動の途中で hook が測る」の 2 経路あることを記述しなければならない（MUST）。対象は `skills/develop/SKILL.md`、`references/roles/worker.md`、`references/roles/gate-runner.md`、`references/decision-criteria.md`、`templates/escalation-tripwires.md` の 5 本とする（SHALL）。

W / G の指示書は、途中計測の通知（「今の工程を締めて成果を列挙して return せよ」）を受け取ったら、次のツールを呼ばずにその起動を締めて return しなければならない（MUST）と書かなければならない。また、強制停止の閾値を超えると編集系ツールと git 以外の Bash が拒否され、残せるのは commit と return だけになることを書かなければならない（SHALL）。

手渡しで起こされた W / G の指示書は、前任が途中停止で return した可能性があるため、再出発の前に作業ツリーの未コミット差分（`git status` / `git diff`）を確認しなければならない（MUST）と書かなければならない。

#### Scenario: 手順書に途中計測が書いてある

- **WHEN** `SKILL.md` と `references/roles/worker.md` と `references/roles/gate-runner.md` を読む
- **THEN** 再開前チェックに加えて起動の途中でも計測されること、通知を受けたらその起動を締めて return することが書かれている

#### Scenario: 手渡し先が未コミット差分を先に見る

- **WHEN** `references/roles/worker.md` の手渡しの節を読む
- **THEN** 前任が途中停止した可能性があるので `git status` / `git diff` で未コミット差分を先に確認する、と書かれている

#### Scenario: 閾値の環境変数が手順書に載っている

- **WHEN** `references/decision-criteria.md` のコンテキスト上限の節を読む
- **THEN** `DEV_WORKFLOW_CONTEXT_CAP`（通知）と `DEV_WORKFLOW_CONTEXT_HARD_CAP`（強制停止）の両方と、全解除の `DEV_WORKFLOW_CONTEXT_TRIPWIRE=off` が書かれている
