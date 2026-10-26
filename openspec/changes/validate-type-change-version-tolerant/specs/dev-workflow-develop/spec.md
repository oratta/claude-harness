## MODIFIED Requirements

### Requirement: W の仕様化経路は openspec CLI だけで進める
`dev-workflow:worker` は `Skill` を持たないので、W は仕様化・実装の検証・archive を openspec CLI で行わなければならない（MUST）。仕様化は `openspec new change` と artifact の直書き（雛形と書き方の指示は `openspec instructions <artifact> --change <name>`、依存順は `openspec status --change <name>` で得る）、実装の検証は `openspec validate <change> --strict` と `tasks.md` のチェックボックスの確認、archive は `openspec archive <change>` で行う（SHALL）。工程の区切り（(1) 仕様化まで／(3a) 実装＋verify／(3b) archive＋PR＋仕様宣言）は変えない（SHALL）。R1 の仕様レビューも、文言合わせの通し方（次の段落）を除いて変えない（SHALL）。

文言合わせの通し方（`dev-workflow-spec-review` の「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）では、change に proposal.md が無いので、W は実装の検証を `openspec validate <change> --type change --strict` で行わなければならない（MUST。`--type change` を付けない形の結果は openspec の版で変わる。change を見つけられず `Unknown item` で終了コード 1 になる版も、change として検証して終了コード 0 になる版もある。付けておけば版によらず change として検証され、spec と同名のときの曖昧さも避けられる。`openspec validate --changes --strict` もこの change を検査しない版があるので使わない）。`tasks.md` が無いのでチェックボックスの確認は行わない（SHALL）。`openspec archive <change>` は見出しが既存の要件名と一致しないとき、何も変えずに終了コード 0 で終わるので、W は archive のあと `openspec/changes/archive/` に change のディレクトリがあることを確かめる（MUST）。`references/roles/worker/implement.md` と `references/roles/worker/finish.md` はこの 2 点を書かなければならない（MUST）。

W の仕様化経路があるかどうかは `openspec --version` が成功するかだけで決めなければならない（MUST）。`.claude/commands/opsx/` の有無で決めてはならない（MUST NOT）。opsx コマンドがあっても openspec CLI が無ければ、W は `仕様化判断: しない` の理由に「openspec 不在」と書いてコード直行する（SHALL）。

`references/roles/worker.md` で `/opsx:` のスラッシュコマンドが出てよいのは、本体や主が対話で `/opsx:*` を使う場面（例: W が来る前に本体や主が `/opsx:ff` で change を作っていた場合）を述べる行だけで、その行は `本体` か `主` の語を含まなければならない（MUST）。W が `/opsx:*` を実行する指示を書いてはならない（MUST NOT）。

#### Scenario: worker.md が CLI の経路で書かれている
- **WHEN** `plugins/dev-workflow/skills/develop/references/roles/worker.md` を読む
- **THEN** `openspec new change`・`openspec validate`・`openspec archive` を使う手順があり、(3a) の節と (3b) の節に `/opsx:` の文字列が無く、`/opsx:` を含む行はどれも `本体` か `主` の語を含む

#### Scenario: 文言合わせの通し方の検証コマンドが書かれている
- **WHEN** `references/roles/worker/implement.md` の実装と verify の記述と、`references/roles/worker/finish.md` の archive の記述を読む
- **THEN** `implement.md` に文言合わせの通し方では `openspec validate <change-name> --type change --strict` を使うことが書かれ、`finish.md` に archive のあと `openspec/changes/archive/` に change のディレクトリがあることを確かめることが書かれている

#### Scenario: proposal.md の無い change を名前だけで検証する
- **WHEN** `specs/<capability>/spec.md` だけを持つ change に `openspec validate <change> --type change --strict` を実行する
- **THEN** 差分が検査され、正しい差分なら版によらず終了コード 0 で終わる。`--type change` を付けない形は、終了コード 0 で終わるか、`Unknown item` と出て終了コード 1 で終わるかのどちらかで、どちらになるかは openspec の版で決まる

#### Scenario: 経路の有無を CLI だけで決める
- **WHEN** `worker.md` の仕様化判断の節と、`develop/SKILL.md` の前提の表の openspec の行を読む
- **THEN** W の経路の有無を `openspec --version` で決めることが書かれ、`worker.md` に `ls .claude/commands/opsx/` による検出が無い
