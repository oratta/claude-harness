## MODIFIED Requirements

### Requirement: 周回は前の段から引き継ぐ

G は `周回:` を前の段の Gate Result の値から引き継がなければならない（MUST）。W の修正後の再レビューで起こされた前提確認と重さ判定の G だけが 1 増やす（MUST）。ただし前の Gate Result に行 `取り直し: 説明の整合（周に数えない）` がある failed のあとは増やさない（MUST。pr-review-gate の手順 4-2 の不合格はレビューの指摘の周ではない）。戻した指摘が順 3 だけの修正のあとは周を消費しない（`stages/triage.md` の既存規則のまま）。取り直し行は 4-2 の failed が初めて出し、Gate Result の `周回:` 行の直後に箇条書き記号なしで一度だけ書く（MUST）。取り直した前提確認の `needs-reviewer`、照合と振り分けの `次の段へ`、合格処理、保留・保留の解除、判定待ちの Gate Result にも同じ行を引き継ぎ、順 3 だけの修正による往復でも残す（MUST）。4-2 以外の failed で `次の段: 前提確認と重さ判定` に戻すときは行を外し（MUST）、ゲートの新規開始と CI の見張りのあとの全体レビューには持ち越さない（MUST NOT）。取り直しの前提確認はレビュー範囲を今回の修正差分から判定し直し、前回の `（全体レビュー: …）` の注記を流用してはならない（MUST NOT。今回全体レビューにしたときだけ付け、その後の段は注記も引き継ぐ）。

#### Scenario: 再レビューの周

- **WHEN** 周回 1 で、行 `取り直し: 説明の整合（周に数えない）` を持たない failed が返り、W の修正後に前提確認と重さ判定の G を起こす
- **THEN** その G の Gate Result は `周回: 2` を持つ

#### Scenario: 説明の整合の取り直し

- **WHEN** 周回 2 の合格処理の G が取り直しの行を持つ failed を返し、W の修正後に前提確認と重さ判定の G を起こす
- **THEN** その G の Gate Result は `周回: 2` を持つ

#### Scenario: 1 周目の説明の整合の取り直し

- **WHEN** 周回 1 の合格処理の G が取り直しの行を持つ failed を返し、W の修正後に前提確認と重さ判定の G を起こす
- **THEN** その G の Gate Result は `周回: 1` を持つ

#### Scenario: 取り直し行は段をまたいで残る

- **WHEN** 取り直しの前提確認の G が `needs-reviewer` を返し、照合と振り分けの G が `次の段へ` を返す
- **THEN** どちらの Gate Result も `周回:` 行の直後に取り直し行を持ち、合格処理の G に渡る

#### Scenario: 通常の failed に戻ると取り直し行を外す

- **WHEN** 取り直しの周の照合と振り分けの G が、止める指摘で 4-2 以外の failed（`次の段: 前提確認と重さ判定`）を返す
- **THEN** その Gate Result は取り直し行を持たず、次の前提確認と重さ判定の G は `周回:` を 1 増やす

### Requirement: 入口 0 は記録先を決める
SKILL.md は 1 ループの最初の工程「入口 0」として記録先の決め方を規定しなければならない（MUST）: issue があれば（番号・URL・自然文マッチ）それを記録先にする。無ければ issue を切らず、W が worktree を用意された直後に空 commit（`git commit --allow-empty`）を積んで push し、`gh pr create --draft` で Draft PR を開いてそれを記録先にする。この Draft PR は仕様化判断を記録する**前**に存在していなければならない（MUST。記録先が無い状態で判定を先に進めない）。Draft PR を記録先にする場合、受け入れ条件は PR 本文（位置づけ・動作確認ポイント）に書かなければならず（MUST）、受け入れ条件自体を省いてはならない（MUST NOT）。記録先を PR にした場合、PR 本文に `Closes` / `Fixes` / `Refs #N` の issue 参照を書いてはならない（MUST NOT。書くと pr-review-gate の照合先がその issue に移る。エピックの子は子 issue が記録先なので `Closes #子` を書く）。仕様化判断（`仕様化判断: する|しない`）・仕様レビュー結果（`仕様レビュー: APPROVE|REQUEST_CHANGES`）は記録先のコメントに置く（SHALL）。仕様宣言（`対象 HEAD:` 付き。書式の正本は pr-review-gate スキル手順 3-b）は記録先が issue か Draft PR かにかかわらず常に **PR コメント**に置き、記録先が issue のときに issue コメントへ置いてはならない（MUST NOT。pr-review-gate 手順 5 は PR のコメントで 4 見出しを照合し、`対象 HEAD:` 規約は PR の HEAD に紐づくため）。軽い通し方（`dev-workflow-spec-review` の「些細な修正は軽い通し方で新しいテストと W の起動を省く」Requirement）を当てる場合だけは例外で、記録先が無いときは本体が Draft PR を作る（SHALL）。そのときの順序は、本体が依頼から受け入れ条件を整理する → その受け入れ条件で軽い通し方を当てるかを決める → 当てるなら本体が空 commit・push・`gh pr create --draft` で Draft PR を開き受け入れ条件を本文に書く → 仕様化判断を Draft PR のコメントに記録する、の 1 通りとし（MUST）、当てないなら本体は Draft PR を作らずに W を起こし、W がこれまでどおり作る（SHALL）。SKILL.md は入口 0 にこの例外と順序を、正本（`references/light-path.md`）を指す形で書かなければならない（MUST）。SKILL.md はこの分離（記録先に置くもの＝仕様化判断・仕様レビュー結果、PR コメントに置くもの＝仕様宣言）を入口 0 に明記しなければならない（MUST）。issue を切るのは追跡・キュー・議論が要るとき（エピック／無人キュー／判断を残す議論）に限ることを明記する（SHALL）。

#### Scenario: issue が無い依頼は Draft PR が記録先になる
- **WHEN** 会話で依頼された変更に対応する issue が無い
- **THEN** SKILL.md は issue を切らず、worktree 直後に空 commit → push → `gh pr create --draft` で Draft PR を開いてから仕様化判断を記録し、受け入れ条件を PR 本文に書き、PR 本文に issue 参照を書かないよう指示している

#### Scenario: issue を切る条件が限定されている
- **WHEN** SKILL.md の入口 0 を読む
- **THEN** issue を切る条件がエピック・無人キュー・判断を残す議論の 3 つに限定されている

#### Scenario: 仕様宣言の投稿先は記録先と分離されている
- **WHEN** SKILL.md の入口 0 を読む
- **THEN** 仕様化判断・仕様レビュー結果は記録先のコメントに置くと書かれ、仕様宣言は記録先が issue でも PR コメントに置くと書かれており、記録先のコメントに置くものの列挙に仕様宣言が含まれていない

#### Scenario: 軽い通し方では記録先の Draft PR を本体が作る
- **WHEN** SKILL.md の入口 0 を読む
- **THEN** 記録先が無い依頼に軽い通し方を当てるときだけ本体が Draft PR を作ることと、受け入れ条件の整理 → 軽い通し方の判断 → Draft PR の作成 → 仕様化判断の記録の順序が、`references/light-path.md` を指して書かれている

### Requirement: G は段ごとに新しく起こし、SendMessage で再開しない

`plugins/dev-workflow/skills/develop/SKILL.md` の (4) は、G を段ごとに新しく spawn することを規定しなければならない（MUST）。1 体の G は次の 4 つの段のうち 1 つだけを担当する（MUST）。

| 段 | 本体が起こす時点 | G が読むファイル（`skills/pr-review-gate/` から） | 返しうる Status |
|---|---|---|---|
| 前提確認と重さ判定 | ゲートの開始、W の修正後の再レビュー（failed の `次の段: 前提確認と重さ判定`。`原因: 軽い通し方の条件外` を除く）、保留の解除が `次の段: 前提確認と重さ判定` を返したとき、CI の見張りで `ready` になったあとの取り直し | `stages/prepare.md`（W の修正後の再レビューのときは加えて `stages/triage-convergence.md` の収束ルールの節と「W の修正後の再レビュー」の入力） | `needs-reviewer` / failed（軽い通し方の条件外） / 保留 / `重複で降りた` |
| 照合と振り分け | レビュー要約・補足レビューの結果・決める役の裁定・直し方の判定を受け取ったとき、戻した指摘が順 3 だけの修正のあと（failed の `次の段: 照合と振り分け`） | `stages/triage.md` | `次の段へ` / failed / 保留 / `needs-reviewer`（補足） / `needs-decider` / `needs-fix-check` / `review-incomplete` |
| 合格処理 | 照合と振り分けが止める指摘なしで終わったとき、保留の解除が `次の段: 合格処理` を返したとき、引き継ぎの判定を受け取ったとき（合格処理の G が `needs-carryover-judge` を返したあと） | `declarations.md` と `stages/pass.md`（前の HEAD の許容があるときは加えて `stages/carryover.md`、保留を返すとき・`needs-carryover-judge` を返すときは加えて `stages/hold.md`） | passed / failed（確かめ方の非 0、または手順 4-2 の食い違い。`次の段: 前提確認と重さ判定`） / 保留 / `needs-carryover-judge` |
| 保留の解除 | 主の回答が届いたとき | `stages/hold.md`（切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage-nonblocking.md` の置き場所の段落・候補探しと `stages/triage-epic.md` の段 C の節） | 復帰手順の表どおりに `次の段へ`（`次の段:` は合格処理か前提確認と重さ判定） / failed / needs-decider / 保留 |

本体は G の起動指示に `段: <段の名前>` の 1 行を書かなければならない（MUST）。`skills/develop/SKILL.md` の (4)（`(4) G を` で始まる行から、その行を含むコードブロックの閉じ ``` の行まで）と `skills/develop/references/roles/gate-runner.md` は、`SendMessage` の語と `G を再開` の文字列を持ってはならない（MUST NOT）。SKILL.md の (4) の「G の起動・再開・手渡しの指示」「G を再開か手渡しで起こして」も段ごとの起動の言い方に書き換える（MUST）。G への SendMessage は `skills/develop/references/decision-criteria.md`「コンテキスト上限（サブエージェントの手渡し）」の停止の指示だけに残し、その規則は decision-criteria.md にだけ書く（MUST）。`gate-runner.md` の「時点ごとに読むファイル」の表は、上の段の表に揃えなければならない（MUST）。

保留の解除の G は、復帰手順の表が別の段の作業に進むと示したとき、その作業を自分で行ってはならず（MUST NOT）、Status `次の段へ` と `次の段:` で返さなければならない（MUST）。許容したとき・切り出して残りが無いときは `次の段: 合格処理`、許容せず代替案で手順 2 からやり直すときは `agent-review:failed` に付け替えて failed（`次の段: 前提確認と重さ判定`）で返す（MUST）。`次の段へ` の `次の段: 前提確認と重さ判定` は、W の修正が要らないときだけに使う。

W の修正後の再レビューで起こされた前提確認と重さ判定の G は、前の周の指摘を仕分けコメントから読み、`stages/triage-convergence.md` の収束ルールどおり差分限定か全体レビューかを自分で判定し、全体レビューにしたときは 2 つの行数を PR コメントに記録しなければならない（MUST）。

保留の解除のあとで起こされた合格処理の G（前の Gate Result が `段: 保留の解除`）は、今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントがあれば、宣言を出し直してはならず（MUST NOT）、手順 5 の真正性確認から入らなければならない（MUST）。そのコメントが無ければ（切り出しの確認を解除した場合）、`declarations.md` の手順 3 から入らなければならない（MUST）。照合と振り分けのあとの合格処理は、前の Gate Result の `段: 照合と振り分け` で見分ける（MUST。`次の段: 合格処理` は保留の解除の Gate Result にもあるため入口の判別に使わない）。許容済みの PR で HEAD が動いていたときの許容の引き継ぎ（手順 3-c）は、合格処理の G が宣言の前に `stages/carryover.md` を読んで試す（MUST）。引き継ぎの判定を受けて起こされた合格処理の G（前の Gate Result が `段: 合格処理`・Status `needs-carryover-judge`）は、`declarations.md` の手順 3 から入り直し、3-c で PR の判定の記録を読まなければならない（MUST）。

この要件は、develop の本体がレビュアーを起こす adapter 経路（起動指示が `レビュー経路: adapter`）に掛かる。従来経路の G はレビューを自分の起動の中で起こすので、手順 1〜5 と保留までを 1 体で続けてよい（MAY）。そのときの Gate Result は `段: 一括（従来経路）`、`次の段: なし` と書く（MUST）。

#### Scenario: SendMessage による G の再開の記述が無い

- **WHEN** `plugins/dev-workflow/tests/` の develop の役割の bats が `skills/develop/SKILL.md` の (4) と `gate-runner.md` を検査する
- **THEN** 段ごとに新しい G を起こす記述と `段:` の行の指示があり、SKILL.md の (4) の範囲と gate-runner.md の全体に `SendMessage` と `G を再開` の文字列が無い

#### Scenario: 従来経路の G

- **WHEN** develop の本体以外の呼び出し元が `レビュー経路: 従来` で G を起こす
- **THEN** G は手順 1〜5 と保留までを 1 体で続けてよく、Gate Result に `段: 一括（従来経路）` と `次の段: なし` を書く

#### Scenario: 代替案への作り直し

- **WHEN** 主が許容せず、代替案で手順 2 からやり直すと答える
- **THEN** 保留の解除の G は `agent-review:failed` に付け替えて failed（`次の段: 前提確認と重さ判定`）で返し、次の前提確認と重さ判定の G は W の修正後の再レビューとして `周回:` を 1 増やす

#### Scenario: 保留の解除のあとの合格処理

- **WHEN** 保留の解除の G が主の許容を受けて `次の段へ`・`次の段: 合格処理` で返し、本体が合格処理の G を起こす
- **THEN** 合格処理の G は前の Gate Result の `段: 保留の解除` を見て、今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントがあれば宣言を出し直さず手順 5 の真正性確認から入る

#### Scenario: 切り出しの確認を解除したあとの合格処理

- **WHEN** 照合と振り分けの G が切り出すかを主に聞く保留を返し、主が「切り出す」と答えて保留の解除の G が `次の段: 合格処理` で返す
- **THEN** 今の HEAD の `対象 HEAD:` を持つ `## リスク宣言` コメントが無いので、合格処理の G は `declarations.md` の手順 3 から入る

#### Scenario: 保留の解除の G が切り出しの確認の回答で追加に読むもの

- **WHEN** `gate-runner.md` の「時点ごとに読むファイル」の表の保留の解除の行を読む
- **THEN** 切り出しの確認に「切り出す」と答えられたときは加えて `stages/triage-nonblocking.md` の置き場所の段落・候補探しと `stages/triage-epic.md` の段 C の節を読むことが書かれている

#### Scenario: CI の見張りのあとの取り直し

- **WHEN** CI の見張りが `ready` になり、本体がゲートを取り直す
- **THEN** 本体は前提確認と重さ判定の G を新しく起こし、前の G を再開しない

#### Scenario: 段の表に needs-fix-check がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 照合と振り分けの行の起こす時点に「直し方の判定を受け取ったとき」があり、返しうる Status に `needs-fix-check` がある

#### Scenario: 段の表に needs-carryover-judge がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 合格処理の行の起こす時点に「引き継ぎの判定を受け取ったとき」があり、返しうる Status に `needs-carryover-judge` がある

#### Scenario: 段の表の前提確認と重さ判定に failed がある

- **WHEN** SKILL.md の (4) と `gate-runner.md` の段ごとの表を読む
- **THEN** 前提確認と重さ判定の行の返しうる Status に failed があり、それが軽い通し方の条件外のときに返るものだと分かる

#### Scenario: 引き継ぎの判定のあとの合格処理

- **WHEN** 合格処理の G が `needs-carryover-judge` で返し、本体が判定の記録を投稿して合格処理の G を新しく起こす
- **THEN** 新しい合格処理の G は前の Gate Result の `段: 合格処理`・Status `needs-carryover-judge` を見て `declarations.md` の手順 3 から入り直し、3-c で判定の記録を読む
