## MODIFIED Requirements

### Requirement: 入口 0 は記録先を決める
SKILL.md は 1 ループの最初の工程「入口 0」として記録先の決め方を規定しなければならない（MUST）: issue があれば（番号・URL・自然文マッチ）それを記録先にする。無ければ issue を切らず、W が worktree を用意された直後に空 commit（`git commit --allow-empty`）を積んで push し、`gh pr create --draft` で Draft PR を開いてそれを記録先にする。この Draft PR は仕様化判断を記録する**前**に存在していなければならない（MUST。記録先が無い状態で判定を先に進めない）。Draft PR を記録先にする場合、受け入れ条件は PR 本文（位置づけ・動作確認ポイント）に書かなければならず（MUST）、受け入れ条件自体を省いてはならない（MUST NOT）。記録先を PR にした場合、PR 本文に `Closes` / `Fixes` / `Refs #N` の issue 参照を書いてはならない（MUST NOT。書くと pr-review-gate の照合先がその issue に移る。エピックの子は子 issue が記録先なので `Closes #子` を書く）。仕様化判断（`仕様化判断: する|しない`）・仕様レビュー結果（`仕様レビュー: APPROVE|REQUEST_CHANGES`）は記録先のコメントに置く（SHALL）。仕様宣言（`対象 HEAD:` 付き。書式の正本は pr-review-gate スキル手順 3-b）は記録先が issue か Draft PR かにかかわらず常に **PR コメント**に置き、記録先が issue のときに issue コメントへ置いてはならない（MUST NOT。pr-review-gate 手順 5 は PR のコメントで 3 見出しを照合し、`対象 HEAD:` 規約は PR の HEAD に紐づくため）。SKILL.md はこの分離（記録先に置くもの＝仕様化判断・仕様レビュー結果、PR コメントに置くもの＝仕様宣言）を入口 0 に明記しなければならない（MUST）。issue を切るのは追跡・キュー・議論が要るとき（エピック／無人キュー／判断を残す議論）に限ることを明記する（SHALL）。

#### Scenario: issue が無い依頼は Draft PR が記録先になる
- **WHEN** 会話で依頼された変更に対応する issue が無い
- **THEN** SKILL.md は issue を切らず、worktree 直後に空 commit → push → `gh pr create --draft` で Draft PR を開いてから仕様化判断を記録し、受け入れ条件を PR 本文に書き、PR 本文に issue 参照を書かないよう指示している

#### Scenario: issue を切る条件が限定されている
- **WHEN** SKILL.md の入口 0 を読む
- **THEN** issue を切る条件がエピック・無人キュー・判断を残す議論の 3 つに限定されている

#### Scenario: 仕様宣言の投稿先は記録先と分離されている
- **WHEN** SKILL.md の入口 0 を読む
- **THEN** 仕様化判断・仕様レビュー結果は記録先のコメントに置くと書かれ、仕様宣言は記録先が issue でも PR コメントに置くと書かれており、記録先のコメントに置くものの列挙に仕様宣言が含まれていない
