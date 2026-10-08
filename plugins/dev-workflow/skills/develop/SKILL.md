---
name: develop
description: コード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変えるときは必ず通す標準開発ワークフロー。記録先 → 仕様化判断 → 仕様レビュー → TDD 実装 → pr-review-gate を 1 ループで回す。issue 番号・issue URL・「この issue 対応して」等の自然文、issue の無い会話依頼・cron・エピックの子のいずれからでも起動する。人間依頼（interactive）と無人サイクル（`--unmanned`）の両対応。
version: 2.1.0
---

# develop — 入口を問わない標準開発ワークフロー（本体＝オーケストレータ）

このスキルは「開発の進め方」を毎回同じに通すための正本で、本体（このスキルを読んでいるメインセッション）は**作業を自分ではせず、役割別のサブエージェントを起こして回す**。役割は W・R1・G・V の 4 つを使う（V は画面確認が要るときだけ）:

| 役割 | 名前 | 指示書 | 担当 |
|---|---|---|---|
| 作業者 | **W**（`dev-workflow:worker`） | `references/roles/worker/common.md`＋`段:` が指す `references/roles/worker/<段>.md`（索引は `references/roles/worker.md`） | 記録先の用意（Draft PR 経路）・仕様化判断の記録・分割判定・`openspec new change`・TDD 実装・verify・archive・PR・仕様宣言 |
| 仕様レビュアー | **R1** | `references/roles/spec-reviewer.md` | 実装前の仕様レビュー（別コンテキスト・読み取り専用） |
| ゲート実行者 | **G**（`dev-workflow:gate-runner`） | `references/roles/gate-runner.md` | pr-review-gate の手順 1〜5 |
| 画面確認役 | **V**（`general-purpose`） | `references/roles/screen-checker.md` | 必要な場合だけ画面観測を返す |

旧スキル（issue 限定の入口で、本体が自分で Step A〜D を実行する手順書だったもの）の後継。反転した理由は 1 つで、Claude Code のサブエージェントは Agent ツールを持たない（孫を spawn できない）ため、本体向けの手順書をサブエージェントに渡すと仕様レビュー・別コンテキストの PR レビュー・fable 昇格がすべて自己レビューに退化するから。別コンテキストを要する工程は**すべて本体が起こす**。

## Role profile の選択

profile と旧 account/model のどちらも明示しない場合、各 canonical phase の開始時に adapter で再評価する。登録 Codex accounts の週次 snapshot の実効値（取得からの経過時間で捨てず、リセット時刻で読み替えた値）と Claude 起動 account の実効値（セッション記録と snapshot をリセット時刻で読み替えた値）から `margin = 週経過率 - 使用率` を求め、両方が 0 以上なら `claude-write-codex-review`、Codex だけが 0 以上なら `codex-standard`、それ以外は Claude 既定構成を選ぶ。開始済み role は工程途中で切り替えない。adapter が返す構成、reason、両 provider の margin / fetched_at、代表 Codex account を、最初の develop 開始コメントと後続 phase の dispatch 記録へ残す。値が無ければ `missing` と記録する。

`--profile NAME [--profile-file PATH]` または旧形式の Codex account/model を明示したときは、`${CLAUDE_PLUGIN_ROOT}/references/codex-develop.md`（未設定ならこの SKILL.md から `../../references/codex-develop.md`）を絶対パスに解決して Read する。各委譲の直前に adapter から canonical role の per-role execution result を取得し、provider 操作は同 reference の「role 解決直後の一度だけの分岐」に従う。事前分類に当たる R1 または G が要求したレビュアーは、対象 role の entry ではなく profile の `decider` entry（executor/account/model）を使い、`subagent_type: dev-workflow:decider` として起動する。この SKILL.md はその分岐を再掲せず、工程順、role、review 条件、return 契約、次工程の判断だけを正本として維持する。

G の起動指示（段ごとに新しく起こす G と、手渡しで起こす後任 G のすべて）には、起動形を問わず常に `レビュー経路: adapter` の 1 行を書く（自動選択・明示 profile・旧形式のどれも adapter で解決するので、今が adapter 経路かを評価しない）。Codex の G では request の instructions（`--input` の指示ファイル）にも書く。develop の本体は `レビュー経路: 従来` を書かない（develop の本体以外の呼び出し元のための値）。G は再開せず段ごとに新しく起こすので、起動指示に行が無い G は従来経路（full は G が Codex を直接呼ぶ）として動く。どの段の起動指示でも行を省略しない（`references/roles/gate-runner.md`「レビュー経路の判別」）。

名前付き profile では profile role ごとに thread と requested tuple / applied model / reason を記録する。同じ Claude profile role を再開する直前に毎回現在の `FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` 上限を再確認し、既存 applied model が上限内のときだけ SendMessage する。上限を超える場合は SendMessage せず、既存の工程完了または停止確認条件を満たしてから requested tuple を変えずに capped model の fresh thread へ成果物と必要な要約を手渡す。profile role の境界、独立 review、Codex 委譲も fresh thread とする。以下の spawn / SendMessage 表記は、profile 利用時にはこの規則を適用した provider 操作を意味する。

## いつ使うか

ソースコード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変える作業は、依頼の入口を問わず（GitHub issue・会話・cron・エピックの子のいずれでも）このスキルを通す。「issue があるか」は入口 0 で記録先を決める材料にすぎず、スキルを通すかどうかの条件ではない。

例外は「読むだけ・回答だけ・生成物を出すだけ」の作業（調査報告・質問への回答・レポートや図の生成など、リポジトリの追跡対象を変えないもの）に限る。

## 前提

無いときの縮退まで含めて列挙する。本体が spawn できない環境（本体自身がサブエージェント）ではこのスキルは成立しないので、その場合は親に return して親を本体にする。

| 前提 | 使い方 | 無いとき |
|---|---|---|
| **Agent ツール** | W (`dev-workflow:worker`) / R1 (`general-purpose` または `dev-workflow:decider`) / G (`dev-workflow:gate-runner`) / G が要求するレビュアー (`dev-workflow:reviewer` または `dev-workflow:decider`) / V (`general-purpose`) の spawn。`model` を必ず明示し、W と G は**名前付き**で spawn する（W は SendMessage で再開するため。G は再開せず段ごとに新しく起こし、名前は (4) の形にする）。W は本体が対象専用の worktree にいなければ `isolation: "worktree"` で起こす。**`isolation: "remote"` で W / G を起こしてはならない**（強制停止に当たった作業を本体が引き取れなくなるため。理由は「worktree の用意」を参照） | 本体になれない。親セッションに return する |
| **SendMessage** | 名前付きで起こした W の再開（コンテキストを引き継いだまま次の工程を指示する）。G は再開しない（段ごとに新しく起こし、レビュー要約は起動指示で渡す） | 再開できないので、前任を手渡してよい状態のときだけ新しい W を spawn し、前回の return 全文をプロンプトに渡す。条件は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本で、満たさないなら spawn せず親に返す（前任が動いたまま後任を起こさない） |
| **`gh`** | 記録先（issue / PR）へのコメントとラベル操作、Draft PR の作成、エピックの子の依存（`gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by`、issue dependencies API） | 記録先を作れないので開始しない（記録なしで実装に進まない） |
| **openspec CLI** | W は `openspec --version` で経路の有無を決め、`openspec new change` → R1 → TDD → `openspec validate --strict` → `openspec archive` と進める。opsx コマンドは本体や主の対話用 | 仕様化経路が発生しない（W は `仕様化判断: しない` の理由に「openspec 不在」と書き、コード直行する） |
| **`orca`** | エピックの子を Orca の子ワークツリーで独立した Claude Code セッションとして起動する（`scripts/epic-dispatch.sh launch`。「エピックの扱い」→「回し方」） | エピックはサブエージェント方式で回す。`orca` はあっても本体が Orca 管理外のワークツリーにいるときも同じ（`route` が `subagent` を返す） |
| **Codex CLI** | adapter 経路（develop の本体が起こす G）では G は full でも `needs-reviewer` を返し、本体が phase `review` で投げ先を選び直す（Codex が選ばれればそこで使う）。従来経路（develop の本体以外の呼び出し元が起こす G）では G が full レビューを Bash から `codex exec` / `codex-companion.mjs` で実行する | G が `needs-reviewer` を return し、本体が別のレビュアーを spawn して要約を G に渡す（gate-runner.md） |

## 本体の役割

本体は役割 W / R1 / G を `model` 明示で spawn し、**return の要約と記録先（issue または Draft PR）のコメント・ラベルだけ**を見て次に誰を起こすかを決める。並列可能な役割（エピックの子どうし、独立した change の W どうし）は並列に起こしてよい。**ただし、1 つの worktree で同時に動く同一役割のサブエージェントは常に 1 人（MUST）。並列に起こしてよいのは別々の worktree を持つ役割に限る。**

禁止事項（本体がこれをやると、別コンテキストの網が全部外れる）:

- **本体は Edit でコードを書かない。** テスト・実装・仕様ファイルの編集はすべて W の仕事。本体が「小さいから」と直接直した瞬間に、その変更は R1 / G の別コンテキストレビューを通らずに PR に乗る
- **本体はレビューを代行しない。** 仕様レビューは R1、PR レビューは G（と G が要求したレビュアー）が行う。本体が W の return を読んで「よさそう」と判断することはレビューではない
- **W が孫を呼ぶ必要がある工程を設けない。** 別コンテキストを要する工程（R1・G・G のレビュアー）はすべて本体が起こす。W の指示書に「サブエージェントを spawn せよ」と書かない

本体がやること: 入口 0 の記録先の確定、worktree の用意、各役割の spawn と再開、return の要約の転記（記録先のコメントは各役割が自分で投稿する。**例外: `subagent_type: dev-workflow:decider` で起こした役割は `Bash` を持たず `gh` を実行できないので、その return は本体が同じ書式で代理投稿する**。ただし pr-review-gate の仕分け表の順 6 の裁定は代理投稿せず G に返し、G が記録する）、needs-approval 時のオーナーへの依頼、エピックの進行管理。

## 入口 0: 記録先を決める

1 ループの最初の工程。仕様化判断・仕様レビュー結果を置く「記録先」を先に確定する。

- **issue があればそれを記録先にする**（番号・URL・自然文マッチ。`/develop` の 5 分岐は `commands/develop.md`）。エピックの子は子 issue が記録先
- **無ければ issue を切らない。** 本体が worktree を用意し、W が worktree 直後に空 commit（`git commit --allow-empty`）を積んで push し、`gh pr create --draft` で Draft PR を開いてそれを記録先にする（GitHub の "open a draft PR early" の慣行）。この Draft PR は**仕様化判断を記録する前**に存在していなければならない — 記録先が無い状態で判定を先に進めない（手順は `references/roles/worker/spec.md`「記録先の用意」）
- Draft PR を記録先にする場合、**受け入れ条件は PR 本文**（位置づけ・動作確認ポイント）に書く。issue に書かない分の省略であって、受け入れ条件自体を省くことはできない
- 記録先を PR にした場合、PR 本文に `Closes #N` / `Fixes #N` / `Refs #N` の issue 参照を**書かない**。書くと pr-review-gate の照合先がその issue に移る（探索順は issue → 無ければ PR 自身のコメント）。エピックの子は子 issue が記録先なので `Closes #子` を書く
- 仕様化判断（`仕様化判断: する|しない`）・仕様レビュー結果（`仕様レビュー: APPROVE|REQUEST_CHANGES`）は記録先のコメントに置く（書式の正本は `references/roles/spec-reviewer.md`「判断記録の契約」）
- **仕様宣言は記録先ではなく常に PR コメントに置く**（記録先が issue でも issue には書かない）。pr-review-gate 手順 5 が PR のコメントでリスク宣言・仕様宣言・動作確認の 3 見出しを照合し、`対象 HEAD:` 規約が PR の HEAD に紐づくため。書式の正本は pr-review-gate スキル手順 3-b

**issue を切るのは追跡・キュー・議論が要るときだけ**: エピック（複数 PR にまたがる。下の「エピックの扱い」）／無人キュー（loop-dev-agent が拾う対象にしたい）／判断を残す議論（決定の経緯を issue スレッドに残したい）。この 3 つに当たらなければ Draft PR で足りる。issue を切る経路は `commands/develop.md` の issueify フォールバック。

## worktree の用意

worktree は**本体が用意する**。`.worktreeinclude` が無いときは本体が `/wt-setup` を呼ぶ。本体が既に対象専用の worktree（1 issue = 1 worktree = 1 ブランチ）にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。**W は自分で worktree を切らない**（セットアップは worktree プラグインの `WorktreeCreate` / `SessionStart` hooks が担うので、W は判定もしない）。unmanned では憲法側が用意した worktree を使う。**`isolation: "remote"` は使わない**（MUST NOT）。強制停止中は `Bash` が全件拒否されるため止まったサブエージェント自身は commit できず、未コミット差分は本体が引き取る設計（下の「工程中断: で返ってきたら」を参照）だが、`remote` 隔離は本体から見えない環境なので、そこで強制停止に当たると作業がそのまま失われる。

## 1 ループ（W → R1 → W → G）

1 issue（または 1 Draft PR）につき次を回す。各工程の担い手と、本体が次に誰を起こすかの判断材料を書く。

下の各工程の spawn・SendMessage による再開・Codex executor への委譲の直前には、毎回「PR トークン上限」の節の計測を行う（exit 2 なら起こさず止まる）。

```
(0) 記録先を確定する（入口 0）。worktree を用意する
(1) W を `subagent_type: dev-workflow:worker` で名前付き spawn（起動指示に `段: spec` の 1 行を書く。model: references/pre-classification.md の事前分類表の「1 周目」列に当たればその値（4 分類のいずれでも opus。W の上限は opus）、それ以外 sonnet。W を fable にはしない。共有枠モードが下限を決める）:
      記録先の用意（Draft PR 経路）→ 仕様化判断の記録 → 分割判定 → openspec new change → return「仕様できた」
      仕様化しない判定なら → (3) へ直行（TDD → PR）
(2) R1 を spawn（model: 既定 opus。マージ条件・層間契約・課金/法務に触れれば subagent_type: dev-workflow:decider で spawn する。聖域パスだけでは上げない）:
      references/roles/spec-reviewer.md に従って別コンテキストで仕様レビュー → 結果を記録先にコメント → return
      dev-workflow:decider で起こした R1 は gh を実行できないので投稿せず return し、本体が同じ書式で代理投稿する
      （記録先の本文と関連コメントは本体が入力文に貼って渡す）
      REQUEST_CHANGES → W を SendMessage で再開（再開指示に `段: spec`）して artifact を修正 → R1 を再開して差分再レビュー
      （初回＋差分 1 回の 2 周キャップ。超えたら needs-approval を付けて本体がオーナーに 1 アクションで依頼し、「保留で止まるときの引き継ぎ」の節どおり引き継ぎを残す）
      R1 の APPROVE が記録先に記録されるまで W を apply に進めない（再開しない）
(3) W を SendMessage で再開（再開前に `scripts/subagent-context.sh <W の名前>` で測る。上限超を検知した
      あとの扱いは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本。正本を読むまで手渡さない）。
      (3) は 2 回の return に分かれる:
      (3a) 再開指示に `段: implement` を書く。apply（TDD。openspec CLI で tasks を実装）→ openspec validate --strict → return「工程完了: 実装＋verify」
           （実行したテストコマンドと exit code、openspec validate --strict の exit code、画面確認: の行を載せる）
           → 本体はここで `scripts/subagent-context.sh <W の名前>` をもう一度実行して測ってから (3b) を指示する
      (3b) 再開指示に `段: finish` を書く。openspec archive → PR を Draft のまま用意（無ければ Draft で作成。Ready 化は (4) の G が pr-review-gate 手順 5 で行う）→ 仕様宣言を PR コメントに書く
           → return「工程完了: archive＋PR＋仕様宣言」（PR #N と仕様宣言のコメント URL を載せる）
      (3a) の `画面確認: 不要` なら V を起こさず (3b) へ進む。`画面確認: 要る — <開く URL か起動手順> / <見る点>` なら先に V を `subagent_type: general-purpose`・`model: sonnet`、名前 `V-<記録先番号>-<n>`、description `V: screen check for #N` で起こす。V に W の行と worktree パスを渡し、`isolation` は付けない。
           V の合格は観測を (3b) の W に渡す。不合格なら (3a) に戻し、同じ画面確認の 2 回目の不合格は本体が失敗ループと数える。実行不能なら理由を (3b) の W に渡し、画面証拠は書かずゲートの保留経路へ進む。V は再開せず、再確認は新しい V を起こす。
      (3) をこれより細かく切らない（`tasks.md` の項目単位や「実装／verify／archive／PR／仕様宣言」の 5 段にしない）。
           手渡しが 1 回起きるたびに、後任は指示書と正本の節を読み直し、記録先を取り直し、`git status` / `git diff` でファイルの現状を確認する固定分を払う。
           この固定分は工程の大きさに依存しないので、区切りを増やすほど 1 区切りあたりの実質作業比が下がる。
           また区切りが実装の途中に落ちると、後任は Red のまま止まったテストから再出発することになり、前任の設計意図を再発明する危険が最も高い地点で交代することになる
      本体は次に指示する工程を、自分が (3a) を指示したか (3b) を指示したかで決め、工程名の文字列照合では決めない。
           (3a) の return に PR 番号と仕様宣言のコメント URL が既に揃っていれば（古い世代の W が (3) を
           通しで終えた場合）、(3b) を指示せず、そのまま (4)（G の工程）へ進む
(4) G を `subagent_type: dev-workflow:gate-runner` で段ごとに名前付き spawn（model: 既定 sonnet。G の仕事は照合・ラベル操作で、欠陥探索は needs-reviewer で本体が起こすレビュアー（従来経路では Codex）が担う）:
      段ごとに新しい G を起こす（段は 前提確認と重さ判定・照合と振り分け・合格処理・保留の解除 の 4 つ。1 体は 1 段だけを担当する。
           起こす時点と渡すものの表は gate-runner.md「段ごとの起動と入力」）。名前は `G-<PR>-<prepare|triage|pass|hold>-<n>`（n はその PR・その段で
           起こした回数）、description は `G: <段> for PR #N (#issue)`（先頭の `G:` を残す。役割別集計がこの接頭辞で G と判定する）
      G の起動指示には常に `レビュー経路: adapter` の 1 行と `段: <段の名前>` の 1 行を書き（Codex の G では request の instructions にも。
           `レビュー経路: 従来` は書かない。理由は「Role profile の選択」節）、2 つ目以降の段では前の段の `## Gate Result` ブロックを要約し直さずそのまま貼る
      次に起こす段は Gate Result の Status と `次の段:` だけで決める（止める指摘が残っているか・戻した指摘の仕分け・復帰手順の行き先を本体は判断しない）。
           G が `工程中断:` で返したら同じ段の新しい G を起こし、前任の return 全文と前任の起動指示に書いた入力を渡す
           （起こしてよい条件は references/decision-criteria.md「コンテキスト上限（サブエージェントの手渡し）」の「手渡しの許可」）
      4 つの段で pr-review-gate の手順 1〜5 → return「passed / failed / 保留 / needs-reviewer / needs-decider / review-incomplete / 次の段へ」
      次の段へ → `次の段:` の G を新しく起こす（照合と振り分けが止める指摘なしで終われば合格処理。保留の解除は合格処理か前提確認と重さ判定で、
           代替案で手順 2 からやり直すときに W の修正が要るなら、W の修正のあとで前提確認と重さ判定の G を起こす）
      合格処理（手順 5）では PR が Draft なら Ready にしてから agent-review:passed を付ける（W は Ready にしない）
      passed → 本体が `plugins/dev-workflow/references/ci-watch.md` の手順で CI の見張りを始める（G は見張りを始めない。中身は reference が正本）。
           見張りの一手が `fix` なら W に直させ（再開指示に `段: implement`。再開か手渡しかは (3) と同じく正本に従う）、
           W が push したら本体が passed を外したまま同じ状態ファイルで `wait` → `next` を続け（CI のやり直し・再度の直しもここで処理する）、
           `ready` になってから前提確認と重さ判定の G を新しく起こしてゲートを取り直させ、
           G が再び passed を返したら見張りの続き（reference の「`ready` を受けたあと」）に進む。合格するまでマージ待ち・マージ依頼に進まない。unmanned は (4) を回さないので対象外
      needs-reviewer → adapter 経路では G は full でも light でもこれを返す。本体は次の順で進む:
           ① codex-develop.py request --phase review で投げ先を選び直す（実行先オプションはこの develop 開始時と同じ。自動選択なら無指定）
           ② 返った選択（構成・reason・両 provider の margin・各 fetched_at・代表 Codex account。欠測は missing）と解決した executor / model を
              記録先に dispatch 記録として投稿する。投稿に成功するまでレビュアーを起動しない
           ③ 選ばれた投げ先でレビュアーを起動する（executor が claude なら Agent ツールで `subagent_type: dev-workflow:reviewer` として、model は adapter の値に残量上限を適用したもの。
              事前分類に当たれば profile の decider entry で dev-workflow:decider。codex なら request を実行する）
              一周目で payload に区画があり executor が claude なら、区画ごとに 1 体ずつ並列に起こす。description は
              `Reviewer: 区画 <k>/<n> for PR #<N> (#<issue>)` とする。executor が codex なら区画を使わず差分全体を 1 つの request に渡す。
           ④ レビュー要約と、選ばれた executor / model・dispatch 記録のコメント URL を G に渡す。review phase の executor が codex なら、worker の結果 JSON の `execution.model_resolution.requested` / `execution.model_resolution.resolved` も G に渡す。resolved が未観測なら null をそのまま渡し、要求値や dispatch 時の model で補完しない。Claude の G は照合と振り分けの G を新しく起こし、前の Gate Result ブロックと一緒に起動指示で渡す
              （gate-runner.md「needs-reviewer の return」）。Codex の G は新しい phase gate を開始してその入力に渡す（codex-develop.md「品質と transport 差分」）
              全区画の要約が揃ってから、各要約の先頭に `区画 <k>/<n>` の見出しを付けてまとめ、照合と振り分けの G を 1 体だけ起こして渡す（G は見出しの有無で区画レビューかを判定する）。
           通常の初回レビュー依頼も補足要求も同じ ①〜④ で進める。`needs-reviewer` が一周目照合の補足要求である場合に限り、③ のレビュアーへ
           同じレビューの固定 HEAD・元の三表・残差・補足済み回数を payload のまま渡し、不足分だけを補わせる。補足結果は照合と振り分けの G を新しく起こして渡す（補足済み回数は G が最新の `レビュー三表:` の PR コメントから読むので、fresh thread でもリセットされない）
           補足は `一周目の区画:` の構成と既存 ID のまま、元の三表を置き換えず残差だけを補う。区画を計算し直さず、差分全体のレビューを始めない。
           一周目に区画があり補足の executor が claude なら、残差のある区画だけを 1 体ずつ並列に起こし、description を
           `Reviewer: 補足 区画 <k>/<n> for PR #<N> (#<issue>)` とする。一周目に区画があり executor が codex なら、
           1 つの request に残差のある区画ごとに番号・ファイル一覧・元の三表・残差を分けて載せ、`P<k>-` の ID で補わせる。
           一周目に区画が無く executor が claude なら補足レビュアーを 1 体だけ起こし、1 組の三表と残差を接頭辞の無い ID で補わせる。
           一周目に区画が無く executor が codex なら今までどおり 1 つの補足 request にする。補足済み回数は PR で 1 つだけ数える。
           develop の本体以外から G を起こす従来経路の手順（呼び出し元がレビュアーを起こす）は gate-runner.md のまま
      review-incomplete → reviewer を再起動しない。`agent-review:pending` のまま Gate Result の残差を報告して工程を止め、合格処理へ進まない
      failed → 原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）で戻し方を決める。モデルを上げるのは実装品質起因のときだけで、
           上げるのは決める役と実行役の一方だけ（実行側が原因なら W を opus に、判断側が原因なら dev-workflow:decider を立てて修正方針を作らせる。
           W を fable にはしない）。仕様が曖昧なら仕様修正、誤検出なら反証で返す（どちらもモデルを上げない）
           → W を再開（再開指示に `段: implement`。再開前に測る。上限超のあとの扱いは (3) と同じく正本に従う）→ W の修正のあと、failed の Gate Result の `次の段:` どおりの G を新しく起こして再レビュー（順 3 だけなら照合と振り分け、それ以外は前提確認と重さ判定。
           2 周キャップ。範囲と 3 周目の扱いは pr-review-gate の収束ルールに従う）
      保留 → needs-approval のまま本体がオーナーに 1 アクション（許容する／しない、動作確認の結果、切り出しの確認への回答（切り出す／この PR で直す））で依頼する。止まる前に「保留で止まるときの引き継ぎ」の節どおり記録先へ引き継ぎを残し、主に新しいセッションでの再開を案内する。依頼を出したあとに同じ保留の通知・報告の再送が届いたときは、同節の「依頼の出し直し」に従う。回答が届いたら保留の解除の G を新しく起こし、回答を渡す（新しいセッションなら同節の再開手順から）。リスク許容を会話で受けたら主に PR へのコメントを求めず、自分のセッション ID（`$CLAUDE_CODE_SESSION_ID`）・その発言の日時（会話ログの timestamp）・原文を G に渡す（記録の書式と真正性確認は pr-review-gate 手順 5 の「会話で受領」が正本）
      needs-decider → 仕分け表の順 6（同じ型の再発）。本体が subagent_type: dev-workflow:decider を残量モードどおりのモデルで起こし、
           入力に decider.md の入力契約どおり、記録先の本文・判断に必要な関連コメント（`仕様化判断:` の記録・G の仕分けの PR コメント・順 3 の一覧表の
           PR コメントがあればそれ）・同じ型の指摘と前の周の指摘の原文・対象ファイルのパス・G の仕分け欄・W の直近の return を貼って、「この PR の中で
           同じ型を全部列挙してから直すべきか（可）、切り出すべきか（否）」を問う（順 6 の依頼はマージ可否と同じ可否と根拠の形で問う。decider.md は変えない）。
           依頼文で返答の 1 行目を `裁定: 可`・`裁定: 否`・`不足: <足りないもの>` のどれかちょうどに指定し、本体はその 1 行目で分岐する（本文の読み取りで分岐しない）。
           `裁定: 可` を「全部列挙してから直す」、`裁定: 否` を「切り出す」に読み替え、根拠とともに照合と振り分けの G を新しく起こして渡す。1 行目が `不足:` なら裁定として扱わず
           G に渡さない。足りないものを補って同じ問いで 1 回だけ依頼し直す。1 行目が 3 形のどれにも一致しなければ `不足:` と同じに扱う（1 回だけ依頼し直す）。
           2 回目も不足（または 3 形に一致しない）なら「裁定なし（入力不足）」と足りなかったものを、照合と振り分けの G を新しく起こして渡す（G は「切り出す」として主に聞く）。
           本体は裁定を代理投稿しない（G が `決める役の裁定:` の PR コメントとして記録する）
```

W は名前付きで spawn し、SendMessage で再開してコンテキストを引き継ぐ（(1) の判定・(2) の指摘・(3) の実装が同じコンテキストにある）。**ただし再開の前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測る（exit 2 が上限超）。閾値と全解除の環境変数・途中計測 hook を含む 2 経路・上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言・前任が動作中のまま交代させる手順）は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本で、この SKILL.md には書かない。正本を読むまで手渡さない。** G は再開せず段ごとに新しく起こすので、再開前の計測は W だけに掛かる。**W の起動指示・SendMessage による再開指示・手渡しの起動指示には `段: spec` / `段: implement` / `段: finish` の 1 行を必ず書く**（W は `references/roles/worker/common.md` とこの行が指す段のファイルだけを読み、行が無ければ読まずに聞き返す）。値はその起動・再開で本体が指示する工程で決める（上のコードブロックの各工程に書いた値）。手渡しでは、前任が工程の途中で止まり（return の 1 行目が `工程完了:` でない）後任に同じ工程を続けさせるなら前任が担っていた段、前任が `工程完了:` で return したあとに後任へ次の工程を指示するならその工程の段にする（(3a) を終えた前任の後任に (3b) を指示するなら `段: finish`、(1) を終えた前任の後任に R1 の REQUEST_CHANGES の修正を指示するなら `段: spec`）。次の工程は本体が自分の指示した工程から決め、前任の return の工程名の文字列から決めない（新しいセッションで引き継ぎから再開する本体は、引き継ぎの「次に起こす役割」に書かれた `段:` の値を使う）。**`工程中断:` で返ってきた return にレビュー結果（`agent-review` の判定やレビュー本文）が含まれていたら、本体がそれを記録先に代理投稿する**（G が途中計測の強制停止に当たると `gh pr comment` も拒否されるため。R1 の仕様レビューを代理投稿するのと同じ形）。**強制停止中は commit も本体が行う**: `工程中断:` の return を受け取ったとき、および次の手渡し・次の spawn・そのサイクルの終了・worktree の撤去のいずれよりも先に、本体は return に書かれた作業ツリーのパス（強制停止による中断なら hook の `permissionDecisionReason` に含まれる `cwd`）に対して `git -C <path> status --porcelain` を実行して未コミット差分を確認し、残っていれば本体が commit する（MUST。止まったサブエージェント自身は `Bash` が全件拒否されて commit できない。手渡し先が確認するのは**次に起こされた**サブエージェントの差分だけなので、手渡しが発生しない経路や後継が G の場合はこの本体側の確認が無いと作業が失われたまま残る）。W が孫を呼ぶ必要がある工程は存在しない。仕様化する場合で複数 change に割れたときは、interactive では change ごとに (1)〜(3) を回す（change ごとに仕様レビューを行う。並列可能なら W を並列に起こす。change ごとに worktree を分ける）。

## ループの終わり

- **worktree の片付けを提案も質問もしない**（完了報告でも途中でも）。片付けは、Orca 経路のエピックの子なら親セッションが行い、それ以外はオーナーが別のセッションで `/wt-clean` を使う
- 記録先が issue で PR がマージ済みなら、完了報告を書き終えてから、**そのループの最後のツール呼び出し**として `scripts/epic-dispatch.sh mark <done|waiting> <記録先の issue 番号>` を Bash で 1 回呼び、このワークスペースに印を付ける。オーナーに頼むことが残っていなければ `done`（用が済んだ）、完了報告にマージ後の依頼（動作確認など）を書いたなら `waiting`（オーナーの確認待ち）にし、オーナーが済んだと返事をしたら `done` で呼び直す
- PR がマージされていないとき（保留・マージ待ち・unmanned）と、記録先が Draft PR のときは呼ばない
- 出力が `marked` / `skipped` なら何もしない。`failed` なら完了報告に 1 行書く。どの出力でも止まらない
- 印を最後に置くのは、`done` の印が付くと、エピックの親セッションが最短で次のポーリング（既定 300 秒以内）にこのワークスペースの端末を閉じてワークツリーを消すため。印のあとに文章を書き足さない。スクリプトは今のワークスペースがこの issue のものかを自分で確かめる（違えば `skipped`）ので、エピックの子かどうかを判断せずに呼んでよい

## PR トークン上限（spawn・再開・Codex 委譲の前に毎回測る）

1 つの記録先に使ったトークンの累計に上限を掛ける（#288）。周回数のキャップでは、1 周が重い場合や W の再開が繰り返される場合を止められないため。

**紐付けの規約**: その記録先のためにサブエージェントを spawn するときは、役割を問わない（W / R1 / G / G のレビュアー / 決める役はその例）で Agent ツールの `description` に記録先番号を `#N` の形で入れる（例: `W: impl for #288`。PR 番号も分かっていれば `G: gate for PR #400 (#288)` のように併記してよい）。番号の無い description のサブエージェントは計測から漏れる。

**Codex の消費の記録**: その記録先のために Codex を呼んだら、そのたびに記録先へ 1 行目が `Codex 消費: <thread_id> <tokens>` のコメントを投稿する。executor が `codex` の役割へ委譲したときは codex-worker の結果 JSON の `thread_id` と `usage.total.totalTokens` を書く（`usage` が null か `usage.total.totalTokens` が読めないときは `<tokens>` を `-` と書く）。G が full レビューで Bash から Codex を呼んだときは、G が return に書いた Codex thread の thread_id を使い、`<tokens>` を `-` と書く。結果 JSON を受け取れなかった委譲と、G が thread_id を取れなかった呼び出しは記録できず、上限の外になる。

**計測**: その記録先のためにサブエージェントを spawn する直前、SendMessage で再開する直前、および Codex executor へ委譲する直前に、役割と executor を問わず毎回次を実行する（`subagent-context.sh` を再開前に呼ぶのと同じ位置。こちらは spawn と委譲の前にも呼ぶ）。

```bash
# 渡すすべての記録先番号のコメントを全ページ取得し、1 行目が ^Codex 消費:  のものだけを集める。
# 全番号の取得に成功したときだけ exit 0 で記録ファイルを書く
if scripts/codex-records.sh --repo <owner>/<repo> --out "<scratchpad>/codex-records.txt" <記録先番号> [PR 番号]; then
  scripts/pr-token-budget.sh <記録先番号> [PR 番号] --codex-records "<scratchpad>/codex-records.txt" \
    --codex-home <account 対応表の各 CODEX_HOME>... --codex-home "${CODEX_HOME:-$HOME/.codex}" [--cap <新上限>]
fi
```

`codex-records.sh` が exit 0 以外を返したら（通信障害・認証エラー・`gh` か `jq` が無い等）、`pr-token-budget.sh` を呼ばず、下の exit 1（計測できない）と同じ扱いにする。取得に失敗した記録を空の記録や前回のファイルで代えない（Codex 分が抜けた合計を上限以内と読み違えるため）。

`--codex-home` には codex-develop の account と CODEX_HOME の対応表（`--account-home` / `--account-home-file`）にある全パスと、本体の環境の `${CODEX_HOME:-$HOME/.codex}` を渡す。記録先に `PR トークン上限:` のコメントがあれば、最新のものの値を `--cap` に渡す。上限の既定は 30,000,000（Claude 分と Codex 分の合計に対する値。環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP` で変更可）。計測はこの SKILL.md の手順で、adapter（`references/codex-develop.md`）と `scripts/codex-worker.py` には置かない。

**exit 2（上限超）**: spawn / SendMessage / Codex への委譲をしない。PR があれば PR、無ければ記録先に `needs-approval` を付け（引き継ぎの「ラベルの付け先」と同じ）、「保留で止まるときの引き継ぎ」の節どおり引き継ぎを残し、主に「続けるか、範囲外として閉じるか」を問う。問いには合計（Claude 分と Codex 分の内訳）・体数・上限・残工程（次に起こそうとした役割と、そのあと残る工程）・推奨（どちらを選ぶかとその理由）を添え、判断材料なしで出さない。unmanned でも同じく止まり、問いを記録先のコメントに書いてサイクルを終える。

- 「続ける」: 記録先に 1 行目が `PR トークン上限: <新上限>` のコメントを投稿し、以後この記録先の計測に `--cap <新上限>` を渡す。新上限は「その時点の合計 ＋ 直前の計測で上限に使った値（`--cap`、無ければ `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000）」。後任の本体は記録先の最新の `PR トークン上限:` コメントの値を使う
- 「範囲外として閉じる」: この記録先について以後サブエージェントを起こさず、Codex にも委譲しない。残作業を記録先にコメントしてサイクルを終える

**exit 1（計測できない。引数エラー・python3 が無い・リポジトリ外・Codex 消費コメントを取得できなかった）**: 止まらずに進み、計測できなかったことと理由を記録先にコメントする。コメントは同じ記録先・同じ理由について 1 サイクルに 1 回までにする（interactive では本体の 1 セッション、unmanned では loop-dev-agent の 1 サイクル）。

計測に入らないもの: 本体自身の消費、Workflow 経由のサブエージェント。出力の `unresolved`（作業ディレクトリが消えたサブエージェント）と `codex_unresolved`（rollout が見つからない thread）は合計に入らないので、0 でなければ問いに件数を添える。

## 保留で止まるときの引き継ぎ（主の返事を待つ前に書く）

本体が `needs-approval` を付けて主の返事を待つと、1 時間以上あいてから同じ会話を再開したときに会話全体のキャッシュを書き直す代金がかかる（#515）。これを避けるため、止まる前に記録先へ引き継ぎのコメントを 1 種類の書式で残し、主には新しいセッションで再開するよう案内する。場面は pr-review-gate の保留（リスク許容・動作確認・切り出しの確認）・「PR トークン上限」の exit 2・レビューの 2 周キャップ超えの 3 つで、場面ごとに別の書式を作らない。

**投稿の順序**: ①主への依頼のコメントを投稿して URL を得る。置き場は対象の PR があれば PR、無ければ記録先（`stages/hold.md` 手順 6 は依頼を PR に投稿するので、記録先が issue でも PR のコメントの URL でよい）。G の保留では G が投稿した依頼コメントを使い、無ければ本体が投稿する。exit 2 と 2 周キャップ超えは本体が問いを書く。②その URL を書いた引き継ぎを記録先に投稿する。③主に案内する。依頼より前に引き継ぎを投稿しない。

**依頼の出し直し**: 保留の依頼を主に出したあと、同じ保留についてゲート担当の終了通知や報告の再送が届いても、新しい情報が無ければ主への依頼を書き直さない。主に返すのは「変化なし」の 1 行まで。新しい情報があって出し直すときは、依頼の全文（決めてほしいこと・推奨・受け入れるリスク・リンク）を省略せずに書き、前のメッセージを指さない（主は前のメッセージを読み返さずにこの 1 通だけで判断できる状態にする）。
- 新しい情報とみなす例: PR の HEAD が動いた／ゲートの判定や保留の理由が変わった／主が判断するときに効く事実（リスクの中身・CI の結果・動作確認の結果）が増えた・変わった／保留の種類が変わった。
- 新しい情報とみなさない例: 同じゲート担当からの同じ内容の終了通知や報告の再送／「状況は変わっていません」と書かれた報告／文面だけが違い、判定・理由・事実が前と同じもの。

**書式**: 1 行目は `^引き継ぎ: 主の返事待ち$` に完全一致（太字・全角コロン・末尾句点を付けない）。2 行目以降に次の項目を `項目名: 値` で 1 行ずつ書く。

| 項目 | 中身 |
|---|---|
| 待ち理由 | `リスク許容` / `動作確認` / `切り出しの確認` / `PR トークン上限` / `2 周キャップ超え` のどれか |
| 主への依頼 | ①の依頼コメントの URL（PR のコメントでもよい） |
| 対象 | PR 番号（まだ無ければ `なし`）・HEAD の 40 桁 SHA・ブランチ・worktree のパス |
| ラベルの付け先 | `needs-approval` を付けた先。PR があれば `PR #N`、無ければ記録先（`issue #N`） |
| 実行モード | interactive / unmanned |
| 実行先 | 実行先オプションと account-home の対応（明示したときだけ。無ければ `自動選択`）と、開始済みの phase の選択結果のコメント URL。最初の phase は develop 開始コメント、以降は dispatch 記録。両方書く（無ければ `なし`） |
| 次に起こす役割 | 返事のあとに最初に起こす役割と、渡す入力の在り処。役割が W なら起動指示に書く `段:` の値も（`段: spec` / `段: implement` / `段: finish`） |
| 周回 | 仕様レビューと G の周回の数・W の修正の周回の数 |
| 前任 W | 直近の return の 1 行目と要約または URL、手渡し可否（次の段落）。W を起こしていなければ `なし` |
| PR トークン上限 | 最新の値と、止まった時点の合計 |
| 回し方 | エピックの子のときだけ。それ以外は `なし` |

W の名前は書かない（新しいセッションでは SendMessage できない）。再び止まるときは新しいコメントを投稿し、最新の 1 件を正とする。

**前任 W の手渡し可否**: 新しいセッションから前任に停止を指示できないので、引き継ぎを書く前に本体が `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の「手渡しの許可」を満たす。前任の直近の return の 1 行目が `工程完了:` なら満たしている。`工程中断:` なら前任に停止を指示して停止確認を受け取り、未コミット差分があれば本体が commit してから書く。満たしたら `手渡し: 可（工程完了 | 停止確認済み）` と確認結果（編集ファイル・commit の SHA）を書く。満たせないとき（exit 2 で SendMessage を送れない・停止確認が返らない）は `手渡し: 不可（理由）`、W を起こしていなければ `手渡し: 不要` と書く。

**主への案内**: 依頼に「返事は新しいセッションで `/develop <記録先>` と一緒に渡す。1 時間以内に返事ができるなら、このセッションで続けてもよい」と書く。リスク許容なら「このセッションの会話で返すか、新しいセッションで `/develop <記録先> 許容する` と打てばよく、PR へのコメントは要らない」と添える。返事がいつ来るかは本体が知らないので引き継ぎは必ず残し、どちらで続けるかは主が決める。

### 新しいセッションでの再開

記録先に `引き継ぎ: 主の返事待ち` のコメントがあれば、`needs-approval` の有無によらずこの手順で始める（`commands/develop.md` の入口も同じ条件）。

1. 記録先の最新の引き継ぎのコメントを読む。
2. そのコメントより後の主の回答（記録先または対象 PR のコメント、または `/develop` の引数の残り）を探して使う。`/develop` の引数の残り（`許容する` など）は会話で受けた回答として扱い、このセッションのセッション ID（`$CLAUDE_CODE_SESSION_ID`）・その発言の日時（会話ログの timestamp）・原文を保留の解除の G に渡す（主に PR へのコメントを求めない）。無ければ、引き継ぎの「主への依頼」を主に見せ直して返事を聞き、返事が来るまで役割を起こさない。
3. 引き継ぎの「ラベルの付け先」に `needs-approval` があることと、PR の HEAD が引き継ぎの HEAD と同じことを確かめる（ラベルは記録先ではなくこの項目の指す先で見る）。ラベルが無ければ保留は解かれているので、記録先のコメントから今の状態を組み立て直して主に報告する。HEAD が動いていれば差分を主に報告し、続けるかを聞く。
4. W は SendMessage しない。「前任 W」が `手渡し: 可` なら手渡し（前任の return と記録先を渡して新しい W を起こす）、`手渡し: 不要` なら「次に起こす役割」の入力で初回の W を起こす。どちらも起動指示の `段:` の行は「次に起こす役割」に書かれた値を使う。`手渡し: 不可` なら W を起こさず、理由を主に報告して指示を聞く。G は従来どおり段ごとに新しく起こす。
5. 実行先: 明示の実行先オプションが引き継ぎにあれば再推測せずそのまま使う。自動選択では、次に起こす役割の phase の選択結果が引き継ぎの「実行先」の指すコメント（develop 開始コメントか dispatch 記録）にあればその構成・executor・account・model を続け、選び直さない。どちらにも無い（未開始の）phase だけ、開始時に adapter で自動選択を評価する。
6. 「PR トークン上限」の計測の `--cap` には、記録先の最新の `PR トークン上限:` コメントの値を使う。

**守備範囲**: 読む入力は記録先のコメント・主の返事（記録先または対象 PR のコメントか `/develop` の引数）・ラベル・PR の HEAD で、出どころは GitHub の記録先と PR と、`/develop` の引数を打ったこのセッションの会話だけ。拾いたい誤りは、引き継ぎが最新でないまま読むこと・返事が無いまま役割を起こすこと・保留が解かれているのに進めること・HEAD が動いているのに気づかず続けること・手渡し不可の前任に代えて W を起こすことの 5 つ。通してよい入力は、項目の並び順が違うコメント・値の前後の空白・返事が引数でなく記録先か PR のコメントで来たもの・HEAD が引き継ぎと同じ PR。守らないのは、引き継ぎの値（周回の数・要約）の事実確認と、主の返事の真正性（pr-review-gate 手順 5 が正本）。この 5 つ以外の不備を見つけるたびに検査を足し続けることを、完了条件にしない。前のセッションの会話・名前付き W への SendMessage・引き継ぎに無い実行先の推測に頼らない。

## モデル

役割ごとのモデルは事前分類と残量モードで決める。実行戦略の分岐はもう無く、判断は「どの役割をどのモデルで起こすか」だけ。

| 役割 | 既定 | 上げる条件 |
|---|---|---|
| W（実行役。`dev-workflow:worker`） | `sonnet` | `opus`: 記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含む、実行側が原因の失敗ループでの昇格、または事前分類の 4 分類（聖域パス・マージ権限・層間契約・課金/法務。正本は `references/pre-classification.md`、ここに再掲しない）に当たる。**W の上限は `opus` で、`model: fable` の W は `scripts/agent-model-guard.sh` に拒否される** |
| R1（読んで判断する役） | `opus` | 仕様の対象がマージ条件・層間契約・課金/法務に触れるときは `subagent_type: dev-workflow:decider` で spawn する（`general-purpose` に `model: fable` を付けない。聖域パスだけでは上げない） |
| G（`dev-workflow:gate-runner`） | `sonnet` | 上げない。G の仕事は HEAD 固定・ラベル操作・宣言の書式照合・証拠の実在確認で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う |
| V（画面確認役。`general-purpose`） | `sonnet` | 上げない |
| G が要求するレビュアー（読んで判断する役） | `opus` | 既定の種別は `dev-workflow:reviewer`。レビュー対象がマージ条件・層間契約・課金/法務に触れるときは `subagent_type: dev-workflow:decider`（従来経路では G の `needs-reviewer` の推奨モデルに従う。adapter 経路では adapter が返した model に残量上限を適用した値を使い、推奨モデルは参考値。(4) の ③） |

W の既定が `sonnet` なのは、監査（2026-09）で W に Sonnet が 1 本も無く、昇格ラダーの Sonnet 段が構造的に通っていなかったため。W は事前分類と失敗ループで `opus` まで上がる。W の上限を `opus` にしたのは、Fable が消費するのはターン数（会話履歴の cache 読込）で、実装・修正ループは 1 件で数十〜数百ターン回るため。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体の判断で吸収し、W は確定した内容を落とす作業だけを担う。読んで判断する役（R1・レビュアー）が Fable に当たるときは `dev-workflow:decider` で起こす — Fable を渡せる `subagent_type` はこれだけで、判定は `scripts/agent-model-guard.sh` が行う。

残量モード（`FABLE_BUDGET_MODE`）は `references/decision-criteria.md` の表に従う: `abundant` はどの役割の既定も上げない（Fable の余裕は人間の対話と verify に回す）、`reserve` は**自動実行のみ** `opus` 上限（interactive は制限しない）、`exhausted` は**全経路**で `opus` 上限。共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が下限を決め、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 固定。両者が食い違えば共有枠モードが勝つ。

昇格トリップワイヤー（`templates/escalation-tripwires.md`）は失敗の原因側だけを上げるラダーとして残す: 同じテストが 2 連続で落ちた、または同じ箇所を 2 回書き直したと W が return したら、本体は失敗の原因が判断側（指示を解釈できなかった・指示自体が外れていた）か実行側（指示どおりやって結果が違う）かで、**決める役と実行役のどちらか一方だけ**を上げる（両方同時に上げない）。判断側なら `subagent_type: dev-workflow:decider` を立てて修正方針を作らせ（`model` は `opus` → `fable`。種別は固定して `model` だけ切り替える）、実行側なら W を `opus` で再開する（W の上限は `opus`）。残量モードと共有枠モードの上限が先に効く。コンテキスト上限（`subagent-context.sh` が exit 2）は昇格の理由にはならず、モデルは変えない（そのあとの扱いは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本）。規模超過（編集対象 5 ファイル超・作業項目が 2 回増えた）を W が return したら、本体が change / 子 issue（エピック化）に分割する。

## 実行モード

| モード | 起動 | 本体 | 対話 | 回す工程 |
|---|---|---|---|---|
| **interactive**（既定） | 人間が `/develop`・`/work-issue`・自然文で依頼 | そのセッション | AskUserQuestion で聞ける | (0)〜(4) 全部。複数 change はその場で change ごとに回す |
| **unmanned**（`--unmanned`） | loop-dev-agent の憲法 Step 3 から | **憲法のメイン自身**が develop の本体を務め、W / R1 をメインが spawn する | 聞けない（1 サイクル 1 仕事） | (0)〜(3)。worktree は憲法側が用意したものを使う。(3) で W が Draft PR の作成と `agent-review:pending` の付与（憲法 Step 3 の 5〜6 に相当）まで行う。**(4) の G は起こさず**、憲法 Step 1（レビューモード）が次サイクル以降で担う |

unmanned で複数 change に割れた場合は、W が change 単位で子 issue を作って `blocked_by` で順序付けし、元 issue に分割結果をコメントしてそのサイクルを終える（`references/roles/worker/spec.md`「分割判定」）。判断がつかないほど曖昧なら Discord で質問し、`needs-approval` を付けてサイクルを終える。

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

**経路の決め方**: 本体は子 issue の依存グラフ（`gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by`）を読み、blocked されていない子の番号を `scripts/epic-dispatch.sh route <子>...` に渡す。blocked されていない子が 2 件以上あり、`orca` が PATH にあり、本体が Orca 管理のワークツリーにいれば `orca`（**Orca 経路**）、それ以外は `subagent`（**サブエージェント方式**）が返る。経路は `/develop <エピック番号>` の最初の開始時に 1 回だけ決めて途中で変えない（Orca 経路では、あとから解けた子は 1 件でも `launch` する）。決めたらエピックに 1 行コメント（`回し方: Orca（並列可能な子 k 件）` または `回し方: サブエージェント（並列可能な子 k 件）`）を残す。別セッションで同じエピックを再開したときは、`回し方:` で始まる最新のコメントから経路を引き継ぎ、`route` をやり直さない（コメントが無いときだけ `route` で決める）。unmanned（`--unmanned`）は `route` を呼ばず、サブエージェント方式で進める（背景で待って起こされる動きが 1 サイクル 1 仕事と合わないため）。

**エピックである子を外す**: 本体は blocked されていない子のうち、sub-issue を持つ子（`gh api repos/{owner}/{repo}/issues/<N> --jq .sub_issues_summary.total` が 1 以上。`null` や空は 0 とみなす）をエピックとして外し、`route`・`launch`・サブエージェント方式のどれにも渡さない。経路が `nested` でないと確定したら（`route` が `nested` 以外を返したとき。`route` を呼ばない unmanned と、`回し方:` のコメントから経路を引き継いだ再開を含む）、外した子ごとにエピックへ `後で別に起動するエピック: #N` と 1 行コメントする。外した結果、渡す子が 0 件になっても `route` は呼ぶ。`回し方:` のコメントから経路を引き継いで再開したときも、`launch` に渡す前に同じ確認で外す。

**`nested` を受けたセッション**: `launch` は子セッションを `EPIC_DISPATCH_PARENT_EPIC=<エピック番号> cld --model '<model>'` の形で起動するので、並列起動された子のセッションでは `route` が `nested` を返す。子であることは、この端末に付けた環境変数と、子のワークツリーが持つ親子関係（issue の付いた親ワークツリーから作られたこと）のどちらからでも判定されるので、子のセッションを閉じて同じワークツリーで `/develop #<N>` だけを打ち直した起動し直したセッションでも `route` は `nested` を返す。`nested` を受けたらエピックを展開しない（Orca 経路もサブエージェント方式も使わない）。親エピック（`route` の stderr に出る `parent epic: #<N>` の番号）と自分の issue に `後で別に起動するエピック: #<自分の issue>` とコメントし、ユーザーに「このエピックは後で `/develop #<自分の issue>` を別に起動して回す」と伝えて止まる。自分の issue は閉じない。`launch` が stderr に `child epics are not expanded here` を含む理由を出して exit 1 で終わったときも `nested` と同じに扱い、「親ワークツリーで開き直す」とは報告しない（Orca 管理外で止まった exit 1 とは stderr のこの語で見分ける）。`route` の stderr に `parent epic:` があり、そのセッションに `EPIC_DISPATCH_PARENT_EPIC` が無いとき（ワークツリーの親子関係で `nested` になったとき）は、同じワークツリーで起動し直しても `nested` になるので、ユーザーには親を持たないワークツリー（Orca の子として作られていないワークツリー）で `/develop #<自分の issue>` を起動するよう伝える。

**Orca 経路**: 子は独立した Claude Code セッションとして `/develop #<N>` の 1 ループを丸ごと回し、本体は子の W / R1 / G を起こさない。本体は子セッションに SendMessage できないので、子への指示はすべて起動プロンプト（`--note`）で渡す。子ごとに違う注意書き（「後続の範囲に手を出さない」など）が要るときは子ごとに `launch` を分けて呼ぶ。`launch` は `--note` の文を、子 issue に `親エピックからの注意書き: #<エピック番号>` で始まるコメントとしても残す。子のセッションの本体（起動し直したセッションを含む）は、記録先に `親エピックからの注意書き:` で始まるコメントがあればすべて従い、W・R1・G に渡す関連コメントに必ず含める。

1. `scripts/epic-dispatch.sh launch [--note <text>] [--base <branch>] <エピック番号> <子>...` で子を起動する。出力は子ごとに `launched <N>`（最初の指示を子の入力欄に送り、ターンの開始まで確かめた）・`skipped <N>`（同じ子のワークツリーが既にある＝起動済み。再開時や取り違えでも二重に起動しない）・`failed <N>` の 1 行。再開時も、依存が解けた open の子をそのまま `launch` に渡し、起動済みの子は `skipped` で見分ける。stderr に `note not posted to #<N>` があれば、注意書きのコメントを残せていないので、本体が stderr に出た本文をその子 issue に投稿する。起点は `origin/main`。既定ブランチが `main` でないリポジトリでは `--base <既定ブランチ>` を付ける（環境変数 `EPIC_DISPATCH_BASE` でも既定を変えられ、`--base` が優先する）
2. `launched` と `skipped` の子を動いている子として、`scripts/epic-dispatch.sh wait --watch-done <片付け待ちの子> ... <動いている子>...` を Bash の `run_in_background: true` で起動してターンを終える（背景タスクが終わると本体が起こされる）。片付け待ちの子は、`launch` に渡したことのある子（閉じた子を含む）から、エピックに `子 #N のワークツリーを残した` で始まる行がある子を除いたもので、1 件ごとに `--watch-done <N>` を付ける。出力は `closed <N>...` と `done <N>...` のどちらか、または両方の 2 行（両方なら両方を処理する）
3. `done <N>...` で起こされたら（子が「用が済んだ」の印を付けた）、`scripts/epic-dispatch.sh reap <N>...` を Bash で 1 回呼ぶ。wt-clean は呼ばず、子ごとの確認もオーナーに取らない（子が印を付けたことを片付けの承認として扱う）。出力は子ごとに 1 行で、`reaped <N>` と `gone <N>` は何もしない。`reaped <N> branch-kept` はエピックに `子 #N のローカルブランチを残した` と 1 行コメントする。`kept <N> not-done` は待ちを続ける。それ以外の `kept <N> <理由>` はエピックに `子 #N のワークツリーを残した（<理由>）` と 1 行コメントしてオーナーの判断に残し、手で消し直さない。そのあと、動いている子か片付け待ちの子があれば 2 に戻る
4. `closed <N>...` で起こされたら、閉じた子ごとに `gh api repos/{owner}/{repo}/issues/<N> --jq .state_reason` を読む。`completed` ならエピックへ `子 #N マージ → 残り k 件` とコメントし、依存グラフを読み直して解けた子を件数にかかわらず `launch` する。`completed` 以外（`not_planned` など）ならエピックへ `子 #N 見送り（<state_reason>）→ 残り k 件` とコメントし、その子を前提にしていた子は起動せずにユーザーに報告する（依存 API は前提が閉じれば理由を問わず後続の blocked を外すので、理由を見ないと作業されていない前提の上に後続が起動する）。残りの動いている子があれば 2 に戻る。開いている子が無くなったら、片付け待ちの子（2 と同じ集合）で `reap` を 1 回呼んで 3 と同じに扱い、`kept <N> not-done` の子だけを `--watch-done` に渡して（位置引数の子なしで）待ちを続ける。エピックの完了条件の確認と報告は、この待ちを理由に遅らせない。この待ちが `timeout` で終わったら、残っている子の番号をユーザーに報告して待ちをやめる（6 時間ごとに親のターンを使い続けないため）
5. `timeout <N>...` で起こされたら、その子 issue に `needs-approval` ラベルや止まっている旨のコメントが無いかを見て、あればユーザーに報告する。報告したかどうかにかかわらず、残りの動いている子で再び `wait` する。子セッションは interactive の `/develop` なので、子が自分のタブでユーザーに質問して止まっていてもラベルもコメントも残らず、この確認では検知できない。ユーザーには子のタブも見るよう伝える
6. `wait` の `error gh ...`・`error workspaces` と `launch` の `failed <N>` はユーザーに報告して止まる。`failed` の子をサブエージェント方式に自動で振り替えない（Orca 側に途中までできたワークツリーが残っていて二重に起動しうるため）。指示が届かなかった `failed` の子は、報告に stderr の送り直しのコマンドを添え、stderr に出た確認のコマンドで届いていないことを確かめて送り直し、動き出したのを確かめてから再開する（送らずに再開するとその子は `skipped` になり、`wait` が何もしない子を最長 6 時間待つ）。端末を作れなかった `failed` の子は、stderr に出た確認のコマンドでそのワークツリーに既存の端末が無いことを確かめ（あるのに作ると同じ子が二重に走る）、stderr の作り直しのコマンドで端末を作り、返ったハンドルに stderr の送信のコマンドを送って、動き出したのを確かめてから再開する（作り直さずに再開するとその子は `skipped` になり、`wait` が端末の無い子を最長 6 時間待つ）。Orca 経路で始めたエピックを Orca 管理外のワークツリーで再開して `launch` が止まった（exit 1 で子を 1 件も作らない）ときと、`--watch-done` 付きの `wait` が stdout に何も出さず exit 1 で終わった（今のワークツリーを Orca から読めない）ときは、報告に「親ワークツリーで開き直す」と書く
7. `回し方: Orca` を引き継いで再開したら、`launch` の前に、`launch` に渡したことのある子（閉じた子を含む。`子 #N のワークツリーを残した` の行がある子も除かない）で `reap` を 1 回呼び、3 と同じに扱う（待ちをやめたあとに印が付いた子を拾うため）

`timeout` と `closed` で起こされたときの確認では、エピックに `後で別に起動するエピック: #N` の行がある子を動いている子から外す（その子は子エピックとして止まっていて閉じないので、`wait` に渡し続けると最長 6 時間待つ）。

子セッションは `launch` が `cld --model '<model>'` で起動する。`<model>` の既定は `opus`（子は `/develop` の 1 ループを丸ごと回すオーケストレーターなのでメインセッションと同じ扱い）で、環境変数 `EPIC_DISPATCH_MODEL` で変えられる。Claude Code の既定モデルは子に効かない。コマンド部分（既定 `cld`）は環境変数 `EPIC_DISPATCH_CLAUDE_CMD` で差し替えられ、クォートせずそのまま置くので `cld-account b` のような引数付きも書ける。Orca に設定したエージェントのコマンドはハーネスから読めないので、Orca 側のコマンドを変えたら `EPIC_DISPATCH_CLAUDE_CMD` も合わせて変える。端末を作れずに `failed` になった子には、既存の端末が無いことの確認・端末の作り直し・最初の指示の送信のコマンドが stderr に出る（使い方は手順 6）。

子セッションは `cld`（`EPIC_DISPATCH_CLAUDE_CMD` で差し替えたコマンド）が付ける `--dangerously-skip-permissions` で動き（`epic-dispatch.sh` が足すのは `--model` だけ）、許可の確認画面は出ない（hooks は効く）。マージを止めているのは確認画面ではなく develop と pr-review-gate の規則と hooks である。子の PR のマージは今までどおり子セッションの中で人の承認で行い、本体は自動でマージしない。

**サブエージェント方式**: blocked されていない子から**上の 1 ループを子ごとに並列**で起こす。worktree は子ごとで、本体が W を `isolation: "worktree"` で spawn して用意する（W は自分で worktree を切らない）。子の PR がマージされたらエピックに 1 行コメント（`子 #N マージ → 残り k 件`）し、依存が解けた子を次に起こす。

**両経路に共通**:

- スタック PR（子 B が子 A のブランチを base にする）は避け、A のマージを待ってから B を main から切る。やむを得ずスタックする場合は、A マージ後に B の base が自動では main に切り替わらないので本体が張り替える
- 子の実装中に新しい問題が見つかったら、その子の中で直さず**新しい子 issue** を切ってエピックに追加する（子の受け入れ条件を膨らませない）

### 完了条件

全子 PR がマージされ、**かつ**本体（または G）がエピックの完了条件（ユーザーストーリーの成立）を実機で確認して、その証拠をエピックにコメントしたとき。子が全部マージされただけでは閉じない。

動いている子が無くなったときの報告（エピックへのコメントとユーザーへの完了報告）には、エピックに記録した `後で別に起動するエピック:` の番号をすべて載せる。子エピックが閉じるまで全子 PR のマージは満たされないので、親エピックは閉じない。

## 上流の壁打ち（`/opsx:explore`）を呼ばない理由

このスキルは規模が大きくても、上流の壁打ち（openspec の `/opsx:explore`。まだ形になっていない曖昧な要望を、対話で質問しながら実装可能な単位に分解し、相互矛盾がないか確認する工程）を内部から呼ばない。このスキルが扱う依頼（issue・受け入れ条件付きの会話依頼・エピックの子）は既にその「ほぐす作業」が終わった状態にある。複数 change が必要なら記録先の記述を根拠に分割すれば足りる（エピックの作り方）。`/opsx:explore` は issue の体裁を成す前の構想専用として切り離し、その出口（`/opsx:new` / `/opsx:ff`）からこのスキルに入る。

## 参照

- 役割の指示書: `references/roles/worker/`（W。索引は `references/roles/worker.md`）・`references/roles/spec-reviewer.md`（R1）・`references/roles/gate-runner.md`（G）
- 仕様化要否・change 分割・残量モードの判定基準: `references/decision-criteria.md`
- 昇格トリップワイヤーの常駐ルールテンプレート: `plugins/dev-workflow/templates/escalation-tripwires.md`
- G の手順書: pr-review-gate の段のファイル（`skills/pr-review-gate/stages/` と `declarations.md`。索引は `skills/pr-review-gate/SKILL.md`、G が時点ごとに読むファイルは `references/roles/gate-runner.md` の表。記録先の探索順・仕様宣言の照合は据え置き）
- 入口の 5 分岐と issueify フォールバック: `commands/develop.md`（`/work-issue` はエイリアス）
- worktree セットアップの自動化: worktree プラグインの `hooks/hooks.json`（`WorktreeCreate` / `SessionStart`）
- 棲み分け相手: 各リポに配備された loop-dev-agent の憲法（`docs/agent-loop.md`。flatmate が保守する正本で、harness にテンプレートは無い）。unmanned の外形（ラベル・Draft PR・キュー）は憲法側
- 1 ループに収まらない規模を Workflow で回す型: `plugins/dev-workflow/references/workflow-execution.md`（スクリプトの書き方は `workflow-authoring` スキル）
