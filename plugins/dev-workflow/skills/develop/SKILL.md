---
name: develop
description: コード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変えるときは必ず通す標準開発ワークフロー。本体はオーケストレータ専任で、作業者 W・仕様レビュアー R1・ゲート実行者 G を model 明示で spawn し、記録先（issue または Draft PR）→ 仕様化判断の記録 → 仕様レビュー → TDD 実装 → pr-review-gate の 1 ループを回す。issue 番号・issue URL・「この issue 対応して」等の自然文、issue の無い会話依頼・cron・エピックの子のいずれからでも起動する。人間依頼（interactive）と loop-dev-agent 無人サイクル（--unmanned）の両対応。
version: 2.1.0
---

# develop — 入口を問わない標準開発ワークフロー（本体＝オーケストレータ）

このスキルは「開発の進め方」を毎回同じに通すための正本で、本体（このスキルを読んでいるメインセッション）は**作業を自分ではせず、役割別のサブエージェントを起こして回す**。役割は 3 つに固定する:

| 役割 | 名前 | 指示書 | 担当 |
|---|---|---|---|
| 作業者 | **W** | `references/roles/worker.md` | 記録先の用意（Draft PR 経路）・仕様化判断の記録・分割判定・`/opsx:ff`・TDD 実装・verify・archive・PR・仕様宣言 |
| 仕様レビュアー | **R1** | `references/roles/spec-reviewer.md` | 実装前の仕様レビュー（別コンテキスト・読み取り専用） |
| ゲート実行者 | **G** | `references/roles/gate-runner.md` | pr-review-gate の手順 1〜5 |

旧スキル（issue 限定の入口で、本体が自分で Step A〜D を実行する手順書だったもの）の後継。反転した理由は 1 つで、Claude Code のサブエージェントは Agent ツールを持たない（孫を spawn できない）ため、本体向けの手順書をサブエージェントに渡すと仕様レビュー・別コンテキストの PR レビュー・fable 昇格がすべて自己レビューに退化するから。別コンテキストを要する工程は**すべて本体が起こす**。

## いつ使うか

ソースコード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変える作業は、依頼の入口を問わず（GitHub issue・会話・cron・エピックの子のいずれでも）このスキルを通す。「issue があるか」は入口 0 で記録先を決める材料にすぎず、スキルを通すかどうかの条件ではない。

例外は「読むだけ・回答だけ・生成物を出すだけ」の作業（調査報告・質問への回答・レポートや図の生成など、リポジトリの追跡対象を変えないもの）に限る。

## 前提

無いときの縮退まで含めて列挙する。本体が spawn できない環境（本体自身がサブエージェント）ではこのスキルは成立しないので、その場合は親に return して親を本体にする。

| 前提 | 使い方 | 無いとき |
|---|---|---|
| **Agent ツール** | W / R1 / G の spawn。`model` を必ず明示し、W と G は**名前付き**で spawn する（SendMessage で再開するため）。W は本体が対象専用の worktree にいなければ `isolation: "worktree"` で起こす | 本体になれない。親セッションに return する |
| **SendMessage** | 名前付きで起こした W / G の再開（コンテキストを引き継いだまま次の工程を指示する）と、G へのレビュー要約の受け渡し | 再開できないので W を毎回新規 spawn し、前回の return 全文をプロンプトに渡す |
| **`gh`** | 記録先（issue / PR）へのコメントとラベル操作、Draft PR の作成、エピックの子の依存（`gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by`、issue dependencies API） | 記録先を作れないので開始しない（記録なしで実装に進まない） |
| **opsx コマンドまたは openspec CLI** | 仕様化経路（`/opsx:ff` → R1 → `/opsx:apply` → verify → archive）。CLI だけなら W が直叩きで同じ工程を踏む | 仕様化経路が発生しない（W は `仕様化判断: しない` の理由に「openspec 不在」と書き、コード直行する） |
| **Codex CLI** | G が full レビューを Bash から `codex exec` / `codex-companion.mjs` で実行する | G が `needs-reviewer` を return し、本体が別のレビュアーを spawn して要約を G に渡す（gate-runner.md） |

## 本体の役割

本体は役割 W / R1 / G を `model` 明示で spawn し、**return の要約と記録先（issue または Draft PR）のコメント・ラベルだけ**を見て次に誰を起こすかを決める。並列可能な役割（エピックの子どうし、独立した change の W どうし）は並列に起こしてよい。

禁止事項（本体がこれをやると、別コンテキストの網が全部外れる）:

- **本体は Edit でコードを書かない。** テスト・実装・仕様ファイルの編集はすべて W の仕事。本体が「小さいから」と直接直した瞬間に、その変更は R1 / G の別コンテキストレビューを通らずに PR に乗る
- **本体はレビューを代行しない。** 仕様レビューは R1、PR レビューは G（と G が要求したレビュアー）が行う。本体が W の return を読んで「よさそう」と判断することはレビューではない
- **W が孫を呼ぶ必要がある工程を設けない。** 別コンテキストを要する工程（R1・G・G のレビュアー）はすべて本体が起こす。W の指示書に「サブエージェントを spawn せよ」と書かない

本体がやること: 入口 0 の記録先の確定、worktree の用意、各役割の spawn と再開、return の要約の転記（記録先のコメントは各役割が自分で投稿する）、needs-approval 時のオーナーへの依頼、エピックの進行管理。

## 入口 0: 記録先を決める

1 ループの最初の工程。仕様化判断・仕様レビュー結果を置く「記録先」を先に確定する。

- **issue があればそれを記録先にする**（番号・URL・自然文マッチ。`/develop` の 5 分岐は `commands/develop.md`）。エピックの子は子 issue が記録先
- **無ければ issue を切らない。** 本体が worktree を用意し、W が worktree 直後に空 commit（`git commit --allow-empty`）を積んで push し、`gh pr create --draft` で Draft PR を開いてそれを記録先にする（GitHub の "open a draft PR early" の慣行）。この Draft PR は**仕様化判断を記録する前**に存在していなければならない — 記録先が無い状態で判定を先に進めない（手順は `references/roles/worker.md`「記録先の用意」）
- Draft PR を記録先にする場合、**受け入れ条件は PR 本文**（位置づけ・動作確認ポイント）に書く。issue に書かない分の省略であって、受け入れ条件自体を省くことはできない
- 記録先を PR にした場合、PR 本文に `Closes #N` / `Fixes #N` / `Refs #N` の issue 参照を**書かない**。書くと pr-review-gate の照合先がその issue に移る（探索順は issue → 無ければ PR 自身のコメント）。エピックの子は子 issue が記録先なので `Closes #子` を書く
- 仕様化判断（`仕様化判断: する|しない`）・仕様レビュー結果（`仕様レビュー: APPROVE|REQUEST_CHANGES`）は記録先のコメントに置く（書式の正本は `references/roles/spec-reviewer.md`「判断記録の契約」）
- **仕様宣言は記録先ではなく常に PR コメントに置く**（記録先が issue でも issue には書かない）。pr-review-gate 手順 5 が PR のコメントでリスク宣言・仕様宣言・動作確認の 3 見出しを照合し、`対象 HEAD:` 規約が PR の HEAD に紐づくため。書式の正本は pr-review-gate スキル手順 3-b

**issue を切るのは追跡・キュー・議論が要るときだけ**: エピック（複数 PR にまたがる。下の「エピックの扱い」）／無人キュー（loop-dev-agent が拾う対象にしたい）／判断を残す議論（決定の経緯を issue スレッドに残したい）。この 3 つに当たらなければ Draft PR で足りる。issue を切る経路は `commands/develop.md` の issueify フォールバック。

## worktree の用意

worktree は**本体が用意する**。本体が既に対象専用の worktree（1 issue = 1 worktree = 1 ブランチ）にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。**W は自分で worktree を切らない**（セットアップは worktree プラグインの `WorktreeCreate` / `SessionStart` hooks が担うので、W は判定もしない）。unmanned では憲法側が用意した worktree を使う。

## 1 ループ（W → R1 → W → G）

1 issue（または 1 Draft PR）につき次を回す。各工程の担い手と、本体が次に誰を起こすかの判断材料を書く。

```
(0) 記録先を確定する（入口 0）。worktree を用意する
(1) W を名前付きで spawn（model: worker.md の事前分類に当たれば fable、それ以外 sonnet。共有枠モードが下限を決める）:
      記録先の用意（Draft PR 経路）→ 仕様化判断の記録 → 分割判定 → /opsx:ff → return「仕様できた」
      仕様化しない判定なら → (3) へ直行（TDD → PR）
(2) R1 を spawn（model: 既定 opus。マージ条件・聖域・層間契約に触れれば fable）:
      references/roles/spec-reviewer.md に従って別コンテキストで仕様レビュー → 結果を記録先にコメント → return
      REQUEST_CHANGES → W を SendMessage で再開して artifact を修正 → R1 を再開して差分再レビュー
      （初回＋差分 1 回の 2 周キャップ。超えたら needs-approval を付けて本体がオーナーに 1 アクションで依頼）
      R1 の APPROVE が記録先に記録されるまで W を apply に進めない（再開しない）
(3) W を SendMessage で再開（再開前に `scripts/subagent-context.sh <W の名前>` で測り、上限超なら再開せず手渡しで新しい W を spawn）:
      apply（TDD。/opsx:apply または直叩き）→ verify → archive → PR を Ready に（または作成）→ 仕様宣言を PR コメントに書く → return「PR #N」
(4) G を名前付きで spawn（model: 既定 opus。ゲートがマージ条件・聖域・層間契約に触れれば fable）:
      pr-review-gate の手順 1〜5 → return「passed / failed / 保留 / needs-reviewer」
      needs-reviewer → 本体がレビュアーを spawn し、要約を SendMessage で G に渡す（gate-runner.md）
      failed → W を再開（再開前にコンテキストを測る。原因分類が実装品質起因なら 1 段昇格、同じテスト 2 連続失敗でも 1 段昇格。sonnet → opus → fable）→ G を再開して差分再レビュー（2 周キャップ。G も再開前に測る）
      保留 → needs-approval のまま本体がオーナーに 1 アクション（許容する／しない、動作確認の結果）で依頼する
```

W は名前付きで spawn し、SendMessage で再開してコンテキストを引き継ぐ（(1) の判定・(2) の指摘・(3) の実装が同じコンテキストにある）。**ただし再開の前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測り、上限（`DEV_WORKFLOW_CONTEXT_CAP`、既定 150000 tokens）を超えていたら再開せず、前回の return を渡して新しい W を spawn する（手渡し。正本は `references/decision-criteria.md`「コンテキスト上限」）。** G の再開も同じ。W が孫を呼ぶ必要がある工程は存在しない。仕様化する場合で複数 change に割れたときは、interactive では change ごとに (1)〜(3) を回す（change ごとに仕様レビューを行う。並列可能なら W を並列に起こす）。

## モデル

役割ごとのモデルは事前分類と残量モードで決める。実行戦略の分岐はもう無く、判断は「どの役割をどのモデルで起こすか」だけ。

| 役割 | 既定 | `fable` に上げる条件 |
|---|---|---|
| W | `sonnet` | `opus`: 記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含む、または失敗ループの昇格。`fable`: `worker.md` の「重要実装の事前分類」表（聖域パス・マージ権限・層間契約・課金/法務。正本は worker.md、ここに再掲しない）に当たる |
| R1 / G | `opus` | 仕様またはゲートの対象がマージ条件・聖域・層間契約に触れる |
| G が要求するレビュアー | `opus` | 同上（G の `needs-reviewer` の推奨モデルに従う） |

W の既定が `sonnet` なのは、監査（2026-09）で W に Sonnet が 1 本も無く、昇格ラダーの Sonnet 段が構造的に通っていなかったため。W は事前分類と失敗ループで上がる。

残量モード（`FABLE_BUDGET_MODE`）は `references/decision-criteria.md` の表に従う: `abundant` は R1 / G の既定を 1 段上げてよい（W は上げない）、`reserve` は**自動実行のみ** `opus` 上限（interactive は制限しない）、`exhausted` は**全経路**で `opus` 上限。共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が下限を決め、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 固定。両者が食い違えば共有枠モードが勝つ。

昇格トリップワイヤー（`templates/escalation-tripwires.md`）は W の再開時のモデル選択として残す: 同じテストが 2 連続で落ちた、または同じ箇所を 2 回書き直したと W が return したら、本体は W を 1 段昇格したモデルで再開する（`sonnet` → `opus` → `fable`。残量モードと共有枠モードの上限内）。コンテキスト上限（`subagent-context.sh` が exit 2）は昇格ではなく手渡しで、モデルは変えない。規模超過（編集対象 5 ファイル超・作業項目が 2 回増えた）を W が return したら、本体が change / 子 issue（エピック化）に分割する。

## 実行モード

| モード | 起動 | 本体 | 対話 | 回す工程 |
|---|---|---|---|---|
| **interactive**（既定） | 人間が `/develop`・`/work-issue`・自然文で依頼 | そのセッション | AskUserQuestion で聞ける | (0)〜(4) 全部。複数 change はその場で change ごとに回す |
| **unmanned**（`--unmanned`） | loop-dev-agent の憲法 Step 3 から | **憲法のメイン自身**が develop の本体を務め、W / R1 をメインが spawn する | 聞けない（1 サイクル 1 仕事） | (0)〜(3)。worktree は憲法側が用意したものを使う。(3) で W が Draft PR の作成と `agent-review:pending` の付与（憲法 Step 3 の 5〜6 に相当）まで行う。**(4) の G は起こさず**、憲法 Step 1（レビューモード）が次サイクル以降で担う |

unmanned で複数 change に割れた場合は、W が change 単位で子 issue を作って `blocked_by` で順序付けし、元 issue に分割結果をコメントしてそのサイクルを終える（worker.md「分割判定」）。判断がつかないほど曖昧なら Discord で質問し、`needs-approval` を付けてサイクルを終える。

**仕様化判断の記録と仕様レビューは unmanned でも免除しない**（同じ書式で記録先に記録し、R1 の APPROVE まで W を apply に進めない）。

## エピックの扱い

### 条件

次のいずれかに当たればエピックにする:

- 1 つのユーザーストーリー（「〜な人が〜できない」）の原因が複数あり、**独立してマージできる PR が 2 本以上**に割れる
- 複数の capability（openspec の spec）にまたがる
- 子の間に順序依存があり、1 サイクルで終わらない

### 作り方

洗い出しセッションの成果物として作る（洗い出しと解決はセッションを分ける）:

- **エピック issue**: ユーザーストーリー・完了条件（ストーリーが成立したことを何で確かめるか）・子 issue の一覧と依存順を書く。**エピック自身にはコードを紐づけない**（PR の `Closes` は子に向ける。エピックに `Closes` を向けた PR を作らない）
- **子 issue**: それ単体で実装可能な記述＋測定可能な受け入れ条件を持つ。依存は `gh api -X POST repos/<owner>/<repo>/issues/<後続>/dependencies/blocked_by -F issue_id=<前提の issue id>` で張る
- 解決セッションの入口は `/develop <エピック番号>`

### 回し方

- 本体は子 issue の依存グラフ（`gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by`）を読み、blocked されていない子から**上の 1 ループを子ごとに並列**で起こす。worktree は子ごとで、本体が W を `isolation: "worktree"` で spawn して用意する（W は自分で worktree を切らない）
- 子の PR がマージされたらエピックに 1 行コメント（`子 #N マージ → 残り k 件`）し、依存が解けた子を次に起こす
- スタック PR（子 B が子 A のブランチを base にする）は避け、A のマージを待ってから B を main から切る。やむを得ずスタックする場合は、A マージ後に B の base が自動では main に切り替わらないので本体が張り替える
- 子の実装中に新しい問題が見つかったら、その子の中で直さず**新しい子 issue** を切ってエピックに追加する（子の受け入れ条件を膨らませない）

### 完了条件

全子 PR がマージされ、**かつ**本体（または G）がエピックの完了条件（ユーザーストーリーの成立）を実機で確認して、その証拠をエピックにコメントしたとき。子が全部マージされただけでは閉じない。

## 上流の壁打ち（`/opsx:explore`）を呼ばない理由

このスキルは規模が大きくても、上流の壁打ち（openspec の `/opsx:explore`。まだ形になっていない曖昧な要望を、対話で質問しながら実装可能な単位に分解し、相互矛盾がないか確認する工程）を内部から呼ばない。このスキルが扱う依頼（issue・受け入れ条件付きの会話依頼・エピックの子）は既にその「ほぐす作業」が終わった状態にある。複数 change が必要なら記録先の記述を根拠に分割すれば足りる（エピックの作り方）。`/opsx:explore` は issue の体裁を成す前の構想専用として切り離し、その出口（`/opsx:new` / `/opsx:ff`）からこのスキルに入る。

## 参照

- 役割の指示書: `references/roles/worker.md`（W）・`references/roles/spec-reviewer.md`（R1）・`references/roles/gate-runner.md`（G）
- 仕様化要否・change 分割・残量モードの判定基準: `references/decision-criteria.md`
- 昇格トリップワイヤーの常駐ルールテンプレート: `plugins/dev-workflow/templates/escalation-tripwires.md`
- G の手順書: `skills/pr-review-gate/SKILL.md`（記録先の探索順・仕様宣言の照合は据え置き）
- 入口の 5 分岐と issueify フォールバック: `commands/develop.md`（`/work-issue` はエイリアス）
- worktree セットアップの自動化: worktree プラグインの `hooks/hooks.json`（`WorktreeCreate` / `SessionStart`）
- 棲み分け相手: 各リポに配備された loop-dev-agent の憲法（`docs/agent-loop.md`。flatmate が保守する正本で、harness にテンプレートは無い）。unmanned の外形（ラベル・Draft PR・キュー）は憲法側
- 1 ループに収まらない規模を Workflow で回す型: `plugins/dev-workflow/references/workflow-execution.md`（スクリプトの書き方は `workflow-authoring` スキル）
