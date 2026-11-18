# Spec Delta

## MODIFIED Requirements

### Requirement: 手順の本文は段ごとのファイルと宣言の書式ファイルに置く

手順の本文は `plugins/dev-workflow/skills/pr-review-gate/stages/` の次の 6 つの段の入口と、各入口から条件付きで読む詳細ファイル、および宣言の書式ファイル `plugins/dev-workflow/skills/pr-review-gate/declarations.md` に置かなければならない（MUST）。手順番号（1・2-0・2-1・2-2・3・3-b・3-c・4・5・6）は変えてはならない（MUST NOT）。

| 段 | ファイル | 持つ手順 |
|---|---|---|
| 前提確認と重さ判定 | `stages/prepare.md` | 手順 1・手順 2 の冒頭・2-0 |
| レビューの起動 | `stages/review-run.md` | 2-1 のうちレビュー実行者の優先順・Codex 呼び出し規約・Task サブエージェントのモデル・各 PC の確認 |
| レビュー担当向けの指示 | `stages/reviewer-brief.md` | 2-1 のレビュアー向け指示ブロック・共通一覧契約・Codex の読み替え表 |
| 照合と指摘の振り分け | `stages/triage.md` | 2-1 のうちマージを止めるかの判定・仕分け表・収束ルール・2 周目の終わり・決める役・2-2 |
| 合格処理 | `stages/pass.md` | 手順 4・5 |
| 保留 | `stages/hold.md` | 3-c・手順 6・主に承認を求めてよい 4 分類 |

表の「持つ手順」は、入口自身と入口が条件付きで指す詳細の担当範囲である。詳細を読む条件とパスは入口に明記し、条件が成り立たない本文を入口に再掲してはならない（MUST NOT）。手順 2-1 の入口の見出しは残し、見出しを次の 3 つの形にしなければならない（MUST。番号は変えない）: `stages/review-run.md` に `#### 2-1. レビューの実行（レビュー実行者）`、`stages/reviewer-brief.md` に `#### 2-1. レビューの実行（レビュアー向け指示）`、`stages/triage.md` に `#### 2-1. レビューの実行（止める判定と仕分け）`。

`declarations.md` は手順 3（リスク宣言）と 3-b（仕様宣言）を持つ（MUST）。旧 SKILL.md 冒頭の「前提と理由」の各項目は、それを使う段のファイル（HEAD SHA と仕様宣言は `declarations.md`、stale passed は `stages/prepare.md`、auto-merge の配備状況は `stages/pass.md`、リポ固有の仕組みは `stages/hold.md`）に移さなければならない（MUST）。移すときに規則・閾値・雛形・コマンドの中身を変えてはならない（MUST NOT）。declarations.md の issue 承認済みと論点なしの詳細は、条件付きで読む stages/issue-approved.md と stages/no-point-check.md を正本とし、宣言の雛形は declarations.md に残す。

#### Scenario: 手順番号の対応表

- **WHEN** 索引の手順番号の対応表を読む
- **THEN** 1・2-0・2-1・2-2・3・3-b・3-c・4・5・6 のすべてに行があり（2-1 は「レビュー実行者」「レビュアー向け指示」「止める判定と仕分け」の 3 行）、各行が指すファイルにその手順の見出しがある（2-1 の 3 行は、それぞれ括弧書きまで一致する見出しがある）

#### Scenario: 段のファイルが揃っている

- **WHEN** `ls plugins/dev-workflow/skills/pr-review-gate/stages/` を実行する
- **THEN** `prepare.md`・`review-run.md`・`reviewer-brief.md`・`triage.md`・`pass.md`・`hold.md` がある

#### Scenario: 条件が違う詳細を最初から読ませない

- **WHEN** 前 HEAD の許容が無く、リスクなし・通常の仕様化経路の PR の合格処理を始める
- **THEN** carryover.md、carryover-judge.md、authenticity-relayed.md、authenticity-delegated.md、pass-wording.md の本文は入口に入っておらず、該当する条件が成り立ったときだけ読む案内がある

#### Scenario: 同じ停止条件とコマンドで動く

- **WHEN** 軽い通し方、順 3、引き継ぎ、真正性、文言合わせの詳細を移動前の手順と比較する
- **THEN** 条件の判定順、停止条件、Status、コマンドの内容と守備範囲が同じである


### Requirement: 同じ手順を 2 か所に書かない

各手順の見出しは pr-review-gate 配下の 1 ファイルにだけ置かなければならない（MUST）。別の段のファイルがその手順や前提に触れるときは、ファイル名と節名で参照し、中身を言い換えて再掲してはならない（MUST NOT）。各段の入口と条件付き詳細は、冒頭に読む条件を、末尾に出口（戻る手順か次に読むファイル）を書かなければならない（MUST）。gate-runner.md と段の間でも同じ規則を言い換えず、三表の照合と要約受領は stages/gate-triage.md を正本とする（MUST）。

この要件の回帰テスト（`plugins/dev-workflow/tests/pr-review-gate-index.bats`）の守備範囲は次のとおりとする。入力は pr-review-gate 配下の `.md` で、拾うのは手順の見出しの重複・索引の中のコードブロック・段の表が指すファイルの不在である。見出し以外の本文で規則を言い換えて再掲したものはテストを通ってしまうので、PR レビューで見る。この穴をテストで塞ぎ切ることは完了条件にしない。

#### Scenario: 見出しの重複が無い

- **WHEN** pr-review-gate 配下の `.md` から手順の見出し（`### 1.`・`#### 2-0.` など）を見出し行全体で集める
- **THEN** 各見出し行はちょうど 1 ファイルにだけ、1 回だけ現れる（2-1 の 3 つの見出しは括弧書きが違うので別の見出しとして数える）

### Requirement: G の再開を書いた既存要件は段ごとに新しく起こす G の入力として読む

既存要件のうち、G を「再開する」「SendMessage で G に返す」と書いた箇所、および `gate-runner.md` の「再開節」「`## 再開`」を指す箇所は、`dev-workflow-develop` の要件「G は段ごとに新しく起こし、SendMessage で再開しない」の段の表で、その時点に当たる段の G を新しく起こし、その起動指示に渡すものとして読まなければならない（MUST）。再開節が持っていた分岐は、`gate-runner.md` の段ごとの起動と入力を定める節と、照合と振り分けの入力を受け取る `stages/gate-triage.md` の「段ごとの起動と入力」と、段の入口と条件付き詳細の「G として動くとき（develop）」節のうち、その段で起こされたときの入力を書いた小節を指す（MUST）。分岐の中身（三表の機械照合、仕分け表の順への当て方、順 5 と順 6 の処理順、裁定の回数を PR コメントから数えること）は変えない（MUST NOT）。

この読み替えは、少なくとも次の既存要件に掛かる: 「同じ型の再発は決める役が方式を裁定する（順 6）」（裁定を渡して G を再開する → 裁定を渡して照合と振り分けの G を新しく起こす）・「レビュアーの要約受領の分岐を 1 か所に置く」（再開節の「レビュアーの要約受領」→ 段ごとの起動と入力を定める節の照合と振り分けの入力）・「G の指示書の failed 節と周回欄が収束ルールに揃っている」（再開節の「W の修正後の再レビュー」「保留の解除」→ 前提確認と重さ判定・保留の解除の G の入力。`周回:` は前の段から引き継ぐ）・「順 5 と順 6 が同じ周に混ざったときの処理順」（`## 再開` の「保留の解除」「決める役の裁定受領」→ 保留の解除・照合と振り分けの G の入力）。

#### Scenario: 裁定の回数は PR コメントから数える

- **WHEN** 決める役の裁定を渡されて新しく起こされた照合と振り分けの G が、この PR で裁定が何回目かを判定する
- **THEN** G は既存要件どおり 1 行目が `^決める役の裁定: (全部列挙してから直す|切り出す)$` の PR コメントを `gh api --paginate --slurp` で全ページから数え、起動指示の記述から数えない

#### Scenario: 要約受領の分岐の所在

- **WHEN** 既存要件「レビュアーの要約受領の分岐を 1 か所に置く」が求める分岐を探す
- **THEN** `stages/gate-triage.md` に 1 か所だけあり、gate-runner.md の照合の入力からその正本を指す

### Requirement: 既存要件が SKILL.md に置いた内容は段のファイルを指す

`dev-workflow-pr-review-gate`・`dev-workflow-develop`・`dev-workflow-subagent-waiting` の既存要件が `skills/pr-review-gate/SKILL.md`（「SKILL.md」「移植版 SKILL.md」「スキル」「pr-review-gate/SKILL.md の雛形」と書いたものを含む）に置く・含む・明記する・規定する・渡す・読むと定めた内容は、索引の対応表がその手順を割り当てた段のファイル（宣言は `declarations.md`、旧「前提と理由」の項目は移した先の段のファイル）を指すものとして読まなければならない（MUST）。「SKILL.md の手順 N」「SKILL.md 手順 2-1 のレビュアー向け指示ブロック」「SKILL.md の〜を読む」の形の WHEN も同じく読み替える（MUST）。「SKILL.md に再掲しない」の類の禁止は、索引・段のファイル・`declarations.md` のすべてに掛かる（MUST）。

この読み替えは、少なくとも次の既存要件の「SKILL.md は…含む/明記する/規定する/置く」の形の文に掛かる: 「スキルはリポ非依存で、flatmate 固有の仕組みには条件分岐で対応する」「flatmate issue #240 の収束ルールが織り込まれている」「auto-merge への組み込みは範囲外と明記する」「2 周目終了時に残った指摘を違反文の引用で仕分ける」「レビュアーの指摘に固定書式を課す」。既存要件が `gate-runner.md` に置くと定めた内容の読み替えは `dev-workflow-develop` 側の要件「既存要件が gate-runner.md に置いた内容のうち段に移したものは段のファイルを指す」が定める。

#### Scenario: 待ち値の再掲禁止が段のファイルにも掛かる

- **WHEN** `stages/review-run.md` の Codex 呼び出し規約を読む
- **THEN** 具体の待ち値・繰り返し回数・総待ちの上限は書かれておらず、正本 `plugins/dev-workflow/references/subagent-waiting.md` を参照している

#### Scenario: SKILL.md に置くと定めた内容の所在

- **WHEN** 既存要件「auto-merge への組み込みは範囲外と明記する」が SKILL.md に求める記述を探す
- **THEN** 旧「前提と理由」の「仕様宣言」項目の移り先である `declarations.md` に、auto-merge への組み込みは別 issue である旨が書かれている

#### Scenario: 場面別の切り出し後の所在

- **WHEN** 既存 capability の要件が、切り出し前の prepare / triage / pass / hold / declarations / gate-runner の節を名指しする
- **THEN** 移動した本文だけを次の正本として読む: 軽い通し方は prepare-light.md、区画は prepare-partitions.md、needs-reviewer の payload は prepare-reviewer.md、三表と要約受領は gate-triage.md（区画の詳細は gate-triage-partitions.md）、順 3 は triage-row3.md、止めない指摘と候補探しは triage-nonblocking.md（エピック固有部分は triage-epic.md）、収束と周の終わり・混在の条件付き処理は triage-convergence.md、手順 2-2 は triage-escalation.md、上限コメントは comment-parts.md、issue 承認は issue-approved.md、3-c は carryover.md（判定役は carryover-judge.md）、6-0 は no-point-check.md、真正性は authenticity.md と記録の形に対応した authenticity-conversation / relayed / delegated.md、文言合わせは pass-wording.md、復帰表は hold-resume.md、4 分類は hold-categories.md。すべて stages/ 配下であり、移動していない本文の要件は読み替えない

#### Scenario: 読み替えを共有する既存 capability

- **WHEN** dev-workflow-subagent-waiting、dev-workflow-spec-review、owner-question-style、dev-workflow-review-issue-candidates、dev-workflow-execution-strategy、dev-workflow-role-agent-types、dev-workflow-agent-effort、dev-workflow-pr-token-budget、destructive-git-hook の旧ファイルへの言及を確認する
- **THEN** 移動した節を名指しする言及にだけ、上の場面別の所在を適用する。仕様上のコマンド・書式・停止条件・守備範囲には読み替えを掛けない


## ADDED Requirements

### Requirement: 場面別に切り出しても宣言と return の契約を保存する

ゲートの本文を移動するとき、宣言と return の書式は変更前と一字一句同じにしなければならない（MUST）。Status 名、停止条件、コマンド、守備範囲の段落も変えてはならない（MUST NOT）。経緯の削除は、規則や許す誤りを含まない説明に限る（SHALL）。

#### Scenario: 宣言と return を比較する

- **WHEN** 固定した変更前の main と変更後から宣言・return の全雛形を集め、対応するブロックの文字列を比較する
- **THEN** すべて一致する。詳細へ移したブロックも比較対象に含み、共通 Gate Result・各 Status の欄・needs-reviewer・引き継ぎ・真正性・仕様宣言・動作確認の形を省かない

#### Scenario: 利用が残る分岐を削らない

- **WHEN** 従来経路や書式不一致の既定を削る候補にするが、呼び出し元不在を証明できない
- **THEN** 分岐とその停止条件を保存する。ファイルを条件付きで読む形への移動だけを行う

### Requirement: G が段と条件ごとに読むファイルの合計に予算を置く

ゲートの手順書には、段ごとの基礎読込と条件付き詳細を加えた読込の合計にバイト数の予算を置き、超えたら bats が非 0 で終わらなければならない（MUST）。予算値と計測ファイルの一覧は検査可能な形で管理する（SHALL）。削減量・率・トークン目標は合否の条件にしない（MUST NOT）。

Claude のファイル読込と Codex の本文注入には個別の profile を置かなければならない（MUST）。Codex は design.md の固定入力で生成した prompt 全体と条件付き追加読込を測り、注入予定の一覧の合計だけで済ませてはならない（MUST NOT）。生成物の正本集合・本文を読む表と照合し、注入済みのファイルは追加分で二度数えてはならない（MUST NOT）。

#### Scenario: 基礎の 5 場面を測る

- **WHEN** gate-reading-budget.bats を実行する
- **THEN** agents/gate-runner.md、develop/references/roles/gate-runner.md、develop/references/return-declaration.md を共通とし、prepare・review・triage・pass・hold の入口と必ず読む詳細の合計を個別に検査する。パスは plugins/dev-workflow/skills/ または agents/ から解決する。review は review-run.md と reviewer-brief.md の読込場面であり、adapter の G に追加で読ませない

#### Scenario: Codex の生成入力も測る

- **WHEN** adapter の phase gate の 4 段と phase review、一括の従来経路について固定入力で生成した prompt と、各条件で追加で読む詳細を測る
- **THEN** Claude のファイル合計とは別の profile でそれぞれを予算検査し、prompt 内の正本の欠落・余分・重複や、条件付き詳細だけの予算超過も落ちる。agent 定義を注入済みと仮定せず、定型指示・固定 REQUEST・CANONICAL SOURCE 行・sha256・正本本文を含む prompt 全体を測る。固定 REQUEST と cwd は design.md の測定定義に揃え、実行ごとに変わる PR 本文・レビュー結果・ログなどの長さを予算外と明記する

#### Scenario: 条件付きの増加も拾う

- **WHEN** 基礎 profile を変えずに条件付き詳細の本文だけをその profile の予算を超えて増やした fixture を検査する
- **THEN** 非 0 で終わる。条件付き詳細は少なくとも 1 profile に含まれ、同じファイルは profile 内で 1 回だけ数える。段ごとの複合条件の和集合も測る

#### Scenario: 予算の値を実測から離さない

- **WHEN** 予算を更新する
- **THEN** 実測以上かつ実測の 1.1 倍以下の整数にし、その範囲を外れた fixture は落ちる

#### Scenario: 予算と一覧の不備

- **WHEN** 予算の profile が未知・欠落・重複、不正な数値、または一覧のファイルが不在の fixture を検査する
- **THEN** 非 0 で終わる。予算ちょうどの fixture は通る。予算 +1 バイトの fixture は落ちる

#### Scenario: 計測の守備範囲

- **WHEN** 予算と読む一覧の検査を確認する
- **THEN** 入力は一覧・本文・予算値で、大きさ超過・不在・一覧の欠落を拾うと明記する。同じ大きさでの本文の入れ替えや条件の読み違いを通し得ること、自然文の参照の解釈はレビューでも見ることを明記し、穴を塞ぎ切ることを完了条件にしない

### Requirement: 場所を固定した文言テストを移動可能にする

ゲートと develop の関係手順書の文言テストは、移動した規則が関係手順書のどこかにあることで満たせるようにしなければならない（MUST）。入口からの到達と読む場面の正しさは関係テスト・予算とレビューで確かめる（SHALL）。

文言検査の守備範囲: 入力は pr-review-gate 配下の .md と develop の関係手順書を連結した本文（回帰検査では同じ構成の fixture）である。既存の文言検査が確認する規則の文字列が連結対象の全体から欠落した誤りを拾う。「停止条件の文が別段の詳細にだけ残り、本来の入口から参照されない」入力や「必要な文が残る一方で、逆の指示も別の段落にある」入力が文言検査を通ることは許す。到達や条件は関係テスト、量は予算、意味はレビューでも見る。これらの穴を文言検査で塞ぎ切ることは完了条件にしない。この守備範囲は、量・ファイルの不在・一覧の欠落を見る予算検査の守備範囲とは区別する。

#### Scenario: 文の移動と欠落を区別する

- **WHEN** 既存の規則の文を別ファイルへ移した fixture と、その文を関係手順書全体から消した fixture を検査する
- **THEN** 前者は通り、後者は落ちる。特定ファイルの文字列検査を単に消して成功させない

#### Scenario: 文言が残る入力の通過を許す

- **WHEN** 必要な文は連結対象に残るが、入口から参照されない別段の詳細にある fixture、または逆の指示も別の段落にある fixture を文言検査する
- **THEN** 文言検査だけでは通過を許す。この検査の成功を到達・条件・規則の正しさの保証とせず、穴を塞ぎ切ることを完了条件にしない

### Requirement: 段ごとの字数と移した段落を報告する

変更前後の読むファイルの合計を UTF-8 ロケールの wc -m で測り、段ごとに PR 本文と親エピックに記録しなければならない（MUST）。変更前は指定された固定 main とし、条件付きの差は内訳を添える（SHALL）。分けた段落ごとに元・先・読む条件を PR 本文に書く（MUST）。

#### Scenario: 数字と測定範囲を再現できる

- **WHEN** PR 本文の prepare・review・triage・pass・hold と条件付き profile の前後の表を読む
- **THEN** revision・ロケール・共通分・ファイル一覧・重複除外・hook 注入を除く測り方があり、同じ値を再現できる。Codex の生成 prompt は別表とし、固定入力・定型文を含むこと、追加読込の内訳、実行ごとに変わる入力の長さは予算外であることも記す。減った量は合否に使わない。親エピックにも同じ前後の表への記録がある
