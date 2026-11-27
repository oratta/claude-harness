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
