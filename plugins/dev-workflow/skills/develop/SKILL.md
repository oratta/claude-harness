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

## 開始時の idle compaction 設定

工程前に `references/reply-after-idle.md`「開始時の設定」を Read して従う（親・子・単発、新セッション・compact 後も同じ）。

## Role profile の選択

profile と旧 account/model のどちらも明示しない場合、各 canonical phase の開始時に adapter で再評価する。登録 Codex accounts の週次 snapshot の実効値（取得からの経過時間で捨てず、リセット時刻で読み替えた値）と Claude 起動 account の実効値（セッション記録と snapshot をリセット時刻で読み替えた値）から構成を選ぶ（margin の求め方と構成の選び方は `references/codex-develop.md`「起動と role 解決」が正本）。開始済み role は工程途中で切り替えない。adapter が返す構成（`claude-write-codex-review`・`codex-standard`・Claude 既定構成のどれか）、reason、両 provider の margin / fetched_at、代表 Codex account を、最初の develop 開始コメントと後続 phase の dispatch 記録へ残す。値が無ければ `missing` と記録する。develop 開始コメントには、あわせて「実行モード」の節の `実行モード:` の行と、channel のときは `references/channel.md` の「channel のリスク許容」で決める `チャンネルの返事の確認:` の行を残す。

`--profile NAME [--profile-file PATH]` または旧形式の Codex account/model を明示したときは、`${CLAUDE_PLUGIN_ROOT}/references/codex-develop.md`（未設定ならこの SKILL.md から `../../references/codex-develop.md`）を絶対パスに解決して Read する。各委譲の直前に adapter から canonical role の per-role execution result を取得し、provider 操作は同 reference の「role 解決直後の一度だけの分岐」に従う。事前分類に当たる R1 または G が要求したレビュアーは、対象 role の entry ではなく profile の `decider` entry（executor/account/model）を使い、`subagent_type: dev-workflow:decider` として起動する。この SKILL.md はその分岐を再掲せず、工程順、role、review 条件、return 契約、次工程の判断だけを正本として維持する。

G の起動指示（段ごとに新しく起こす G と、手渡しで起こす後任 G のすべて）には、起動形を問わず常に `レビュー経路: adapter` の 1 行を書く（自動選択・明示 profile・旧形式のどれも adapter で解決するので、今が adapter 経路かを評価しない）。Codex の G では request の instructions（`--input` の指示ファイル）にも書く。develop の本体は `レビュー経路: 従来` を書かない（develop の本体以外の呼び出し元のための値）。G は再開せず段ごとに新しく起こすので、起動指示に行が無い G は従来経路（full は G が Codex を直接呼ぶ）として動く。どの段の起動指示でも行を省略しない（`references/roles/gate-runner.md`「レビュー経路の判別」）。

本体は、名前付き profile（自動選択が profile 構成を返した場合を含む）で起こすたびに thread と requested tuple / applied model / reason を記録し、同じ Claude profile role を再開する直前に毎回 `FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` の上限を再確認して、上限内のときだけ SendMessage する（上限を超えるなら SendMessage せず、工程完了か停止確認の条件を満たしてから requested tuple を変えずに capped model の fresh thread へ手渡す）。fresh thread にする境界を含め、細目は `references/codex-develop.md`「本体が行う操作」が正本（その操作を行う前に Read する）。以下の spawn / SendMessage 表記は、profile 利用時にはこの規則を適用した provider 操作を意味する。

## いつ使うか

ソースコード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変える作業は、依頼の入口を問わず（GitHub issue・会話・cron・エピックの子のいずれでも）このスキルを通す。「issue があるか」は入口 0 で記録先を決める材料にすぎず、スキルを通すかどうかの条件ではない。

例外は「読むだけ・回答だけ・生成物を出すだけ」の作業（調査報告・質問への回答・レポートや図の生成など、リポジトリの追跡対象を変えないもの）に限る。

## 前提

無いときの縮退まで含めて列挙する。本体が spawn できない環境（本体自身がサブエージェント）ではこのスキルは成立しないので、その場合は親に return して親を本体にする。

| 前提 | 使い方 | 無いとき |
|---|---|---|
| **Agent ツール** | W (`dev-workflow:worker`) / R1 (`general-purpose` または `dev-workflow:decider`) / G (`dev-workflow:gate-runner`) / G が要求するレビュアー (`dev-workflow:reviewer` または `dev-workflow:decider`) / V (`general-purpose`) の spawn。`model` を必ず明示し、W と G は**名前付き**で spawn する（W は SendMessage で再開するため。G は再開せず段ごとに新しく起こし、名前は (4) の形にする）。W は本体が対象専用の worktree にいなければ `isolation: "worktree"` で起こす。**`isolation: "remote"` は使わない**（理由は「worktree の用意」） | 本体になれない。親セッションに return する |
| **SendMessage** | 名前付きで起こした W の再開（コンテキストを引き継いだまま次の工程を指示する）。G は再開しない（段ごとに新しく起こし、レビュー要約は起動指示で渡す） | 再開できないので、前任を手渡してよい状態のときだけ新しい W を spawn し、前回の return 全文をプロンプトに渡す。条件は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本で、満たさないなら spawn せず親に返す（前任が動いたまま後任を起こさない） |
| **`gh`** | 記録先（issue / PR）へのコメントとラベル操作、Draft PR の作成、エピックの子の依存（`gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by`、issue dependencies API） | 記録先を作れないので開始しない（記録なしで実装に進まない） |
| **openspec CLI** | W は `openspec --version` で経路の有無を決め、`openspec new change` → R1 → TDD → `openspec validate --strict` → `openspec archive` と進める。opsx コマンドは本体や主の対話用 | 仕様化経路が発生しない（W は `仕様化判断: しない` の理由に「openspec 不在」と書き、コード直行する） |
| **`orca`** または **`tmux`** | エピックの子を、Orca の子ワークツリーか tmux のウィンドウで独立した Claude Code セッションとして起動する（`scripts/epic-dispatch.sh launch`。`references/epic.md` の「回し方」の別セッション方式。`tmux` は本体が tmux の中にいる場合） | エピックはサブエージェント方式で回す。`orca` はあっても本体が Orca 管理外のワークツリーにいて tmux の中にもいないときも同じ（`route` が `subagent` を返す） |
| **Codex CLI** | adapter 経路（develop の本体が起こす G）では G は full でも `needs-reviewer` を返し、本体が phase `review` で投げ先を選び直す（Codex が選ばれればそこで使う）。従来経路（develop の本体以外の呼び出し元が起こす G）では G が full レビューを Bash から `codex exec` / `codex-companion.mjs` で実行する | G が `needs-reviewer` を return し、本体が別のレビュアーを spawn して要約を G に渡す（gate-runner.md） |

## 本体の役割

本体は役割 W / R1 / G を `model` 明示で spawn し、**return の要約と記録先（issue または Draft PR）のコメント・ラベルだけ**を見て次に誰を起こすかを決める。並列可能な役割（エピックの子どうし、独立した change の W どうし）は並列に起こしてよい。**ただし、1 つの worktree で同時に動く同一役割のサブエージェントは常に 1 人（MUST）。並列に起こしてよいのは別々の worktree を持つ役割に限る。**

禁止事項（本体がこれをやると、別コンテキストの網が全部外れる）:

- **本体は Edit でコードを書かない。** テスト・実装・仕様ファイルの編集はすべて W の仕事。本体が「小さいから」と直接直した瞬間に、その変更は R1 / G の別コンテキストレビューを通らずに PR に乗る
- **本体はレビューを代行しない。** 仕様レビューは R1、PR レビューは G（と G が要求したレビュアー）が行う。本体が W の return を読んで「よさそう」と判断することはレビューではない
- **W が孫を呼ぶ必要がある工程を設けない。** 別コンテキストを要する工程（R1・G・G のレビュアー）はすべて本体が起こす。W の指示書に「サブエージェントを spawn せよ」と書かない

本体がやること: 入口 0 の記録先の確定、worktree の用意、各役割の spawn と再開、return の要約の転記（記録先のコメントは各役割が自分で投稿する。**例外: `subagent_type: dev-workflow:decider` で起こした役割は `Bash` を持たず `gh` を実行できないので、その return は本体が同じ書式で代理投稿する**。ただし pr-review-gate の仕分け表の順 6 の裁定は代理投稿せず G に返し、G が記録する）、needs-approval 時のオーナーへの依頼、エピックの進行管理。

## 主に聞かずに決めること

本体・W・G が主に聞くのは、次のどれかが要るときだけ（#1035）: 主の側にしか無い情報（好み・事業判断・許容度）、主の手でしかできない操作（MFA・OAuth・ログインなど）、規則が主の承認を求める操作（`rules/destructive-git-guard.md` の一覧・マージ・聖域）で、それは（`~/.claude/output-styles/readable.md` の節 3 の主に聞く理由の 3 つに当たる。マージは、人が押すと決まっている場面では主の手でしかできない操作、マージしてよいかを聞く場面では決まりの側）。それ以外は次の 4 つの型の決め方で自分で決め、記録先に事後報告する。

- **自分側の誤りの後始末**: 本体・W・G・レビュアーが記録先の範囲の外に誤って入れた変更（実ホームの設定ファイルへの書き足しなど）は、控え・git の履歴・自分のツール呼び出しの記録のどれかと今の状態を比べ、差分が自分側の入れた分だけで戻し先が一意に決まるなら、主に聞かずに今の状態の控えを取って戻し、記録先に何を・どこから戻したか・控えの場所を事後報告する。差分が自分側の分だけと確かめられないときは主に聞く。git の破壊的操作（`rules/destructive-git-guard.md` の一覧）はこの型に入らず、事前承認のまま。聖域（CLAUDE.md・hooks・権限設定）への変更を戻す操作も、差分が一意でもこの型に入らず、無条件で人間承認のまま。例: claude-harness #977 でゲート担当が実ホームの `~/.claude/accounts.json` に書き足した `z` の 1 件は、控えの `.bak` との差分がその 1 件だけなので、聞かずに消して事後報告する
- **範囲外の問題の起票**: 本体が作業中に見つけた記録先の範囲外の問題（レビュー指摘ではないもの。G の振り分けを経た指摘は G の振り分けのまま扱う）は、本体が行き先（捨てる・既存 issue に参考として入れる・新しい issue）を決め、起票したら URL を事後報告する。`skills/pr-review-gate/stages/triage.md` は PR 番号・PR コメント・G の手順 3 を前提にしているので丸ごとは当てず、段 B・段 D・段 E の問い（エピックの子の記録先なら段 C の問いも）と段 B の表だけを借りる。起票してよいかを主に聞かない。G の振り分けの結果を主への報告にまとめるときも、行き先を「オーナーが決める」に書き換えない。起票によって配布や後続の作業の順番を変えるかは主に聞いてよいが、起票はその前に済ませる。例: flatmate #1104 でリハーサルの記録から見つけた詰まった操作は、本体が起票して URL を報告する
  - 候補探し: 段 B を通った問題が 1 件以上あれば、問題がファイルを指すなら `plugins/dev-workflow/scripts/review-issue-candidates.sh --repo $R --exclude <記録先の番号> [--epic <エピック番号>] <パス>...` を、ファイルを指さないなら `gh issue list --repo $R --state open --search "<問題を表す語>"` を、それぞれ 1 回だけ走らせる。記録先の番号は記録先の issue、記録先が Draft PR ならその PR の番号。終了コードが 0 でないときの扱いは `triage.md` の候補探しの段落に従う。再試行後の終了コードは記録先の `範囲外の問題の振り分け` コメントに書き、既存 issue への相乗りをせずに段 E へ進む
  - 判断結果の記録: 記録先（issue、または Draft PR）に、1 行目が `範囲外の問題の振り分け` ちょうどのコメントを 1 件置き、問題ごとに、問題の要約・当てた段・行き先（issue にした・コメントで入れたならその URL、捨てたなら理由の 1 行）を書く
  - 段 B の確認待ち: 条件がいつ成り立つかを、記録先・エピックの本文・受け入れ条件・コード・本文の節 `## 条件の答え` から決められないときは、起票の可否ではなく条件についての問いを主に聞く。同じコメントにその問題を `条件の確認待ち` として質問文とともに残し、`needs-approval` を付けず、作業を止めない。答えは 1 行にして記録先（エピックの子ならエピック）の本文の節 `## 条件の答え` に足し（節が無ければ作る）、その問題を段 B から当て直す
  - エピックの注意書き: 記録先にエピックの親（OWNER）からの注意書きがあり、新しい問題の置き場所を指定している（例: エピック #1038 の「新しい問題はエピックに新しい子 issue として切る」）ときは、段 C の「既存の子 issue の受け入れ条件に足す」より注意書きを優先する
- **小さな実装の選択**: どれを選んでも受け入れ条件と利用者に見える振る舞いが変わらない選択肢は、その工程の担い手が選び、選んだ理由を記録先に残す。レビューの 2 周目以降の周の終わりに残った指摘の直し方は、`references/fix-check.md` の節「レビューの周を主に聞かずに続ける（直し方の判定）」に従う（例: flatmate #1564 の、仕様レビューの BLOCKER を閉じるテストの方式 A/B）
- **閉じる操作**: 受け入れ条件を満たした記録先を閉じる操作は、節「ループの終わり」に従い、主に渡さない（例: claude-harness #693 の調査だけの issue）

自分側の誤りの後始末の守備範囲は、本体・W・G・レビュアーのツール呼び出しが記録先の範囲の外（実ホームの設定ファイル・別のリポジトリなど）に書いた変更である。拾いたい誤りは、戻す内容が差分から一意に決まるのに、戻してよいか・いつ戻すかを主に聞いて止まることで、これは主に聞かずに戻す。通してよい例は、控えの `.bak` との差分が自分側の書き足した 1 件だけで、その 1 件を消すこと。主の変更と区別できない差分・git の破壊的操作・聖域への変更を戻す操作は主に上げる。戻した内容が誤っていたことは防がない（戻す前に取った控えから取り消せる）。

範囲外の問題の起票の守備範囲は、本体が作業中（リハーサル・調査・実装の確認など）に見つけた、レビュー指摘ではない記録先の範囲外の問題である。拾いたい誤りは、起票してよいか・誰が起票するかを主に聞いて止まることと、G の振り分けの結果を「オーナーが決める」に書き換えて主に渡すことで、これらは主に聞かずに起票か捨てるかを決める。通してよい例は、リハーサルで詰まった操作を新しい issue にして URL を事後報告すること。主に上げるのは、段 B の条件が本体に決められないときの条件についての問いと、起票によって配布や後続の作業の順番を変えるかの判断だけである。行き先の選び方が外れること（捨てた問題が後で効くなど）は防がない（記録先のコメントに理由が残るので、後から拾い直せる）。

## 入口 0: 記録先を決める

1 ループの最初の工程。仕様化判断・仕様レビュー結果を置く「記録先」を先に確定する。

- **issue があればそれを記録先にする**（番号・URL・自然文マッチ。`/develop` の 5 分岐は `commands/develop.md`）。エピックの子は子 issue が記録先
- **無ければ issue を切らない。** 本体が worktree を用意し、W が worktree 直後に空 commit（`git commit --allow-empty`）を積んで push し、`gh pr create --draft` で Draft PR を開いてそれを記録先にする（GitHub の "open a draft PR early" の慣行）。この Draft PR は**仕様化判断を記録する前**に存在していなければならない — 記録先が無い状態で判定を先に進めない（手順は `references/roles/worker/spec.md`「記録先の用意」）
- Draft PR を記録先にするときの PR 本文の決まり（受け入れ条件は PR 本文に書く・PR 本文に `Closes #N` / `Fixes #N` / `Refs #N` の issue 参照を書かない。エピックの子は `Closes #子` を書く）は、`references/roles/worker/spec.md`「記録先の用意」が正本
- 仕様化判断（`仕様化判断: する|しない`）・仕様レビュー結果（`仕様レビュー: APPROVE|REQUEST_CHANGES`）は記録先のコメントに置く（書式の正本は `references/roles/spec-reviewer.md`「判断記録の契約」）
- **仕様宣言は記録先ではなく常に PR コメントに置く**（記録先が issue でも issue には書かない）。pr-review-gate 手順 5 が PR のコメントでリスク宣言・仕様宣言・動作確認の 3 見出しを照合し、`対象 HEAD:` 規約が PR の HEAD に紐づくため。書式の正本は pr-review-gate スキル手順 3-b

**issue を切るのは追跡・キュー・議論が要るときだけ**: エピック（複数 PR にまたがる。`references/epic.md`）／無人キュー（loop-dev-agent が拾う対象にしたい）／判断を残す議論（決定の経緯を issue スレッドに残したい）。この 3 つに当たらなければ Draft PR で足りる。issue を切る経路は `commands/develop.md` の issueify フォールバック。

## worktree の用意

worktree は**本体が用意する**。`.worktreeinclude` が無いときは本体が `/wt-setup` を呼ぶ。本体が既に対象専用の worktree（1 issue = 1 worktree = 1 ブランチ）にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。**W は自分で worktree を切らない**（セットアップは `WorktreeCreate` / `SessionStart` hooks が担い、W は判定もしない）。unmanned では憲法側が用意した worktree を使う。**`isolation: "remote"` は使わない**（MUST NOT）。強制停止中は `Bash` 全件拒否で commit できず、差分は本体が引き取る（「工程中断: で返ってきたら」）。本体から見えない `remote` では差分を失うため。

## 1 ループ（W → R1 → W → G）

1 issue（または 1 Draft PR）につき次を回す。各工程の担い手と、本体が次に誰を起こすかの判断材料を書く。

下の各工程の spawn・SendMessage による再開・Codex executor への委譲の直前には、毎回「PR トークン上限」の節の計測を行う（exit 2 なら起こさず止まる）。

```
(0) 記録先を確定する（入口 0）。worktree を用意する
(1) W を `subagent_type: dev-workflow:worker` で名前付き spawn（起動指示に `段: spec` の 1 行を書く。model: references/pre-classification.md の事前分類表の「1 周目」列に当たればその値、それ以外 sonnet。上限は「モデル」節の表の W の行、残量の効き方は同節の残量モードの段落）:
      記録先の用意（Draft PR 経路）→ 仕様化判断の記録 → 分割判定 → openspec new change → return「仕様できた」
      仕様化しない判定なら → (3) へ直行（TDD → PR）
      文言合わせの通し方（既存の仕様の文言を実装に合わせて直すだけの変更。判定基準は `references/decision-criteria.md` Step B）なら → W は仕様の差分 1 ファイルだけを書いて return する。
           本体は W の return の文面ではなく、記録先の最新の仕様化判断のコメントに `通し方: 文言合わせ` の行があることを確かめ、あれば次の R1 の工程を飛ばして W を `段: implement` で再開する。
           行が無ければ W を実装に進めず、`段: spec` で再開して仕様化判断を投稿し直させる（そのあとは R1 の工程を通す）
(2) R1 を spawn（model: 既定 opus。マージ条件・層間契約・課金/法務に触れれば subagent_type: dev-workflow:decider で spawn する。聖域パスだけでは上げない）:
      references/roles/spec-reviewer.md に従って別コンテキストで仕様レビュー → 結果を記録先にコメント → return
      dev-workflow:decider で起こした R1 は gh を実行できないので投稿せず return し、本体が同じ書式で代理投稿する
      （記録先の本文と関連コメントは本体が入力文に貼って渡す。エピックの子ならエピックの本文も）
      R1 を起こすときは（当て直しを含む）エピックの本文（エピックの子でなければ記録先の本文）の節 `## 条件の答え` の行を依頼文に入れ、エピックの子ならエピックの番号も書く
      BLOCKER に `条件の問い:` がある・2 周目以降の周の終わりに BLOCKER が残った・NOTE に `後で成り立つ:` の行があるときは、W の再開と直し方の判定の前に `references/fix-check.md` を Read し、その節「残った指摘の条件を確かめる」を通す（成り立つ予定が無い指摘は判定に回さず捨てる）
      REQUEST_CHANGES → W を SendMessage で再開（再開指示に `段: spec`）して artifact を修正 → R1 を再開して差分再レビュー
      （既定 2 周＝初回＋差分 1 回。2 周目以降の周の終わりに BLOCKER が残れば、`references/fix-check.md` を Read し、その節「レビューの周を主に聞かずに続ける（直し方の判定）」の判定を通す。
       残った BLOCKER がすべて直し方が決まっているもので PR トークン上限の内側（`pr-token-budget.sh` が exit 2 でない）なら、主に聞かず次の周を回す（W を `段: spec` で再開 → R1 に差分再レビュー。その周の R1 の結果を受け取ったら、`references/fix-check.md` の「続行と事後報告」の書式で事後報告を記録先に投稿する）。
       方針の選び直しが要るなら needs-approval を付けて本体がオーナーに 1 アクションで依頼し、`references/handover.md` どおり引き継ぎを残す）
      R1 の APPROVE が記録先に記録されるまで W を apply に進めない（再開しない。例外は (1) の文言合わせの通し方だけ）
(3) W を SendMessage で再開（再開前に `scripts/subagent-context.sh <W の名前>` で測る。上限超を検知した
      あとの扱いは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本。正本を読むまで手渡さない）。
      (3) は 2 回の return に分かれる:
      (3a) 再開指示に `段: implement` を書く。apply（TDD。openspec CLI で tasks を実装）→ openspec validate --strict → return「工程完了: 実装＋verify」
           （収集した検査コマンドの一覧と各 exit code〔未導入は明記〕、openspec validate --strict の exit code、画面確認: の行を載せる）
           （文言合わせの通し方の (3a) では `tasks.md` が無いので、W が (1) の return に書いた作業項目を TDD で実装し、検証は `openspec validate <change-name> --type change --strict` で行う）
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
(4) G を `subagent_type: dev-workflow:gate-runner` で段ごとに名前付き spawn（model: 既定 sonnet。G の仕事は照合・ラベル操作で、欠陥探索は needs-reviewer で本体が起こすレビュアー（従来経路では Codex）が担う）:
      文言合わせの通し方では、本体は G を起こす前に、記録先の最新の仕様化判断のコメントの `直す文:` の行が archive 済みの差分の要件名と一致することを確かめる
           （1 つの記録先を複数の change が共有すると、最新の仕様化判断が別の change のものになることがある。一致しなければ G を起こさず、W を `段: spec` で再開してその change の仕様化判断を投稿し直させる）
      段ごとに新しい G を起こす（段は 前提確認と重さ判定・照合と振り分け・合格処理・保留の解除 の 4 つ。1 体は 1 段だけを担当する。
           起こす時点と渡すものの表は gate-runner.md「段ごとの起動と入力」）。名前は `G-<PR>-<prepare|triage|pass|hold>-<n>`（n はその PR・その段で
           起こした回数）、description は `G: <段> for PR #N (#issue)`（先頭の `G:` を残す。役割別集計がこの接頭辞で G と判定する）
      G の起動指示には常に `レビュー経路: adapter` の 1 行と `段: <段の名前>` の 1 行を書き（`レビュー経路: 従来` は書かない。
           詳細は「Role profile の選択」節の、`レビュー経路` の行の書き方（`レビュー経路: 従来` を書かない規則と Codex の G への書き方）、2 つ目以降の段では前の段の `## Gate Result` ブロックを要約し直さずそのまま貼る。
           channel のときは `実行モード: channel` の行と、develop 開始コメントと同じ値の `チャンネルの返事の確認:` の行（`可` / `不可`）も書く（G が hold.md 手順 6-3 の依頼文を書き分ける入力。`references/channel.md` の「channel のリスク許容」）
      次に起こす段は Gate Result の Status と `次の段:` だけで決める（止める指摘が残っているか・戻した指摘の仕分け・復帰手順の行き先を本体は判断しない）。
           G が `工程中断:` で返したら同じ段の新しい G を起こし、前任の return 全文と前任の起動指示に書いた入力を渡す
           （起こしてよい条件は references/decision-criteria.md「コンテキスト上限（サブエージェントの手渡し）」の「手渡しの許可」）
      4 つの段で pr-review-gate の手順 1〜5 → return「passed / failed / 保留 / needs-reviewer / needs-decider / needs-fix-check / review-incomplete / needs-carryover-judge / 次の段へ」
      次の段へ → `次の段:` の G を新しく起こす（照合と振り分けが止める指摘なしで終われば合格処理。保留の解除は合格処理か前提確認と重さ判定）
      合格処理（手順 5）では PR が Draft なら Ready にしてから agent-review:passed を付ける（W は Ready にしない）
      passed → 本体が `plugins/dev-workflow/references/ci-watch.md` の手順で CI の見張りを始める（G は見張りを始めない）。
           見張りの背景タスクの `stopped` / `killed` 通知は `references/ci-watch.md` の 9 に従う。
           ただし G の return に `issue で承認済み:` があれば、CI の見張りの前に主へその行（宣言 URL・分類・引用）を 1 回伝える（pr-review-gate 手順 5 の事後報告。書式は pr-review-gate `stages/pass.md`）。
           見張りの一手が `fix` なら W に直させ（再開指示に `段: implement`。再開か手渡しかは (3) と同じく正本に従う）、
           W が push したら本体が passed を外したまま同じ状態ファイルで `wait` → `next` を続け、
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
      failed → 原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出／段 A だけ（昇格なし））で戻し方を決める。モデルを上げるのは実装品質起因のときだけで、上げるのは決める役と実行役の一方だけ（実行側が原因なら W を `opus` まで（`fable` にしない。上限の正本は「モデル」節の表の W の行）、判断側が原因なら dev-workflow:decider。判断側・実行側の定義と decider の model の段は「モデル」節の昇格トリップワイヤーの段落）。
           仕様が曖昧なら仕様修正、誤検出なら反証で返す（どちらもモデルを上げない）。段 A だけなら W を据え置きで再開する
           → W を再開（再開指示に `段: implement`。再開前に測る。上限超のあとの扱いは (3) と同じく正本に従う）→ W の修正のあと、failed の Gate Result の `次の段:` どおりの G を新しく起こして再レビュー（順 3 だけなら照合と振り分け、それ以外は前提確認と重さ判定。
           2 周キャップ。範囲と 3 周目の扱いは pr-review-gate の収束ルールに従う）
      保留 → needs-approval のまま本体がオーナーに 1 アクション（許容する／しない、動作確認の結果、切り出しの確認への回答（切り出す／この PR で直す））で依頼する。止まる前に `references/handover.md` どおり記録先へ引き継ぎを残し、主に新しいセッションでの再開を案内する（channel では新しいセッションを案内せず、同ファイルの channel の案内をチャンネルに送る）。依頼を出したあとに同じ保留の通知・報告の再送が届いたときは、同ファイルの「依頼の出し直し」に従う。回答が届いたら保留の解除の G を新しく起こし、回答を渡す（新しいセッションなら同ファイルの再開手順から）。リスク許容を会話で受けたら主に PR へのコメントを求めず、自分のセッション ID（`$CLAUDE_CODE_SESSION_ID`）・その発言の日時（会話ログの timestamp。`owner-reply-check.sh` を回す前に `references/handover.md` の「会話で受けた返事の日時の取り方」を Read し、その手順で取る）・原文を G に渡す（記録の書式と真正性確認は pr-review-gate 手順 5 の「会話で受領」が正本）。エピックの子が親経由で許容を受けたときは、自分のセッション ID で確かめず、`references/epic-child-stop.md` の「親から届いた返事」の手順で確かめてから G に渡す
      needs-fix-check → 2 周目以降の周の終わりに残った指摘の直し方の判定（G が判定に回す条件は pr-review-gate 手順 2-1 の周の終わりの段落）。
           本体は `references/fix-check.md` を Read し、その節「レビューの周を主に聞かずに続ける（直し方の判定）」の手順で、PR トークン上限を測ってから dev-workflow:decider を起こして判定を受け取り、
           判定の記録を記録先に投稿し、判定（決まっている／選び直しが要る）と判定の記録の URL を渡して照合と振り分けの G を新しく起こす。
           本体は自分でラベルを付け替えず、W も再開しない（W に戻す指摘の一覧とラベルは G が決める）。判定が「決まっている」で開いた周の結果
           （その周の照合と振り分けの G の return）を受け取ったら、同じ節の書式で事後報告を記録先に投稿する
      needs-carryover-judge → 許容済みの PR で HEAD が動き、risk-carryover-check.sh が終了コード 4 を返した（G が判定に回す条件は pr-review-gate の `stages/hold.md` 手順 3-c の「終了コード 4 の判定役」）。
           本体は PR トークン上限を測ってから、`stages/hold.md` 手順 3-c の依頼の書き方で subagent_type: dev-workflow:decider・model: `opus` の判定役を起こし
           （入力は G の return の前 HEAD・新しい HEAD・前の宣言・EVIDENCE_PR_CHANGED= のファイルから作る。作業の文脈は渡さない）、判定の記録を PR に代理投稿し（書式は 3-c が正本）、
           判定と判定の記録の URL を渡して合格処理の G を新しく起こす。SHARED_BUDGET_MODE=depleted なら判定役を起こさず、3-c の書式で
           `引き継ぎ判定: 判断できない` の記録を投稿して同じく合格処理の G を新しく起こす（G が手順 6 で主に聞く）。
           本体は判定を受けて自分で宣言を投稿せず、ラベルを付けず、主に聞かない（引き継ぐか主に聞くかは合格処理の G が決める）。
           ただし、判定を受けて起こした合格処理の G が同じ前 HEAD・新しい HEAD・根拠ファイルの組で再び needs-carryover-judge を返したときは、
           判定役を起こし直さず、投稿した記録の URL を添えて主に聞く（G 側の止めが外れたときに opus の判定役を繰り返し起こさないため）
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

W は名前付きで spawn し、SendMessage で再開してコンテキストを引き継ぐ（(1) の判定・(2) の指摘・(3) の実装が同じコンテキストにある）。**ただし再開の前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測る（exit 2 が上限超）。閾値と全解除の環境変数・途中計測 hook を含む 2 経路・上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言・前任が動作中のまま交代させる手順）は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本で、この SKILL.md には書かない。正本を読むまで手渡さない。** G は再開せず段ごとに新しく起こすので、再開前の計測は W だけに掛かる。**W の起動指示・SendMessage による再開指示・手渡しの起動指示には `段: spec` / `段: implement` / `段: finish` の 1 行を必ず書く**（W は `references/roles/worker/common.md` とこの行が指す段のファイルだけを読み、行が無ければ読まずに聞き返す）。値はその起動・再開で本体が指示する工程で決める（上のコードブロックの各工程に書いた値）。手渡しでは、前任が工程の途中で止まり（return の 1 行目が `工程完了:` でない）後任に同じ工程を続けさせるなら前任が担っていた段、前任が `工程完了:` で return したあとに後任へ次の工程を指示するならその工程の段にする（(3a) を終えた前任の後任に (3b) を指示するなら `段: finish`、(1) を終えた前任の後任に R1 の REQUEST_CHANGES の修正を指示するなら `段: spec`）。次の工程は本体が自分の指示した工程から決め、前任の return の工程名の文字列から決めない（新しいセッションで引き継ぎから再開する本体は、引き継ぎの「次に起こす役割」に書かれた `段:` の値を使う）。**`工程中断:` で返ってきた return にレビュー結果（`agent-review` の判定やレビュー本文）が含まれていたら、本体がそれを記録先に代理投稿する**（G が途中計測の強制停止に当たると `gh pr comment` も拒否されるため。R1 の仕様レビューを代理投稿するのと同じ形）。**強制停止中は commit も本体が行う**: `工程中断:` の return を受け取ったとき、および次の手渡し・次の spawn・そのサイクルの終了・worktree の撤去のいずれよりも先に、本体は return に書かれた作業ツリーのパス（強制停止による中断なら hook の `permissionDecisionReason` に含まれる `cwd`）に対して `git -C <path> status --porcelain` を実行して未コミット差分を確認し、残っていれば本体が commit する（MUST。止まったサブエージェント自身は `Bash` が全件拒否されて commit できない。手渡し先が確認するのは**次に起こされた**サブエージェントの差分だけなので、手渡しが発生しない経路や後継が G の場合はこの本体側の確認が無いと作業が失われたまま残る）。W が孫を呼ぶ必要がある工程は存在しない。仕様化する場合で複数 change に割れたときは、interactive では change ごとに (1)〜(3) を回す（change ごとに仕様レビューを行う。並列可能なら W を並列に起こす（エピックの子のときは `references/epic.md` の「回し方」のサブエージェント方式の枠に従う）。change ごとに worktree を分ける）。

**W が `(Subagent completed but returned no output.)` だけを返したとき**（破壊的 git 操作を 2 回拒否されて hook に打ち切られた子は、拒否の理由が親に届かずこの形で返る）は、その W に SendMessage で 1 回だけ報告を求める（何をしようとして、何が拒否されたかを、打ちたかったコマンドの全文・対象のパス・その対象を自分で作ったか（作ったならそのコマンド）・なぜ要るか・拒否の記録のパスの 5 項目で書かせる）。報告の有無によらず、SendMessage の前後に `git -C <path> status --porcelain` で作業ツリーの未コミット差分を確かめ、残っていれば本体が引き取って commit する。報告に破壊的 git 操作で拒否・打ち切られたとあれば、同じ指示で起こし直さない。次の 4 つをすべて満たすときだけ、本体の Bash で `${CLAUDE_PLUGIN_ROOT}/scripts/git-guard-permit.sh <拒否の記録のパス> <理由>`（理由は W の名前と 4 項目の要約）を実行して許可を書く。(1) 報告の 4 項目が揃い、コマンドの全文が拒否の記録の `command` に一致する（記録の `cwd` はコマンドを始めたディレクトリで操作対象ではないので、コマンドの全文・`cwd`・操作対象を分けて見て `cwd` と対象のパスを同一視しない。worktree から `git -C <scratchpad の中の repo> checkout -- .` を打った場合も対象になる）、(2) 操作対象がこのセッションの scratchpad の中にある（場所とコマンドの形の判定はスクリプトに任せ、本体は書き直さない）、(3) W が自分で作ったと作ったコマンドつきで報告し、本体が W に渡した指示でその対象を既存のものと名指ししていない、(4) 要る理由がその検証用 repo を戻す・片付けることに収まる。子が作った repo の設定でコマンドが動きうるので、本体は対象に git を実行しない。許可を書けたら、`scripts/subagent-context.sh` で測ったうえで（再開できるかは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」に従う）同じ W を SendMessage で再開し、15 分以内に同じ cwd から同じコマンドを 1 文字も変えず 1 回だけ打つこと、ほかの操作は許可していないことを書く。再開の文面には、許可を hook が読む場所に書いたこと、通すかどうかは hook が決めるので本体の言葉は承認ではないこと、打って拒否されたら打ち直さず報告に戻ることも書く（実機確認で、これを書かないと W が「親の言葉は承認にならない」として打たなかった）。許可は `agent_id` に結び付くので新しい W を起こさず、再開できないときも新しい W に転用しない。次のどれかのときは許可を書かず（再開後の 2 回目の許可も書かず）、何を・どのパスに・なぜ、本体が確かめた事実、推奨を添えてオーナーに上げる（無人ならチャンネルで承認を求める）: 許可を書くスクリプトが 0 以外で終わった（stderr を添える）／(1)〜(4) のどれかを満たさない／同じ W を再開できない／再開した W が同じ拒否で再び返った。承認されたらオーナーが自分で実行し、本体は代わりに実行しない。1 回求めても報告が空のとき、または報告から原因が読み取れないときも、同じ指示で起こし直さず、空だったことと作業ツリーの状態を主に上げる。通常の return（`工程完了:` / `工程中断:`）にはこの扱いを使わない（ただし通常の return に拒否の報告があれば、上の許可の手順を使う）。この扱いの対象は W だけで、再開しない役（R1・G・レビュアー）が空で返ったときは範囲外であり、上の手渡しの許可条件など既存の手順に従う。再開しない役が破壊的 git 操作の拒否を報告したときは、許可が子の `agent_id` に結び付いて使えないので、許可を書かずオーナーに上げる。

## ループの終わり

- **worktree の片付けを提案も質問もしない**（完了報告でも途中でも）。片付けは、別セッション方式（Orca・tmux）のエピックの子なら親セッションが行い、それ以外はオーナーが別のセッションで `/wt-clean` を使う
- エピックの子（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested`）の完了報告は、1 行目を `主がこのセッションで次にすること: なし` か `主がこのセッションで次にすること: <どの画面で何をするか>` にする（子のタブを開いた主が最初に読むため）。下の `mark` を呼ぶときは、1 行目が `なし` なら `done`、中身があれば `waiting` を選ぶ。エピックの子でないセッションの完了報告にはこの 1 行を求めない
- 記録先が issue で PR がマージ済みなら、完了報告を書き終えてから、**そのループの最後のツール呼び出し**として `scripts/epic-dispatch.sh mark <done|waiting> <記録先の issue 番号>` を Bash で 1 回呼び、このワークスペースに印を付ける。オーナーに頼むことが残っていなければ `done`（用が済んだ）、完了報告にマージ後の依頼（動作確認など）を書いたなら `waiting`（オーナーの確認待ち）にし、オーナーが済んだと返事をしたら `done` で呼び直す
- PR を伴わない記録先 issue（調査だけの issue など、受け入れ条件がリポジトリの変更を求めないもの）で受け入れ条件を満たしたら、本体が結果を記録先にコメントし、`gh issue close <N> --reason completed` で閉じる。閉じる操作を主に渡さない。受け入れ条件が推奨を出すことなら、推奨を出した時点で満たしたと数え、主が推奨を採るかを閉じる条件にしない（issue を閉じるのは reopen で戻せるので、破壊的な操作として扱わない）。閉じたあとは、PR がマージ済みのときと同じく最後のツール呼び出しで `scripts/epic-dispatch.sh mark <done|waiting> <記録先の issue 番号>` を呼ぶ。親の `epic-dispatch.sh reap` は、そのブランチに PR が無く・issue が閉じていて・HEAD がリモートの今の main に含まれる子を片付ける（main に入っていない commit を積んだまま閉じると `kept <N> unmerged-commits` で残る）
- PR がマージされていないとき（保留・マージ待ち・unmanned）と、記録先が Draft PR のときは呼ばない（PR を伴わない記録先 issue を閉じたときを除く）。エピックの子（`nested`）が PR のマージを主に頼んでループを終えるときは、完了報告で「マージしたら教えてください」「ステータスを変えます」のような、マージ後にこのタブへ戻る連絡を主に頼まず、「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書く（親の `epic-dispatch.sh wait --watch-done` が、記録先が completed で閉じて子のセッションが止まった子を完了と推定するため）。1 行目の `主がこのセッションで次にすること:` はPR のマージだけにする
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

**exit 2（上限超）**: spawn / SendMessage / Codex への委譲をしない。PR があれば PR、無ければ記録先に `needs-approval` を付け（引き継ぎの「ラベルの付け先」と同じ）、`references/handover.md` どおり引き継ぎを残し、主に「続けるか、範囲外として閉じるか」を問う。問いには合計（Claude 分と Codex 分の内訳）・体数・上限・残工程（次に起こそうとした役割と、そのあと残る工程）・推奨（どちらを選ぶかとその理由）を添え、判断材料なしで出さない。unmanned でも同じく止まり、問いを記録先のコメントに書いてサイクルを終える。

- 「続ける」: 記録先に 1 行目が `PR トークン上限: <新上限>` のコメントを投稿し、以後この記録先の計測に `--cap <新上限>` を渡す。新上限は「その時点の合計 ＋ 直前の計測で上限に使った値（`--cap`、無ければ `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000）」。後任の本体は記録先の最新の `PR トークン上限:` コメントの値を使う
- 「範囲外として閉じる」: この記録先について以後サブエージェントを起こさず、Codex にも委譲しない。残作業を記録先にコメントしてサイクルを終える

**記録先がエピックの子のとき**: 主に聞く前に、エピックの親が持つ子 1 件あたりの PR トークンの権限（エピックの 1 行目 `子の PR トークン権限: <値>` のコメント。既定 60000000）の内かを照らす。照らし方の正本は `references/epic.md` の **PR トークン上限の子** の段落。

- 別セッション方式の子: 今までどおり止まり、停止の記録の `止まった理由:` と `前提:` に見込みを書く（`references/epic-child-stop.md`）。起こされた親が照らす
- サブエージェント方式（unmanned・channel を含む）: 親を兼ねる本体が、見込みを子の記録先にコメントしてから（終わるまでにあと何トークンで、合計がいくつになるか）、`references/epic.md` の **PR トークン上限の子** の条件 (a)(b) で照らす。照らす前にエピックに権限のコメントが無ければ既定値で投稿し、主に伝える（unmanned はコメントだけ）。満たさなければ上の手順どおり主に問う
- 親の権限で続けるとき: 新上限は「合計 ＋ 直前の上限」ではなく権限の値にする。記録先に次の 4 行のコメントを投稿し、以後 `--cap <権限>` を渡す。親の返事 `続ける。新しい上限 <権限>（親の権限。<URL>）` を受けた子の本体もこの書式で書く。親の返事は主が権限のコメントで先に承認した範囲の執行なので、子の本体は主に聞き直さない
- 既定の上限（30,000,000）は変えない。止まることで工程の中の無駄に気づく機会を残すためで、権限は止まったあとの続け方だけを変える

```
PR トークン上限: <権限>
決めた人: <親エピック #<E> の判断（親の権限の内。主の承認ではない）か、エピック #<E> の本体（親の権限の内）>
権限: <権限のコメントの URL>
停止の記録: <停止の記録の URL か なし>
```

**exit 1（計測できない。引数エラー・python3 が無い・リポジトリ外・Codex 消費コメントを取得できなかった）**: 止まらずに進み、計測できなかったことと理由を記録先にコメントする。コメントは同じ記録先・同じ理由について 1 サイクルに 1 回までにする（interactive では本体の 1 セッション、unmanned では loop-dev-agent の 1 サイクル）。

計測に入らないもの: 本体自身の消費、Workflow 経由のサブエージェント。出力の `unresolved`（作業ディレクトリが消えたサブエージェント）と `codex_unresolved`（rollout が見つからない thread）は合計に入らないので、0 でなければ問いに件数を添える。

## 保留で止まるときの引き継ぎ（主の返事を待つ前に書く）

引き継ぎの書式・投稿の順序・主への案内・新しいセッションでの再開の手順は `references/handover.md` にある。次のときにそのファイルを Read してから進める。

- 主の返事を待って止まる前のうち、引き継ぎを書く 4 つの場面（pr-review-gate の保留・「PR トークン上限」の exit 2・レビューの 2 周キャップ超え・仕様レビューの条件の問い）に当たるとき。引き継ぎを書き終えるまで止まらない
- 記録先に 1 行目が `引き継ぎ: 主の返事待ち` のコメントがある保留中の記録先を再開するとき（`/develop <記録先>` の入口、または channel で `#<番号>` を添えた返事を受けたとき）。`needs-approval` の有無によらず、入口 0 に進む前に読む

## エピックの子が主の返事を待って止まるとき

別セッション方式（Orca・tmux）で起動されたエピックの子のセッション（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返すセッション）は、主の返事を待って止まる前と、`親エピック #` か `主の返事（親エピック #` で始まる入力が届いたとき（起動し直されたセッションの最初の指示に付いて届いたときを含む）に、`references/epic-child-stop.md` を Read してその手順に従う。`nested` でないセッションは読まない。

## モデル

役割ごとのモデルは事前分類と残量モードで決める。判断は「どの役割をどのモデルで起こすか」だけ。

| 役割 | 既定 | 上げる条件 |
|---|---|---|
| W（実行役。`dev-workflow:worker`） | `sonnet` | `opus`: 記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含む、実行側が原因の失敗ループでの昇格、または事前分類の 4 分類（聖域パス・マージ権限・層間契約・課金/法務。正本は `references/pre-classification.md`、ここに再掲しない）に当たる。**W の上限は `opus` で、`model: fable` の W は `scripts/agent-model-guard.sh` に拒否される** |
| R1（読んで判断する役） | `opus` | 仕様の対象がマージ条件・層間契約・課金/法務に触れるときは `subagent_type: dev-workflow:decider` で spawn する（`general-purpose` に `model: fable` を付けない。聖域パスだけでは上げない） |
| G（`dev-workflow:gate-runner`） | `sonnet` | 上げない。G の仕事は HEAD 固定・ラベル操作・宣言の書式照合・証拠の実在確認で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う |
| V（画面確認役。`general-purpose`） | `sonnet` | 上げない |
| 引き継ぎの判定役（`needs-carryover-judge` を受けて本体が起こす） | `opus` | 上げも下げもしない（種別は `dev-workflow:decider`。残量モードによらず `opus` を明示する）。`SHARED_BUDGET_MODE=depleted` のときは起こさない（「判断できない」の記録を投稿して主に聞く側に倒す。(4) の needs-carryover-judge） |
| G が要求するレビュアー（読んで判断する役） | `opus` | 既定の種別は `dev-workflow:reviewer`。レビュー対象がマージ条件・層間契約・課金/法務に触れるときは `subagent_type: dev-workflow:decider`（従来経路では G の `needs-reviewer` の推奨モデルに従う。adapter 経路では adapter が返した model に残量上限を適用した値を使い、推奨モデルは参考値。(4) の ③） |

W の既定が `sonnet` なのは、監査（2026-09）で W に Sonnet が 1 本も無く、昇格ラダーの Sonnet 段が構造的に通っていなかったため。W は事前分類と失敗ループで `opus` まで上がる。W の上限を `opus` にしたのは、Fable が消費するのはターン数（会話履歴の cache 読込）で、実装・修正ループは 1 件で数十〜数百ターン回るため。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体の判断で吸収し、W は確定した内容を落とす作業だけを担う。読んで判断する役（R1・レビュアー）が Fable に当たるときは `dev-workflow:decider` で起こす — Fable を渡せる `subagent_type` はこれだけで、判定は `scripts/agent-model-guard.sh` が行う。

残量モード（`FABLE_BUDGET_MODE`）と共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が、上の表の既定と昇格の上限を決める。値ごとの効果と両者が食い違ったときの扱いは `references/decision-criteria.md` の残量モードと共有枠モードの表が正本で、ここに再掲しない。

昇格トリップワイヤーは失敗の原因側だけを上げるラダーとして残す（ラダーの正本は `templates/escalation-tripwires.md`）: 同じテストが 2 連続で落ちた、または同じ箇所を 2 回書き直したと W が return したら、本体は失敗の原因が判断側（指示を解釈できなかった・指示自体が外れていた）か実行側（指示どおりやって結果が違う）かで、**決める役と実行役のどちらか一方だけ**を上げる（両方同時に上げない）。decider の `model` の段（1 回目の失敗は `opus`、2 回目で判断側の失敗なら `fable`）は `templates/escalation-tripwires.md` を Read して従う。判断側なら `subagent_type: dev-workflow:decider` を立てて修正方針を作らせ、実行側なら W を `opus` で再開する（W の上限は「モデル」節の表の W の行（`opus`））。残量モードと共有枠モードの上限が先に効く。コンテキスト上限（`subagent-context.sh` が exit 2）は昇格の理由にはならず、モデルは変えない（そのあとの扱いは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本）。規模超過（編集対象 5 ファイル超・作業項目が 2 回増えた）を W が return したら、本体が change / 子 issue（エピック化）に分割する。

## 実行モード

| モード | 起動 | 本体 | 対話 | 回す工程 |
|---|---|---|---|---|
| **interactive**（既定） | 人間が `/develop`・`/work-issue`・自然文で依頼 | そのセッション | AskUserQuestion で聞ける | (0)〜(4) 全部。複数 change はその場で change ごとに回す |
| **channel** | 印 `DEV_WORKFLOW_UNATTENDED` のあるセッション、またはチャンネル（Discord など）のメッセージで依頼（常駐の開発エージェントが、オーナーからチャンネルで開発を頼まれたときの形） | そのセッション | チャンネルで聞く（AskUserQuestion は使わない） | (0)〜(4) 全部（G を起こし、PR の合格まで進む）。複数 change は interactive と同じ |
| **unmanned**（`--unmanned`） | loop-dev-agent の憲法 Step 3 から | **憲法のメイン自身**が develop の本体を務め、W / R1 をメインが spawn する | 質問は本体が代理送信し終了（1 サイクル 1 仕事） | (0)〜(3)。worktree は憲法側が用意したものを使う。(3) で W が Draft PR の作成と `agent-review:pending` の付与（憲法 Step 3 の 5〜6 に相当）まで行う。**(4) の G は起こさず**、憲法 Step 1（レビューモード）が次サイクル以降で担う |

unmanned で複数 change に割れた場合（W が change 単位で子 issue を作って `blocked_by` で順序付けし、そのサイクルを終える。割り方が判断できないほど曖昧なときは子 issue を作らず、W が質問文・理由を return し、本体が代理送信して `needs-approval` で終える）の手順は、`references/roles/worker/spec.md`「分割判定」が正本。

unmanned で W の return に質問文・理由が含まれるとき、本体（憲法のメイン自身）が受け取り、質問を Discord へ代理送信する。記録先の `needs-approval` を維持してそのサイクルを終了する。

**仕様化判断の記録と仕様レビューは unmanned でも免除しない**（同じ書式で記録先に記録し、R1 の APPROVE まで W を apply に進めない）。文言合わせの通し方（1 ループの (1)。判定基準は `references/decision-criteria.md` Step B）で R1 を起こさないのは、モードによる免除ではなく、interactive と同じ対象・同じ当てる条件で unmanned にも当てる。

channel が interactive と違うのは次の点だけで、それ以外の工程と記録は interactive と同じ。W・R1 の起動指示の実行モードには interactive と書く（W・R1 の手順の分岐は channel でも interactive 側をとり、主に聞くのは W・R1 の return を受けた本体がチャンネルで行う）。違う点: 主に聞く先と主への発言の宛先がチャンネルになる（`references/channel.md` の「channel の聞き方」「channel の主への発言」）・保留からの再開の案内がチャンネルの返事になる（`references/handover.md` と G の依頼文）・リスク許容をチャンネルで受けるのは返事を確かめられるときだけ（`references/channel.md` の「channel のリスク許容」）・エピックは `route` を呼ばずサブエージェント方式で回す（`references/epic.md` の「回し方」）。

### モードの決め方

本体は develop を始めるときに 1 回、次の順で決める。

1. 引数に `--unmanned` があれば unmanned
2. セッションに印 `DEV_WORKFLOW_UNATTENDED` があるか、develop の依頼の発言がチャンネルのメッセージ（本文が `<channel source=` で始まる発言）なら channel。印は Bash で読み（例: `printf '%s' "${DEV_WORKFLOW_UNATTENDED-}"`）、読み方は git ガードと同じにする: 前後の空白を除いて、未設定・空・`0` は印なし、それ以外は印あり
3. どちらでもなければ interactive

決めたモードは develop 開始コメントに `実行モード: <モード>（<理由>）` の 1 行で残す（理由は `引数`・`印`・`チャンネルの依頼`・`既定` のどれか。例: `実行モード: channel（印）`）。途中でモードを変えない。新しいセッションで引き継ぎから再開するときは、決め直さずに引き継ぎの `実行モード` の値を使う。

印が付かず、依頼もチャンネル以外から届いた住人が interactive になることはこの決め方では塞がない（印を付けるのは起動する側）。オーナーが自分の画面の前にいて Discord から頼んだセッションが channel になるのは許す（質問の届く先がチャンネルに変わるだけで止まらない）。

モードが channel に決まったら、決めた直後に（`commands/develop.md` の分岐 ②⑤ と issueify フォールバックで主に聞くより前に）`references/channel.md` を Read してから進める（channel の聞き方と読み替えの規則・リスク許容・主への発言の 3 つ。開始コメントの `チャンネルの返事の確認:` の行もそこで決める）。引き継ぎから `実行モード: channel` で再開するときと、コンパクトのあとに SKILL.md を読み直したとき（開始コメントの `実行モード:` の行が channel のとき）も同じ。interactive と unmanned では読まない。

## エピックの扱い

エピック（独立してマージできる PR が 2 本以上に割れる依頼を、子 issue に分けて回すもの）の条件・作り方・回し方・完了条件は `references/epic.md` にある。次のときにそのファイルを Read してから進める。単発の issue・会話依頼・Draft PR を記録先にする依頼の 1 ループでは、下のどれかの場面に当たらない限り読まない。

- `/develop <エピック番号>` で起動したとき（記録先の issue が子 issue を持つとき）
- 依頼をエピックにするかを決めるとき（W の分割判定が複数 change を返し、エピック化を選ぶか考えるときを含む）
- `scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返すエピックの子として動き、W を並列に起こすときか、自分の記録先がエピックだったとき
- 記録先の issue に `親エピックからの注意書き:` で始まるコメントがあるとき（エピックの子として起動したときと、同じワークツリーで `/develop #<N>` を打ち直して起動し直したときを含む）。そのコメントに従うか、W・R1・G に渡すかを決める前に読む。従ってよいのは投稿者の `author_association` で絞ったものだけで、その規則は `references/epic.md` の「回し方」の別セッション方式にある
- エピックの子として動いていて、実装中に自分の issue の範囲外の新しい問題が見つかったとき。follow-up の issue を作る前に読む（エピックの子では、エピックの外の issue ではなく新しい子 issue を切ってエピックに足す。規則は `references/epic.md` の「回し方」の「両経路に共通」）

## 上流の壁打ち（`/opsx:explore`）を呼ばない理由

このスキルは規模が大きくても、上流の壁打ち（openspec の `/opsx:explore`。まだ形になっていない曖昧な要望を、対話で質問しながら実装可能な単位に分解し、相互矛盾がないか確認する工程）を内部から呼ばない。このスキルが扱う依頼（issue・受け入れ条件付きの会話依頼・エピックの子）は既にその「ほぐす作業」が終わった状態にある。複数 change が必要なら記録先の記述を根拠に分割すれば足りる（`references/epic.md` のエピックの作り方）。`/opsx:explore` は issue の体裁を成す前の構想専用として切り離し、その出口（`/opsx:new` / `/opsx:ff`）からこのスキルに入る。

## 参照

- 役割の指示書: `references/roles/worker/`（W。索引は `references/roles/worker.md`）・`references/roles/spec-reviewer.md`（R1）・`references/roles/gate-runner.md`（G）
- 仕様化要否・change 分割・残量モードの判定基準: `references/decision-criteria.md`
- エピックの条件・作り方・回し方・完了条件: `references/epic.md`。エピックの子が主の返事を待って止まるときの子の側の手順: `references/epic-child-stop.md`
- 昇格トリップワイヤーの常駐ルールテンプレート: `plugins/dev-workflow/templates/escalation-tripwires.md`
- G の手順書: pr-review-gate の段のファイル（`skills/pr-review-gate/stages/` と `declarations.md`。索引は `skills/pr-review-gate/SKILL.md`、G が時点ごとに読むファイルは `references/roles/gate-runner.md` の表。記録先の探索順・仕様宣言の照合は据え置き）
- 入口の 5 分岐と issueify フォールバック: `commands/develop.md`（`/work-issue` はエイリアス）
- worktree セットアップの自動化: worktree プラグインの `hooks/hooks.json`（`WorktreeCreate` / `SessionStart`）
- 棲み分け相手: 各リポに配備された loop-dev-agent の憲法（`docs/agent-loop.md`。それを配るリポジトリが保守する正本で、harness にテンプレートは無い）。unmanned の外形（ラベル・Draft PR・キュー）は憲法側
- 1 ループに収まらない規模を Workflow で回す型: `plugins/dev-workflow/references/workflow-execution.md`（スクリプトの書き方は `workflow-authoring` スキル）
