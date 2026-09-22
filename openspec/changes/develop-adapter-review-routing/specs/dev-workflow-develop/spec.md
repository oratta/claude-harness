## ADDED Requirements

### Requirement: G はレビュー経路を起動指示の 1 行で判別する
develop の本体は、(4) で G を起動する指示・再開する指示・手渡しで後任の G を起動する指示のすべてに、起動形を問わず**常に** `レビュー経路: adapter` の 1 行を書かなければならない（MUST）。条件付きにしてはならない（MUST NOT）。現行の develop は実行先の 3 つの起動形（自動選択・明示 profile・旧形式の account/model 指定）すべてを adapter（`codex-develop.py request`）で解決するため、develop の本体が G を起こす場面はすべて adapter 経路である。Codex の G に対しては、request の instructions（`--input` に渡す指示ファイル）が起動指示に当たり、そこにも同じ行を書かなければならない（MUST）。

`レビュー経路: 従来` は、develop の本体以外の呼び出し元が `gate-runner.md` で G を起こす場合と、行を書かない古い本体のための値であり、develop の本体は書いてはならない（MUST NOT）。

`gate-runner.md` は、G がこの行だけで経路を判別し、環境変数・記録先のコメント・自分の起動方法から推測しないことを書かなければならない（MUST）。行が無いときは従来経路として扱うことを書かなければならない（MUST）。あわせて、`レビュー経路: adapter` は新 Codex モードを含む adapter 解決の全構成（`claude-default` を含む）を指し、従来モードのレビュー実行者の表は `レビュー経路: 従来`（または行が無い）ときだけ適用すると書かなければならない（MUST）。`SKILL.md` は、G の起動・再開指示に常に `レビュー経路: adapter` を書く本体の責任を、Role profile の選択節と (4) の両方に書かなければならない（MUST）。

#### Scenario: 自動選択での G 起動
- **WHEN** 本体が自動選択（profile も旧形式も無指定）で develop を進め、(4) で G を起動する
- **THEN** G の起動指示に `レビュー経路: adapter` の行があり、G はこの行を見て adapter 経路の規則に従う

#### Scenario: 明示 profile で Codex の G を起動
- **WHEN** 本体が明示 profile で develop を進め、phase `gate` の投げ先が Codex で request を作る
- **THEN** request の instructions に `レビュー経路: adapter` の行がある

#### Scenario: 行が無い G 起動
- **WHEN** `レビュー経路:` の行を含まない指示で G が起動される
- **THEN** G は従来経路として扱い、full では今までどおり Bash から Codex を直接呼ぶ

#### Scenario: 手渡し後の G 再開
- **WHEN** 本体が G を SendMessage で再開する、または手渡しで後任の G を起動する
- **THEN** その指示にも `レビュー経路: adapter` の行がある

### Requirement: adapter 経路の G はレビュアーを自分で呼ばず needs-reviewer を返す
`gate-runner.md` は、G（phase `gate` として起動された G）が `レビュー経路: adapter` のとき、full でも light でも `codex exec`・`codex-companion.mjs`・レビュアーを自分で呼ばず、手順 1（前提を揃える・HEAD SHA の固定）と手順 2-0（light / full の判定と `レビュー重量:` コメント）を済ませてから `needs-reviewer` を返すことを書かなければならない（MUST）。full のときの payload の判定は `full（adapter 経路）` とし、Codex 不可の実測を行わないことを書かなければならない（MUST）。adapter 経路の payload では `選んだ経路`・`実行コマンド`・`終了コード`・`出力の要点`・`実待ち時間` を `未実行（adapter 経路）` と書き、Codex の証拠を作らないことを書かなければならない（MUST）。

この規則は phase `review` のレビュアーとして起動されたときには適用しないと限定しなければならない（MUST）。従来経路の既定（full は G の Bash から Codex を直接呼び、Codex が使えないときと light のときだけ `needs-reviewer` を返す）は変えてはならない（MUST NOT）。

#### Scenario: adapter 経路の full レビュー
- **WHEN** `レビュー経路: adapter` で起動された G が手順 2-0 で full と判定する
- **THEN** G は Codex を起動せず、判定 `full（adapter 経路）`・HEAD SHA・受け入れ条件の所在を含み、実行の証拠欄が `未実行（adapter 経路）` の `needs-reviewer` を返す

#### Scenario: 従来経路の full レビュー
- **WHEN** `レビュー経路: 従来` で起動された G が手順 2-0 で full と判定する
- **THEN** G は Bash から `codex exec` または `codex-companion.mjs` で Codex を呼ぶ

#### Scenario: phase review のレビュアーが gate-runner.md を読む
- **WHEN** Codex に委譲された phase `review` のレビュアーが `gate-runner.md` を読む
- **THEN** adapter 経路の `needs-reviewer` 規則は G 向けに限定されており、レビュアーは自分でレビューを行う

### Requirement: 本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する
`SKILL.md` の (4) は、adapter 経路で G から `needs-reviewer` を受けた本体の手順として、次の順序を書かなければならない（MUST）: `codex-develop.py request --phase review` で投げ先を選び直す（実行先オプションはその develop の開始時と同じ）→ 返った選択（構成・reason・Claude と最良 Codex の margin・各 `fetched_at`。欠測は `missing`）と解決した executor / model を記録先の dispatch 記録に投稿する → 投稿に成功してから、選ばれた投げ先でレビュアーを起動する → レビュー要約と、選ばれた executor / model・dispatch 記録のコメント URL を G に渡す。

渡し方は G の起動形で分けて書かなければならない（MUST）: Claude の G は SendMessage で再開して渡す（`gate-runner.md`「needs-reviewer の return」節と `SKILL.md` の (4) の既存規則）。Codex の G は新しい phase `gate` を開始してその入力に渡す（`codex-develop.md`「品質と transport 差分」の G の項）。

本体は選び直しと記録の前にレビュアーを起動してはならない（MUST NOT）。従来経路（`レビュー経路: 従来` または行が無い G）が `needs-reviewer` を返したときに呼び出し元がレビュアーを起こす手順（`gate-runner.md` の既存記述）は変えてはならない（MUST NOT）。

`gate-runner.md` と `pr-review-gate/SKILL.md` は、adapter 経路で要約を受け取った G の「レビュー実行者:」コメントの形 `レビュー実行者: <executor>/<model>（adapter 経路・dispatch 記録: <URL>）` を持たなければならない（MUST）。`pr-review-gate/SKILL.md` の「レビュー実行者:」の書き分けと PR コメント雛形にこの 1 形を足し、gate-runner.md と正本が食い違わないようにしなければならない（MUST）。

#### Scenario: claude-default が選ばれる
- **WHEN** adapter 経路（自動選択）で G が `needs-reviewer` を返し、`request --phase review` が構成 `claude-default`・executor `claude`・model `opus` を返す
- **THEN** 本体は構成・reason・両 provider の margin と `fetched_at` を記録先に投稿してから、Agent ツールで `opus` のレビュアーを起動し、Codex を呼ばない。要約を渡すとき `claude/opus` と dispatch 記録の URL も G に渡す

#### Scenario: Codex が選ばれる
- **WHEN** adapter 経路で `request --phase review` が executor `codex` の request を返す
- **THEN** 本体は選択を記録先に投稿してから request を実行し、結果を G に渡す

#### Scenario: G がレビュー実行者を記録する
- **WHEN** adapter 経路の G が本体からレビュー要約と executor / model・dispatch 記録の URL を受け取る
- **THEN** G は `レビュー実行者: <executor>/<model>（adapter 経路・dispatch 記録: <URL>）` の PR コメントを投稿し、その形は `pr-review-gate/SKILL.md` の雛形にもある

#### Scenario: 回帰テスト
- **WHEN** `bash scripts/test.sh` を実行する
- **THEN** `gate-runner.md`・`SKILL.md`・`codex-develop.md`・`pr-review-gate/SKILL.md` の上記文言を照合する bats を含めて exit 0 になる
