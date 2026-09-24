## MODIFIED Requirements

### Requirement: 本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する
`SKILL.md` の (4) は、adapter 経路で G から `needs-reviewer` を受けた本体の手順として、次の順序を書かなければならない（MUST）: `codex-develop.py request --phase review` で投げ先を選び直す（実行先オプションはその develop の開始時と同じ）→ 返った選択（構成・reason・Claude と最良 Codex の margin・各 `fetched_at`。欠測は `missing`）と解決した executor / model を記録先の dispatch 記録に投稿する → 投稿に成功してから、選ばれた投げ先でレビュアーを起動する → レビュー要約と、選ばれた executor / model・dispatch 記録のコメント URL を G に渡す。

review phase の executor が `codex` のときは、本体は worker の結果 JSON にある `execution.model_resolution.requested` と `execution.model_resolution.resolved` も G に渡さなければならない（MUST）。G は `レビュー実行者:` 行の `<model>` を `<requested>→<resolved>` の形で記録しなければならない（MUST）。解決値が未観測のときは要求値や dispatch 時の model から補完してはならない（MUST NOT）。

渡し方は G の起動形で分けて書かなければならない（MUST）: Claude の G は SendMessage で再開して渡す（`gate-runner.md`「needs-reviewer の return」節と `SKILL.md` の (4) の既存規則）。Codex の G は新しい phase `gate` を開始してその入力に渡す（`codex-develop.md`「品質と transport 差分」の G の項）。

本体は選び直しと記録の前にレビュアーを起動してはならない（MUST NOT）。従来経路（`レビュー経路: 従来` または行が無い G）が `needs-reviewer` を返したときに呼び出し元がレビュアーを起こす手順（`gate-runner.md` の既存記述）は変えてはならない（MUST NOT）。

`gate-runner.md` と `pr-review-gate/SKILL.md` は、adapter 経路で要約を受け取った G の「レビュー実行者:」コメントの形 `レビュー実行者: <executor>/<model>（adapter 経路・<light|full>・dispatch 記録: <URL>）` を持たなければならない（MUST）。`<light|full>` には手順 2-0 の判定を書く。executor が `codex` なら `<model>` は `execution.model_resolution.requested` と `resolved` を使った `<requested>→<resolved>` とし、executor が `claude` なら従来の model 値を使う。`pr-review-gate/SKILL.md` の「レビュー実行者:」の書き分けと PR コメント雛形にこの 1 形を足し、gate-runner.md と正本が食い違わないようにしなければならない（MUST）。

#### Scenario: claude-default が選ばれる
- **WHEN** adapter 経路（自動選択）で G が `needs-reviewer` を返し、`request --phase review` が構成 `claude-default`・executor `claude`・model `opus` を返す
- **THEN** 本体は構成・reason・両 provider の margin と `fetched_at` を記録先に投稿してから、Agent ツールで `opus` のレビュアーを起動し、Codex を呼ばない。要約を渡すとき `claude/opus` と dispatch 記録の URL も G に渡す

#### Scenario: Codex が選ばれる
- **WHEN** adapter 経路で `request --phase review` が executor `codex` の request を返し、worker の結果 JSON の `execution.model_resolution` が requested=`sol`、resolved=`gpt-6-sol` を返す
- **THEN** 本体は選択を記録先に投稿してから request を実行し、レビュー要約・dispatch 記録 URL とともに requested=`sol`、resolved=`gpt-6-sol` を G に渡す

#### Scenario: G がレビュー実行者を記録する
- **WHEN** adapter 経路の G が本体から Codex レビュー要約と requested=`sol`、resolved=`gpt-6-sol`、dispatch 記録の URL を受け取る
- **THEN** G は `レビュー実行者: codex/sol→gpt-6-sol（adapter 経路・<light|full>・dispatch 記録: <URL>）` の PR コメントを投稿し、その埋め方は `pr-review-gate/SKILL.md` の雛形にも説明される

#### Scenario: 回帰テスト
- **WHEN** `bash scripts/test.sh` を実行する
- **THEN** `gate-runner.md`・`SKILL.md`・`codex-develop.md`・`pr-review-gate/SKILL.md` の上記文言を照合する bats を含めて exit 0 になる
