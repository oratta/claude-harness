## MODIFIED Requirements

### Requirement: 主への依頼文は宣言を写さず正本の型で書き、照合される行は変えない
pr-review-gate の `declarations.md` の手順 3 は「この形式以外で主にリスク承認を求めない」を持ってはならず（MUST NOT）、主への依頼文は宣言を写さず `~/.claude/output-styles/readable.md` の節 3 の型で書くと定めなければならない（MUST）。宣言の行頭の `リスクなし` / `主のリスク許容が必要`、2 行目の `対象 HEAD:`、`- 該当する観点:` などの項目、返事の照合に使う `主の回答: 許容` は変えてはならない（MUST NOT。自動マージの判定と `owner-reply-check.sh` が照合している）。`stages/hold.md` は、宣言が論点なしのときは依頼も論点なしの短い形で書くと定め、行数は自前で決めずに正本の節 3 の論点の無い依頼の決まり（対話のセッションでは題名・アクション・論点・推奨の 4 行、目的を足せば 5 行。ほかの場所は使う場所の表）を指さなければならない（MUST）。再開の案内・満たさなかった条件はアクションの行に畳むか区切りの下に置く。`stages/hold.md`・`declarations.md`・`stages/pass.md` は、依頼の行を旧い型の語（`答え方`・`3〜4 行`・`OK すると何が起きるかを中身で書いた質問`）で指してはならない（MUST NOT）。

#### Scenario: 照合される行は変わらない
- **WHEN** 手順 3 の雛形を読む
- **THEN** 1 行目は `## リスク宣言`、2 行目は `対象 HEAD: <$HEAD_SHA 40桁フル>` のままで、`この形式以外で主にリスク承認を求めない` の文は無く、主への依頼文は宣言を写さず `~/.claude/output-styles/readable.md` の節 3 の型で書くと書かれている

#### Scenario: 論点なしの宣言の依頼は短い
- **WHEN** `stages/hold.md` の、宣言を受けて主に依頼する箇所を読む
- **THEN** 宣言が論点なしのときは、依頼を論点なしの短い形で書き、行数は正本の節 3 の論点の無い依頼の決まりを指し、宣言を写さないと書かれ、`3〜4 行` と `答え方の行` は無い

#### Scenario: 参照先に旧い型の語が残っていない
- **WHEN** `plugins/dev-workflow/skills/pr-review-gate/declarations.md`・`stages/hold.md`・`stages/pass.md` を `答え方`・`3〜4 行`・`OK すると何が起きるかを中身で書いた質問` で検索する
- **THEN** どれも見つからない
