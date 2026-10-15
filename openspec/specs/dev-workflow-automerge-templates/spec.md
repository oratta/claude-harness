# dev-workflow-automerge-templates Specification

## Purpose
TBD - created by archiving change promote-pr-review-gate-to-dev-workflow. Update Purpose after archive.
## Requirements
### Requirement: auto-merge workflow 一式がテンプレートとして配布される

dev-workflow プラグインは `templates/auto-merge/` に、展開先リポのツリーをそのまま鏡写しにした形（`.github/workflows/auto-merge.yml` / `.github/workflows/revert-pr.yml` / `docs/auto-merge.md` / `scripts/test-auto-merge-workflow.sh`）と展開手順 `README.md` を含む（SHALL）。テンプレートはリポ固有の差し替え箇所を既存マーカー（`# >>> sacred-paths` / `# >>> required-checks` 等）で明示し、README がそれ以外を変更せずに展開できる手順を提供する（SHALL）。

#### Scenario: テンプレートファイル群の存在

- **WHEN** `plugins/dev-workflow/templates/auto-merge/` を確認する
- **THEN** README.md と、展開先ツリーを鏡写しにした `.github/workflows/auto-merge.yml` / `.github/workflows/revert-pr.yml` / `.github/workflows/staging-smoke.yml` / `.claude/settings.json` / `docs/auto-merge.md` / `scripts/test-auto-merge-workflow.sh` の計 7 ファイルが存在する

#### Scenario: 差し替え箇所のマーカーが揃っている

- **WHEN** テンプレートの auto-merge.yml を検査する
- **THEN** `sacred-paths` / `sacred-paths-jq` / `required-checks` / `labeled-target` / `passed-head-binding` / `pre-merge-recheck` / `automerge-script` のマーカー対（`# >>> name` と `# <<< name`）がすべて存在し、revert-pr.yml には `revert-script` のマーカー対が存在する

#### Scenario: README が展開手順を提供する

- **WHEN** templates/auto-merge/README.md を読む
- **THEN** リポ展開時に必ず差し替える 3 点（聖域パス定義・REQUIRED_CHECKS と展開先 ci.yml のジョブ名の一致・`AUTOMERGE_PAT` の発行と Secrets 登録）と、`AUTOMERGE_PAUSED` による緊急停止・revert-pr.yml による巻き戻しの運用手順が記載されている

### Requirement: テンプレートは flatmate で実証済みの安全不変条件を維持する

テンプレートの auto-merge.yml は次の安全不変条件を維持する（SHALL）: 素の `pull_request` トリガーを持たない、`pull_request_target` のイベント種は labeled のみ、`actions/checkout` や head の clone を行わない、マージは `gh pr merge` ではなく REST API に検証済み HEAD SHA をピンして行う、`agent-review:passed` ラベルは判定時の HEAD SHA と一致する「対象 HEAD: <40桁フル SHA>」コメント（pr-review-gate スキルの宣言・証拠コメント規約）が実在しない限り合格として扱わない（stale passed の fail-closed 無効化。コメント取得失敗もマージしない側に倒す）、PAT 未設定時と `AUTOMERGE_PAUSED` 設定時は fail-closed で何もマージしない。revert-pr.yml は revert PR の作成までを行いマージしない（SHALL NOT merge）。revert-pr.yml は、対象 PR の base（`.base.ref`）が既定ブランチ以外なら拒否し（SHALL）、マージコミットが既定ブランチの履歴に含まれること（`git merge-base --is-ancestor`）を副作用（ブランチ作成・push）より前に検証し（SHALL）、部分失敗後の re-run（RUN_ID 同一・attempt 増加）では既存の revert ブランチと revert PR を発見して残工程だけを続行する（SHALL）。

#### Scenario: 安全不変条件の退行検知

- **WHEN** このリポの CI（bats テスト）がテンプレートを検査する
- **THEN** 素の `pull_request` トリガーの不在・checkout / clone の不在・`gh pr merge` の不在・`-f sha=` による SHA ピンの存在・合格ラベルの HEAD 束縛（`対象 HEAD: $HEAD_SHA` 照合・不一致時 continue・取得失敗の fail-closed）の存在・`AUTOMERGE_PAUSED` と PAT 未設定の fail-closed 分岐の存在が機械的に検証され、破れていればテストが落ちる

#### Scenario: 攻撃再現テストが展開先で実行可能

- **WHEN** テンプレートを展開したリポの CI が test-auto-merge-workflow.sh を実行する
- **THEN** 聖域パス正規表現の挙動検査・rename 迂回の封鎖・合格ラベルの HEAD 束縛（照合の存在・`$HEAD_SHA` 変数の同一性・不一致時 continue・ラベルチェック後〜マージ前の位置）・REQUIRED_CHECKS と ci.yml ジョブ名の一致・埋め込みスクリプトの構文がすべて機械検証される

#### Scenario: 合格後 push の stale passed はマージされない

- **WHEN** HEAD A で `agent-review:passed` が付与された後にコミット B が push され、いずれかのトリガーで判定 run が走る
- **THEN** PR コメントに「対象 HEAD: <B の40桁フル SHA>」が実在しないため PR はスキップされ、B はマージされない（スキップ理由がログに出る）

#### Scenario: revert の base/ancestor 検証と再開の退行検知

- **WHEN** CI（automerge-templates.bats と test-auto-merge-workflow.sh）が revert-pr.yml の実行コード（コメント除去済みの revert-script ブロック）を検査する
- **THEN** `.base.ref` の取得と `$BASE_BRANCH` 不一致の拒否・`merge-base --is-ancestor` が revert / push より前にあること・`ls-remote` / `gh pr list` による既存状態の発見が push / `gh pr create` より前にあることが機械検証され、破れていればテストが落ちる

### Requirement: staging スモーク + auto-revert が auto-merge テンプレートの一部として配布される

テンプレートは `.github/workflows/staging-smoke.yml` を含み、`Deploy to Staging` という名前の workflow の完了イベント（`workflow_run` / `completed`）を購読して staging の外形スモークを実行し、失敗時に revert PR（`incident` ラベル付き。人間のレビュー待ちであることを本文に書く）と incident issue の両方を起票する経路を持たなければならず（MUST）、機械生成の revert PR に `agent-review:passed` ラベルと「対象 HEAD:」コメントを自己付与してはならない（MUST NOT。ゲートを迂回して auto-merge に乗る経路を作らない。`agent-review:passed` は人間がレビューして付ける）。全チェックが認証系（3xx / 401 / 403）だけで落ちた場合は「デプロイ保護で検証不能」と判定して revert 経路に入らず警告 issue のみ起票する誤検知ガードを持ち（MUST）、その判定は bats テストが smoke ステップのスクリプトを実行して固定する（SHALL）。README は staging を持つリポだけに展開する手順（差し替え箇所・`vars.STAGING_DOMAIN`・bypass secret）を提供する（SHALL）。

#### Scenario: 誤検知ガード（認証系のみで落ちたときは revert しない）

- **WHEN** smoke ステップのスクリプト（`# >>> smoke-script` マーカーの間）を、全チェックが HTTP 401 を返す curl スタブで実行する
- **THEN** exit code は 1 で `GITHUB_OUTPUT` に `blocked=true` が出力され、revert ジョブの条件 `needs.smoke.outputs.blocked != 'true'` を満たさない

#### Scenario: 認証系以外の失敗が 1 件でもあれば revert する

- **WHEN** 同スクリプトを、1 件が 401・残りが 500 を返すスタブで実行する
- **THEN** exit code は 1 で `blocked=true` は出力されず、revert ジョブの条件を満たす

#### Scenario: revert 経路と incident 経路の存在

- **WHEN** staging-smoke.yml の revert ステップ（`# >>> smoke-revert-script` マーカーの間）を検査する
- **THEN** `git revert` / `gh pr create` / `gh issue create` と `incident` ラベル付与が存在し、`agent-review:passed` ラベル付与・「対象 HEAD:」コメント投稿・`gh pr merge` は存在しない

#### Scenario: main が検査したコミットから進んでいれば自動 revert せず incident のみ

- **WHEN** revert ステップのスクリプトを、origin/main の先頭が検知対象のデプロイのコミット（`workflow_run.head_sha`）と異なる状態で、`gh` をスタブにして実行する
- **THEN** exit code は 0 で incident issue が起票され、revert ブランチの push と `gh pr create` は行われない（後続のデプロイで壊れた staging を理由に、正常な先行コミットを巻き戻さない）

#### Scenario: incident は revert の成否に依存せず起票され、再実行で revert PR が回復する

- **WHEN** revert ステップのスクリプトを、`gh pr create` が失敗するスタブで実行し、その後スタブを成功させて同じスクリプトを再実行する
- **THEN** 1 回目は revert PR の作成より前に incident issue が起票されたうえで非 0 で終わり、2 回目は push 済みの revert ブランチを再利用して revert PR を作成し、incident issue を重複起票しない

### Requirement: deny 設定が auto-merge 配線と同じ場所から配布される

テンプレートは `.claude/settings.json` に、LLM による `gh pr merge`・main / master への直接 push・force push（`-f` / `--force` / `--force-with-lease`）・`--no-verify` push を塞ぐ `permissions.deny` 断片を含まなければならない（MUST）。README は展開先の既存 `.claude/settings.json` に既存の deny を消さずにマージする手順を提供し（SHALL）、docs/auto-merge.md は各 deny が塞ぐ経路を説明する（SHALL）。配布経路は他のプラグインに依存しない（SHALL）。

#### Scenario: deny 断片の内容

- **WHEN** `templates/auto-merge/.claude/settings.json` を jq で検査する
- **THEN** `permissions.deny` に `Bash(gh pr merge:*)` / `Bash(git push origin main:*)` / `Bash(git push origin master:*)` / `Bash(git push -f:*)` / `Bash(git push --force:*)` / `Bash(git push --force-with-lease:*)` / `Bash(git push --no-verify:*)` の 7 件が含まれる

#### Scenario: 既存 settings.json へのマージで既存 deny が残る

- **WHEN** README のマージコマンド（jq 式）を、既存の deny と他キー（allow / env）を持つ settings.json とテンプレートの断片に対して実行する
- **THEN** 既存 deny・allow・env が保持され、テンプレートの deny が和集合で足され、重複は 1 件に畳まれる

### Requirement: 運用ガイドはリポ非依存の記述で提供される

テンプレートの README と運用ガイド（`docs/auto-merge.md`）は特定リポの URL を直書きせず、`<owner>/<repo>` 形式のプレースホルダまたは相対参照で記述する（SHALL）。

#### Scenario: flatmate URL の不在

- **WHEN** templates/auto-merge/ 配下の全ファイルを検査する
- **THEN** `genetta-inc/flatmate` の直書きが存在しない

### Requirement: 自動マージの処理は親の判断の印を受け取り、聖域接触だけで付いた human-merge を見送りの理由から外す

展開先（`.github/workflows/auto-merge.yml`）と原本（`plugins/dev-workflow/templates/auto-merge/.github/workflows/auto-merge.yml`）の auto-merge.yml は、聖域パスの正規表現 `SACRED` とは別に、マージ条件そのもののパスの正規表現 `MERGE_CONDITION` をマーカー `# >>> merge-condition-paths` 〜 `# <<< merge-condition-paths` の間に持たなければならない（MUST）。原本の既定は `^\.github/workflows/` で、claude-harness の展開先は `^\.github/workflows/|^plugins/dev-workflow/skills/pr-review-gate/|^plugins/dev-workflow/templates/auto-merge/` である（SHALL）。`MERGE_CONDITION` に一致するパスは `SACRED` にも一致しなければならない（MUST）。

auto-merge.yml は、親の判断の印があるかをマーカー `# >>> parent-merge-judgment` 〜 `# <<< parent-merge-judgment` の 1 か所で判定し、次の 4 つをすべて満たすときだけ `PARENT_OK` を真にしなければならない（MUST）。

1. PR に `parent-merge-approved` ラベルがあり、かつ PR コメントのうち投稿者の `author_association` が `OWNER`・`MEMBER`・`COLLABORATOR` のどれかで、1 行目がちょうど `親のマージ判断: 可`、本文のある行がちょうど `親が見た HEAD: <判定時の HEAD の 40 桁 SHA>` のものが 1 件以上ある（行の比較の前に本文から `\r` を取り除く。Web UI から投稿されたコメントの改行 `\r\n` でも一致させるため）
2. `human-merge` が付いていて、`human-merge` 以外の見送りラベル（`BLOCKING_LABELS` のうち `needs-human-merge`・`human-only`・`needs-approval`）が 1 つも付いていない
3. 変更ファイルの一覧（変更後のパスと rename 元のパス）のどれかが `SACRED` に一致する
4. 変更ファイルの一覧（変更後のパスと rename 元のパス）のどれも `MERGE_CONDITION` に一致しない

コメントの取得に失敗したとき、判定時の HEAD が 40 桁の 16 進でないときは `PARENT_OK` を偽にしなければならない（MUST。マージしない側に倒す）。

印が `human-merge` より先に付いた聖域接触の PR は、初回の判定では条件 2 を満たさないので `PARENT_OK` が偽になり、聖域判定で `human-merge` が付いて見送られる。次の判定（次のイベントか定期実行）で条件 2 を満たし、`PARENT_OK` が真になる（SHALL）。

`PARENT_OK` が真のときに限り、auto-merge.yml は見送りラベルの判定で `human-merge` を見送りの理由に数えず、聖域判定で `human-merge` を付けて見送る代わりに次の判定へ進まなければならない（MUST）。それ以外の条件（`agent-review:passed`・`対象 HEAD:` による合格の HEAD 束縛・必須チェックの green・`AUTOMERGE_PAUSED` の全停止・`AUTOMERGE_PAT` 未設定の fail-closed・SHA ピンのマージ・draft と base の判定）は `PARENT_OK` によって変えてはならない（MUST NOT）。`human-merge` 以外の見送りラベルを `PARENT_OK` によって外してはならない（MUST NOT）。マージ直前の取り直し（`pre-merge-recheck`）でも同じ判定をやり直し、そのとき `PARENT_OK` が偽なら `human-merge` を見送りの理由に数えなければならない（MUST）。

`pull_request_target: labeled` で起動したジョブは、付いたラベルが `agent-review:passed` か `parent-merge-approved` のときに判定を走らせなければならない（SHALL）。イベント種は labeled のまま変えてはならない（MUST NOT）。`PARENT_OK` で進んだ PR は、判定ログに 1 行その旨を出し、マージ後のコメントに親の判断で `human-merge` を外したことと、印のコメントの URL を書かなければならない（SHALL）。

運用ガイド（展開先と原本の `docs/auto-merge.md`）は、`human-merge` を外せる 4 つの条件、`MERGE_CONDITION` のパスと `SACRED` との関係、印の書式（`parent-merge-approved` ラベルと `親のマージ判断: 可`・`親が見た HEAD:` の行）、親の判断があっても他の見送りラベルと他の条件はそのまま効くこと、マージされないときの調べ方、聖域に触れる PR を親の判断からも外したいときは `human-merge` ではなく `human-only` か `needs-approval` を付けることを書かなければならない（SHALL）。「マージの実行権は常に自動マージの処理の側で、LLM が直接マージすることは禁止」の原則は変えずに書く（SHALL）。原本の README は、必ず差し替える 3 点を変えずに、`merge-condition-paths` を任意の差し替え箇所（既定の `^\.github/workflows/` のままでも動き、リポ固有のマージ条件があれば足す）として書く（SHALL）。

この要件の守備範囲で入力として扱うのは、判定時に REST で取る PR のラベル・コメント（本文と `author_association`）・変更ファイルの一覧（`filename` と `previous_filename`）と HEAD の SHA だけである。拾いたい誤りは、マージ条件そのものに触れる PR を親の判断でマージすること、人が手で付けた `human-merge`（聖域に触れていない PR のもの）や他の見送りラベルを親の判断で外すこと、親が見たあとに push されたコミットを親の判断で入れること、親の判断のコメントを既存の合格の HEAD 束縛として数えること、の 4 つである。次はこの要件では止めない: 主の資格情報で動くセッションが印を付けること（誰が付けたかは区別しない。手順書の規則で扱う）／印のコメントの 2 行目以降の他の行の書き方／印の判断の中身の正しさ／聖域に触れる PR に人が手で付けた `human-merge` と処理が付けた `human-merge` の区別（運用ガイドで `human-only`・`needs-approval` を使うよう案内する）。抜け穴を塞ぎ切ることをこの要件の完了条件にしない。

#### Scenario: 聖域だけに触れ、印がある PR はマージに進む

- **WHEN** `agent-review:passed` と今の HEAD の `対象 HEAD:` コメントがあり、必須チェックが green で、変更ファイルが `rules/example.md` だけ、ラベルが `human-merge` と `parent-merge-approved`、OWNER の投稿で 1 行目 `親のマージ判断: 可`・`親が見た HEAD: <今の HEAD>` の行を持つコメントがある PR を判定する
- **THEN** `PARENT_OK` が真になり、`human-merge` で見送られず、`human-merge` も付け直されず、マージに進む。判定ログとマージ後のコメントに親の判断で `human-merge` を外したことが出る

#### Scenario: マージ条件そのものに触れる PR は印があってもマージしない

- **WHEN** 上と同じ印があり、変更ファイルに `.github/workflows/ci.yml`（または claude-harness の展開先で `plugins/dev-workflow/skills/pr-review-gate/SKILL.md`、または rename 元が `.github/workflows/old.yml` のファイル）を含む PR を判定する
- **THEN** `PARENT_OK` が偽になり、`human-merge` で見送られる

#### Scenario: 印の HEAD が今の HEAD と違えばマージしない

- **WHEN** 印のコメントの `親が見た HEAD:` が前の HEAD で、そのあとにコミットが push された PR を判定する
- **THEN** `PARENT_OK` が偽になり、`human-merge` で見送られる

#### Scenario: 印が human-merge より先に付いた PR は次の判定でマージに進む

- **WHEN** 聖域だけに触れ、印（ラベルとコメント）があり、まだ見送りラベルが 1 つも付いていない PR を判定し、そのあと同じ HEAD のまま次の判定が走る
- **THEN** 初回の判定では `PARENT_OK` が偽になり、聖域判定で `human-merge` が付いて見送られる。次の判定では `PARENT_OK` が真になり、マージに進む

#### Scenario: Web UI から投稿された印のコメント（改行が \r\n）も数える

- **WHEN** 聖域だけに触れ `human-merge` と `parent-merge-approved` が付いた PR の印のコメントの本文が、`親のマージ判断: 可\r\n親が見た HEAD: <今の HEAD>\r\n` のように `\r\n` で改行されている
- **THEN** `PARENT_OK` が真になる

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

