## ADDED Requirements

### Requirement: G はレビュー経路を起動指示の 1 行で判別する
本体は G を起動する指示と再開する指示の両方に、`レビュー経路: adapter` または `レビュー経路: 従来` のどちらか 1 行を書かなければならない（MUST）。adapter 経路とは、実行先を自動選択・明示 profile・旧形式の account/model 指定のいずれかで adapter（`codex-develop.py request`）に解決させている develop を指す。本体は adapter 経路では `レビュー経路: adapter` を必ず書かなければならない（MUST）。

`gate-runner.md` は、G がこの行だけで経路を判別し、環境変数・記録先のコメント・自分の起動方法から推測しないことを書かなければならない（MUST）。行が無いときは従来経路として扱うことを書かなければならない（MUST）。`SKILL.md` は、G の起動・再開指示に `レビュー経路:` を書く本体の責任を、Role profile の選択節と (4) の両方に書かなければならない（MUST）。

#### Scenario: adapter 経路の G 起動
- **WHEN** 本体が自動選択（profile も旧形式も無指定）で develop を進め、(4) で G を起動する
- **THEN** G の起動指示に `レビュー経路: adapter` の行があり、G はこの行を見て adapter 経路の規則に従う

#### Scenario: 行が無い G 起動
- **WHEN** `レビュー経路:` の行を含まない指示で G が起動される
- **THEN** G は従来経路として扱い、full では今までどおり Bash から Codex を直接呼ぶ

#### Scenario: 手渡し後の G 再開
- **WHEN** 本体が adapter 経路の G を SendMessage で再開する、または手渡しで後任の G を起動する
- **THEN** その指示にも `レビュー経路: adapter` の行がある

### Requirement: adapter 経路の G はレビュアーを自分で呼ばず needs-reviewer を返す
`gate-runner.md` は、G（phase `gate` として起動された G）が `レビュー経路: adapter` のとき、full でも light でも `codex exec`・`codex-companion.mjs`・レビュアーを自分で呼ばず、手順 1（前提を揃える・HEAD SHA の固定）と手順 2-0（light / full の判定と `レビュー重量:` コメント）を済ませてから `needs-reviewer` を返すことを書かなければならない（MUST）。full のときの payload の判定は `full（adapter 経路）` とし、Codex 不可の実測を行わないことを書かなければならない（MUST）。

この規則は phase `review` のレビュアーとして起動されたときには適用しないと限定しなければならない（MUST）。従来経路の既定（full は G の Bash から Codex を直接呼び、Codex が使えないときと light のときだけ `needs-reviewer` を返す）は変えてはならない（MUST NOT）。

#### Scenario: adapter 経路の full レビュー
- **WHEN** `レビュー経路: adapter` で起動された G が手順 2-0 で full と判定する
- **THEN** G は Codex を起動せず、判定 `full（adapter 経路）`・HEAD SHA・受け入れ条件の所在を含む `needs-reviewer` を返す

#### Scenario: 従来経路の full レビュー
- **WHEN** `レビュー経路: 従来` で起動された G が手順 2-0 で full と判定する
- **THEN** G は Bash から `codex exec` または `codex-companion.mjs` で Codex を呼ぶ

#### Scenario: phase review のレビュアーが gate-runner.md を読む
- **WHEN** Codex に委譲された phase `review` のレビュアーが `gate-runner.md` を読む
- **THEN** adapter 経路の `needs-reviewer` 規則は G 向けに限定されており、レビュアーは自分でレビューを行う

### Requirement: 本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する
`SKILL.md` の (4) は、adapter 経路で G から `needs-reviewer` を受けた本体の手順として、次の順序を書かなければならない（MUST）: `codex-develop.py request --phase review` で投げ先を選び直す（実行先オプションはその develop の開始時と同じ）→ 返った選択（構成・reason・Claude と最良 Codex の margin・各 `fetched_at`。欠測は `missing`）と解決した executor / model を記録先の dispatch 記録に投稿する → 投稿に成功してから、選ばれた投げ先でレビュアーを起動する → レビュー要約を G に渡す（渡し方は `codex-develop.md` の規則に従う）。

本体は選び直しと記録の前にレビュアーを起動してはならない（MUST NOT）。従来経路で `needs-reviewer` を受けたときの本体の手順は変えてはならない（MUST NOT）。

#### Scenario: claude-default が選ばれる
- **WHEN** adapter 経路（自動選択）で G が `needs-reviewer` を返し、`request --phase review` が構成 `claude-default`・executor `claude`・model `opus` を返す
- **THEN** 本体は構成・reason・両 provider の margin と `fetched_at` を記録先に投稿してから、Agent ツールで `opus` のレビュアーを起動し、Codex を呼ばない

#### Scenario: Codex が選ばれる
- **WHEN** adapter 経路で `request --phase review` が executor `codex` の request を返す
- **THEN** 本体は選択を記録先に投稿してから request を実行し、結果を G に渡す

#### Scenario: 回帰テスト
- **WHEN** `bash scripts/test.sh` を実行する
- **THEN** `gate-runner.md`・`SKILL.md`・`codex-develop.md` の上記文言を照合する bats を含めて exit 0 になる
