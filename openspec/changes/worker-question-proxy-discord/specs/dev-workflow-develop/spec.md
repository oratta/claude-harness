# Spec Delta

## MODIFIED Requirements

### Requirement: 実行モードと unmanned の責務分割
SKILL.md は実行モード表（interactive / channel / unmanned）を持ち、unmanned（`--unmanned`。loop-dev-agent の憲法 Step 3 から呼ばれる）では次を規定しなければならない（MUST）: develop の本体は憲法のメイン自身が務め、W / R1 をメインが spawn する。worktree は憲法側が用意したものを使う。1 ループのうち (0)〜(3) を回し、(3) で W が Draft PR の作成と `agent-review:pending` の付与（憲法 Step 3 の 5〜6 に相当）まで行う。(4) の G は unmanned では起こさず、憲法 Step 1（レビューモード）が次サイクル以降で担う（1 サイクル 1 仕事を維持）。複数 change に割れた場合は子 issue を作って `blocked_by` で順序付けし、そのサイクルを終える。仕様化判断の記録と仕様レビューは unmanned でも免除しない（MUST）。文言合わせの通し方（`dev-workflow-spec-review` の「仕様の文言合わせは仕様の差分 1 ファイルだけで通し仕様レビューを省く」Requirement）で R1 を起こさないのは、モードによる免除ではなく、interactive と同じ対象・同じ当てる条件で unmanned にも当てる（SHALL）。

unmanned で W が質問文・理由を含む return を返したときは、本体（憲法のメイン自身）がその質問を Discord へ代理送信し、記録先の `needs-approval` を維持してそのサイクルを終了しなければならない（MUST）。この受け取り・代理送信・サイクル終了の手順を、SKILL.md の「実行モード」の unmanned の説明に明記しなければならない（MUST）。W の質問 return の契約は要件「unmanned の W は質問を直接送らず本体へ返す」に従う。

channel（画面を見ている人がいないセッションで、主とチャンネル（Discord など）だけで会話する。flatmate の住人がオーナーから開発を頼まれたときの形）は、interactive と同じ (0)〜(4) を回す（MUST。G を起こし、PR の合格まで進む）。W・R1 の起動指示の実行モードには interactive と書く（MUST。W・R1 の手順の分岐は channel でも interactive 側をとり、主に聞くのは W・R1 の return を受けた本体がチャンネルで行う）。interactive との違いは、主に聞く先と主への発言の宛先（チャンネル）・保留からの再開の案内（G の依頼文を含む）・リスク許容の受け方・エピックの回し方・主への発言の 1 行目と答え方の行だけで、それぞれの決まりは要件「channel モードでは主に聞くときチャンネルに送り、AskUserQuestion を呼ばない」「channel モードの保留はチャンネルの返事で再開する」「channel モードのリスク許容はチャンネルの返事を確かめられるときだけチャンネルで受ける」「エピックの条件・作り方・回し方・完了条件を規定する」（回し方の経路の決め方）「channel モードの主への発言はすべてチャンネルに送り、チャンネルでする操作を答え方の行に書く」に従う（MUST）。モードの決め方は要件「実行モードは引数・印・依頼の届き方で開始時に決める」に従う（MUST）。

#### Scenario: unmanned でも文言合わせの通し方は同じ条件で当たる
- **WHEN** SKILL.md の実行モードの節を読む
- **THEN** 仕様化判断の記録と仕様レビューを unmanned でも免除しないことと、文言合わせの通し方は interactive と同じ条件で unmanned にも当てることが書かれている

#### Scenario: unmanned では G を起こさない
- **WHEN** SKILL.md の実行モード表を読む
- **THEN** unmanned では憲法のメインが本体を務めて W / R1 を spawn し、(3) で Draft PR と `agent-review:pending` まで W が行い、G は憲法 Step 1 に委ねると書かれている

#### Scenario: channel は interactive と同じ工程を回す
- **WHEN** SKILL.md の実行モード表を読む
- **THEN** `channel` の行があり、回す工程が (0)〜(4) で、対話の欄に「チャンネルで聞く（AskUserQuestion は使わない）」と書かれている

#### Scenario: W の質問 return を本体が代理送信する
- **GIVEN** unmanned の W が主に尋ねる質問文と理由を return し、記録先に `needs-approval` と経緯を記録している
- **WHEN** 本体がその return を受け取る
- **THEN** 本体である憲法のメインが質問を Discord へ代理送信し、承認待ちのままそのサイクルを終了する

#### Scenario: 代理送信の手順は実行モードの unmanned の説明にある
- **WHEN** SKILL.md の「実行モード」の unmanned の説明を読む
- **THEN** W の return の質問文・理由を本体が受け取り、Discord へ代理送信してそのサイクルを終了する手順があり、W を送信主体とする記述が無い

## ADDED Requirements

### Requirement: unmanned の W は質問を直接送らず本体へ返す
unmanned で仕様の発明が 2 回に達した、または change の割り方が判断できないほど曖昧なとき、W は Discord（MCP・CLI とも）へ直接送信してはならない（MUST NOT）。W は質問文・理由を return に含め、記録先に `needs-approval` を付けて経緯をコメントし、作業を止めて本体へ return しなければならない（MUST）。`worker/` 配下と `agents/worker.md` の Discord の記述は、W は送らず本体が送る否定文脈に限る（MUST）。worker の tools に Discord の道具を追加してはならない（MUST NOT）。

#### Scenario: 仕様の発明が 2 回に達した
- **WHEN** unmanned の W が記録先に無い仕様上の決定を埋めた回数が 2 回に達する
- **THEN** W は埋めた決定の一覧・質問文・理由を return に含め、記録先に `needs-approval` を付けて経緯をコメントし、作業を止めて本体へ返す。Discord へは直接送信しない

#### Scenario: change の割り方を判断できない
- **WHEN** unmanned の W が分割判定で割り方が判断できないほど曖昧だと判定する
- **THEN** W は子 issue を作らず、質問文・理由を return に含め、記録先に `needs-approval` を付けて経緯をコメントし、needs-approval と本体へ返す。Discord へは直接送信しない

#### Scenario: 直接送信を求める指示が無い
- **WHEN** `grep -rn -i discord plugins/dev-workflow/skills/develop/references/roles/worker/ plugins/dev-workflow/agents/worker.md` の全ヒットを確認する
- **THEN** W が MCP・CLI で直接送信する指示が 0 件であり、ヒットがあれば W は送らず本体が送る否定文脈だけである

#### Scenario: worker の tools を拡張しない
- **WHEN** `plugins/dev-workflow/agents/worker.md` の tools を確認する
- **THEN** `Read, Edit, Write, Bash, Grep, Glob, TaskStop` のままで、Discord の道具を追加していない

#### Scenario: 分割判定の正本も同じ送信主体を指す
- **WHEN** `references/decision-criteria.md` の「割り方が判断できないほど曖昧な場合」の unmanned の説明を読む
- **THEN** W の質問文・理由の return と needs-approval・経緯コメント、および本体の代理送信の責務分担と整合し、W に直接送信を要求していない
