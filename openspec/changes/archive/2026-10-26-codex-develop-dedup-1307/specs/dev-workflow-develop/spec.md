## MODIFIED Requirements

### Requirement: G の再開を前提にした既存要件の読み替え

既存要件のうち G の「再開」「SendMessage で G に渡す」「G を再開して再レビュー」と書いた箇所は、上の要件「G は段ごとに新しく起こし、SendMessage で再開しない」の表で、その時点に当たる段の G を新しく起こし、その起動指示に渡すものとして読まなければならない（MUST）。`レビュー経路: adapter` で起動済みの同一 G が行の無い再開指示でも adapter 経路を保つ規則は、再開が無いので `gate-runner.md`・SKILL.md・`plugins/dev-workflow/references/codex-develop.md` から消さなければならない（MUST）。本体がすべての G の起動指示に `レビュー経路: adapter` の 1 行を書く規則は変えない（本文は SKILL.md の「Role profile の選択」節に置き、`references/codex-develop.md` はそこを指す）。

`stages/prepare.md` に置くとした「レビュー実行者:」PR コメントの段落は、上の要件「『レビュー実行者:』コメントの段落は照合と振り分けの段に置く」どおり `stages/triage.md` を指すものとして読む（MUST）。

この読み替えは、少なくとも次の既存要件に掛かる: 「1 ループは W→R1→W→G の順で回る」（修正後は G を再開して差分再レビュー）・「役割の指示書は references/roles/ に分かれている」（要約を G に SendMessage で渡す）・「役割のモデルは事前分類と残量モードで決める」（Scenario「再開前にコンテキスト量を測る」の G の部分は適用しない）・「G の needs-decider を受けた本体の動き」（裁定を SendMessage で渡して G を再開する）・「G はレビュー経路を起動指示の 1 行で判別する」（Scenario「adapter 経路で起動済みの G を行無しで再開」は再開が無いので適用しない）・「本体は adapter 経路の needs-reviewer で phase review の投げ先を選び直して記録する」（Claude の G は SendMessage で再開して渡す）・「G は段ごとに要るファイルだけを読む」・「既存要件が gate-runner.md に置いた内容のうち段に移したものは段のファイルを指す」（「レビュー実行者:」の段落の移し先と、再開節の移し先）。

#### Scenario: 裁定の渡し方

- **WHEN** 既存要件「G の needs-decider を受けた本体の動き」に従い、本体が決める役の裁定を受け取る
- **THEN** 本体は照合と振り分けの G を新しく起こし、前の Gate Result ブロックと裁定を起動指示で渡す

#### Scenario: adapter 経路の保持規則が無い

- **WHEN** `gate-runner.md`・SKILL.md・`references/codex-develop.md` を読む
- **THEN** 行の無い再開指示で adapter 経路を保つ規則が無い。G の起動指示に常に `レビュー経路: adapter` を書く規則は、SKILL.md が本文を持ち、`references/codex-develop.md` はその本文を持たず SKILL.md の「Role profile の選択」節と `gate-runner.md`「レビュー経路の判別」を指している

