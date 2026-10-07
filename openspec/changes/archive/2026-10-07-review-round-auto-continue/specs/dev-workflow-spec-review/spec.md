## MODIFIED Requirements

### Requirement: 仕様レビューは 2 周で確定し結果を issue に記録する
仕様レビューは初回と修正後の差分再レビュー 1 回の計 2 周を既定とする（MUST）。3 周目以降の周も差分再レビューとし、前の周の指摘が閉じたかと、修正で新たに生じた矛盾だけを見る（MUST）。

2 周目以降の周の終わりに BLOCKER が残ったら（R1 の結果が `REQUEST_CHANGES`）、本体は主に聞く前に、決める役（`subagent_type: dev-workflow:decider`）に残った BLOCKER の直し方の判定を依頼しなければならない（MUST。判定役・入力・返答の 1 行目・判定の記録と事後報告の書式は `dev-workflow-develop` の「レビューの 2 周目以降の周の終わりは直し方の判定を通して続ける」Requirement が正本）。判定が「決まっている」で、PR トークン上限の計測が exit 2 でなければ、本体は主に聞かずに W を再開して artifact を直させ、R1 に次の周の差分再レビューをさせる（MUST）。interactive と unmanned で同じに扱う（MUST）。

主に聞くのは次の 2 つのときだけとする（MUST）: ①直し方の判定が「選び直しが要る」（設計の選択肢が複数ある・記録先の範囲を変える・前の周で「決まっている」とした直し方で閉じなかった。入力不足で判定が出なかったときも含む） ②PR トークン上限の計測が exit 2（`scripts/pr-token-budget.sh` が上限超を返した）。①のときは記録先に `needs-approval` ラベルを付けて経緯をコメントし（MUST）、interactive モードでは本体が AskUserQuestion で判断を仰ぎ、unmanned モードではそのサイクルを終了する（MUST）。②のときは `skills/develop/SKILL.md`「PR トークン上限」の exit 2 の手順に従う（MUST）。

判定結果は記録先のコメントとして記録しなければならず（MUST）、その書式は `references/roles/spec-reviewer.md` に置く（SHALL）。コメントの 1 行目は正規表現 `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` に完全一致し、2 行目以降に周回数・レビュアーのモデル・残課題を書く（MUST）。

投稿者は R1 の spawn 方法で分かれる（SHALL）。`general-purpose` に `model` を明示して spawn した R1 は、従来どおり自分で `gh issue comment` / `gh pr comment` を実行して投稿する。`subagent_type: dev-workflow:decider` で spawn した R1 は `Bash` を持たず投稿できないため、**本体が R1 の return を同じ書式で代理投稿しなければならない**（MUST）。代理投稿でも書式・記録先・「APPROVE が記録されるまで実装に進まない」の判定は変わってはならない（MUST NOT）。同様に decider として起こした R1 は記録先を `gh` で読めないため、**呼び出し側が記録先の本文と関連コメント（受け入れ条件・`仕様化判断:` の記録）を入力文に貼り付けなければならない**（MUST）。`references/roles/spec-reviewer.md` は、レビュアーへの入力と結果の記録の節にこの 2 経路（自分で投稿する場合と本体が代理投稿する場合）を書き分けなければならない（MUST）。

#### Scenario: 2 周の既定と直し方の判定による続行が書かれている
- **WHEN** SKILL.md または `references/roles/spec-reviewer.md` を読む
- **THEN** 既定 2 周・差分限定の再レビュー・2 周目以降の周の終わりに BLOCKER が残れば決める役の直し方の判定を通すこと・残った BLOCKER がすべて直し方の決まったもので PR トークン上限の内側なら主に聞かず次の周を回すこと・主に聞くのは「方針の選び直しが要る」と「PR トークン上限を超える（`pr-token-budget.sh` が exit 2）」の 2 つだけであることが書かれ、「3 周目の例外は設けない」の文は無い

#### Scenario: 直し方が決まっている BLOCKER だけが残る
- **WHEN** 2 周目の R1 の結果が `REQUEST_CHANGES` で、決める役の返答の 1 行目が `裁定: 可` で、PR トークン上限の計測が exit 0
- **THEN** 本体は `needs-approval` を付けず主にも聞かずに、判定の記録を記録先に投稿して W を `段: spec` で再開し、R1 に 3 周目の差分再レビューをさせ、3 周目の結果を受け取ったら事後報告を記録先に投稿する

#### Scenario: 方針の選び直しが要る BLOCKER が残る
- **WHEN** 2 周目以降の周の終わりに残った BLOCKER について、決める役の返答の 1 行目が `裁定: 否`
- **THEN** 本体は判定の記録を記録先に投稿したうえで `needs-approval` を付けて経緯をコメントし、interactive は AskUserQuestion、unmanned はサイクル終了とする

#### Scenario: 続行の前にトークン上限を超えている
- **WHEN** 直し方の判定が「決まっている」だったが、W を再開する前の PR トークン上限の計測が exit 2
- **THEN** 本体は W を再開せず、PR トークン上限の exit 2 の手順で主に「続けるか、範囲外として閉じるか」を問う

#### Scenario: 結果コメントの書式と投稿手順が spec-reviewer.md にある
- **WHEN** `references/roles/spec-reviewer.md` を読む
- **THEN** `^仕様レビュー: (APPROVE|REQUEST_CHANGES)$` の書式と、周回数・モデル・残課題を含めて記録先にコメントする手順が書かれている

#### Scenario: decider として起こした R1 は本体が代理投稿する
- **WHEN** 本体が R1 を `subagent_type: dev-workflow:decider` で spawn し、R1 が判定を return する
- **THEN** R1 は `gh` を実行せず判定と理由を return し、本体が同じ 1 行目書式で記録先にコメントする

#### Scenario: decider として起こした R1 には記録先の本文が入力で渡る
- **WHEN** `references/roles/spec-reviewer.md` の「レビュアーへの入力」を読む
- **THEN** decider 経路では記録先の本文と関連コメントを呼び出し側が入力文に貼ること、`gh` で自分で取りに行かないことが書かれている
