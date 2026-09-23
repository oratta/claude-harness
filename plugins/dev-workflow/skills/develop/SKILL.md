---
name: develop
description: コード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変えるときは必ず通す標準開発ワークフロー。記録先 → 仕様化判断 → 仕様レビュー → TDD 実装 → pr-review-gate を 1 ループで回す。issue 番号・issue URL・「この issue 対応して」等の自然文、issue の無い会話依頼・cron・エピックの子のいずれからでも起動する。人間依頼（interactive）と無人サイクル（`--unmanned`）の両対応。
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

## Role profile の選択

profile と旧 account/model のどちらも明示しない場合、各 canonical phase の開始時に adapter で再評価する。Claude 起動 account と登録 Codex accounts の fresh な週次 snapshot（age `<=300` 秒）から `margin = 週経過率 - 使用率` を求め、両方が 0 以上なら `claude-write-codex-review`、Codex だけが 0 以上なら `codex-standard`、それ以外は Claude 既定構成を選ぶ。開始済み role は工程途中で切り替えない。adapter が返す構成、reason、両 provider の margin / fetched_at、代表 Codex account を、最初の develop 開始コメントと後続 phase の dispatch 記録へ残す。値が無ければ `missing` と記録する。

`--profile NAME [--profile-file PATH]` または旧形式の Codex account/model を明示したときは、`${CLAUDE_PLUGIN_ROOT}/references/codex-develop.md`（未設定ならこの SKILL.md から `../../references/codex-develop.md`）を絶対パスに解決して Read する。各委譲の直前に adapter から canonical role の per-role execution result を取得し、provider 操作は同 reference の「role 解決直後の一度だけの分岐」に従う。事前分類に当たる R1 または G が要求したレビュアーは、対象 role の entry ではなく profile の `decider` entry（executor/account/model）を使い、`subagent_type: dev-workflow:decider` として起動する。この SKILL.md はその分岐を再掲せず、工程順、role、review 条件、return 契約、次工程の判断だけを正本として維持する。

G の起動・再開・手渡しの指示には、起動形を問わず常に `レビュー経路: adapter` の 1 行を書く（自動選択・明示 profile・旧形式のどれも adapter で解決するので、今が adapter 経路かを評価しない）。Codex の G では request の instructions（`--input` の指示ファイル）にも書く。develop の本体は `レビュー経路: 従来` を書かない（develop の本体以外の呼び出し元のための値）。adapter で起動済みの同一 G は、行の無い再開でも adapter 経路を保持する。新しい G の起動指示（手渡しで起こされた後任 G を含む）に行が無い場合だけ従来経路（full は G が Codex を直接呼ぶ）として動く。この sticky 規則は欠落時の安全策であり、本体に行の省略を許可する規則ではない（`references/roles/gate-runner.md`「レビュー経路の判別」）。

名前付き profile では profile role ごとに thread と requested tuple / applied model / reason を記録する。同じ Claude profile role を再開する直前に毎回現在の `FABLE_BUDGET_MODE` / `SHARED_BUDGET_MODE` 上限を再確認し、既存 applied model が上限内のときだけ SendMessage する。上限を超える場合は SendMessage せず、既存の工程完了または停止確認条件を満たしてから requested tuple を変えずに capped model の fresh thread へ成果物と必要な要約を手渡す。profile role の境界、独立 review、Codex 委譲も fresh thread とする。以下の spawn / SendMessage 表記は、profile 利用時にはこの規則を適用した provider 操作を意味する。

## いつ使うか

ソースコード・スキル・コマンド・規範文書（openspec / docs / CLAUDE.md 等）を変える作業は、依頼の入口を問わず（GitHub issue・会話・cron・エピックの子のいずれでも）このスキルを通す。「issue があるか」は入口 0 で記録先を決める材料にすぎず、スキルを通すかどうかの条件ではない。

例外は「読むだけ・回答だけ・生成物を出すだけ」の作業（調査報告・質問への回答・レポートや図の生成など、リポジトリの追跡対象を変えないもの）に限る。

## 前提

無いときの縮退まで含めて列挙する。本体が spawn できない環境（本体自身がサブエージェント）ではこのスキルは成立しないので、その場合は親に return して親を本体にする。

| 前提 | 使い方 | 無いとき |
|---|---|---|
| **Agent ツール** | W / R1 / G の spawn。`model` を必ず明示し、W と G は**名前付き**で spawn する（SendMessage で再開するため）。W は本体が対象専用の worktree にいなければ `isolation: "worktree"` で起こす。**`isolation: "remote"` で W / G を起こしてはならない**（強制停止に当たった作業を本体が引き取れなくなるため。理由は「worktree の用意」を参照） | 本体になれない。親セッションに return する |
| **SendMessage** | 名前付きで起こした W / G の再開（コンテキストを引き継いだまま次の工程を指示する）と、G へのレビュー要約の受け渡し | 再開できないので、前任を手渡してよい状態のときだけ新しい W を spawn し、前回の return 全文をプロンプトに渡す。条件は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」が正本で、満たさないなら spawn せず親に返す（前任が動いたまま後任を起こさない） |
| **`gh`** | 記録先（issue / PR）へのコメントとラベル操作、Draft PR の作成、エピックの子の依存（`gh api repos/<owner>/<repo>/issues/<N>/dependencies/blocked_by`、issue dependencies API） | 記録先を作れないので開始しない（記録なしで実装に進まない） |
| **opsx コマンドまたは openspec CLI** | 仕様化経路（`/opsx:ff` → R1 → `/opsx:apply` → verify → archive）。CLI だけなら W が直叩きで同じ工程を踏む | 仕様化経路が発生しない（W は `仕様化判断: しない` の理由に「openspec 不在」と書き、コード直行する） |
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
- **無ければ issue を切らない。** 本体が worktree を用意し、W が worktree 直後に空 commit（`git commit --allow-empty`）を積んで push し、`gh pr create --draft` で Draft PR を開いてそれを記録先にする（GitHub の "open a draft PR early" の慣行）。この Draft PR は**仕様化判断を記録する前**に存在していなければならない — 記録先が無い状態で判定を先に進めない（手順は `references/roles/worker.md`「記録先の用意」）
- Draft PR を記録先にする場合、**受け入れ条件は PR 本文**（位置づけ・動作確認ポイント）に書く。issue に書かない分の省略であって、受け入れ条件自体を省くことはできない
- 記録先を PR にした場合、PR 本文に `Closes #N` / `Fixes #N` / `Refs #N` の issue 参照を**書かない**。書くと pr-review-gate の照合先がその issue に移る（探索順は issue → 無ければ PR 自身のコメント）。エピックの子は子 issue が記録先なので `Closes #子` を書く
- 仕様化判断（`仕様化判断: する|しない`）・仕様レビュー結果（`仕様レビュー: APPROVE|REQUEST_CHANGES`）は記録先のコメントに置く（書式の正本は `references/roles/spec-reviewer.md`「判断記録の契約」）
- **仕様宣言は記録先ではなく常に PR コメントに置く**（記録先が issue でも issue には書かない）。pr-review-gate 手順 5 が PR のコメントでリスク宣言・仕様宣言・動作確認の 3 見出しを照合し、`対象 HEAD:` 規約が PR の HEAD に紐づくため。書式の正本は pr-review-gate スキル手順 3-b

**issue を切るのは追跡・キュー・議論が要るときだけ**: エピック（複数 PR にまたがる。下の「エピックの扱い」）／無人キュー（loop-dev-agent が拾う対象にしたい）／判断を残す議論（決定の経緯を issue スレッドに残したい）。この 3 つに当たらなければ Draft PR で足りる。issue を切る経路は `commands/develop.md` の issueify フォールバック。

## worktree の用意

worktree は**本体が用意する**。本体が既に対象専用の worktree（1 issue = 1 worktree = 1 ブランチ）にいればそこで W を起こし、そうでなければ W を `isolation: "worktree"` で spawn する。**W は自分で worktree を切らない**（セットアップは worktree プラグインの `WorktreeCreate` / `SessionStart` hooks が担うので、W は判定もしない）。unmanned では憲法側が用意した worktree を使う。**`isolation: "remote"` は使わない**（MUST NOT）。強制停止中は `Bash` が全件拒否されるため止まったサブエージェント自身は commit できず、未コミット差分は本体が引き取る設計（下の「工程中断: で返ってきたら」を参照）だが、`remote` 隔離は本体から見えない環境なので、そこで強制停止に当たると作業がそのまま失われる。

## 1 ループ（W → R1 → W → G）

1 issue（または 1 Draft PR）につき次を回す。各工程の担い手と、本体が次に誰を起こすかの判断材料を書く。

下の各工程の spawn・SendMessage による再開・Codex executor への委譲の直前には、毎回「PR トークン上限」の節の計測を行う（exit 2 なら起こさず止まる）。

```
(0) 記録先を確定する（入口 0）。worktree を用意する
(1) W を名前付きで spawn（model: worker.md の事前分類表の「1 周目」列に当たればその値（4 分類のいずれでも opus。W の上限は opus）、それ以外 sonnet。W を fable にはしない。共有枠モードが下限を決める）:
      記録先の用意（Draft PR 経路）→ 仕様化判断の記録 → 分割判定 → /opsx:ff → return「仕様できた」
      仕様化しない判定なら → (3) へ直行（TDD → PR）
(2) R1 を spawn（model: 既定 opus。マージ条件・層間契約・課金/法務に触れれば subagent_type: dev-workflow:decider で spawn する。聖域パスだけでは上げない）:
      references/roles/spec-reviewer.md に従って別コンテキストで仕様レビュー → 結果を記録先にコメント → return
      dev-workflow:decider で起こした R1 は gh を実行できないので投稿せず return し、本体が同じ書式で代理投稿する
      （記録先の本文と関連コメントは本体が入力文に貼って渡す）
      REQUEST_CHANGES → W を SendMessage で再開して artifact を修正 → R1 を再開して差分再レビュー
      （初回＋差分 1 回の 2 周キャップ。超えたら needs-approval を付けて本体がオーナーに 1 アクションで依頼）
      R1 の APPROVE が記録先に記録されるまで W を apply に進めない（再開しない）
(3) W を SendMessage で再開（再開前に `scripts/subagent-context.sh <W の名前>` で測る。上限超を検知した
      あとの扱いは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本。正本を読むまで手渡さない）。
      (3) は 2 回の return に分かれる:
      (3a) apply（TDD。/opsx:apply または直叩き）→ verify → return「工程完了: 実装＋verify」
           （実行したテストコマンドと exit code、/opsx:verify の合否を載せる）
           → 本体はここで `scripts/subagent-context.sh <W の名前>` をもう一度実行して測ってから (3b) を指示する
      (3b) archive → PR を Draft のまま用意（無ければ Draft で作成。Ready 化は (4) の G が pr-review-gate 手順 5 で行う）→ 仕様宣言を PR コメントに書く
           → return「工程完了: archive＋PR＋仕様宣言」（PR #N と仕様宣言のコメント URL を載せる）
      (3) をこれより細かく（tasks の項目単位・実装／verify／archive／PR／仕様宣言 の 5 段など）切らない。
           手渡しごとに指示書の読み直しと現状確認の固定分が乗り、実装の途中で切ると後任が Red のまま
           止まったテストから再出発することになるため（理由の正本は references/roles/worker.md「コンテキスト上限と手渡し」）
      本体は次に指示する工程を、自分が (3a) を指示したか (3b) を指示したかで決め、工程名の文字列照合では決めない。
           (3a) の return に PR 番号と仕様宣言のコメント URL が既に揃っていれば（古い世代の W が (3) を
           通しで終えた場合）、(3b) を指示せず、そのまま (4)（G の工程）へ進む
(4) G を名前付きで spawn（model: 既定 sonnet。G の仕事は照合・ラベル操作で、欠陥探索は needs-reviewer で本体が起こすレビュアーが担う）:
      G の起動・再開・手渡しの指示には常に `レビュー経路: adapter` の 1 行を書く（Codex の G では request の instructions にも。
           `レビュー経路: 従来` は書かない。理由は「Role profile の選択」節）
      pr-review-gate の手順 1〜5 → return「passed / failed / 保留 / needs-reviewer / needs-decider / review-incomplete」
      合格処理（手順 5）では PR が Draft なら Ready にしてから agent-review:passed を付ける（W は Ready にしない）
      needs-reviewer → adapter 経路では G は full でも light でもこれを返す。本体は次の順で進む:
           ① codex-develop.py request --phase review で投げ先を選び直す（実行先オプションはこの develop 開始時と同じ。自動選択なら無指定）
           ② 返った選択（構成・reason・両 provider の margin・各 fetched_at・代表 Codex account。欠測は missing）と解決した executor / model を
              記録先に dispatch 記録として投稿する。投稿に成功するまでレビュアーを起動しない
           ③ 選ばれた投げ先でレビュアーを起動する（executor が claude なら Agent ツールで、model は adapter の値に残量上限を適用したもの。
              事前分類に当たれば profile の decider entry で dev-workflow:decider。codex なら request を実行する）
           ④ レビュー要約と、選ばれた executor / model・dispatch 記録のコメント URL を G に渡す。review phase の executor が codex なら、worker の結果 JSON の `execution.model_resolution.requested` / `execution.model_resolution.resolved` も G に渡す。resolved が未観測なら null をそのまま渡し、要求値や dispatch 時の model で補完しない。Claude の G は SendMessage で再開して渡す
              （gate-runner.md「needs-reviewer の return」）。Codex の G は新しい phase gate を開始してその入力に渡す（codex-develop.md「品質と transport 差分」）
           通常の初回レビュー依頼も補足要求も同じ ①〜④ で進める。`needs-reviewer` が一周目照合の補足要求である場合に限り、③ のレビュアーへ
           同じレビューの固定 HEAD・元の三表・残差・補足済み回数を payload のまま渡し、不足分だけを補わせる。補足結果は `補足済み回数: 1` として G に渡し、fresh thread でも回数をリセットしない
           develop の本体以外から G を起こす従来経路の手順（呼び出し元がレビュアーを起こす）は gate-runner.md のまま
      review-incomplete → reviewer を再起動しない。`agent-review:pending` のまま Gate Result の残差を報告して工程を止め、合格処理へ進まない
      failed → 原因分類（実装品質起因／仕様が曖昧／レビュアーの誤検出）で戻し方を決める。モデルを上げるのは実装品質起因のときだけで、
           上げるのは決める役と実行役の一方だけ（実行側が原因なら W を opus に、判断側が原因なら dev-workflow:decider を立てて修正方針を作らせる。
           W を fable にはしない）。仕様が曖昧なら仕様修正、誤検出なら反証で返す（どちらもモデルを上げない）
           → W を再開（再開前に測る。上限超のあとの扱いは (3) と同じく正本に従う）→ G を再開して再レビュー（2 周キャップ。G も同じ。範囲と 3 周目の扱いは pr-review-gate の収束ルールに従う）
      保留 → needs-approval のまま本体がオーナーに 1 アクション（許容する／しない、動作確認の結果、切り出しの確認への回答（切り出す／この PR で直す））で依頼する
      needs-decider → 仕分け表の順 6（同じ型の再発）。本体が subagent_type: dev-workflow:decider を残量モードどおりのモデルで起こし、
           入力に decider.md の入力契約どおり、記録先の本文・判断に必要な関連コメント（`仕様化判断:` の記録・G の仕分けの PR コメント・順 3 の一覧表の
           PR コメントがあればそれ）・同じ型の指摘と前の周の指摘の原文・対象ファイルのパス・G の仕分け欄・W の直近の return を貼って、「この PR の中で
           同じ型を全部列挙してから直すべきか（可）、切り出すべきか（否）」を問う（順 6 の依頼はマージ可否と同じ可否と根拠の形で問う。decider.md は変えない）。
           依頼文で返答の 1 行目を `裁定: 可`・`裁定: 否`・`不足: <足りないもの>` のどれかちょうどに指定し、本体はその 1 行目で分岐する（本文の読み取りで分岐しない）。
           `裁定: 可` を「全部列挙してから直す」、`裁定: 否` を「切り出す」に読み替え、根拠とともに SendMessage で G に返す。1 行目が `不足:` なら裁定として扱わず
           G に渡さない。足りないものを補って同じ問いで 1 回だけ依頼し直す。1 行目が 3 形のどれにも一致しなければ `不足:` と同じに扱う（1 回だけ依頼し直す）。
           2 回目も不足（または 3 形に一致しない）なら「裁定なし（入力不足）」と足りなかったものを SendMessage で G に渡す（G は「切り出す」として主に聞く）。
           本体は裁定を代理投稿しない（G が `決める役の裁定:` の PR コメントとして記録する）
```

W は名前付きで spawn し、SendMessage で再開してコンテキストを引き継ぐ（(1) の判定・(2) の指摘・(3) の実装が同じコンテキストにある）。**ただし再開の前に毎回 `scripts/subagent-context.sh <名前>` でコンテキスト量を測る（exit 2 が上限超）。閾値と全解除の環境変数・途中計測 hook を含む 2 経路・上限超を検知したあとの扱い（送ってよい／送ってはならない SendMessage・手渡しを行ってよい条件・return の 1 行目の宣言・前任が動作中のまま交代させる手順）は `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本で、この SKILL.md には書かない。正本を読むまで手渡さない。** G の再開も同じ。**`工程中断:` で返ってきた return にレビュー結果（`agent-review` の判定やレビュー本文）が含まれていたら、本体がそれを記録先に代理投稿する**（G が途中計測の強制停止に当たると `gh pr comment` も拒否されるため。R1 の仕様レビューを代理投稿するのと同じ形）。**強制停止中は commit も本体が行う**: `工程中断:` の return を受け取ったとき、および次の手渡し・次の spawn・そのサイクルの終了・worktree の撤去のいずれよりも先に、本体は return に書かれた作業ツリーのパス（強制停止による中断なら hook の `permissionDecisionReason` に含まれる `cwd`）に対して `git -C <path> status --porcelain` を実行して未コミット差分を確認し、残っていれば本体が commit する（MUST。止まったサブエージェント自身は `Bash` が全件拒否されて commit できない。手渡し先が確認するのは**次に起こされた**サブエージェントの差分だけなので、手渡しが発生しない経路や後継が G の場合はこの本体側の確認が無いと作業が失われたまま残る）。W が孫を呼ぶ必要がある工程は存在しない。仕様化する場合で複数 change に割れたときは、interactive では change ごとに (1)〜(3) を回す（change ごとに仕様レビューを行う。並列可能なら W を並列に起こす。change ごとに worktree を分ける）。

## PR トークン上限（spawn・再開・Codex 委譲の前に毎回測る）

1 つの記録先に使ったトークンの累計に上限を掛ける（#288）。周回数のキャップでは、1 周が重い場合や W の再開が繰り返される場合を止められないため。

**紐付けの規約**: その記録先のためにサブエージェントを spawn するときは、役割を問わない（W / R1 / G / G のレビュアー / 決める役はその例）で Agent ツールの `description` に記録先番号を `#N` の形で入れる（例: `W: impl for #288`。PR 番号も分かっていれば `G: gate for PR #400 (#288)` のように併記してよい）。番号の無い description のサブエージェントは計測から漏れる。

**Codex の消費の記録**: その記録先のために Codex を呼んだら、そのたびに記録先へ 1 行目が `Codex 消費: <thread_id> <tokens>` のコメントを投稿する。executor が `codex` の役割へ委譲したときは codex-worker の結果 JSON の `thread_id` と `usage.total.totalTokens` を書く（`usage` が null か `usage.total.totalTokens` が読めないときは `<tokens>` を `-` と書く）。G が full レビューで Bash から Codex を呼んだときは、G が return に書いた Codex thread の thread_id を使い、`<tokens>` を `-` と書く。結果 JSON を受け取れなかった委譲と、G が thread_id を取れなかった呼び出しは記録できず、上限の外になる。

**計測**: その記録先のためにサブエージェントを spawn する直前、SendMessage で再開する直前、および Codex executor へ委譲する直前に、役割と executor を問わず毎回次を実行する（`subagent-context.sh` を再開前に呼ぶのと同じ位置。こちらは spawn と委譲の前にも呼ぶ）。

```bash
# 渡すすべての記録先番号のコメントを全ページ取得し、1 行目が ^Codex 消費:  のものだけを集める
for n in <記録先番号> [PR 番号]; do
  gh api --paginate --slurp "repos/<owner>/<repo>/issues/$n/comments" \
    | jq -r '.[][] | .body | split("\n")[0] | select(test("^Codex 消費: ")) | sub("^Codex 消費: "; "")'
done > "<scratchpad>/codex-records.txt"
scripts/pr-token-budget.sh <記録先番号> [PR 番号] --codex-records "<scratchpad>/codex-records.txt" \
  --codex-home <account 対応表の各 CODEX_HOME>... --codex-home "${CODEX_HOME:-$HOME/.codex}" [--cap <新上限>]
```

`--codex-home` には codex-develop の account と CODEX_HOME の対応表（`--account-home` / `--account-home-file`）にある全パスと、本体の環境の `${CODEX_HOME:-$HOME/.codex}` を渡す。記録先に `PR トークン上限:` のコメントがあれば、最新のものの値を `--cap` に渡す。上限の既定は 30,000,000（Claude 分と Codex 分の合計に対する値。環境変数 `DEV_WORKFLOW_PR_TOKEN_CAP` で変更可）。計測はこの SKILL.md の手順で、adapter（`references/codex-develop.md`）と `scripts/codex-worker.py` には置かない。

**exit 2（上限超）**: spawn / SendMessage / Codex への委譲をしない。記録先に `needs-approval` を付け、主に「続けるか、範囲外として閉じるか」を問う。問いには合計（Claude 分と Codex 分の内訳）・体数・上限・残工程（次に起こそうとした役割と、そのあと残る工程）・推奨（どちらを選ぶかとその理由）を添え、判断材料なしで出さない。unmanned でも同じく止まり、問いを記録先のコメントに書いてサイクルを終える。

- 「続ける」: 記録先に 1 行目が `PR トークン上限: <新上限>` のコメントを投稿し、以後この記録先の計測に `--cap <新上限>` を渡す。新上限は「その時点の合計 ＋ 直前の計測で上限に使った値（`--cap`、無ければ `DEV_WORKFLOW_PR_TOKEN_CAP`、無ければ 30000000）」。後任の本体は記録先の最新の `PR トークン上限:` コメントの値を使う
- 「範囲外として閉じる」: この記録先について以後サブエージェントを起こさず、Codex にも委譲しない。残作業を記録先にコメントしてサイクルを終える

**exit 1（計測できない。引数エラー・python3 が無い・リポジトリ外）**: 止まらずに進み、計測できなかったことと理由を記録先にコメントする。コメントは同じ記録先・同じ理由について 1 サイクルに 1 回までにする（interactive では本体の 1 セッション、unmanned では loop-dev-agent の 1 サイクル）。

計測に入らないもの: 本体自身の消費、Workflow 経由のサブエージェント。出力の `unresolved`（作業ディレクトリが消えたサブエージェント）と `codex_unresolved`（rollout が見つからない thread）は合計に入らないので、0 でなければ問いに件数を添える。

## モデル

役割ごとのモデルは事前分類と残量モードで決める。実行戦略の分岐はもう無く、判断は「どの役割をどのモデルで起こすか」だけ。

| 役割 | 既定 | 上げる条件 |
|---|---|---|
| W（実行役） | `sonnet` | `opus`: 記録先が設計判断（データモデル・フロー・複数モジュールにまたがる変更）を含む、実行側が原因の失敗ループでの昇格、または事前分類の 4 分類（聖域パス・マージ権限・層間契約・課金/法務。正本は `worker.md`、ここに再掲しない）に当たる。**W の上限は `opus` で、`model: fable` の W は `scripts/agent-model-guard.sh` に拒否される** |
| R1（読んで判断する役） | `opus` | 仕様の対象がマージ条件・層間契約・課金/法務に触れるときは `subagent_type: dev-workflow:decider` で spawn する（`general-purpose` に `model: fable` を付けない。聖域パスだけでは上げない） |
| G | `sonnet` | 上げない。G の仕事は HEAD 固定・ラベル操作・宣言の書式照合・証拠の実在確認で、欠陥探索は Codex か `needs-reviewer` のレビュアーが担う |
| G が要求するレビュアー（読んで判断する役） | `opus` | レビュー対象がマージ条件・層間契約・課金/法務に触れるときは `subagent_type: dev-workflow:decider`（G の `needs-reviewer` の推奨モデルに従う） |

W の既定が `sonnet` なのは、監査（2026-09）で W に Sonnet が 1 本も無く、昇格ラダーの Sonnet 段が構造的に通っていなかったため。W は事前分類と失敗ループで `opus` まで上がる。W の上限を `opus` にしたのは、Fable が消費するのはターン数（会話履歴の cache 読込）で、実装・修正ループは 1 件で数十〜数百ターン回るため。「層間契約だから判断が要る」ぶんは仕様化判断・R1 レビュー・本体の判断で吸収し、W は確定した内容を落とす作業だけを担う。読んで判断する役（R1・レビュアー）が Fable に当たるときは `dev-workflow:decider` で起こす — Fable を渡せる `subagent_type` はこれだけで、判定は `scripts/agent-model-guard.sh` が行う。

残量モード（`FABLE_BUDGET_MODE`）は `references/decision-criteria.md` の表に従う: `abundant` はどの役割の既定も上げない（Fable の余裕は人間の対話と verify に回す）、`reserve` は**自動実行のみ** `opus` 上限（interactive は制限しない）、`exhausted` は**全経路**で `opus` 上限。共有枠モード（`SHARED_BUDGET_MODE`。全モデル共通の週次枠から導出）が下限を決め、`throttled` は W / R1 / G の既定を `sonnet` に落として昇格上限 `opus`、`depleted` は全役割 `sonnet` 固定。両者が食い違えば共有枠モードが勝つ。

昇格トリップワイヤー（`templates/escalation-tripwires.md`）は失敗の原因側だけを上げるラダーとして残す: 同じテストが 2 連続で落ちた、または同じ箇所を 2 回書き直したと W が return したら、本体は失敗の原因が判断側（指示を解釈できなかった・指示自体が外れていた）か実行側（指示どおりやって結果が違う）かで、**決める役と実行役のどちらか一方だけ**を上げる（両方同時に上げない）。判断側なら `subagent_type: dev-workflow:decider` を立てて修正方針を作らせ（`model` は `opus` → `fable`。種別は固定して `model` だけ切り替える）、実行側なら W を `opus` で再開する（W の上限は `opus`）。残量モードと共有枠モードの上限が先に効く。コンテキスト上限（`subagent-context.sh` が exit 2）は昇格の理由にはならず、モデルは変えない（そのあとの扱いは `references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」 が正本）。規模超過（編集対象 5 ファイル超・作業項目が 2 回増えた）を W が return したら、本体が change / 子 issue（エピック化）に分割する。

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
