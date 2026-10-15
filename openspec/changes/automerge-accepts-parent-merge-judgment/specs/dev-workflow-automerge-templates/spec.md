## ADDED Requirements

### Requirement: 自動マージの処理は親の判断の印を受け取り、聖域接触だけで付いた human-merge を見送りの理由から外す

展開先（`.github/workflows/auto-merge.yml`）と原本（`plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml`）の auto-merge.yml は、聖域パスの正規表現 `SACRED` とは別に、マージ条件そのもののパスの正規表現 `MERGE_CONDITION` をマーカー `# >>> merge-condition-paths` 〜 `# <<< merge-condition-paths` の間に持たなければならない（MUST）。原本の既定は `^\.github/workflows/` で、claude-harness の展開先は `^\.github/workflows/|^plugins/dev-workflow/skills/pr-review-gate/|^plugins/dev-workflow/templates/auto-merge/` である（SHALL）。`MERGE_CONDITION` に一致するパスは `SACRED` にも一致しなければならない（MUST）。

auto-merge.yml は、親の判断の印があるかをマーカー `# >>> parent-merge-judgment` 〜 `# <<< parent-merge-judgment` の 1 か所で判定し、次の 4 つをすべて満たすときだけ `PARENT_OK` を真にしなければならない（MUST）。

1. PR に `parent-merge-approved` ラベルがあり、かつ PR コメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のどれかで、1 行目がちょうど `親のマージ判断: 可`、本文のある行がちょうど `親が見た HEAD: <判定時の HEAD の 40 桁 SHA>` のものが 1 件以上ある
2. 付いている見送りラベル（`BLOCKING_LABELS`）が `human-merge` だけである
3. 変更ファイルの一覧（変更後のパスと rename 元のパス）のどれかが `SACRED` に一致する
4. 変更ファイルの一覧（変更後のパスと rename 元のパス）のどれも `MERGE_CONDITION` に一致しない

コメントの取得に失敗したとき、判定時の HEAD が 40 桁の 16 進でないときは `PARENT_OK` を偽にしなければならない（MUST。マージしない側に倒す）。

`PARENT_OK` が真のときに限り、auto-merge.yml は見送りラベルの判定で `human-merge` を見送りの理由に数えず、聖域判定で `human-merge` を付けて見送る代わりに次の判定へ進まなければならない（MUST）。それ以外の条件（`agent-review:passed`・`対象 HEAD:` による合格の HEAD 束縛・必須チェックの green・`AUTOMERGE_PAUSED` の全停止・`AUTOMERGE_PAT` 未設定の fail-closed・SHA ピンのマージ・draft と base の判定）は `PARENT_OK` によって変えてはならない（MUST NOT）。`human-merge` 以外の見送りラベルを `PARENT_OK` によって外してはならない（MUST NOT）。マージ直前の取り直し（`pre-merge-recheck`）でも同じ判定をやり直し、そのとき `PARENT_OK` が偽なら `human-merge` を見送りの理由に数えなければならない（MUST）。

`pull_request_target: labeled` で起動したジョブは、付いたラベルが `agent-review:passed` か `parent-merge-approved` のときに判定を走らせなければならない（SHALL）。イベント種は labeled のまま変えてはならない（MUST NOT）。`PARENT_OK` で進んだ PR は、判定ログに 1 行その旨を出し、マージ後のコメントに親の判断で `human-merge` を外したことを書かなければならない（SHALL）。

運用ガイド（展開先と原本の `docs/auto-merge.md`）は、`human-merge` を外せる 4 つの条件、`MERGE_CONDITION` のパスと `SACRED` との関係、印の書式（`parent-merge-approved` ラベルと `親のマージ判断: 可`・`親が見た HEAD:` の行）、親の判断があっても他の見送りラベルと他の条件はそのまま効くこと、マージされないときの調べ方を書かなければならない（SHALL）。「マージの実行権は常に自動マージの処理の側で、LLM が直接マージすることは禁止」の原則は変えずに書く（SHALL）。原本の README は `merge-condition-paths` をリポ固有の差し替え箇所として書く（SHALL）。

この要件の守備範囲で入力として扱うのは、判定時に REST で取る PR のラベル・コメント（本文と `author_association`）・変更ファイルの一覧（`filename` と `previous_filename`）と HEAD の SHA だけである。拾いたい誤りは、マージ条件そのものに触れる PR を親の判断でマージすること、人が手で付けた `human-merge`（聖域に触れていない PR のもの）や他の見送りラベルを親の判断で外すこと、親が見たあとに push されたコミットを親の判断で入れること、親の判断のコメントを既存の合格の HEAD 束縛として数えること、の 4 つである。次はこの要件では止めない: 主の資格情報で動くセッションが印を付けること（誰が付けたかは区別しない。手順書の規則で扱う）／印のコメントの 2 行目以降の他の行の書き方／印の判断の中身の正しさ。

#### Scenario: 聖域だけに触れ、印がある PR はマージに進む

- **WHEN** `agent-review:passed` と今の HEAD の `対象 HEAD:` コメントがあり、必須チェックが green で、変更ファイルが `rules/example.md` だけ、ラベルが `human-merge` と `parent-merge-approved`、OWNER の投稿で 1 行目 `親のマージ判断: 可`・`親が見た HEAD: <今の HEAD>` の行を持つコメントがある PR を判定する
- **THEN** `PARENT_OK` が真になり、`human-merge` で見送られず、`human-merge` も付け直されず、マージに進む。判定ログとマージ後のコメントに親の判断で `human-merge` を外したことが出る

#### Scenario: マージ条件そのものに触れる PR は印があってもマージしない

- **WHEN** 上と同じ印があり、変更ファイルに `.github/workflows/ci.yml`（または claude-harness の展開先で `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`、または rename 元が `.github/workflows/old.yml` のファイル）を含む PR を判定する
- **THEN** `PARENT_OK` が偽になり、`human-merge` で見送られる

#### Scenario: 印の HEAD が今の HEAD と違えばマージしない

- **WHEN** 印のコメントの `親が見た HEAD:` が前の HEAD で、そのあとにコミットが push された PR を判定する
- **THEN** `PARENT_OK` が偽になり、`human-merge` で見送られる

#### Scenario: human-merge 以外の見送りラベルは外さない

- **WHEN** 印があり聖域だけに触れた PR に、`human-merge` に加えて `needs-approval`（または `needs-human-merge`・`human-only`）が付いている
- **THEN** `PARENT_OK` が偽になり、その見送りラベルで見送られる

#### Scenario: 聖域に触れていない PR の human-merge は外さない

- **WHEN** 変更ファイルが聖域に一致しない PR に人が `human-merge` を付け、印もある
- **THEN** `PARENT_OK` が偽になり、`human-merge` で見送られる

#### Scenario: ラベルだけ、コメントだけ、投稿者が外部の印は数えない

- **WHEN** 聖域だけに触れた PR に、`parent-merge-approved` ラベルだけがある、印のコメントだけがある、または印のコメントの投稿者の `author_association` が `NONE` か `CONTRIBUTOR` である
- **THEN** どの場合も `PARENT_OK` が偽になり、`human-merge` で見送られる

#### Scenario: 親の判断のコメントは合格の HEAD 束縛にならない

- **WHEN** `agent-review:passed` があり、`対象 HEAD: <今の HEAD>` のコメントが無く、印のコメント（`親が見た HEAD: <今の HEAD>`）だけがある PR を判定する
- **THEN** 合格の HEAD 束縛を満たさず見送られる

#### Scenario: マージ直前に印が外されたら止まる

- **WHEN** 初回の判定で `PARENT_OK` が真だった PR から、マージ直前の取り直しまでに `parent-merge-approved` ラベルが外される
- **THEN** 取り直しで `PARENT_OK` が偽になり、`human-merge` で見送られてマージされない

#### Scenario: 原本と展開先に同じ判定がありテストで固定される

- **WHEN** CI（`plugins/dev-workflow/tests/automerge-templates.bats` と、展開先・原本の `scripts/test-auto-merge-workflow.sh`）が auto-merge.yml を検査する
- **THEN** `merge-condition-paths` と `parent-merge-judgment` のマーカー対が両方にあり、`MERGE_CONDITION` の代表パスがすべて `SACRED` に一致し、`rules/`・`CLAUDE.md`・`plugins/*/hooks/` の代表パスが `MERGE_CONDITION` に一致せず、`parent-merge-judgment` の判定をスタブの `gh` で動かして上の各シナリオの真偽どおりになり、ジョブの `if:` が `parent-merge-approved` を受け、`pull_request_target` のイベント種が labeled だけであることが機械的に検証される
