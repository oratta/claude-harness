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

## 本体の骨格（詳細は操作前に読み直す）

- **本体は Edit でコードを書かない。** テスト・実装・仕様は W が編集する。例外は軽い通し方だけ（`references/light-path.md`）。
- **本体はレビューを代行しない。** R1・G・レビュアーは本体が別コンテキストで起こす。W に孫の spawn を指示しない。
- 工程順: 記録先 → W の仕様化判断 → 必要なら R1 の APPROVE → W の実装＋verify → 必要なら V → W の archive＋Draft PR＋仕様宣言 → G。仕様化しない場合と文言合わせ、軽い通し方の例外は「1 ループ」と `references/light-path.md` に従う。
- コンパクト後も、操作前に本文の該当節と正本を必ず Read し直す。spawn・再開・Codex 委譲前は `references/pr-token-budget.md`、G の結果は Status 表、W の空 return・通常 return 内の拒否報告は `references/worker-recovery.md`、役割の起動・再開は plugin の `references/codex-develop.md` が入口。

<!-- startup-core-end -->

## 開始時の idle compaction 設定

工程前に `references/reply-after-idle.md`「開始時の設定」を Read して従う（親・子・単発、新セッション・compact 後も同じ）。

## Role profile の選択

新しい role の起動・同じ Claude role の再開の直前には、Claude 既定の経路を含む全経路で `${CLAUDE_PLUGIN_ROOT}/references/codex-develop.md`（未設定ならこの SKILL.md から `../../references/codex-develop.md`）を絶対パスに解決して必ず Read する。「起動と role 解決」の入力・結果・監査記録・再開条件に従い、以下の spawn / SendMessage 表記にも適用する。

G の起動指示（段ごとに新しく起こす G と、手渡しで起こす後任 G のすべて）には、起動形を問わず常に `レビュー経路: adapter` の 1 行を書く（自動選択・明示 profile・旧形式のどれも adapter で解決するので、今が adapter 経路かを評価しない）。Codex の G では request の instructions（`--input` の指示ファイル）にも書く。develop の本体は `レビュー経路: 従来` を書かない（develop の本体以外の呼び出し元のための値）。G は再開せず段ごとに新しく起こすので、起動指示に行が無い G は従来経路（full は G が Codex を直接呼ぶ）として動く。どの段の起動指示でも行を省略しない（`references/roles/gate-runner.md`「レビュー経路の判別」）。

## いつ使うか

ソースコード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変える作業は、依頼の入口を問わず（GitHub issue・会話・cron・エピックの子のいずれでも）このスキルを通す。「issue があるか」は入口 0 で記録先を決める材料にすぎず、スキルを通すかどうかの条件ではない。

例外は「読むだけ・回答だけ・生成物を出すだけ」の作業（調査報告・質問への回答・レポートや図の生成など、リポジトリの追跡対象を変えないもの）に限る。

## 前提

無いときの縮退まで含めて列挙する。本体が spawn できない環境（本体自身がサブエージェント）ではこのスキルは成立しないので、その場合は親に return して親を本体にする。

| 前提 | 使い方 | 無いとき |
|---|---|---|
| **Agent ツール** | 先頭の役割表・「本体の役割」「worktree の用意」に従って起動する | 本体になれない。親セッションに return する |
| **SendMessage** | 名前付きで起こした W の再開（コンテキストを引き継いだまま次の工程を指示する）。G は再開しない（段ごとに新しく起こし、レビュー要約は起動指示で渡す） | 再開できないので、前任を手渡してよい状態のときだけ新しい W を spawn し、前回の return 全文をプロンプトに渡す。条件は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本で、満たさないなら spawn せず親に返す（前任が動いたまま後任を起こさない） |
| **`gh`** | 記録先（issue / PR）へのコメントとラベル操作、Draft PR の作成、エピックの子の依存（`gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by`、issue dependencies API） | 記録先を作れないので開始しない（記録なしで実装に進まない） |
| **openspec CLI** | W は `openspec --version` で経路の有無を決め、`openspec new change` → R1 → TDD → `openspec validate --strict` → `openspec archive` と進める。opsx コマンドは本体や主の対話用 | 仕様化経路が発生しない（W は `仕様化判断: しない` の理由に「openspec 不在」と書き、コード直行する） |
| **`orca`** または **`tmux`** | エピックの子を、Orca の子ワークツリーか tmux のウィンドウで独立した Claude Code セッションとして起動する（`scripts/epic-dispatch.sh launch`。`references/epic-loop.md` の別セッション方式。`tmux` は本体が tmux の中にいる場合） | エピックはサブエージェント方式で回す。`orca` はあっても本体が Orca 管理外のワークツリーにいて tmux の中にもいないときも同じ（`route` が `subagent` を返す） |
| **Codex CLI** | adapter 経路（develop の本体が起こす G）では G は full でも `needs-reviewer` を返し、本体が phase `review` で投げ先を選び直す（Codex が選ばれればそこで使う）。従来経路（develop の本体以外の呼び出し元が起こす G）では G が full レビューを Bash から `codex exec` / `codex-companion.mjs` で実行する | G が `needs-reviewer` を return し、本体が別のレビュアーを spawn して要約を G に渡す（gate-runner.md） |

## 本体の役割

本体は役割 W / R1 / G を `model` 明示で spawn し、**return の要約と記録先（issue または Draft PR）のコメント・ラベルだけ**を見て次に誰を起こすかを決める。並列可能な役割（エピックの子どうし、独立した change の W どうし）は並列に起こしてよい。**ただし、1 つの worktree で同時に動く同一役割のサブエージェントは常に 1 人（MUST）。並列に起こしてよいのは別々の worktree を持つ役割に限る。**

禁止事項（本体がこれをやると、別コンテキストの網が全部外れる）:

- **本体は Edit でコードを書かない。** 例外は軽い通し方だけ（`references/light-path.md`）。テスト・実装・仕様ファイルの編集はすべて W の仕事。本体が「小さいから」と直接直した瞬間に、その変更は R1 / G の別コンテキストレビューを通らずに PR に乗る
- **本体はレビューを代行しない。** 仕様レビューは R1、PR レビューは G（と G が要求したレビュアー）が行う。本体が W の return を読んで「よさそう」と判断することはレビューではない
- **W が孫を呼ぶ必要がある工程を設けない。** 別コンテキストを要する工程（R1・G・G のレビュアー）はすべて本体が起こす。W の指示書に「サブエージェントを spawn せよ」と書かない

本体がやること: 入口 0 の記録先の確定、worktree の用意、各役割の spawn と再開、return の要約の転記（記録先のコメントは各役割が自分で投稿する。**例外: `subagent_type: dev-workflow:decider` で起こした役割は `Bash` を持たず `gh` を実行できないので、その return は本体が同じ書式で代理投稿する**。ただし pr-review-gate の仕分け表の順 6 の裁定は代理投稿せず G に返し、G が記録する）、needs-approval 時のオーナーへの依頼、エピックの進行管理。

## 主に聞かずに決めること

本体・W・G が主に聞くのは、次のどれかが要るときだけ（#1035）: 主の側にしか無い情報（好み・事業判断・許容度）、主の手でしかできない操作（パスワード・MFA・CAPTCHA のように、エージェントの手では通せないもの）、規則が主の承認を求める操作（`rules/destructive-git-guard.md` の一覧・マージ・聖域）で、それは（`~/.claude/output-styles/readable.md` の節 3 の主に聞く理由の 3 つに当たる。マージは、人が押すと決まっている場面では主の手でしかできない操作、マージしてよいかを聞く場面では決まりの側）。ログイン済みのブラウザで押せる操作（OAuth の認可ボタン・チャットの板の作成など）は、主の手でしかできない操作に入らない（#1654）。そのうち主の名義で外へ公開・送信する・課金する・外部のアプリやサービスに権限を渡す（OAuth の認可を含む）・取り消せないものは、手が要るからではなく規則が主の承認を求める操作として聞く。それ以外は次の 4 つの型の決め方で自分で決め、記録先に事後報告する。

- **自分側の誤りの後始末**: 本体・W・G・レビュアーが記録先の範囲の外に誤って入れた変更（実ホームの設定ファイルへの書き足しなど）は、控え・git の履歴・自分のツール呼び出しの記録のどれかと今の状態を比べ、差分が自分側の入れた分だけで戻し先が一意に決まるなら、主に聞かずに今の状態の控えを取って戻し、記録先に何を・どこから戻したか・控えの場所を事後報告する。差分が自分側の分だけと確かめられないときは主に聞く。git の破壊的操作（`rules/destructive-git-guard.md` の一覧）はこの型に入らず、事前承認のまま。聖域（CLAUDE.md・hooks・権限設定）への変更を戻す操作も、差分が一意でもこの型に入らず、無条件で人間承認のまま
- **範囲外の問題の起票**: 本体が作業中に見つけた記録先の範囲外の問題（レビュー指摘ではないもの。G の振り分けを経た指摘は G の振り分けのまま扱う）は、本体が行き先（捨てる・既存 issue に参考として入れる・新しい issue）を決め、起票したら URL を事後報告する。`skills/pr-review-gate/stages/triage-nonblocking.md`（段 C は `skills/pr-review-gate/stages/triage-epic.md`）は PR 番号・PR コメント・G の手順 3 を前提にしているので丸ごとは当てず、段 B・段 D・段 E の問い（エピックの子の記録先なら段 C の問いも）と段 B の表だけを借りる。起票してよいかを主に聞かない。G の振り分けの結果を主への報告にまとめるときも、行き先を「オーナーが決める」に書き換えない。起票によって配布や後続の作業の順番を変えるかは主に聞いてよいが、起票はその前に済ませる
  - 候補探し: 段 B を通った問題が 1 件以上あれば、問題がファイルを指すなら `plugins/dev-workflow/scripts/review-issue-candidates.sh --repo $R --exclude <記録先の番号> [--epic <エピック番号>] <パス>...` を、ファイルを指さないなら `gh issue list --repo $R --state open --search "<問題を表す語>"` を、それぞれ 1 回だけ走らせる（打ち切られたパスの再実行だけ例外）。記録先の番号は記録先の issue、記録先が Draft PR ならその PR の番号。エピックに属するときは、`--exclude` にエピックの番号も渡す。出力に `(15 件で打ち切り。ほかにも一致あり)` が出たパスがあり、エピックに属するときは、そのパスだけ `--epic <エピック番号> --children-only` を付けて再実行し、子の候補を足す（打ち切られたパスごとに 1 回を超えない）。終了コードが 0 でないときの扱い（再実行を含む）は `stages/triage-nonblocking.md` の候補探しの段落に従う。再試行後の終了コードは記録先の `範囲外の問題の振り分け` コメントに書き、既存 issue への相乗りをせずに段 E へ進む
  - 判断結果の記録: 記録先（issue、または Draft PR）に、1 行目が `範囲外の問題の振り分け` ちょうどのコメントを 1 件置き、問題ごとに、問題の要約・当てた段・行き先（issue にした・コメントで入れたならその URL、捨てたなら理由の 1 行）を書く
  - 段 B の確認待ち: 条件がいつ成り立つかを、記録先・エピックの本文・受け入れ条件・コード・本文の節 `## 条件の答え` から決められないときは、起票の可否ではなく条件についての問いを主に聞く。同じコメントにその問題を `条件の確認待ち` として質問文とともに残し、`needs-approval` を付けず、作業を止めない。答えは 1 行にして記録先（エピックの子ならエピック）の本文の節 `## 条件の答え` に足し（節が無ければ作る）、その問題を段 B から当て直す
  - エピックの注意書き: 段 C で完了条件に効くとした問題だけ、親（OWNER）の置き場所の指定を「既存の子 issue の受け入れ条件に足す」より優先する。効かない問題は段 D・段 E へ進め、注意書きを理由に子にしない
- **小さな実装の選択**: どれを選んでも受け入れ条件と利用者に見える振る舞いが変わらない選択肢は、その工程の担い手が選び、選んだ理由を記録先に残す。レビューの 2 周目以降の周の終わりに残った指摘の直し方は、`references/fix-check.md` の節「レビューの周を主に聞かずに続ける（直し方の判定）」に従う
- **閉じる操作**: 受け入れ条件を満たした記録先を閉じる操作は、節「ループの終わり」に従い、主に渡さない

自分側の誤りの後始末の守備範囲は、本体・W・G・レビュアーのツール呼び出しが記録先の範囲の外（実ホームの設定ファイル・別のリポジトリなど）に書いた変更である。拾いたい誤りは、戻す内容が差分から一意に決まるのに、戻してよいか・いつ戻すかを主に聞いて止まることで、これは主に聞かずに戻す。通してよい例は、控えの `.bak` との差分が自分側の書き足した 1 件だけで、その 1 件を消すこと。主の変更と区別できない差分・git の破壊的操作・聖域への変更を戻す操作は主に上げる。戻した内容が誤っていたことは防がない（戻す前に取った控えから取り消せる）。

範囲外の問題の起票の守備範囲は、本体が作業中（リハーサル・調査・実装の確認など）に見つけた、レビュー指摘ではない記録先の範囲外の問題である。拾いたい誤りは、起票してよいか・誰が起票するかを主に聞いて止まることと、G の振り分けの結果を「オーナーが決める」に書き換えて主に渡すことで、これらは主に聞かずに起票か捨てるかを決める。通してよい例は、リハーサルで詰まった操作を新しい issue にして URL を事後報告すること。主に上げるのは、段 B の条件が本体に決められないときの条件についての問いと、起票によって配布や後続の作業の順番を変えるかの判断だけである。行き先の選び方が外れること（捨てた問題が後で効くなど）は防がない（記録先のコメントに理由が残るので、後から拾い直せる）。

## 入口 0: 記録先を決める

1 ループの最初の工程。仕様化判断・仕様レビュー結果を置く「記録先」を先に確定する。

- **issue があればそれを記録先にする**（番号・URL・自然文マッチ。`/develop` の 5 分岐は `commands/develop.md`）。エピックの子は子 issue が記録先
- **無ければ issue を切らない。** 本体が worktree を用意し、W が worktree 直後に空 commit（`git commit --allow-empty`）を積んで push し、`gh pr create --draft` で Draft PR を開いてそれを記録先にする（GitHub の "open a draft PR early" の慣行）。この Draft PR は**仕様化判断を記録する前**に存在していなければならない — 記録先が無い状態で判定を先に進めない（手順は `references/roles/worker/spec.md`「記録先の用意」）
- **入口 0 の例外**: 軽い通し方だけ本体が Draft PR を作る。整理 → 判定 → Draft PR → 判断の記録（`references/light-path.md`）
- Draft PR を記録先にするときの PR 本文の決まり（受け入れ条件は PR 本文に書く・PR 本文に `Closes #N` / `Fixes #N` / `Refs #N` の issue 参照を書かない。エピックの子は `Closes #子` を書く）は、`references/roles/worker/spec.md`「記録先の用意」が正本
- 仕様化判断（`仕様化判断: する|しない`）・仕様レビュー結果（`仕様レビュー: APPROVE|REQUEST_CHANGES`）は記録先のコメントに置く（書式の正本は `references/roles/spec-reviewer.md`「判断記録の契約」）
- **仕様宣言は記録先ではなく常に PR コメントに置く**（記録先が issue でも issue には書かない）。pr-review-gate 手順 5 が PR のコメントでリスク宣言・仕様宣言・動作確認の 3 見出しを照合し、`対象 HEAD:` 規約が PR の HEAD に紐づくため。書式の正本は pr-review-gate スキル手順 3-b

**issue を切るのは追跡・キュー・議論が要るときだけ**: エピック（複数 PR にまたがる。`references/epic.md`）／無人キュー（loop-dev-agent が拾う対象にしたい）／判断を残す議論（決定の経緯を issue スレッドに残したい）。この 3 つに当たらなければ Draft PR で足りる。issue を切る経路は `commands/develop.md` の issueify フォールバック。

## worktree の用意

worktree は**本体が用意する**。`.worktreeinclude` が無いときは本体が `/wt-setup` を呼ぶ。本体が既に対象専用の worktree（1 issue = 1 worktree = 1 ブランチ）にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。**W は自分で worktree を切らない**（セットアップは `WorktreeCreate` / `SessionStart` hooks が担い、W は判定もしない）。unmanned では憲法側が用意した worktree を使う。**`isolation: "remote"` は使わない**（MUST NOT）。強制停止中は `Bash` 全件拒否で commit できず、差分は本体が引き取る（「工程中断: で返ってきたら」）。本体から見えない `remote` では差分を失うため。

## 1 ループ（W → R1 → W → G）

1 issue（または 1 Draft PR）につき次を回す。各工程の担い手と、本体が次に誰を起こすかの判断材料を書く。

下の各工程の spawn・SendMessage による再開・Codex executor への委譲の直前には、毎回必ず `references/pr-token-budget.md` を Read して計測を行う（exit 2 なら起こさず止まる）。

```
(0) 記録先を確定する（入口 0）。worktree を用意する
     軽い通し方なら W を起こさず本体が直して G の工程へ（`references/light-path.md`）
(1) W を `subagent_type: dev-workflow:worker` で名前付き spawn（起動指示に `段: spec` の 1 行を書く。model: `request` が返した `model`。入力は「Role profile の選択」節、既定と上限は「モデル」節の表の W の行）:
      記録先の用意（Draft PR 経路）→ 仕様化判断の記録 → 分割判定 → openspec new change → return「仕様できた」
      仕様化しない判定なら → (3) へ直行（TDD → PR）
      文言合わせの通し方なら W は仕様の差分 1 ファイルだけを書いて return（正本: `references/spec-decision.md` Step B・`references/roles/worker/spec.md`）。
           return の文面ではなく記録先の最新の判断に `通し方: 文言合わせ` があれば R1 の工程を飛ばして `段: implement` で再開。
           行が無ければ `段: spec` で判断を投稿し直させ R1 の工程を通す
(2) R1 を spawn（model: `request` が返した `model`。既定 opus。マージ条件・層間契約・課金/法務に触れれば `--pre-class` を渡し、返った `role: decider` で subagent_type: dev-workflow:decider として spawn する。聖域パスだけでは上げない）:
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
           （文言合わせの (3a): return の作業項目を TDD で実装 → `openspec validate <change-name> --type change --strict`）
           → 本体はここで `scripts/subagent-context.sh <W の名前>` をもう一度実行して測ってから (3b) を指示する
      (3b) 再開指示に `段: finish` を書く。openspec archive → PR を Draft のまま用意（無ければ Draft で作成。Ready 化は (4) の G が pr-review-gate 手順 5 で行う）→ 仕様宣言を PR コメントに書く
           → return「工程完了: archive＋PR＋仕様宣言」（PR #N と仕様宣言のコメント URL を載せる）
      (3a) の `画面確認: 不要` なら V を起こさず (3b) へ進む。`画面確認: 要る — <開く URL か起動手順> / <見る点>` なら先に V を `subagent_type: general-purpose`・`model: sonnet`、名前 `V-<記録先番号>-<n>`、description `V: screen check for #N` で起こす。V に W の行と worktree パスを渡し、`isolation` は付けない。
           V の合格は観測を (3b) の W に渡す。不合格なら (3a) に戻し、同じ画面確認の 2 回目の不合格は本体が失敗ループと数える。実行不能なら理由を (3b) の W に渡し、画面証拠は書かずゲートの保留経路へ進む。V は再開せず、再確認は新しい V を起こす。
      (3) をこれより細かく切らない（`tasks.md` の項目単位や「実装／verify／archive／PR／仕様宣言」の 5 段にしない）。
           手渡しが 1 回起きるたびに、後任は指示書と正本の節を読み直し、記録先を取り直し、`git status` / `git diff` でファイルの現状を確認する固定分を払う。
           この固定分は工程の大きさによらないので、区切りを増やすほど 1 区切りあたりの実質作業比が下がる。
           区切りが実装の途中に落ちると、後任は Red のまま止まったテストから再出発し、前任の設計意図を再発明する危険が最も高い地点で交代する
      本体は次に指示する工程を、自分が (3a) を指示したか (3b) を指示したかで決め、工程名の文字列照合では決めない。
(4) G を `subagent_type: dev-workflow:gate-runner` で段ごとに名前付き spawn（model: `request` が返した `model`。既定 sonnet。G の仕事は照合・ラベル操作で、欠陥探索は needs-reviewer で本体が起こすレビュアー（従来経路では Codex）が担う）:
      文言合わせ: G を起こす前に最新の判断の `直す文:` と archive 済みの差分の要件名を照合。不一致なら W を `段: spec` で再開して再投稿（`references/roles/worker/spec.md`）
      段ごとに新しい G を起こす（段は 前提確認と重さ判定・照合と振り分け・合格処理・保留の解除 の 4 つ。1 体は 1 段だけを担当する。
           起こす時点と渡すものの表は gate-runner.md「段ごとの起動と入力」）。名前は `G-<PR>-<prepare|triage|pass|hold>-<n>`（n はその PR・その段で
           起こした回数）、description は `G: <段> for PR #N (#issue)`（先頭の `G:` を残す。役割別集計がこの接頭辞で判定する）
      G の起動指示には常に `レビュー経路: adapter` の 1 行と `段: <段の名前>` の 1 行を書き（`レビュー経路: 従来` は書かない。
           詳細は「Role profile の選択」節の、`レビュー経路` の行の書き方（`レビュー経路: 従来` を書かない規則と Codex の G への書き方）、2 つ目以降の段では前の段の `## Gate Result` ブロックを要約し直さずそのまま貼る。
           channel のときは `実行モード: channel` の行と、develop 開始コメントと同じ値の `チャンネルの返事の確認:` の行（`可` / `不可`）も書く（G が hold.md 手順 6-3 の依頼文を書き分ける入力。`references/channel.md` の「channel のリスク許容」）
      次に起こす段は Gate Result の Status と `次の段:` だけで決める（止める指摘が残っているか・戻した指摘の仕分け・復帰手順の行き先を本体は判断しない）。
           G が `工程中断:` で返したら同じ段の新しい G を起こし、前任の return 全文と起動指示の入力を渡す
           （起こしてよい条件は references/decision-criteria.md「コンテキスト上限（サブエージェントの手渡し）」の「手渡しの許可」）
      4 つの段で pr-review-gate の手順 1〜5 → return「passed / failed / 保留 / needs-reviewer / needs-decider / needs-fix-check / review-incomplete / needs-carryover-judge / needs-no-point-check / 重複で降りた / 次の段へ」
```

G の結果を処理する前に、次の Status → 読むファイルの表の行き先を必ず Read して従う。`工程中断:` の手渡し条件は上記の正本を読む。

| Status | 読むファイル |
|---|---|
| 次の段へ | `references/gate-result.md#次の段へ` |
| passed | `references/gate-result.md#passed` |
| needs-reviewer | `references/gate-result.md#needs-reviewer` |
| 重複で降りた | `references/gate-result.md#重複で降りた` |
| review-incomplete | `references/gate-result.md#review-incomplete` |
| failed | `references/gate-result.md#failed` |
| 保留 | `references/gate-result.md#保留` |
| needs-fix-check | `references/gate-result.md#needs-fix-check` |
| needs-carryover-judge | `references/gate-result.md#needs-carryover-judge` |
| needs-no-point-check | `references/gate-result.md#needs-no-point-check` |
| needs-decider | `references/gate-result.md#needs-decider` |


W は名前付きで spawn し、SendMessage で再開してコンテキストを引き継ぐ（(1) の判定・(2) の指摘・(3) の実装が同じコンテキストにある）。**ただし再開の前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測る（exit 2 が上限超）。閾値と全解除の環境変数・途中計測 hook を含む 2 経路・上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言・前任が動作中のまま交代させる手順）は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本で、この SKILL.md には書かない。正本を読むまで手渡さない。** G は再開せず段ごとに新しく起こすので、再開前の計測は W だけに掛かる。**W の起動指示・SendMessage による再開指示・手渡しの起動指示には `段: spec` / `段: implement` / `段: finish` の 1 行を必ず書く**（W は `references/roles/worker/common.md` とこの行が指す段のファイルだけを読み、行が無ければ読まずに聞き返す）。値はその起動・再開で本体が指示する工程で決める（上のコードブロックの各工程に書いた値）。手渡しでは、前任が工程の途中で止まり（return の 1 行目が `工程完了:` でない）後任に同じ工程を続けさせるなら前任が担っていた段、前任が `工程完了:` で return したあとに後任へ次の工程を指示するならその工程の段にする（(3a) を終えた前任の後任に (3b) を指示するなら `段: finish`、(1) を終えた前任の後任に R1 の REQUEST_CHANGES の修正を指示するなら `段: spec`）。次の工程は本体が自分の指示した工程から決め、前任の return の工程名の文字列から決めない（新しいセッションで引き継ぎから再開する本体は、引き継ぎの「次に起こす役割」に書かれた `段:` の値を使う）。**`工程中断:` で返ってきた return にレビュー結果（`agent-review` の判定やレビュー本文）が含まれていたら、本体がそれを記録先に代理投稿する**（G が途中計測の強制停止に当たると `gh pr comment` も拒否されるため。R1 の仕様レビューを代理投稿するのと同じ形）。**強制停止中は commit も本体が行う**: `工程中断:` の return を受け取ったとき、および次の手渡し・次の spawn・そのサイクルの終了・worktree の撤去のいずれよりも先に、本体は return に書かれた作業ツリーのパス（強制停止による中断なら hook の `permissionDecisionReason` に含まれる `cwd`）に対して `git -C <path> status --porcelain` を実行して未コミット差分を確認し、残っていれば本体が commit する（MUST。止まったサブエージェント自身は `Bash` が全件拒否されて commit できない。手渡し先が確認するのは**次に起こされた**サブエージェントの差分だけなので、手渡しが発生しない経路や後継が G の場合はこの本体側の確認が無いと作業が失われたまま残る）。W が孫を呼ぶ必要がある工程は存在しない。仕様化する場合で複数 change に割れたときは、interactive では change ごとに (1)〜(3) を回す（change ごとに仕様レビューを行う。並列可能なら W を並列に起こす（エピックの子のときは `references/epic-worker-slots.md` の枠に従う）。change ごとに worktree を分ける）。

W の空 return、または通常 return（`工程完了:` / `工程中断:`）を含む破壊的 git 操作の拒否報告を受けたら、再開や許可を書く前に必ず `references/worker-recovery.md` を Read して従う。

## ループの終わり

- **worktree の片付けを提案も質問もしない**（完了報告でも途中でも）。片付けは、別セッション方式（Orca・tmux）のエピックの子なら親セッションが行い、それ以外はオーナーが別のセッションで `/wt-clean` を使う
- エピックの子（`scripts/epic-dispatch.sh route`（子の番号なし）が `nested`）の完了報告は、1 行目を `主がこのセッションで次にすること: なし` か `主がこのセッションで次にすること: <どの画面で何をするか>` にする（子のタブを開いた主が最初に読むため）。下の `mark` を呼ぶときは、1 行目が `なし` なら `done`、中身があれば `waiting` を選ぶ。エピックの子でないセッションの完了報告にはこの 1 行を求めない
- 記録先が issue で PR がマージ済みなら、完了報告を書き終えてから、**そのループの最後のツール呼び出し**として `scripts/epic-dispatch.sh mark <done|waiting> <記録先の issue 番号>` を Bash で 1 回呼び、このワークスペースに印を付ける。オーナーに頼むことが残っていなければ `done`（用が済んだ）、完了報告にマージ後の依頼（動作確認など）を書いたなら `waiting`（オーナーの確認待ち）にし、オーナーが済んだと返事をしたら `done` で呼び直す
- PR を伴わない記録先 issue（調査だけの issue など、受け入れ条件がリポジトリの変更を求めないもの）で受け入れ条件を満たしたら、本体が結果を記録先にコメントし、`gh issue close <N> --reason completed` で閉じる。閉じる操作を主に渡さない。受け入れ条件が推奨を出すことなら、推奨を出した時点で満たしたと数え、主が推奨を採るかを閉じる条件にしない（issue を閉じるのは reopen で戻せるので、破壊的な操作として扱わない）。閉じたあとは、PR がマージ済みのときと同じく最後のツール呼び出しで `scripts/epic-dispatch.sh mark <done|waiting> <記録先の issue 番号>` を呼ぶ。親の `epic-dispatch.sh reap` は、そのブランチに PR が無く・issue が閉じていて・HEAD がリモートの今の main に含まれる子を片付ける（main に入っていない commit を積んだまま閉じると `kept <N> unmerged-commits` で残る）
- PR がマージされていないとき（保留・マージ待ち・unmanned）と、記録先が Draft PR のときは呼ばない（PR を伴わない記録先 issue を閉じたときを除く）。エピックの子（`nested`）が PR のマージを主に頼んでループを終えるときは、完了報告で「マージしたら教えてください」「ステータスを変えます」のような、マージ後にこのタブへ戻る連絡を主に頼まず、「マージしたらこのタブは放っておいてよい。記録先が閉じれば親が完了にしてワークツリーを片付ける」と書く（親の `epic-dispatch.sh wait --watch-done` が、記録先が completed で閉じて子のセッションが止まった子を完了と推定するため）。1 行目の `主がこのセッションで次にすること:` はPR のマージだけにする
- 出力が `marked` / `skipped` なら何もしない。`failed` なら完了報告に 1 行書く。どの出力でも止まらない
- 印を最後に置くのは、`done` の印が付くと、エピックの親セッションが最短で次のポーリング（既定 300 秒以内）にこのワークスペースの端末を閉じてワークツリーを消すため。印のあとに文章を書き足さない。スクリプトは今のワークスペースがこの issue のものかを自分で確かめる（違えば `skipped`）ので、エピックの子かどうかを判断せずに呼んでよい

## PR トークン上限

spawn・再開・Codex 委譲の前は毎回、必ず `references/pr-token-budget.md` を Read して測る。開始・dispatch・消費の印を書く前も同ファイルを必ず Read する。

## 保留で止まるときの引き継ぎ（主の返事を待つ前に書く）

引き継ぎの書式・投稿の順序・主への案内・新しいセッションでの再開の手順は `references/handover.md` にある。次のときにそのファイルを Read してから進める。

- 主の返事を待って止まる前のうち、引き継ぎを書く 4 つの場面（pr-review-gate の保留・「PR トークン上限」の exit 2・レビューの 2 周キャップ超え・仕様レビューの条件の問い）に当たるとき。引き継ぎを書き終えるまで止まらない
- 記録先に 1 行目が `引き継ぎ: 主の返事待ち` のコメントがある保留中の記録先を再開するとき（`/develop <記録先>` の入口、または channel で `#<番号>` を添えた返事を受けたとき）。`needs-approval` の有無によらず、入口 0 に進む前に読む

- failed 後の W 起動／再開前に最新 CI 用引き継ぎが可なら、`references/handover.md`「起動／再開前の無効化と再許可」を読み、不可を投稿し、投稿成功後だけ指示する

## エピックの子が主の返事を待って止まるとき

`scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返す子は、主の返事待ちで止まる前と、`親エピック #` か `主の返事（親エピック #` で始まる入力の受信時（セッション再起動後の最初の指示に付く場合も含む）に、`references/epic-child-stop.md` を Read して従う。`nested` 以外は読まない。`nested` の本体が自分の agent・CI・Monitor・Codex を 60 分以上待ちうる場合、開始・延長前に `references/child-background-wait.md` を Read する。

## モデル

モデルの起動・再開（失敗ループを含む）を扱う前に、必ず `../../references/codex-develop.md`（plugin の `references/codex-develop.md`）の「起動と role 解決」を Read して従う。役割の格は下表、対応は `references/model-tier-map.json`、残量モード（`FABLE_BUDGET_MODE`）と共有枠モード（`SHARED_BUDGET_MODE`）はここに再掲しない。優先順位は `references/decision-criteria.md` が正本。V と引き継ぎの判定役と論点なしの確認役は表の明示値を使う。

| 役割 | 既定の格 | 上げる条件 |
|---|---|---|
| W（実行役。`dev-workflow:worker`） | 中位（`sonnet`） | 上位（`opus`）: 記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含む、実行側が原因の失敗ループでの昇格、または事前分類の 4 分類（聖域パス・マージ権限・層間契約・課金/法務。正本は `references/pre-classification.md`、ここに再掲しない）に当たる。**W の上限は `opus` で、`model: fable` の W は `scripts/agent-model-guard.sh` に拒否される** |
| R1（読んで判断する役） | 上位（`opus`） | 仕様の対象がマージ条件・層間契約・課金/法務に触れるときは `--pre-class` を渡し、返った `role: decider` で `subagent_type: dev-workflow:decider` として spawn する（`general-purpose` に `model: fable` を付けない。聖域パスだけでは上げない） |
| G（`dev-workflow:gate-runner`） | 中位（`sonnet`） | 上げない。G の仕事は HEAD 固定・ラベル操作・宣言の書式照合・証拠の実在確認で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う |
| V（画面確認役。`general-purpose`） | 中位（`sonnet`） | 上げない。`request` を通らない |
| 引き継ぎの判定役（`needs-carryover-judge` を受けて本体が起こす） | 上位（`opus`） | 上げも下げもしない（種別は `dev-workflow:decider`。`request` を通らず、残量モードによらず `opus` を明示する）。`SHARED_BUDGET_MODE=depleted` のときは起こさない（「判断できない」の記録を投稿して主に聞く側に倒す。(4) の needs-carryover-judge） |
| 論点なしの確認役（`needs-no-point-check` を受けて本体が起こす） | 上位（`opus`） | 引き継ぎの判定役と同じ（`dev-workflow:decider`・`request` を通らない・depleted のときは起こさない） |
| G が要求するレビュアー（読んで判断する役） | 上位（`opus`） | 既定の種別は `dev-workflow:reviewer`。レビュー対象がマージ条件・層間契約・課金/法務に触れるときは `--pre-class` を渡し、返った `role: decider` で `subagent_type: dev-workflow:decider` として起動する（従来経路では G の `needs-reviewer` の推奨モデルに従う。adapter 経路では `request` が返した `model` を使い、推奨モデルは参考値） |

失敗の判断側・実行側の分類の定義は `templates/escalation-tripwires.md`。model は上の必読正本に従う。コンテキスト上限（`subagent-context.sh` が exit 2）は昇格の理由にはならず、モデルは変えない。手渡しは `references/decision-criteria.md` が正本。規模超過（編集対象5ファイル超・作業項目が2回増えた）を W が return したら本体が change / 子 issue に分割する。

## 実行モード

| モード | 起動 | 本体 | 対話 | 回す工程 |
|---|---|---|---|---|
| **interactive**（既定） | 人間が `/develop`・`/work-issue`・自然文で依頼 | そのセッション | AskUserQuestion で聞ける | (0)〜(4) 全部。複数 change はその場で change ごとに回す |
| **channel** | 印 `DEV_WORKFLOW_UNATTENDED` のあるセッション、またはチャンネル（Discord など）のメッセージで依頼（常駐の開発エージェントが、オーナーからチャンネルで開発を頼まれたときの形） | そのセッション | チャンネルで聞く（AskUserQuestion は使わない） | (0)〜(4) 全部（G を起こし、PR の合格まで進む）。複数 change は interactive と同じ |
| **unmanned**（`--unmanned`） | loop-dev-agent の憲法 Step 3 から | **憲法のメイン自身**が develop の本体を務め、W / R1 をメインが spawn する | 質問は本体が代理送信し終了（1 サイクル 1 仕事） | (0)〜(3)。worktree は憲法側が用意したものを使う。(3) で W が Draft PR の作成と `agent-review:pending` の付与（憲法 Step 3 の 5〜6 に相当）まで行う。**(4) の G は起こさず**、憲法 Step 1（レビューモード）が次サイクル以降で担う |

unmanned で複数 change に割れた場合（W が change 単位で子 issue を作って `blocked_by` で順序付けし、そのサイクルを終える。割り方が判断できないほど曖昧なときは子 issue を作らず、W が質問文・理由を return し、本体が代理送信して `needs-approval` で終える）の手順は、`references/roles/worker/spec.md`「分割判定」が正本。

unmanned で W の return に質問文・理由が含まれるとき、本体（憲法のメイン自身）が受け取り、質問を Discord へ代理送信する。記録先の `needs-approval` を維持してそのサイクルを終了する。

**仕様化判断の記録と仕様レビューは unmanned でも免除しない**（同じ書式で記録先に記録し、R1 の APPROVE まで W を apply に進めない）。文言合わせの通し方（1 ループの (1)。判定基準は `references/spec-decision.md` Step B）で R1 を起こさないのは、モードによる免除ではなく、interactive と同じ対象・同じ当てる条件で unmanned にも当てる。

W・R1 の起動指示の実行モードには interactive と書く（channel でも interactive 側で分岐し、主への質問は return を受けた本体が行う）。channel の読み替えは `references/channel.md`、エピックの方式は `references/epic.md` を場面別の必読入口から読む。

### モードの決め方

`scripts/develop-mode.sh [--unmanned（develop の引数にあるとき）] [--channel-request（依頼本文が <channel source= で始まるとき）]` を新規開始時に 1 回呼ぶ。

| 出力／終了 | 本体の扱い |
|---|---|
| `実行モード: interactive（既定）`、exit 0 | 出力を開始コメントへ記録して interactive で進む |
| `実行モード: channel（印）` / `実行モード: channel（チャンネルの依頼）`、exit 0 | 出力を記録し、直後の案内に従い channel.md を読む |
| `実行モード: unmanned（引数）`、exit 0 | 出力を記録して unmanned で進む |
| exit 0 以外、または上のどの行にも当たらない出力 | stderr を添えて報告し、推測で進めない |

決めたモードは develop 開始コメントに `実行モード: <モード>（<理由>）` の 1 行で残す。途中でモードを変えない。新しいセッションで引き継ぎから再開するときは、決め直さずに引き継ぎの `実行モード` の値を使う。

モードが channel に決まったら、決めた直後に（`commands/develop.md` の分岐 ②⑤ と issueify フォールバックで主に聞くより前に）`references/channel.md` を Read してから進める（channel の聞き方と読み替えの規則・リスク許容・主への発言の 3 つ。開始コメントの `チャンネルの返事の確認:` の行もそこで決める）。引き継ぎから `実行モード: channel` で再開するときと、コンパクトのあとに SKILL.md を読み直したとき（開始コメントの `実行モード:` の行が channel のとき）も同じ。interactive と unmanned では読まない。

## エピックの扱い

エピック（独立してマージできる PR が 2 本以上に割れる依頼を、子 issue に分けて回すもの）の条件・作り方・回し方・完了条件は `references/epic.md` にある。次のときにそのファイルを Read してから進める。単発の issue・会話依頼・Draft PR を記録先にする依頼の 1 ループでは、下のどれかの場面に当たらない限り読まない。

- `/develop <エピック番号>` で起動したとき（記録先の issue が子 issue を持つとき）
- 依頼をエピックにするかを決めるとき（W の分割判定が複数 change を返し、エピック化を選ぶか考えるときを含む）
- `scripts/epic-dispatch.sh route`（子の番号なし）が `nested` を返すエピックの子として動き、W を並列に起こすときか、自分の記録先がエピックだったとき
- 記録先の issue に `親エピックからの注意書き:` で始まるコメントがあるとき（エピックの子として起動したときと、同じワークツリーで `/develop #<N>` を打ち直して起動し直したときを含む）。そのコメントに従うか、W・R1・G に渡すかを決める前に読む。従ってよいのは投稿者の `author_association` で絞ったものだけで、その規則は `references/epic.md` の「nested と注意書き」にある
- エピックの子が実装中に範囲外の新しい問題を見つけたとき。follow-up の issue を作る前に読む（段 C で完了条件に効くものだけ子にでき、効かないものは段 D・段 E へ。`references/epic.md` の「別セッション方式とサブエージェント方式に共通」）

## 上流の壁打ち（`/opsx:explore`）を呼ばない理由

このスキルは規模が大きくても、上流の壁打ち（openspec の `/opsx:explore`。まだ形になっていない曖昧な要望を、対話で質問しながら実装可能な単位に分解し、相互矛盾がないか確認する工程）を内部から呼ばない。このスキルが扱う依頼（issue・受け入れ条件付きの会話依頼・エピックの子）は既にその「ほぐす作業」が終わった状態にある。複数 change が必要なら記録先の記述を根拠に分割すれば足りる（`references/epic.md` のエピックの作り方）。`/opsx:explore` は issue の体裁を成す前の構想専用として切り離し、その出口（`/opsx:new` / `/opsx:ff`）からこのスキルに入る。

## その他の正本

- worktree セットアップの自動化: worktree プラグインの `hooks/hooks.json`（`WorktreeCreate` / `SessionStart`）。
- unmanned の外形（ラベル・Draft PR・キュー）: 各リポに配備された loop-dev-agent の憲法 `docs/agent-loop.md`（配布元が保守し、harness にテンプレートは無い）。
